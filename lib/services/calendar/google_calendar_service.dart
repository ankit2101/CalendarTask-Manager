import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/calendar_event.dart';

/// Google Calendar API v3 integration.
///
/// Prerequisites (manual, outside Dart):
/// 1. Create OAuth 2.0 Desktop credentials in Google Cloud Console.
/// 2. Place GoogleService-Info.plist in macos/Runner/.
/// 3. Add reversed client ID URL scheme to macos/Runner/Info.plist:
///    <key>CFBundleURLTypes</key>
///    <array><dict><key>CFBundleURLSchemes</key>
///      <array><string>com.googleusercontent.apps.YOUR_CLIENT_ID</string></array>
///    </dict></array>
class GoogleCalendarService {
  static const _calendarReadonlyScope =
      'https://www.googleapis.com/auth/calendar.readonly';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [_calendarReadonlyScope],
  );

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://www.googleapis.com/calendar/v3',
  ));

  /// Signs in and returns the authenticated email address.
  Future<String> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Google sign-in was cancelled');
    return account.email;
  }

  /// Signs out (disconnects) the Google account.
  Future<void> signOut(String email) async {
    await _googleSignIn.disconnect();
  }

  /// Fetches calendar events for the signed-in Google account.
  Future<List<NormalizedEvent>> fetchEvents(String accountId) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return [];

    final now = DateTime.now().toUtc();
    final timeMin = now.subtract(const Duration(hours: 1)).toIso8601String();
    final timeMax = now.add(const Duration(hours: 24)).toIso8601String();

    final response = await _dio.get(
      '/calendars/primary/events',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      queryParameters: {
        'timeMin': timeMin,
        'timeMax': timeMax,
        'singleEvents': true,
        'orderBy': 'startTime',
        'maxResults': 100,
      },
    );

    final items = (response.data['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => _normalizeEvent(e as Map<String, dynamic>, accountId))
        .toList();
  }

  Future<String?> _getAccessToken() async {
    final account = await _googleSignIn.signInSilently();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.accessToken;
  }

  NormalizedEvent _normalizeEvent(Map<String, dynamic> json, String accountId) {
    final start = (json['start'] as Map<String, dynamic>?)?['dateTime'] as String?
        ?? (json['start'] as Map<String, dynamic>?)?['date'] as String?
        ?? DateTime.now().toIso8601String();
    final end = (json['end'] as Map<String, dynamic>?)?['dateTime'] as String?
        ?? (json['end'] as Map<String, dynamic>?)?['date'] as String?
        ?? DateTime.now().toIso8601String();

    final attendeesList = (json['attendees'] as List<dynamic>?) ?? [];
    final attendees = attendeesList.map((a) {
      final att = a as Map<String, dynamic>;
      final status = _mapResponseStatus(att['responseStatus'] as String? ?? '');
      return Attendee(
        email: att['email'] as String? ?? '',
        name: att['displayName'] as String?,
        status: status,
      );
    }).toList();

    final location = json['location'] as String?;
    final hangoutLink = json['hangoutLink'] as String?;
    final conferenceData = json['conferenceData'] as Map<String, dynamic>?;
    final entryPoints = (conferenceData?['entryPoints'] as List<dynamic>?) ?? [];
    final conferenceUrl = entryPoints.isNotEmpty
        ? (entryPoints.first as Map<String, dynamic>)['uri'] as String?
        : null;
    final onlineMeetingUrl = hangoutLink ?? conferenceUrl;

    final isOnline = onlineMeetingUrl != null ||
        (location != null &&
            (location.contains('meet.google.com') ||
                location.contains('zoom.us') ||
                location.contains('teams.microsoft.com')));

    final organizer = (json['organizer'] as Map<String, dynamic>?)?['email'] as String?;

    return NormalizedEvent(
      id: json['id'] as String,
      accountId: accountId,
      provider: CalendarProvider.google,
      title: json['summary'] as String? ?? '(No title)',
      start: start,
      end: end,
      location: location,
      isOnlineMeeting: isOnline,
      onlineMeetingUrl: onlineMeetingUrl,
      attendees: attendees,
      organizer: organizer,
      bodyPreview: json['description'] as String?,
    );
  }

  ResponseStatus _mapResponseStatus(String status) {
    switch (status) {
      case 'accepted':
        return ResponseStatus.accepted;
      case 'tentative':
        return ResponseStatus.tentative;
      case 'declined':
        return ResponseStatus.declined;
      default:
        return ResponseStatus.none;
    }
  }
}
