import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'widgets/app_scaffold.dart';
import 'widgets/quick_note_dialog.dart';
import 'pages/dashboard_page.dart';
import 'pages/todos_page.dart';
import 'pages/accounts_page.dart';
import 'pages/notes_page.dart';
import 'pages/settings_page.dart';
import 'providers/app_providers.dart';
import 'services/calendar/calendar_manager.dart';
import 'services/meeting_poller.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/today',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppScaffold(
          currentIndex: navigationShell.currentIndex,
          onTabChanged: (index) => navigationShell.goBranch(index),
          child: navigationShell,
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/today', builder: (context, state) => const DashboardPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/todos', builder: (context, state) => const TodosPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/accounts', builder: (context, state) => const AccountsPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/notes', builder: (context, state) => const NotesPage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/settings', builder: (context, state) => const SettingsPage())],
        ),
      ],
    ),
  ],
);

class CalendarTaskApp extends ConsumerStatefulWidget {
  const CalendarTaskApp({super.key});

  @override
  ConsumerState<CalendarTaskApp> createState() => _CalendarTaskAppState();
}

class _CalendarTaskAppState extends ConsumerState<CalendarTaskApp> {
  @override
  void initState() {
    super.initState();
    _initPoller();
  }

  Future<void> _initPoller() async {
    await MeetingPoller.instance.initialize();
    MeetingPoller.instance.onMeetingEndDetected = _onMeetingEnded;
    // Start with defaults; will be restarted in build() when settings load
    _startPoller();
  }

  void _startPoller() {
    final settings = ref.read(settingsProvider);
    final notedIds = ref.read(meetingHistoryProvider).map((r) => r.eventId).toSet();
    final dismissedIds = ref.read(dismissedMeetingsProvider);

    MeetingPoller.instance.start(
      intervalSeconds: settings.pollingIntervalSeconds,
      promptDelayMinutes: settings.promptDelayMinutes,
      minimumAttendees: settings.minimumAttendeesForPrompt,
      notedEventIds: notedIds,
      dismissedEventIds: dismissedIds,
    );
  }

  void _onMeetingEnded(String eventId) {
    final event = CalendarManager.getInstance()
        .cachedEvents
        .where((e) => e.id == eventId)
        .firstOrNull;
    if (event == null) return;

    _rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => QuickNoteDialog(event: event),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Restart poller when settings or meeting history changes
    ref.listen(settingsProvider, (_, __) => _startPoller());
    ref.listen(meetingHistoryProvider, (_, __) => _startPoller());
    ref.listen(dismissedMeetingsProvider, (_, __) => _startPoller());

    return MaterialApp.router(
      title: 'CalendarTask Manager',
      theme: appTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
