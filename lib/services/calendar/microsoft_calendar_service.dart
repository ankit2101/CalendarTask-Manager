import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import '../../models/calendar_event.dart';
import '../../core/time_utils.dart';
import '../auth/token_store.dart';


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
  /// Matches the ICS 60-day window (30 days past → 30 days future) and
  /// follows @odata.nextLink to page through all results.
  Future<List<NormalizedEvent>> fetchEvents(String accountId, String email) async {
    final accessToken = await _refreshAccessToken(email);

    final now = DateTime.now().toUtc();
    final startDateTime = now.subtract(const Duration(days: 30)).toIso8601String();
    final endDateTime = now.add(const Duration(days: 30)).toIso8601String();

    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Prefer': 'outlook.timezone="UTC"',
    };

    final allItems = <Map<String, dynamic>>[];
    String? nextUrl;

    // First page
    final firstResponse = await _dio.get(
      '/me/calendarView',
      options: Options(headers: headers),
      queryParameters: {
        'startDateTime': startDateTime,
        'endDateTime': endDateTime,
        r'$select':
            'id,subject,start,end,location,isOnlineMeeting,onlineMeetingUrl,attendees,organizer,bodyPreview,responseStatus',
        r'$top': 500,
      },
    );
    allItems.addAll(((firstResponse.data['value'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>());
    nextUrl = firstResponse.data['@odata.nextLink'] as String?;

    // Follow pagination links until exhausted
    while (nextUrl != null) {
      final pageResponse = await _dio.getUri(
        Uri.parse(nextUrl),
        options: Options(headers: headers),
      );
      allItems.addAll(((pageResponse.data['value'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>());
      nextUrl = pageResponse.data['@odata.nextLink'] as String?;
    }

    debugPrint('[MS Calendar] Fetched ${allItems.length} events for $email');
    return allItems.map((e) => _normalizeEvent(e, accountId)).toList();
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
        ? (windowsToIana[windowsTzId] ?? windowsTzId)
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
