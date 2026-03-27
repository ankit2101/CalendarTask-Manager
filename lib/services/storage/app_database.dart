import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/calendar_event.dart';
import '../../models/account.dart';
import '../../models/todo_task.dart';
import '../../models/settings.dart';

class AppDatabase {
  static AppDatabase? _instance;
  static Future<AppDatabase>? _initFuture;
  late SharedPreferences _prefs;

  AppDatabase._();

  static Future<AppDatabase> getInstance() {
    _initFuture ??= _create();
    return _initFuture!;
  }

  static Future<AppDatabase> _create() async {
    final db = AppDatabase._();
    db._prefs = await SharedPreferences.getInstance();
    _instance = db;
    return db;
  }

  // Settings
  AppSettings getSettings() {
    final json = _prefs.getString('settings');
    if (json == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString('settings', jsonEncode(settings.toJson()));
  }

  // Accounts
  List<CalendarAccount> getAccounts() {
    final json = _prefs.getString('accounts');
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => CalendarAccount.fromJson(e as Map<String, dynamic>)).toList();
  }

  List<CalendarAccount> getAccountsByProvider(String provider) {
    return getAccounts().where((a) => a.provider == provider).toList();
  }

  Future<void> saveAccount(CalendarAccount account) async {
    final accounts = getAccounts();
    accounts.removeWhere((a) => a.id == account.id);
    accounts.add(account);
    await _prefs.setString('accounts', jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  Future<void> removeAccount(String id) async {
    final accounts = getAccounts();
    accounts.removeWhere((a) => a.id == id);
    await _prefs.setString('accounts', jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  // Meeting history
  List<MeetingRecord> getMeetingHistory() {
    final json = _prefs.getString('meetingHistory');
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => MeetingRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveMeetingRecord(MeetingRecord record) async {
    final history = getMeetingHistory();
    history.removeWhere((r) => r.eventId == record.eventId);
    history.add(record);
    await _prefs.setString('meetingHistory', jsonEncode(history.map((r) => r.toJson()).toList()));
  }

  Future<void> deleteMeetingRecord(String eventId) async {
    final history = getMeetingHistory();
    history.removeWhere((r) => r.eventId == eventId);
    await _prefs.setString('meetingHistory', jsonEncode(history.map((r) => r.toJson()).toList()));
  }

  Future<void> deleteTodosByMeetingId(String meetingEventId) async {
    final todos = getTodos();
    todos.removeWhere((t) => t.meetingEventId == meetingEventId);
    await _prefs.setString('todos', jsonEncode(todos.map((t) => t.toJson()).toList()));
  }

  // Dismissed meetings
  Set<String> getDismissedMeetings() {
    final json = _prefs.getString('dismissedMeetings');
    if (json == null) return {};
    return (jsonDecode(json) as List<dynamic>).cast<String>().toSet();
  }

  Future<void> dismissMeeting(String eventId) async {
    final dismissed = getDismissedMeetings();
    dismissed.add(eventId);
    await _prefs.setString('dismissedMeetings', jsonEncode(dismissed.toList()));
  }

  // Todo tasks
  List<TodoTask> getTodos() {
    final json = _prefs.getString('todos');
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list.map((e) => TodoTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TodoTask> addTodo(TodoTask task) async {
    final todos = getTodos();
    todos.add(task);
    await _prefs.setString('todos', jsonEncode(todos.map((t) => t.toJson()).toList()));
    return task;
  }

  Future<TodoTask?> updateTodo(String id, Map<String, dynamic> updates) async {
    final todos = getTodos();
    final index = todos.indexWhere((t) => t.id == id);
    if (index == -1) return null;
    final existing = todos[index].toJson();
    existing.addAll(updates);
    todos[index] = TodoTask.fromJson(existing);
    await _prefs.setString('todos', jsonEncode(todos.map((t) => t.toJson()).toList()));
    return todos[index];
  }

  Future<void> deleteTodo(String id) async {
    final todos = getTodos();
    todos.removeWhere((t) => t.id == id);
    await _prefs.setString('todos', jsonEncode(todos.map((t) => t.toJson()).toList()));
  }

  // Export/Import
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
      await _prefs.setString('meetingHistory', jsonEncode(data['meetingHistory']));
    }
    if (data.containsKey('todos')) {
      await _prefs.setString('todos', jsonEncode(data['todos']));
    }
    final history = (data['meetingHistory'] as List<dynamic>?)?.length ?? 0;
    final todos = (data['todos'] as List<dynamic>?)?.length ?? 0;
    return {
      'meetingHistoryCount': history,
      'todoTaskCount': todos,
      'exportedAt': data['exportedAt'] ?? '',
    };
  }
}
