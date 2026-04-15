import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../models/calendar_event.dart';
import '../../core/time_utils.dart';

class IcsCalendarService {
  final Dio _dio = Dio();

  Future<List<NormalizedEvent>> fetchEvents(String accountId, String url) async {
    // webcal:// is just http/https — normalize it
    final normalized = url.replaceFirst(RegExp(r'^webcal://', caseSensitive: false), 'https://');
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
    // Unfold continuation lines (RFC 5545)
    final unfolded = icsData.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final lines = unfolded.split(RegExp(r'\r?\n'));

    bool inEvent = false;
    Map<String, String> props = {};
    List<String> attendeeLines = [];
    List<String> exdateLines = [];

    final rawEvents = <_RawEvent>[];

    for (final line in lines) {
      if (line.trim() == 'BEGIN:VEVENT') {
        inEvent = true;
        props = {};
        attendeeLines = [];
        exdateLines = [];
        continue;
      }
      if (line.trim() == 'END:VEVENT') {
        inEvent = false;
        rawEvents.add(_RawEvent(
          props: Map.from(props),
          attendeeLines: List.from(attendeeLines),
          exdateLines: List.from(exdateLines),
        ));
        continue;
      }
      if (!inEvent) continue;

      if (line.startsWith('ATTENDEE')) {
        attendeeLines.add(line);
        continue;
      }
      // Collect all EXDATE lines separately (there may be multiple)
      if (line.startsWith('EXDATE')) {
        exdateLines.add(line);
        continue;
      }

      final colonIdx = line.indexOf(':');
      if (colonIdx == -1) continue;
      final key = line.substring(0, colonIdx);
      final value = line.substring(colonIdx + 1);
      final baseKey = key.split(';').first;
      props[baseKey] = value;
      // Keep full key (with params) for datetime parsing (e.g. DTSTART;TZID=...)
      if (key != baseKey) props[key] = value;
    }

    // Separate override events (RECURRENCE-ID present) from base events
    final overridesByUid = <String, List<_RawEvent>>{};
    final baseEvents = <_RawEvent>[];

    for (final raw in rawEvents) {
      if (raw.props.containsKey('RECURRENCE-ID')) {
        final uid = raw.props['UID'];
        if (uid != null) {
          overridesByUid.putIfAbsent(uid, () => []).add(raw);
        }
      } else {
        baseEvents.add(raw);
      }
    }

    final now = DateTime.now().toUtc();
    final windowStart = now.subtract(const Duration(days: 30));
    final windowEnd = now.add(const Duration(days: 30));

    final events = <NormalizedEvent>[];

    for (final raw in baseEvents) {
      final uid = raw.props['UID'];
      if (uid == null) continue;

      final dtStart = _parseDateTimeFromProps(raw.props, 'DTSTART');
      if (dtStart == null) continue;

      DateTime? dtEnd = _parseDateTimeFromProps(raw.props, 'DTEND');
      if (dtEnd == null && raw.props.containsKey('DURATION')) {
        dtEnd = dtStart.add(_parseDuration(raw.props['DURATION']!));
      }
      if (dtEnd == null) continue;

      final rrule = raw.props['RRULE'];

      if (rrule != null) {
        // --- Recurring event: expand all occurrences within the window ---
        final duration = dtEnd.difference(dtStart);
        final exdates = _parseExdates(raw.exdateLines);

        // Build override map: recurrence UTC ms → override raw event
        final overrideMap = <int, _RawEvent>{};
        for (final ov in overridesByUid[uid] ?? []) {
          final recId = _parseDateTimeFromProps(ov.props, 'RECURRENCE-ID');
          if (recId != null) {
            overrideMap[recId.millisecondsSinceEpoch] = ov;
          }
        }

        final occurrences = _expandRRule(dtStart, rrule, windowEnd);

        for (final occStart in occurrences) {
          if (occStart.isBefore(dtStart)) continue;
          final occEnd = occStart.add(duration);
          if (occEnd.isBefore(windowStart)) continue;
          if (occStart.isAfter(windowEnd)) break;

          // Skip exdated occurrences
          if (_isExcluded(occStart, exdates)) continue;

          // Check for a modified occurrence (RECURRENCE-ID override)
          _RawEvent? override;
          for (final entry in overrideMap.entries) {
            if ((occStart.millisecondsSinceEpoch - entry.key).abs() < 86400000) {
              override = entry.value;
              break;
            }
          }

          final instanceId = '${uid}_${occStart.millisecondsSinceEpoch}';

          if (override != null) {
            final ovStart = _parseDateTimeFromProps(override.props, 'DTSTART') ?? occStart;
            var ovEnd = _parseDateTimeFromProps(override.props, 'DTEND');
            if (ovEnd == null && override.props.containsKey('DURATION')) {
              ovEnd = ovStart.add(_parseDuration(override.props['DURATION']!));
            }
            ovEnd ??= ovStart.add(duration);
            final event = _buildEvent(override.props, override.attendeeLines, accountId,
                instanceId: instanceId, instanceStart: ovStart, instanceEnd: ovEnd);
            if (event != null) events.add(event);
          } else {
            final event = _buildEvent(raw.props, raw.attendeeLines, accountId,
                instanceId: instanceId, instanceStart: occStart, instanceEnd: occEnd);
            if (event != null) events.add(event);
          }
        }
      } else {
        // --- Non-recurring event: simple window filter ---
        if (dtEnd.isBefore(windowStart) || dtStart.isAfter(windowEnd)) continue;
        final event = _buildEvent(raw.props, raw.attendeeLines, accountId);
        if (event != null) events.add(event);
      }
    }

    events.sort((a, b) => parseToLocal(a.start).compareTo(parseToLocal(b.start)));
    return events;
  }

  // ---------------------------------------------------------------------------
  // RRULE expansion
  // ---------------------------------------------------------------------------

  List<DateTime> _expandRRule(DateTime dtStart, String rrule, DateTime windowEnd) {
    final params = <String, String>{};
    for (final part in rrule.split(';')) {
      final eq = part.indexOf('=');
      if (eq != -1) {
        params[part.substring(0, eq).toUpperCase()] = part.substring(eq + 1).trim();
      }
    }

    final freq = params['FREQ']?.toUpperCase() ?? 'WEEKLY';
    final interval = int.tryParse(params['INTERVAL'] ?? '1') ?? 1;
    final countLimit = int.tryParse(params['COUNT'] ?? '');
    DateTime? until;
    if (params.containsKey('UNTIL')) {
      until = _parseDateTimeString(params['UNTIL']!);
    }

    // BYDAY: strip any ordinal prefix (e.g. "1MO" → "MO", "-1FR" → "FR")
    final byday = (params['BYDAY'] ?? '')
        .split(',')
        .map((s) => s.trim().toUpperCase().replaceAll(RegExp(r'^[-+]?\d+'), ''))
        .where((s) => s.length == 2)
        .toSet();

    final maxOccurrences = countLimit ?? 1000;
    final result = <DateTime>[];

    if (freq == 'WEEKLY' && byday.isNotEmpty) {
      // Weekly with explicit day list — may produce multiple occurrences per week
      // Find Monday of the week that contains dtStart
      final startWeekday = dtStart.weekday; // 1=Mon … 7=Sun
      var weekMon = DateTime.utc(
        dtStart.year, dtStart.month, dtStart.day,
        dtStart.hour, dtStart.minute, dtStart.second,
      ).subtract(Duration(days: startWeekday - 1));

      while (result.length < maxOccurrences) {
        if (weekMon.isAfter(windowEnd)) break;
        if (until != null && weekMon.isAfter(until)) break;

        for (var d = 0; d < 7; d++) {
          final candidate = weekMon.add(Duration(days: d));
          if (!byday.contains(_weekdayToStr(candidate.weekday))) continue;
          if (candidate.isBefore(dtStart)) continue;
          if (until != null && candidate.isAfter(until)) continue;
          if (candidate.isAfter(windowEnd)) continue;
          result.add(candidate);
          if (result.length >= maxOccurrences) break;
        }

        weekMon = weekMon.add(Duration(days: 7 * interval));
      }
    } else {
      // Simple DAILY / WEEKLY / MONTHLY / YEARLY
      var current = dtStart;

      while (result.length < maxOccurrences) {
        if (current.isAfter(windowEnd)) break;
        if (until != null && current.isAfter(until)) break;

        result.add(current);

        switch (freq) {
          case 'DAILY':
            current = current.add(Duration(days: interval));
          case 'WEEKLY':
            current = current.add(Duration(days: 7 * interval));
          case 'MONTHLY':
            var m = current.month + interval;
            var y = current.year;
            while (m > 12) { m -= 12; y++; }
            // Clamp day to month boundary (e.g. Jan 31 + 1 month → Feb 28)
            final maxDay = DateTime.utc(y, m + 1, 0).day;
            current = DateTime.utc(y, m, current.day.clamp(1, maxDay),
                current.hour, current.minute, current.second);
          case 'YEARLY':
            current = DateTime.utc(current.year + interval, current.month, current.day,
                current.hour, current.minute, current.second);
          default:
            current = current.add(Duration(days: interval));
        }
      }
    }

    return result;
  }

  String _weekdayToStr(int weekday) {
    const map = {1: 'MO', 2: 'TU', 3: 'WE', 4: 'TH', 5: 'FR', 6: 'SA', 7: 'SU'};
    return map[weekday] ?? 'MO';
  }

  // ---------------------------------------------------------------------------
  // EXDATE helpers
  // ---------------------------------------------------------------------------

  Set<int> _parseExdates(List<String> exdateLines) {
    final result = <int>{};
    for (final line in exdateLines) {
      final colonIdx = line.indexOf(':');
      if (colonIdx == -1) continue;
      final key = line.substring(0, colonIdx);
      final values = line.substring(colonIdx + 1);
      final tzidMatch = RegExp(r'TZID=([^;:]+)').firstMatch(key);
      final tzid = tzidMatch?.group(1);
      for (final v in values.split(',')) {
        final dt = _parseDateTimeString(v.trim(), tzid: tzid);
        if (dt != null) result.add(dt.millisecondsSinceEpoch);
      }
    }
    return result;
  }

  bool _isExcluded(DateTime occStart, Set<int> exdates) {
    // Allow ±30s tolerance for floating-time edge cases
    return exdates.any((ms) => (occStart.millisecondsSinceEpoch - ms).abs() < 30000);
  }

  // ---------------------------------------------------------------------------
  // Event builder
  // ---------------------------------------------------------------------------

  NormalizedEvent? _buildEvent(
    Map<String, String> props,
    List<String> attendeeLines,
    String accountId, {
    String? instanceId,
    DateTime? instanceStart,
    DateTime? instanceEnd,
  }) {
    final uid = props['UID'];
    if (uid == null && instanceId == null) return null;

    final dtStart = instanceStart ?? _parseDateTimeFromProps(props, 'DTSTART');
    if (dtStart == null) return null;

    DateTime? dtEnd = instanceEnd ?? _parseDateTimeFromProps(props, 'DTEND');
    if (dtEnd == null && props.containsKey('DURATION')) {
      dtEnd = dtStart.add(_parseDuration(props['DURATION']!));
    }
    if (dtEnd == null) return null;

    final rawSummary = props['SUMMARY'] ?? '(No title)';
    final classValue = (props['CLASS'] ?? '').toUpperCase();
    final isPrivate = classValue == 'PRIVATE' ||
        classValue == 'CONFIDENTIAL' ||
        rawSummary.trim().toLowerCase() == 'private appointment' ||
        rawSummary.trim().toLowerCase() == 'private';
    final summary = isPrivate ? 'Private' : rawSummary;

    final location = props['LOCATION'];
    final description = props['DESCRIPTION'];
    final isOnline = location != null &&
        (location.contains('http') ||
         location.toLowerCase().contains('teams') ||
         location.toLowerCase().contains('zoom') ||
         location.toLowerCase().contains('meet'));

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

    String? originalTz;
    for (final key in props.keys) {
      if (key.startsWith('DTSTART;TZID=')) {
        originalTz = RegExp(r'TZID=([^;:]+)').firstMatch(key)?.group(1);
        break;
      }
    }

    // Always serialise as an explicit UTC ISO string (with Z suffix) so that
    // parseToLocal() can unambiguously convert to the system timezone.
    // tz.TZDateTime.toUtc() may return a TZDateTime whose isUtc flag is false
    // even when in UTC location — going via millisecondsSinceEpoch guarantees
    // a standard Dart UTC DateTime whose toIso8601String() appends 'Z'.
    String _toUtcIso(DateTime dt) =>
        DateTime.fromMillisecondsSinceEpoch(dt.millisecondsSinceEpoch, isUtc: true)
            .toIso8601String();

    return NormalizedEvent(
      id: instanceId ?? uid!,
      accountId: accountId,
      provider: CalendarProvider.ics,
      title: summary,
      start: _toUtcIso(dtStart),
      end: _toUtcIso(dtEnd),
      timeZone: originalTz,
      location: isPrivate ? null : location,
      isOnlineMeeting: isPrivate ? false : isOnline,
      onlineMeetingUrl: isPrivate ? null : meetingUrl,
      attendees: isPrivate ? [] : attendees,
      organizer: isPrivate ? null : organizerEmail,
      bodyPreview: isPrivate ? null : description,
      isPrivate: isPrivate,
    );
  }

  // ---------------------------------------------------------------------------
  // DateTime parsing
  // ---------------------------------------------------------------------------

  DateTime? _parseDateTimeFromProps(Map<String, String> props, String key) {
    String? value;
    String? matchedKey;
    // The props map contains BOTH the plain base key (e.g. "DTSTART") AND the
    // parametrized key (e.g. "DTSTART;TZID=America/Denver"), inserted in that
    // order. A plain startsWith(key) always hits the base key first, losing
    // the TZID. We must prefer the parametrized key so timezone is honoured.
    for (final entry in props.entries) {
      if (entry.key.startsWith('$key;')) {   // parametrized first (DTSTART;TZID=…)
        value = entry.value;
        matchedKey = entry.key;
        break;
      }
    }
    if (value == null) {
      // Fall back to plain base key (DTSTART with Z suffix, or all-day DATE)
      value = props[key];
      matchedKey = key;
    }
    if (value == null) return null;
    value = value.trim();

    if (value.length >= 15) {
      final year   = int.tryParse(value.substring(0, 4));
      final month  = int.tryParse(value.substring(4, 6));
      final day    = int.tryParse(value.substring(6, 8));
      final hour   = int.tryParse(value.substring(9, 11));
      final minute = int.tryParse(value.substring(11, 13));
      final second = int.tryParse(value.substring(13, 15));
      if (year == null || month == null || day == null ||
          hour == null || minute == null || second == null) return null;

      if (value.endsWith('Z')) {
        return DateTime.utc(year, month, day, hour, minute, second);
      }

      final tzidMatch = RegExp(r'TZID=([^;:]+)').firstMatch(matchedKey ?? '');
      if (tzidMatch != null) {
        final tzid = tzidMatch.group(1)!;
        final utc = parseWithTzid(year, month, day, hour, minute, second, tzid);
        if (utc != null) return utc;
        debugPrint('[ICS] Unknown TZID "$tzid" — treating as system local time');
        return DateTime(year, month, day, hour, minute, second).toUtc();
      }

      // Floating time — treat as local clock time
      return DateTime(year, month, day, hour, minute, second).toUtc();
    }

    // Date-only (all-day): 20231215
    if (value.length >= 8) {
      final year  = int.tryParse(value.substring(0, 4));
      final month = int.tryParse(value.substring(4, 6));
      final day   = int.tryParse(value.substring(6, 8));
      if (year == null || month == null || day == null) return null;
      return DateTime.utc(year, month, day);
    }

    return null;
  }

  DateTime? _parseDateTimeString(String value, {String? tzid}) {
    value = value.trim();
    if (value.length >= 15) {
      final year   = int.tryParse(value.substring(0, 4));
      final month  = int.tryParse(value.substring(4, 6));
      final day    = int.tryParse(value.substring(6, 8));
      final hour   = int.tryParse(value.substring(9, 11));
      final minute = int.tryParse(value.substring(11, 13));
      final second = int.tryParse(value.substring(13, 15));
      if (year == null || month == null || day == null ||
          hour == null || minute == null || second == null) return null;

      if (value.endsWith('Z')) return DateTime.utc(year, month, day, hour, minute, second);
      if (tzid != null) {
        final utc = parseWithTzid(year, month, day, hour, minute, second, tzid);
        if (utc != null) return utc;
      }
      return DateTime(year, month, day, hour, minute, second).toUtc();
    }
    if (value.length >= 8) {
      final year  = int.tryParse(value.substring(0, 4));
      final month = int.tryParse(value.substring(4, 6));
      final day   = int.tryParse(value.substring(6, 8));
      if (year == null || month == null || day == null) return null;
      return DateTime.utc(year, month, day);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // DURATION parsing (RFC 5545: PT1H30M, P1D, P1DT2H, etc.)
  // ---------------------------------------------------------------------------

  Duration _parseDuration(String raw) {
    final s = raw.trim().toUpperCase();
    var weeks = 0, days = 0, hours = 0, minutes = 0, seconds = 0;
    final pattern = RegExp(r'(\d+)([WDHMS])');
    for (final m in pattern.allMatches(s)) {
      final n = int.parse(m.group(1)!);
      switch (m.group(2)) {
        case 'W': weeks   = n;
        case 'D': days    = n;
        case 'H': hours   = n;
        case 'M': minutes = n;
        case 'S': seconds = n;
      }
    }
    return Duration(
      days:    weeks * 7 + days,
      hours:   hours,
      minutes: minutes,
      seconds: seconds,
    );
  }

  // ---------------------------------------------------------------------------
  // Attendee parsing
  // ---------------------------------------------------------------------------

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
        case 'ACCEPTED':  status = ResponseStatus.accepted;
        case 'TENTATIVE': status = ResponseStatus.tentative;
        case 'DECLINED':  status = ResponseStatus.declined;
      }
    }

    return Attendee(email: email, name: name, status: status);
  }
}

// ---------------------------------------------------------------------------
// Internal data class for a parsed VEVENT before normalisation
// ---------------------------------------------------------------------------

class _RawEvent {
  final Map<String, String> props;
  final List<String> attendeeLines;
  final List<String> exdateLines;

  const _RawEvent({
    required this.props,
    required this.attendeeLines,
    required this.exdateLines,
  });
}
