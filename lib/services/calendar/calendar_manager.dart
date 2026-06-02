import 'dart:math' show min;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/calendar_event.dart';
import '../../core/time_utils.dart';
import '../storage/app_database.dart';
import 'ics_calendar_service.dart';
import 'outlook_calendar_service.dart';

class CalendarManager {
  static CalendarManager? _instance;
  final IcsCalendarService _icsService = IcsCalendarService();
  final OutlookCalendarService _outlookService = OutlookCalendarService();
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
        // If this is an Outlook-hosted feed that returned an auth-style error
        // (common when a corporate Defender network extension routes traffic
        // through Azure and Exchange Online rejects the anonymous request),
        // fall back to reading the same calendar from the local Outlook app.
        if (_isOutlookUrl(account.icsUrl!) && _isAuthError(e)) {
          debugPrint('[CalendarManager] Auth error on Outlook ICS — trying local Outlook fallback');
          final fallback = await _outlookService.fetchEvents(account.id);
          if (fallback.isNotEmpty) {
            debugPrint('[CalendarManager] Outlook fallback: ${fallback.length} events added');
            allEvents.addAll(fallback);
          }
        }
      }
    }

    allEvents.sort((a, b) => parseToLocal(a.start).compareTo(parseToLocal(b.start)));

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

  // ---------------------------------------------------------------------------
  // Helpers for Outlook fallback detection
  // ---------------------------------------------------------------------------

  /// Returns true if [url] is an Outlook / Exchange Online ICS feed.
  static bool _isOutlookUrl(String url) =>
      url.contains('outlook.office365.com') || url.contains('outlook.office.com');

  /// Returns true if [error] looks like an HTTP auth/rejection error (400, 401,
  /// 403, 407) — the typical codes returned when Exchange Online blocks an
  /// anonymous ICS request from a corporate-managed device.
  static bool _isAuthError(Object error) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      return code == 400 || code == 401 || code == 403 || code == 407;
    }
    return false;
  }
}
