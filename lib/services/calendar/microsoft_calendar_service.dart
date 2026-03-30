import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import '../../models/calendar_event.dart';
import '../../core/time_utils.dart';
import '../auth/token_store.dart';

/// Maps Windows timezone IDs (as returned by Microsoft Graph) to IANA timezone IDs.
const Map<String, String> _windowsToIana = {
  'AUS Central Standard Time':     'Australia/Darwin',
  'AUS Eastern Standard Time':     'Australia/Sydney',
  'Afghanistan Standard Time':     'Asia/Kabul',
  'Alaskan Standard Time':         'America/Anchorage',
  'Arab Standard Time':            'Asia/Riyadh',
  'Arabian Standard Time':         'Asia/Dubai',
  'Arabic Standard Time':          'Asia/Baghdad',
  'Argentina Standard Time':       'America/Buenos_Aires',
  'Atlantic Standard Time':        'America/Halifax',
  'Azerbaijan Standard Time':      'Asia/Baku',
  'Canada Central Standard Time':  'America/Regina',
  'Cen. Australia Standard Time':  'Australia/Adelaide',
  'Central America Standard Time': 'America/Guatemala',
  'Central Asia Standard Time':    'Asia/Almaty',
  'Central Europe Standard Time':  'Europe/Budapest',
  'Central European Standard Time':'Europe/Warsaw',
  'Central Pacific Standard Time': 'Pacific/Guadalcanal',
  'Central Standard Time':         'America/Chicago',
  'Central Standard Time (Mexico)':'America/Mexico_City',
  'China Standard Time':           'Asia/Shanghai',
  'E. Africa Standard Time':       'Africa/Nairobi',
  'E. Australia Standard Time':    'Australia/Brisbane',
  'E. Europe Standard Time':       'Asia/Nicosia',
  'Eastern Standard Time':         'America/New_York',
  'Eastern Standard Time (Mexico)':'America/Cancun',
  'Egypt Standard Time':           'Africa/Cairo',
  'FLE Standard Time':             'Europe/Kiev',
  'GMT Standard Time':             'Europe/London',
  'GTB Standard Time':             'Europe/Bucharest',
  'Georgian Standard Time':        'Asia/Tbilisi',
  'Greenland Standard Time':       'America/Godthab',
  'Greenwich Standard Time':       'Atlantic/Reykjavik',
  'Hawaii-Aleutian Standard Time': 'Pacific/Honolulu',
  'India Standard Time':           'Asia/Calcutta',
  'Iran Standard Time':            'Asia/Tehran',
  'Israel Standard Time':          'Asia/Jerusalem',
  'Jordan Standard Time':          'Asia/Amman',
  'Korea Standard Time':           'Asia/Seoul',
  'Mauritius Standard Time':       'Indian/Mauritius',
  'Middle East Standard Time':     'Asia/Beirut',
  'Morocco Standard Time':         'Africa/Casablanca',
  'Mountain Standard Time':        'America/Denver',
  'Mountain Standard Time (Mexico)':'America/Chihuahua',
  'Myanmar Standard Time':         'Asia/Rangoon',
  'N. Central Asia Standard Time': 'Asia/Novosibirsk',
  'Namibia Standard Time':         'Africa/Windhoek',
  'Nepal Standard Time':           'Asia/Katmandu',
  'New Zealand Standard Time':     'Pacific/Auckland',
  'Newfoundland Standard Time':    'America/St_Johns',
  'North Asia East Standard Time': 'Asia/Irkutsk',
  'North Asia Standard Time':      'Asia/Krasnoyarsk',
  'Pacific SA Standard Time':      'America/Santiago',
  'Pacific Standard Time':         'America/Los_Angeles',
  'Pacific Standard Time (Mexico)':'America/Santa_Isabel',
  'Romance Standard Time':         'Europe/Paris',
  'Russia Time Zone 11':           'Asia/Kamchatka',
  'Russia Time Zone 3':            'Europe/Samara',
  'Russia Time Zone 9':            'Asia/Yakutsk',
  'Russian Standard Time':         'Europe/Moscow',
  'SA Eastern Standard Time':      'America/Cayenne',
  'SA Pacific Standard Time':      'America/Bogota',
  'SA Western Standard Time':      'America/La_Paz',
  'SE Asia Standard Time':         'Asia/Bangkok',
  'Singapore Standard Time':       'Asia/Singapore',
  'South Africa Standard Time':    'Africa/Johannesburg',
  'Sri Lanka Standard Time':       'Asia/Colombo',
  'Syria Standard Time':           'Asia/Damascus',
  'Taipei Standard Time':          'Asia/Taipei',
  'Tasmania Standard Time':        'Australia/Hobart',
  'Tokyo Standard Time':           'Asia/Tokyo',
  'Tonga Standard Time':           'Pacific/Tongatapu',
  'Turkey Standard Time':          'Europe/Istanbul',
  'US Eastern Standard Time':      'America/Indianapolis',
  'US Mountain Standard Time':     'America/Phoenix',
  'UTC':                           'UTC',
  'UTC+12':                        'Pacific/Fiji',
  'UTC-02':                        'America/Noronha',
  'UTC-11':                        'Pacific/Pago_Pago',
  'Ulaanbaatar Standard Time':     'Asia/Ulaanbaatar',
  'Venezuela Standard Time':       'America/Caracas',
  'W. Australia Standard Time':    'Australia/Perth',
  'W. Central Africa Standard Time':'Africa/Lagos',
  'W. Europe Standard Time':       'Europe/Berlin',
  'West Asia Standard Time':       'Asia/Tashkent',
  'West Pacific Standard Time':    'Pacific/Port_Moresby',
  'Yakutsk Standard Time':         'Asia/Yakutsk',
};

/// Microsoft Graph API calendar integration using PKCE OAuth 2.0.
///
/// Prerequisites (manual, outside Dart):
/// 1. Register an app in Azure Portal (platform: Mobile/Desktop).
///    Scopes: Calendars.Read, User.Read, openid, email, profile, offline_access
///    Redirect URI: msauth.YOUR_BUNDLE_ID://auth
/// 2. Add the redirect URI scheme to macos/Runner/Info.plist:
///    <key>CFBundleURLTypes</key>
///    <array><dict><key>CFBundleURLSchemes</key>
///      <array><string>msauth.YOUR_BUNDLE_ID</string></array>
///    </dict></array>
/// 3. Set [microsoftClientId] below to your Azure Application (client) ID.
const _microsoftClientId = 'YOUR_AZURE_AD_CLIENT_ID';
const _microsoftTenantId = 'common';
const _microsoftRedirectUri = 'msauth.com.example.calendartaskmanager://auth';
const _microsoftScopes = [
  'openid',
  'email',
  'profile',
  'https://graph.microsoft.com/Calendars.Read',
  'offline_access',
];

const _authorizationEndpoint =
    'https://login.microsoftonline.com/$_microsoftTenantId/oauth2/v2.0/authorize';
const _tokenEndpoint =
    'https://login.microsoftonline.com/$_microsoftTenantId/oauth2/v2.0/token';

class MicrosoftCalendarService {
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://graph.microsoft.com/v1.0',
  ));

  /// Signs in via PKCE OAuth and returns the account email + display name.
  Future<({String email, String displayName})> signIn() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _microsoftClientId,
        _microsoftRedirectUri,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: _authorizationEndpoint,
          tokenEndpoint: _tokenEndpoint,
        ),
        scopes: _microsoftScopes,
      ),
    );

    // result is non-nullable in flutter_appauth 7.x

    // Store refresh token for background token refresh
    final response = await _dio.get(
      '/me',
      options: Options(headers: {'Authorization': 'Bearer ${result.accessToken}'}),
    );
    final email = response.data['mail'] as String?
        ?? response.data['userPrincipalName'] as String?
        ?? 'unknown@microsoft.com';
    final displayName = response.data['displayName'] as String? ?? email;

    if (result.refreshToken != null) {
      await TokenStore.instance.saveSecret('ms-refresh-$email', result.refreshToken!);
    }

    return (email: email, displayName: displayName);
  }

  /// Signs out and removes stored tokens.
  Future<void> signOut(String email) async {
    await TokenStore.instance.deleteSecret('ms-refresh-$email');
  }

  /// Fetches calendar events for the account using a refreshed access token.
  Future<List<NormalizedEvent>> fetchEvents(String accountId, String email) async {
    final accessToken = await _refreshAccessToken(email);

    final now = DateTime.now().toUtc();
    final startDateTime = now.subtract(const Duration(hours: 1)).toIso8601String();
    final endDateTime = now.add(const Duration(hours: 24)).toIso8601String();

    final response = await _dio.get(
      '/me/calendarView',
      options: Options(headers: {
        'Authorization': 'Bearer $accessToken',
        'Prefer': 'outlook.timezone="UTC"',
      }),
      queryParameters: {
        'startDateTime': startDateTime,
        'endDateTime': endDateTime,
        r'$select':
            'id,subject,start,end,location,isOnlineMeeting,onlineMeetingUrl,attendees,organizer,bodyPreview,responseStatus',
        r'$top': 100,
      },
    );

    final items = (response.data['value'] as List<dynamic>?) ?? [];
    return items
        .map((e) => _normalizeEvent(e as Map<String, dynamic>, accountId))
        .toList();
  }

  Future<String> _refreshAccessToken(String email) async {
    final storedRefreshToken = await TokenStore.instance.loadSecret('ms-refresh-$email');
    if (storedRefreshToken == null) {
      throw Exception('No refresh token for $email — please re-connect the account');
    }

    final result = await _appAuth.token(
      TokenRequest(
        _microsoftClientId,
        _microsoftRedirectUri,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: _authorizationEndpoint,
          tokenEndpoint: _tokenEndpoint,
        ),
        refreshToken: storedRefreshToken,
        scopes: _microsoftScopes,
      ),
    );

    // Store the new refresh token
    final newRefresh = result.refreshToken;
    if (newRefresh != null) {
      await TokenStore.instance.saveSecret('ms-refresh-$email', newRefresh);
    }

    final accessToken = result.accessToken;
    if (accessToken == null) {
      throw Exception('Failed to refresh Microsoft access token for $email');
    }
    return accessToken;
  }

  NormalizedEvent _normalizeEvent(Map<String, dynamic> json, String accountId) {
    final startMap = json['start'] as Map<String, dynamic>?;
    final endMap = json['end'] as Map<String, dynamic>?;

    // Graph returns dateTime + timeZone. Even with Prefer: UTC, the timeZone field
    // confirms the actual timezone — use it to convert correctly.
    final startStr = _parseGraphDateTime(
        startMap?['dateTime'] as String?, startMap?['timeZone'] as String?);
    final endStr = _parseGraphDateTime(
        endMap?['dateTime'] as String?, endMap?['timeZone'] as String?);

    final attendeesList = (json['attendees'] as List<dynamic>?) ?? [];
    final attendees = attendeesList.map((a) {
      final att = a as Map<String, dynamic>;
      final emailAddr = (att['emailAddress'] as Map<String, dynamic>?);
      final responseStatus = (att['status'] as Map<String, dynamic>?)?['response'] as String? ?? '';
      return Attendee(
        email: emailAddr?['address'] as String? ?? '',
        name: emailAddr?['name'] as String?,
        status: _mapResponseStatus(responseStatus),
      );
    }).toList();

    final locationDisplay =
        (json['location'] as Map<String, dynamic>?)?['displayName'] as String?;
    final isOnline = json['isOnlineMeeting'] as bool? ?? false;
    final onlineMeetingUrl = json['onlineMeetingUrl'] as String?;
    final organizerEmail =
        ((json['organizer'] as Map<String, dynamic>?)?['emailAddress']
            as Map<String, dynamic>?)?['address'] as String?;

    // Map self response status
    final selfResponse =
        (json['responseStatus'] as Map<String, dynamic>?)?['response'] as String? ?? '';

    return NormalizedEvent(
      id: json['id'] as String,
      accountId: accountId,
      provider: CalendarProvider.microsoft,
      title: json['subject'] as String? ?? '(No title)',
      start: startStr,
      end: endStr,
      location: locationDisplay,
      isOnlineMeeting: isOnline,
      onlineMeetingUrl: onlineMeetingUrl,
      attendees: attendees,
      organizer: organizerEmail,
      responseStatus: _mapResponseStatus(selfResponse),
      bodyPreview: json['bodyPreview'] as String?,
    );
  }

  /// Converts a Graph API dateTime string + Windows/IANA timeZone ID to a UTC ISO 8601 string.
  /// Graph returns naive strings like "2024-01-15T14:00:00.0000000" with a separate timeZone.
  String _parseGraphDateTime(String? raw, String? windowsTzId) {
    if (raw == null) return DateTime.now().toUtc().toIso8601String();

    // Strip sub-second precision beyond 6 digits (Graph uses 7-digit fractional seconds)
    final normalized = raw.replaceFirst(RegExp(r'\.(\d{6})\d+'), '.\$1');

    // If the string already carries offset info, trust it directly
    if (normalized.endsWith('Z') || normalized.contains('+') || normalized.contains('-', 10)) {
      return DateTime.parse(normalized).toUtc().toIso8601String();
    }

    // Resolve timezone: try Windows ID → IANA, then try raw value as IANA directly
    final ianaId = windowsTzId != null
        ? (_windowsToIana[windowsTzId] ?? windowsTzId)
        : null;

    if (ianaId != null && ianaId != 'UTC') {
      // Parse as a naive local time in the specified timezone
      final dt = DateTime.parse('${normalized}Z'); // parse fields; Z discarded below
      final utc = parseWithTzid(
          dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, ianaId);
      if (utc != null) return utc.toIso8601String();
      debugPrint('[MS Calendar] Unknown IANA ID "$ianaId" (from "$windowsTzId") — treating as local time');
      return DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second)
          .toUtc()
          .toIso8601String();
    }

    // UTC or no timezone info: treat as UTC
    return DateTime.parse('${normalized}Z').toIso8601String();
  }

  ResponseStatus _mapResponseStatus(String status) {
    switch (status) {
      case 'accepted':
        return ResponseStatus.accepted;
      case 'tentativelyAccepted':
        return ResponseStatus.tentative;
      case 'declined':
        return ResponseStatus.declined;
      default:
        return ResponseStatus.none;
    }
  }
}
