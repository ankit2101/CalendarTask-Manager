import 'package:dio/dio.dart';
import '../../models/calendar_event.dart';

class IcsCalendarService {
  final Dio _dio = Dio();

  Future<List<NormalizedEvent>> fetchEvents(String accountId, String url) async {
    // webcal:// is just http/https — normalize it
    final normalized = url.replaceFirst(RegExp(r'^webcal://', caseSensitive: false), 'https://');
    final response = await _dio.get(normalized);
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
    final summary = props['SUMMARY'] ?? '(No title)';
    final dtStart = _parseDateTime(props, 'DTSTART');
    final dtEnd = _parseDateTime(props, 'DTEND');

    if (uid == null || dtStart == null || dtEnd == null) return null;

    // Filter: events within a 60-day window (30 days past → 30 days future)
    final now = DateTime.now();
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
      location: location,
      isOnlineMeeting: isOnline,
      onlineMeetingUrl: meetingUrl,
      attendees: attendees,
      organizer: organizerEmail,
      bodyPreview: description,
    );
  }

  DateTime? _parseDateTime(Map<String, String> props, String key) {
    // Try to find the value with or without parameters
    String? value;
    for (final entry in props.entries) {
      if (entry.key.startsWith(key)) {
        value = entry.value;
        break;
      }
    }
    if (value == null) return null;

    // Remove any trailing whitespace
    value = value.trim();

    // Format: 20231215T140000Z or 20231215T140000
    if (value.length >= 15) {
      final year = int.parse(value.substring(0, 4));
      final month = int.parse(value.substring(4, 6));
      final day = int.parse(value.substring(6, 8));
      final hour = int.parse(value.substring(9, 11));
      final minute = int.parse(value.substring(11, 13));
      final second = int.parse(value.substring(13, 15));

      if (value.endsWith('Z')) {
        return DateTime.utc(year, month, day, hour, minute, second);
      }
      return DateTime(year, month, day, hour, minute, second);
    }

    // Date only: 20231215
    if (value.length >= 8) {
      final year = int.parse(value.substring(0, 4));
      final month = int.parse(value.substring(4, 6));
      final day = int.parse(value.substring(6, 8));
      return DateTime(year, month, day);
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
