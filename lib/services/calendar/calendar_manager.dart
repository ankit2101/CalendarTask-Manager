import 'dart:math' show min;
import 'package:flutter/foundation.dart';
import '../../models/calendar_event.dart';
import '../storage/app_database.dart';
import 'ics_calendar_service.dart';

class CalendarManager {
  static CalendarManager? _instance;
  final IcsCalendarService _icsService = IcsCalendarService();
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
      if (account.provider != 'ics' || account.icsUrl == null) continue;
      try {
        final events = await _icsService.fetchEvents(account.id, account.icsUrl!);
        allEvents.addAll(events);
      } catch (e) {
        debugPrint('[CalendarManager] Failed to fetch for account ${account.id}: $e');
      }
    }

    allEvents.sort((a, b) => a.start.compareTo(b.start));

    // Deduplicate: same title + same start minute = same meeting across feeds.
    final seen = <String>{};
    final deduped = <NormalizedEvent>[];
    for (final event in allEvents) {
      final key =
          '${event.title.trim().toLowerCase()}|${event.start.substring(0, min(16, event.start.length))}';
      if (seen.add(key)) deduped.add(event);
    }

    _cachedEvents = deduped;
    return deduped;
  }
}
