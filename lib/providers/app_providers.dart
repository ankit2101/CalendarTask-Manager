import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/calendar_event.dart';
import '../models/todo_task.dart';
import '../models/settings.dart';
import '../models/account.dart';
import '../services/storage/app_database.dart';
import '../services/calendar/calendar_manager.dart';
import '../services/ai/claude_client.dart';
import '../services/auth/token_store.dart';

// Database singleton
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  return AppDatabase.getInstance();
});

// Settings
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.getInstance();
    state = db.getSettings();
  }

  Future<void> update(AppSettings settings) async {
    final db = await AppDatabase.getInstance();
    await db.saveSettings(settings);
    state = settings;
  }
}

// Calendar events
final eventsProvider = StateNotifierProvider<EventsNotifier, AsyncValue<List<NormalizedEvent>>>((ref) {
  return EventsNotifier();
});

class EventsNotifier extends StateNotifier<AsyncValue<List<NormalizedEvent>>> {
  Timer? _autoRefreshTimer;

  EventsNotifier() : super(const AsyncValue.loading()) {
    refresh();
    // Auto-refresh every 15 minutes so the calendar stays current
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 15), (_) => refresh());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final events = await CalendarManager.getInstance().fetchAllEvents();
      state = AsyncValue.data(events);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// Accounts
final accountsProvider = StateNotifierProvider<AccountsNotifier, List<CalendarAccount>>((ref) {
  return AccountsNotifier();
});

class AccountsNotifier extends StateNotifier<List<CalendarAccount>> {
  AccountsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.getInstance();
    state = db.getAccounts();
  }

  Future<void> addAccount(CalendarAccount account) async {
    final db = await AppDatabase.getInstance();
    await db.saveAccount(account);
    state = db.getAccounts();
  }

  Future<void> removeAccount(String id) async {
    final db = await AppDatabase.getInstance();
    await db.removeAccount(id);
    state = db.getAccounts();
  }

  void reload() => _load();
}

// Meeting history
final meetingHistoryProvider = StateNotifierProvider<MeetingHistoryNotifier, List<MeetingRecord>>((ref) {
  return MeetingHistoryNotifier();
});

class MeetingHistoryNotifier extends StateNotifier<List<MeetingRecord>> {
  MeetingHistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.getInstance();
    state = db.getMeetingHistory();
  }

  Future<void> saveRecord(MeetingRecord record) async {
    final db = await AppDatabase.getInstance();
    await db.saveMeetingRecord(record);
    state = db.getMeetingHistory();
  }

  Future<void> deleteRecord(String eventId) async {
    final db = await AppDatabase.getInstance();
    await db.deleteMeetingRecord(eventId);
    state = db.getMeetingHistory();
  }

  void reload() => _load();
}

// Todos
final todosProvider = StateNotifierProvider<TodosNotifier, List<TodoTask>>((ref) {
  return TodosNotifier();
});

class TodosNotifier extends StateNotifier<List<TodoTask>> {
  TodosNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.getInstance();
    state = db.getTodos();
  }

  Future<void> addTodo(TodoTask task) async {
    final db = await AppDatabase.getInstance();
    await db.addTodo(task);
    state = db.getTodos();
  }

  Future<void> updateTodo(String id, Map<String, dynamic> updates) async {
    final db = await AppDatabase.getInstance();
    await db.updateTodo(id, updates);
    state = db.getTodos();
  }

  Future<void> deleteTodo(String id) async {
    final db = await AppDatabase.getInstance();
    await db.deleteTodo(id);
    state = db.getTodos();
  }

  Future<void> deleteTodosByMeetingId(String meetingEventId) async {
    final db = await AppDatabase.getInstance();
    await db.deleteTodosByMeetingId(meetingEventId);
    state = db.getTodos();
  }

  void reload() => _load();
}

// Claude AI client — watches settingsProvider so model changes take effect
// immediately without a race against the async DB write.
final claudeClientProvider = FutureProvider<ClaudeClient>((ref) async {
  final settings = ref.watch(settingsProvider); // auto-rebuilds on model change
  final client = ClaudeClient();
  final key = await TokenStore.instance.loadSecret('claude-api-key');
  if (key != null && key.isNotEmpty) client.setApiKey(key);
  client.setModel(settings.claudeModelId);
  return client;
});

// Dismissed meetings — events the user has chosen not to be prompted about
final dismissedMeetingsProvider =
    StateNotifierProvider<DismissedMeetingsNotifier, Set<String>>((ref) {
  return DismissedMeetingsNotifier();
});

class DismissedMeetingsNotifier extends StateNotifier<Set<String>> {
  DismissedMeetingsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final db = await AppDatabase.getInstance();
    state = db.getDismissedMeetings();
  }

  Future<void> dismiss(String eventId) async {
    final db = await AppDatabase.getInstance();
    await db.dismissMeeting(eventId);
    state = {...state, eventId};
  }

  void reload() => _load();
}
