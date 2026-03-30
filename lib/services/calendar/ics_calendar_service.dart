import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/calendar_event.dart';
import '../../core/time_utils.dart';

class IcsCalendarService {
  final Dio _dio = Dio();

  Future<List<NormalizedEvent>> fetchEvents(String accountId, String url) async {
    // webcal:// is just http/https — normalize it
    final normalized = url.replaceFirst(RegExp(r'^webcal://', caseSensitive: false), 'https://');
    // Force no-cache so Refresh always fetches fresh data from the server
    final response = await _dio.get(
      normalized,
      options: Options(headers: {
        'Cache-Control': 'no-cache, no-store',
        'Pragma': 'no-cache',
      }),
    );
    return parseIcs(response.data as String, accountId);
  }

  List<NormalizedEvent> parseIcs(String icsData, String accountId) {
    final events = <NormalizedEvent>[];
    // Unfold lines (RFC 5545: lines starting with space/tab are continuations)
    final unfolded = icsData.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final lines = unfolded.split(RegExp(r'\r?\n'));

    bool inEvent = false;
    Map<String, String> props = {};
    List<String> attendeeLines = [];

    for (final line in lines) {
      if (line.trim() == 'BEGIN:VEVENT') {
        inEvent = true;
        props = {};
        attendeeLines = [];
        continue;
      }
      if (line.trim() == 'END:VEVENT') {
        inEvent = false;
        final event = _buildEvent(props, attendeeLines, accountId);
        if (event != null) events.add(event);
        continue;
      }
      if (!inEvent) continue;

      if (line.startsWith('ATTENDEE')) {
        attendeeLines.add(line);
        continue;
      }

      final colonIdx = line.indexOf(':');
      if (colonIdx == -1) continue;
      final key = line.substring(0, colonIdx);
      final value = line.substring(colonIdx + 1);
      // Strip parameters for common keys
      final baseKey = key.split(';').first;
      props[baseKey] = value;
      // Keep full key for datetime parsing
      if (key != baseKey) props[key] = value;
    }

    // Sort by start time
    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  NormalizedEvent? _buildEvent(Map<String, String> props, List<String> attendeeLines, String accountId) {
    final uid = props['UID'];
    final rawSummary = props['SUMMARY'] ?? '(No title)';
    final classValue = (props['CLASS'] ?? '').toUpperCase();
    // An event is private if CLASS:PRIVATE/CONFIDENTIAL, or if the server
    // has already masked the title to the standard "Private Appointment" string.
    final isPrivate = classValue == 'PRIVATE' ||
        classValue == 'CONFIDENTIAL' ||
        rawSummary.trim().toLowerCase() == 'private appointment' ||
        rawSummary.trim().toLowerCase() == 'private';
    final summary = isPrivate ? 'Private' : rawSummary;
    final dtStart = _parseDateTime(props, 'DTSTART');
    final dtEnd = _parseDateTime(props, 'DTEND');

    if (uid == null || dtStart == null || dtEnd == null) return null;

    // Filter: events within a 60-day window (30 days past → 30 days future)
    final now = DateTime.now().toUtc();
    final windowStart = now.subtract(const Duration(days: 30));
    final windowEnd = now.add(const Duration(days: 30));
    if (dtEnd.isBefore(windowStart) || dtStart.isAfter(windowEnd)) return null;

    final location = props['LOCATION'];
    final description = props['DESCRIPTION'];
    final isOnline = location != null &&
        (location.contains('http') || location.toLowerCase().contains('teams') ||
         location.toLowerCase().contains('zoom') || location.toLowerCase().contains('meet'));

    String? meetingUrl;
    if (isOnline && location != null) {
      final urlMatch = RegExp(r'https?://\S+').firstMatch(location);
      meetingUrl = urlMatch?.group(0);
    }

    final attendees = attendeeLines.map(_parseAttendee).whereType<Attendee>().toList();
    final organizer = props['ORGANIZER'];
    String? organizerEmail;
    if (organizer != null) {
      final match = RegExp(r'mailto:(.+)', caseSensitive: false).firstMatch(organizer);
      organizerEmail = match?.group(1);
    }

    return NormalizedEvent(
      id: uid,
      accountId: accountId,
      provider: CalendarProvider.ics,
      title: summary,
      start: dtStart.toIso8601String(),
      end: dtEnd.toIso8601String(),
      location: isPrivate ? null : location,
      isOnlineMeeting: isPrivate ? false : isOnline,
      onlineMeetingUrl: isPrivate ? null : meetingUrl,
      attendees: isPrivate ? [] : attendees,
      organizer: isPrivate ? null : organizerEmail,
      bodyPreview: isPrivate ? null : description,
      isPrivate: isPrivate,
    );
  }

  DateTime? _parseDateTime(Map<String, String> props, String key) {
    // Try to find the value with or without parameters
    String? value;
    String? matchedKey;
    for (final entry in props.entries) {
      if (entry.key.startsWith(key)) {
        value = entry.value;
        matchedKey = entry.key;
        break;
      }
    }
    if (value == null) return null;

    // Remove any trailing whitespace
    value = value.trim();

    // Format: 20231215T140000Z or 20231215T140000
    if (value.length >= 15) {
      final year   = int.parse(value.substring(0, 4));
      final month  = int.parse(value.substring(4, 6));
      final day    = int.parse(value.substring(6, 8));
      final hour   = int.parse(value.substring(9, 11));
      final minute = int.parse(value.substring(11, 13));
      final second = int.parse(value.substring(13, 15));

      if (value.endsWith('Z')) {
        return DateTime.utc(year, month, day, hour, minute, second);
      }

      // Check for TZID parameter (e.g. DTSTART;TZID=America/New_York:20231215T140000)
      final tzidMatch = RegExp(r'TZID=([^;:]+)').firstMatch(matchedKey ?? '');
      if (tzidMatch != null) {
        final tzid = tzidMatch.group(1)!;
        final utcTime = parseWithTzid(year, month, day, hour, minute, second, tzid);
        if (utcTime != null) return utcTime;
        // Unknown TZID: treat as system local time (not UTC)
        debugPrint('[ICS] Unknown TZID "$tzid" — treating as system local time');
        return DateTime(year, month, day, hour, minute, second).toUtc();
      }

      // Floating time (no Z, no TZID): per ICS spec this is "local clock time"
      return DateTime(year, month, day, hour, minute, second).toUtc();
    }

    // Date only: 20231215
    if (value.length >= 8) {
      final year  = int.parse(value.substring(0, 4));
      final month = int.parse(value.substring(4, 6));
      final day   = int.parse(value.substring(6, 8));
      return DateTime.utc(year, month, day);
    }

    return null;
  }

  Attendee? _parseAttendee(String line) {
    final mailtoMatch = RegExp(r'mailto:([^\s;]+)', caseSensitive: false).firstMatch(line);
    if (mailtoMatch == null) return null;

    final email = mailtoMatch.group(1)!;
    final cnMatch = RegExp(r'CN=([^;:]+)', caseSensitive: false).firstMatch(line);
    final name = cnMatch?.group(1)?.replaceAll('"', '');

    ResponseStatus status = ResponseStatus.none;
    final partstatMatch = RegExp(r'PARTSTAT=(\w+)', caseSensitive: false).firstMatch(line);
    if (partstatMatch != null) {
      switch (partstatMatch.group(1)!.toUpperCase()) {
        case 'ACCEPTED': status = ResponseStatus.accepted;
        case 'TENTATIVE': status = ResponseStatus.tentative;
        case 'DECLINED': status = ResponseStatus.declined;
      }
    }

    return Attendee(email: email, name: name, status: status);
  }
}
