import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/calendar_event.dart';
import '../../models/account.dart';
import '../../models/todo_task.dart';
import '../../models/settings.dart';

const _kDataDirKey = 'dataDirectoryPath';
const _kBookmarkKey = 'dataDirectoryBookmark';
const _kDataFileName = 'calendartask_data.json';

class AppDatabase {
  static AppDatabase? _instance;
  static Future<AppDatabase>? _initFuture;
  late SharedPreferences _prefs;
  late Map<String, dynamic> _data;
  late String _dataFilePath;

  // File watcher
  StreamSubscription<FileSystemEvent>? _watcherSubscription;
  final StreamController<void> _externalChangeController =
      StreamController<void>.broadcast();
  bool _writingInternally = false;
  Timer? _debounceTimer;

  /// Fires whenever another process/machine modifies the data file.
  Stream<void> get externalChanges => _externalChangeController.stream;

  AppDatabase._();

  static Future<AppDatabase> getInstance() {
    _initFuture ??= _create();
    return _initFuture!;
  }

  static Future<AppDatabase> _create() async {
    final db = AppDatabase._();
    db._prefs = await SharedPreferences.getInstance();
    db._dataFilePath = await _resolveDataFilePath(db._prefs);
    await db._loadData();
    db._startWatcher();
    _instance = db;
    return db;
  }

  static Future<String> _resolveDataFilePath(SharedPreferences prefs) async {
    // Try to restore a previously saved security-scoped bookmark (macOS only).
    if (Platform.isMacOS) {
      final bookmark = prefs.getString(_kBookmarkKey);
      if (bookmark != null) {
        try {
          final bookmarks = SecureBookmarks();
          final resolved = await bookmarks.resolveBookmark(bookmark);
          await bookmarks.startAccessingSecurityScopedResource(resolved);
          final dir = resolved.path.replaceAll(RegExp(r'/$'), '');
          await prefs.setString(_kDataDirKey, dir);
          return '$dir/$_kDataFileName';
        } catch (e) {
          debugPrint('[DB] Failed to resolve bookmark: $e');
          // Fall through to path-based fallback below
        }
      }
    }

    String? dir = prefs.getString(_kDataDirKey);
    if (dir == null) {
      final appSupport = await getApplicationSupportDirectory();
      dir = appSupport.path;
      await prefs.setString(_kDataDirKey, dir);
    }
    return '$dir/$_kDataFileName';
  }

  Future<void> _loadData() async {
    final file = File(_dataFilePath);
    if (file.existsSync()) {
      try {
        final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        _data = json;
        return;
      } catch (_) {
        // Fall through to migration if file is corrupt
      }
    }
    await _migrateFromPrefs();
  }

  Future<void> _migrateFromPrefs() async {
    _data = {};
    for (final key in ['accounts', 'meetingHistory', 'todos', 'dismissedMeetings']) {
      final val = _prefs.getString(key);
      if (val != null) {
        _data[key] = jsonDecode(val);
      }
    }
    await _save();
    // Clean up SharedPreferences after migration
    for (final key in ['accounts', 'meetingHistory', 'todos', 'dismissedMeetings']) {
      await _prefs.remove(key);
    }
  }

  Future<void> _save() async {
    _writingInternally = true;
    await File(_dataFilePath).writeAsString(jsonEncode(_data), flush: true);
    // Allow extra time for the OS / sync daemon to process our own write
    // before we start treating file events as external changes.
    Future.delayed(const Duration(seconds: 3), () {
      _writingInternally = false;
    });
  }

  // --- File watcher ---

  void _startWatcher() {
    _watcherSubscription?.cancel();
    _watcherSubscription = null;

    final parentDir = File(_dataFilePath).parent;
    try {
      _watcherSubscription = parentDir
          .watch(events: FileSystemEvent.modify)
          .listen(_onFileSystemEvent, onError: (e) {
        debugPrint('[DB] Watcher error: $e');
      });
      debugPrint('[DB] Watching ${parentDir.path} for changes to $_kDataFileName');
    } catch (e) {
      debugPrint('[DB] Could not start file watcher: $e');
    }
  }

  void _onFileSystemEvent(FileSystemEvent event) {
    if (event.path != _dataFilePath) return;
    if (_writingInternally) return;

    // Debounce: iCloud/Dropbox may fire several events per sync cycle.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      await _reloadExternally();
    });
  }

  Future<void> _reloadExternally() async {
    final file = File(_dataFilePath);
    if (!file.existsSync()) return;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      _data = json;
      debugPrint('[DB] Reloaded data from external change');
      _externalChangeController.add(null);
    } catch (e) {
      debugPrint('[DB] External reload failed: $e');
    }
  }

  // --- Static helpers for data directory management ---

  static Future<String> getDataDirectoryPath() async {
    final prefs = await SharedPreferences.getInstance();
    String? dir = prefs.getString(_kDataDirKey);
    if (dir == null) {
      final appSupport = await getApplicationSupportDirectory();
      dir = appSupport.path;
    }
    return dir;
  }

  static Future<String> getDataFilePath() async {
    // Prefer the live instance's resolved path — it is always authoritative.
    if (_instance != null) return _instance!._dataFilePath;
    final dir = await getDataDirectoryPath();
    return '$dir/$_kDataFileName';
  }

  static Future<void> changeDataDirectory(String newDir) async {
    final prefs = await SharedPreferences.getInstance();
    final inst = _instance;
    if (inst != null) {
      final newPath = '$newDir/$_kDataFileName';
      final targetFile = File(newPath);
      if (targetFile.existsSync()) {
        // Target already has a data file — adopt it as-is.
        // No write needed; the new instance will load it on next init.
        debugPrint('[DB] Adopting existing data file at $newPath');
      } else {
        // New location — copy current data there.
        await File(newPath).writeAsString(jsonEncode(inst._data), flush: true);
        debugPrint('[DB] Wrote data to new location $newPath');
      }
    }
    // Always clear the old bookmark FIRST. If we don't, a failed bookmark
    // write leaves the stale bookmark in prefs and _resolveDataFilePath will
    // later overwrite _kDataDirKey back to the old path, undoing our change.
    await prefs.setString(_kDataDirKey, newDir);
    await prefs.remove(_kBookmarkKey);

    // Try to save a security-scoped bookmark so sandbox access persists after
    // restart. This may fail on ad-hoc signed builds (no real Team ID) — that
    // is fine because we already saved the plain path above as fallback.
    if (Platform.isMacOS) {
      try {
        final bookmarks = SecureBookmarks();
        final bookmark = await bookmarks.bookmark(Directory(newDir));
        await prefs.setString(_kBookmarkKey, bookmark);
        debugPrint('[DB] Bookmark saved for $newDir');
      } catch (e) {
        debugPrint('[DB] Bookmark creation failed (using path fallback): $e');
      }
    }

    resetInstance();
  }

  static void resetInstance() {
    _instance?._watcherSubscription?.cancel();
    _instance?._debounceTimer?.cancel();
    _instance?._externalChangeController.close();
    _initFuture = null;
    _instance = null;
  }

  // --- Settings (remain in SharedPreferences) ---

  AppSettings getSettings() {
    final json = _prefs.getString('settings');
    if (json == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString('settings', jsonEncode(settings.toJson()));
  }

  // --- Accounts ---

  List<CalendarAccount> getAccounts() {
    final list = _data['accounts'] as List<dynamic>?;
    if (list == null) return [];
    return list.map((e) => CalendarAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  List<CalendarAccount> getAccountsByProvider(String provider) {
    return getAccounts().where((a) => a.provider == provider).toList();
  }

  Future<void> saveAccount(CalendarAccount account) async {
    final accounts = getAccounts();
    accounts.removeWhere((a) => a.id == account.id);
    accounts.add(account);
    _data['accounts'] = accounts.map((a) => a.toJson()).toList();
    await _save();
  }

  Future<void> removeAccount(String id) async {
    final accounts = getAccounts();
    accounts.removeWhere((a) => a.id == id);
    _data['accounts'] = accounts.map((a) => a.toJson()).toList();
    await _save();
  }

  // --- Meeting history ---

  List<MeetingRecord> getMeetingHistory() {
    final list = _data['meetingHistory'] as List<dynamic>?;
    if (list == null) return [];
    return list.map((e) => MeetingRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveMeetingRecord(MeetingRecord record) async {
    final history = getMeetingHistory();
    history.removeWhere((r) => r.eventId == record.eventId);
    history.add(record);
    _data['meetingHistory'] = history.map((r) => r.toJson()).toList();
    await _save();
  }

  Future<void> deleteMeetingRecord(String eventId) async {
    final history = getMeetingHistory();
    history.removeWhere((r) => r.eventId == eventId);
    _data['meetingHistory'] = history.map((r) => r.toJson()).toList();
    await _save();
  }

  Future<void> deleteTodosByMeetingId(String meetingEventId) async {
    final todos = getTodos();
    todos.removeWhere((t) => t.meetingEventId == meetingEventId);
    _data['todos'] = todos.map((t) => t.toJson()).toList();
    await _save();
  }

  // --- Dismissed meetings ---

  Set<String> getDismissedMeetings() {
    final list = _data['dismissedMeetings'] as List<dynamic>?;
    if (list == null) return {};
    return list.cast<String>().toSet();
  }

  Future<void> dismissMeeting(String eventId) async {
    final dismissed = getDismissedMeetings();
    dismissed.add(eventId);
    _data['dismissedMeetings'] = dismissed.toList();
    await _save();
  }

  // --- Todo tasks ---

  List<TodoTask> getTodos() {
    final list = _data['todos'] as List<dynamic>?;
    if (list == null) return [];
    return list.map((e) => TodoTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TodoTask> addTodo(TodoTask task) async {
    final todos = getTodos();
    todos.add(task);
    _data['todos'] = todos.map((t) => t.toJson()).toList();
    await _save();
    return task;
  }

  Future<TodoTask?> updateTodo(String id, Map<String, dynamic> updates) async {
    final todos = getTodos();
    final index = todos.indexWhere((t) => t.id == id);
    if (index == -1) return null;
    final existing = todos[index].toJson();
    existing.addAll(updates);
    todos[index] = TodoTask.fromJson(existing);
    _data['todos'] = todos.map((t) => t.toJson()).toList();
    await _save();
    return todos[index];
  }

  Future<void> deleteTodo(String id) async {
    final todos = getTodos();
    todos.removeWhere((t) => t.id == id);
    _data['todos'] = todos.map((t) => t.toJson()).toList();
    await _save();
  }

  // --- Event time overrides (user-corrected start/end times) ---

  /// Returns a map of eventId → {start, end} ISO 8601 UTC strings.
  Map<String, Map<String, String>> getEventTimeOverrides() {
    final map = _data['eventTimeOverrides'] as Map<String, dynamic>?;
    if (map == null) return {};
    return map.map((k, v) {
      final inner = v as Map<String, dynamic>;
      return MapEntry(k, {'start': inner['start'] as String, 'end': inner['end'] as String});
    });
  }

  Future<void> setEventTimeOverride(String eventId, String startIso, String endIso) async {
    final overrides = getEventTimeOverrides();
    overrides[eventId] = {'start': startIso, 'end': endIso};
    _data['eventTimeOverrides'] = overrides;
    await _save();
  }

  Future<void> clearEventTimeOverride(String eventId) async {
    final overrides = getEventTimeOverrides();
    overrides.remove(eventId);
    _data['eventTimeOverrides'] = overrides;
    await _save();
  }

  // --- Export / Import ---

  String exportData() {
    return jsonEncode({
      'meetingHistory': getMeetingHistory().map((r) => r.toJson()).toList(),
      'todos': getTodos().map((t) => t.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> importData(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (data.containsKey('meetingHistory')) {
      _data['meetingHistory'] = data['meetingHistory'];
    }
    if (data.containsKey('todos')) {
      _data['todos'] = data['todos'];
    }
    await _save();
    final history = (data['meetingHistory'] as List<dynamic>?)?.length ?? 0;
    final todos = (data['todos'] as List<dynamic>?)?.length ?? 0;
    return {
      'meetingHistoryCount': history,
      'todoTaskCount': todos,
      'exportedAt': data['exportedAt'] ?? '',
    };
  }
}
