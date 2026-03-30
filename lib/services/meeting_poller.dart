import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/constants.dart';
import '../core/time_utils.dart';
import '../models/calendar_event.dart';
import 'calendar/calendar_manager.dart';

/// Polls for recently ended meetings and shows local notifications.
///
/// Usage:
///   await MeetingPoller.instance.initialize();
///   MeetingPoller.instance.onMeetingEndDetected = (eventId) { ... };
///   MeetingPoller.instance.start(intervalSeconds: 60, ...);
class MeetingPoller {
  static MeetingPoller? _instance;
  MeetingPoller._();
  static MeetingPoller get instance => _instance ??= MeetingPoller._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Timer? _timer;
  final Set<String> _notifiedEventIds = {};

  /// Called when a meeting end is detected and the user should be prompted for notes.
  void Function(String eventId)? onMeetingEndDetected;

  Future<void> initialize() async {
    if (_initialized) return;
    const macSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _notifications.initialize(
      const InitializationSettings(macOS: macSettings),
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
    _initialized = true;
  }

  /// Starts or restarts the polling timer with updated parameters.
  void start({
    required int intervalSeconds,
    required int promptDelayMinutes,
    required int minimumAttendees,
    required Set<String> notedEventIds,
    required Set<String> dismissedEventIds,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: intervalSeconds.clamp(10, 3600)),
      (_) => _checkForEndedMeetings(
        promptDelayMinutes: promptDelayMinutes,
        minimumAttendees: minimumAttendees,
        notedEventIds: notedEventIds,
        dismissedEventIds: dismissedEventIds,
      ),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _checkForEndedMeetings({
    required int promptDelayMinutes,
    required int minimumAttendees,
    required Set<String> notedEventIds,
    required Set<String> dismissedEventIds,
  }) {
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(minutes: promptDelayMinutes));

    final candidates = CalendarManager.getInstance().cachedEvents.where((event) {
      if (event.end.isEmpty) return false;
      final end = parseToLocal(event.end);
      return end.isAfter(windowStart) &&
          end.isBefore(now) &&
          event.attendees.length >= minimumAttendees &&
          !notedEventIds.contains(event.id) &&
          !dismissedEventIds.contains(event.id) &&
          !isLeaveEvent(event.title);
    });

    for (final event in candidates) {
      _showNotification(event);
    }
  }

  Future<void> _showNotification(NormalizedEvent event) async {
    if (_notifiedEventIds.contains(event.id)) return;
    _notifiedEventIds.add(event.id);

    const macDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    await _notifications.show(
      event.id.hashCode & 0x7FFFFFFF,
      'Meeting just ended',
      'Add notes for: ${event.title}',
      const NotificationDetails(macOS: macDetails),
      payload: event.id,
    );
  }

  void _handleNotificationTap(NotificationResponse response) {
    final eventId = response.payload;
    if (eventId != null) {
      onMeetingEndDetected?.call(eventId);
    }
  }
}
