import 'dart:math' show min;
import '../../models/calendar_event.dart';
import '../storage/app_database.dart';
import 'ics_calendar_service.dart';
import 'google_calendar_service.dart';
import 'microsoft_calendar_service.dart';

class CalendarManager {
  static CalendarManager? _instance;
  final IcsCalendarService _icsService = IcsCalendarService();
  final GoogleCalendarService _googleService = GoogleCalendarService();
  final MicrosoftCalendarService _microsoftService = MicrosoftCalendarService();
  List<NormalizedEvent> _cachedEvents = [];

  CalendarManager._();

  static CalendarManager getInstance() {
    _instance ??= CalendarManager._();
    return _instance!;
  }

  List<NormalizedEvent> get cachedEvents => _cachedEvents;

  Future<List<NormalizedEvent>> fetchAllEvents() async {
    final db = await AppDatabase.getInstance();
    final accounts = db.getAccounts();
    final allEvents = <NormalizedEvent>[];

    for (final account in accounts) {
      try {
        switch (account.provider) {
          case 'ics':
            if (account.icsUrl != null) {
              final events = await _icsService.fetchEvents(account.id, account.icsUrl!);
              allEvents.addAll(events);
            }
          case 'google':
            final events = await _googleService.fetchEvents(account.id);
            allEvents.addAll(events);
          case 'microsoft':
            final events = await _microsoftService.fetchEvents(account.id, account.email);
            allEvents.addAll(events);
        }
      } catch (e) {
        // Log but don't fail all accounts
        // ignore: avoid_print
        print('[CalendarManager] Failed to fetch for ${account.email}: $e');
      }
    }

    allEvents.sort((a, b) => a.start.compareTo(b.start));

    // Deduplicate: same title + same start minute = same meeting across providers.
    // Happens when a calendar is connected via both ICS and OAuth simultaneously.
    final seen = <String>{};
    final deduped = <NormalizedEvent>[];
    for (final event in allEvents) {
      // Key on first 16 chars of ISO start (YYYY-MM-DDTHH:MM) + normalised title.
      final key = '${event.title.trim().toLowerCase()}|${event.start.substring(0, min(16, event.start.length))}';
      if (seen.add(key)) deduped.add(event);
    }

    _cachedEvents = deduped;
    return deduped;
  }

  Future<String> connectGoogleAccount() => _googleService.signIn();

  Future<void> disconnectGoogleAccount(String email) =>
      _googleService.signOut(email);

  Future<({String email, String displayName})> connectMicrosoftAccount() =>
      _microsoftService.signIn();

  Future<void> disconnectMicrosoftAccount(String email) =>
      _microsoftService.signOut(email);
}
