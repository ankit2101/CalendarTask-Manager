import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/calendar_event.dart';

/// Reads calendar events from the local Microsoft Outlook for Mac app via
/// the [OutlookBridge] Swift method channel.
///
/// This is used as a fallback when an Outlook ICS feed is blocked (e.g. by a
/// corporate Defender network extension routing traffic through Azure, which
/// causes Exchange Online to reject the anonymous ICS request with HTTP 400).
class OutlookCalendarService {
  static const _channel = MethodChannel('com.caltask/outlook');

  bool? _available; // cached so we don't hammer the channel on every refresh

  /// Returns true if Microsoft Outlook is installed and the Apple Events
  /// bridge is functional. Result is cached after the first call.
  Future<bool> isAvailable() async {
    _available ??= await _checkAvailable();
    return _available!;
  }

  Future<bool> _checkAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (e) {
      debugPrint('[OutlookCalendarService] isAvailable check failed: $e');
      return false;
    }
  }

  /// Fetches events from all local Outlook calendars within ±[daysBack]/
  /// [daysForward] days of today and maps them to [NormalizedEvent]s tagged
  /// with [accountId] so they appear under the correct account in the UI.
  ///
  /// Returns an empty list if Outlook is unavailable or the AppleScript
  /// fails — never throws.
  Future<List<NormalizedEvent>> fetchEvents(
    String accountId, {
    int daysBack = 30,
    int daysForward = 30,
  }) async {
    if (!await isAvailable()) {
      debugPrint('[OutlookCalendarService] Outlook not available, skipping fallback');
      return [];
    }

    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'fetchEvents',
        {'daysBack': daysBack, 'daysForward': daysForward},
      );
      if (raw == null || raw.isEmpty) return [];

      final events = <NormalizedEvent>[];
      for (final item in raw) {
        final map = item is Map ? Map<String, dynamic>.from(item) : null;
        if (map == null) continue;
        final event = _toNormalizedEvent(map, accountId);
        if (event != null) events.add(event);
      }
      debugPrint('[OutlookCalendarService] Fetched ${events.length} events from Outlook');
      return events;
    } on PlatformException catch (e) {
      debugPrint('[OutlookCalendarService] PlatformException: ${e.code} — ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[OutlookCalendarService] Unexpected error: $e');
      return [];
    }
  }

  NormalizedEvent? _toNormalizedEvent(Map<String, dynamic> raw, String accountId) {
    final title = (raw['title'] as String? ?? '').trim();
    final startLocal = raw['start'] as String? ?? '';
    if (title.isEmpty || startLocal.isEmpty) return null;

    // AppleScript returns local time without a TZ suffix.
    // DateTime.parse treats a no-suffix ISO string as local time in Dart,
    // so .toUtc() correctly converts it to UTC for storage.
    final startUtc = _localIsoToUtc(startLocal);
    if (startUtc == null) return null;

    final endLocal = raw['end'] as String? ?? startLocal;
    final endUtc = _localIsoToUtc(endLocal) ?? startUtc;

    final location = (raw['location'] as String? ?? '').trim();

    // Derive a stable ID from the Outlook event ID + start so it survives
    // deduplication across multiple refreshes.
    final rawId = raw['id'] as String? ?? '';
    final stableId = 'outlook|${rawId.isNotEmpty ? rawId : startLocal}|$title'
        .hashCode
        .toRadixString(16);

    return NormalizedEvent(
      id: stableId,
      accountId: accountId,
      provider: CalendarProvider.microsoft,
      title: title,
      start: startUtc,
      end: endUtc,
      location: location.isEmpty ? null : location,
      isOnlineMeeting: false,
    );
  }

  /// Parses a local ISO-8601 string (no timezone suffix) and returns a UTC
  /// ISO-8601 string, or null if parsing fails.
  String? _localIsoToUtc(String localIso) {
    if (localIso.isEmpty) return null;
    try {
      // DateTime.parse with no TZ suffix → local DateTime
      final local = DateTime.parse(localIso);
      return local.toUtc().toIso8601String();
    } catch (_) {
      return null;
    }
  }
}
