import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Call once at app startup to load the full IANA timezone database.
void initTimezones() {
  tz_data.initializeTimeZones();
}

/// Windows timezone name → IANA timezone ID mapping (same set used by Microsoft Graph).
const Map<String, String> windowsToIana = {
  'AUS Central Standard Time':      'Australia/Darwin',
  'AUS Eastern Standard Time':      'Australia/Sydney',
  'Afghanistan Standard Time':      'Asia/Kabul',
  'Alaskan Standard Time':          'America/Anchorage',
  'Arab Standard Time':             'Asia/Riyadh',
  'Arabian Standard Time':          'Asia/Dubai',
  'Arabic Standard Time':           'Asia/Baghdad',
  'Argentina Standard Time':        'America/Buenos_Aires',
  'Atlantic Standard Time':         'America/Halifax',
  'Azerbaijan Standard Time':       'Asia/Baku',
  'Canada Central Standard Time':   'America/Regina',
  'Cen. Australia Standard Time':   'Australia/Adelaide',
  'Central America Standard Time':  'America/Guatemala',
  'Central Asia Standard Time':     'Asia/Almaty',
  'Central Europe Standard Time':   'Europe/Budapest',
  'Central European Standard Time': 'Europe/Warsaw',
  'Central Pacific Standard Time':  'Pacific/Guadalcanal',
  'Central Standard Time':          'America/Chicago',
  'Central Standard Time (Mexico)': 'America/Mexico_City',
  'China Standard Time':            'Asia/Shanghai',
  'E. Africa Standard Time':        'Africa/Nairobi',
  'E. Australia Standard Time':     'Australia/Brisbane',
  'E. Europe Standard Time':        'Asia/Nicosia',
  'Eastern Standard Time':          'America/New_York',
  'Eastern Standard Time (Mexico)': 'America/Cancun',
  'Egypt Standard Time':            'Africa/Cairo',
  'FLE Standard Time':              'Europe/Kiev',
  'GMT Standard Time':              'Europe/London',
  'GTB Standard Time':              'Europe/Bucharest',
  'Georgian Standard Time':         'Asia/Tbilisi',
  'Greenland Standard Time':        'America/Godthab',
  'Greenwich Standard Time':        'Atlantic/Reykjavik',
  'Hawaii-Aleutian Standard Time':  'Pacific/Honolulu',
  'India Standard Time':            'Asia/Calcutta',
  'Iran Standard Time':             'Asia/Tehran',
  'Israel Standard Time':           'Asia/Jerusalem',
  'Jordan Standard Time':           'Asia/Amman',
  'Korea Standard Time':            'Asia/Seoul',
  'Mauritius Standard Time':        'Indian/Mauritius',
  'Middle East Standard Time':      'Asia/Beirut',
  'Morocco Standard Time':          'Africa/Casablanca',
  'Mountain Standard Time':         'America/Denver',
  'Mountain Standard Time (Mexico)':'America/Chihuahua',
  'Myanmar Standard Time':          'Asia/Rangoon',
  'N. Central Asia Standard Time':  'Asia/Novosibirsk',
  'Namibia Standard Time':          'Africa/Windhoek',
  'Nepal Standard Time':            'Asia/Katmandu',
  'New Zealand Standard Time':      'Pacific/Auckland',
  'Newfoundland Standard Time':     'America/St_Johns',
  'North Asia East Standard Time':  'Asia/Irkutsk',
  'North Asia Standard Time':       'Asia/Krasnoyarsk',
  'Pacific SA Standard Time':       'America/Santiago',
  'Pacific Standard Time':          'America/Los_Angeles',
  'Pacific Standard Time (Mexico)': 'America/Santa_Isabel',
  'Romance Standard Time':          'Europe/Paris',
  'Russia Time Zone 11':            'Asia/Kamchatka',
  'Russia Time Zone 3':             'Europe/Samara',
  'Russia Time Zone 9':             'Asia/Yakutsk',
  'Russian Standard Time':          'Europe/Moscow',
  'SA Eastern Standard Time':       'America/Cayenne',
  'SA Pacific Standard Time':       'America/Bogota',
  'SA Western Standard Time':       'America/La_Paz',
  'SE Asia Standard Time':          'Asia/Bangkok',
  'Singapore Standard Time':        'Asia/Singapore',
  'South Africa Standard Time':     'Africa/Johannesburg',
  'Sri Lanka Standard Time':        'Asia/Colombo',
  'Syria Standard Time':            'Asia/Damascus',
  'Taipei Standard Time':           'Asia/Taipei',
  'Tasmania Standard Time':         'Australia/Hobart',
  'Tokyo Standard Time':            'Asia/Tokyo',
  'Tonga Standard Time':            'Pacific/Tongatapu',
  'Turkey Standard Time':           'Europe/Istanbul',
  'US Eastern Standard Time':       'America/Indianapolis',
  'US Mountain Standard Time':      'America/Phoenix',
  'UTC':                            'UTC',
  'UTC+12':                         'Pacific/Fiji',
  'UTC-02':                         'America/Noronha',
  'UTC-11':                         'Pacific/Pago_Pago',
  'Ulaanbaatar Standard Time':      'Asia/Ulaanbaatar',
  'Venezuela Standard Time':        'America/Caracas',
  'W. Australia Standard Time':     'Australia/Perth',
  'W. Central Africa Standard Time':'Africa/Lagos',
  'W. Europe Standard Time':        'Europe/Berlin',
  'West Asia Standard Time':        'Asia/Tashkent',
  'West Pacific Standard Time':     'Pacific/Port_Moresby',
  'Yakutsk Standard Time':          'Asia/Yakutsk',
};

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
