import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Call once at app startup to load the full IANA timezone database.
void initTimezones() {
  tz_data.initializeTimeZones();
}

/// Reinterprets a stored UTC ISO string's wall-clock time in [tzid].
/// Use when the ICS parser used the wrong timezone during ingestion.
/// The "wall-clock time" is recovered by treating the stored UTC as local time,
/// then reinterpreted in [tzid] to produce a corrected UTC → local display time.
DateTime applyTimezoneOverride(String isoString, String tzid) {
  final wall = DateTime.parse(isoString).toLocal();
  return parseWithTzid(wall.year, wall.month, wall.day,
          wall.hour, wall.minute, wall.second, tzid)
      ?.toLocal()
      ?? wall;
}

/// Returns a short timezone abbreviation for display (e.g. "IST", "EST").
/// Falls back to the last segment of [tzid] (e.g. "Kolkata") if lookup fails.
String tzDisplayLabel(String tzid) {
  try {
    final loc = tz.getLocation(tzid);
    return tz.TZDateTime.now(loc).timeZoneName;
  } catch (_) {
    return tzid.split('/').last;
  }
}

/// Parses a stored ISO 8601 string and returns it in the system's local timezone.
/// Handles: UTC (Z suffix), offset-aware (±HH:MM), floating (no suffix → stored as UTC from local).
/// Date-only strings (all-day events) return midnight as a plain local DateTime.
DateTime parseToLocal(String isoString) {
  if (isoString.length == 10) {
    // Date-only all-day event — return as midnight (no tz conversion)
    final d = DateTime.parse(isoString);
    return DateTime(d.year, d.month, d.day);
  }
  return DateTime.parse(isoString).toLocal();
}

/// Converts a naive local-clock time with an IANA TZID into a UTC DateTime.
/// Uses the full IANA tz database — handles DST correctly.
/// Returns null if the TZID is unrecognized (caller should fall back to local time).
DateTime? parseWithTzid(
    int year, int month, int day, int hour, int minute, int second, String tzid) {
  try {
    final location = tz.getLocation(tzid.trim().replaceAll('"', ''));
    final local = tz.TZDateTime(location, year, month, day, hour, minute, second);
    return local.toUtc();
  } catch (e) {
    debugPrint('[TZ] Unrecognized TZID "$tzid": $e');
    return null;
  }
}
