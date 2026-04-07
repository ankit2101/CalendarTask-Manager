enum CalendarProvider { microsoft, google, ics }
enum ResponseStatus { accepted, tentative, declined, none }

class NormalizedEvent {
  final String id;
  final String accountId;
  final CalendarProvider provider;
  final String title;
  final String start; // ISO 8601
  final String end;
  final String? timeZone;
  final String? location;
  final bool isOnlineMeeting;
  final String? onlineMeetingUrl;
  final List<Attendee> attendees;
  final String? organizer;
  final ResponseStatus responseStatus;
  final String? bodyPreview;
  final bool isPrivate;

  NormalizedEvent({
    required this.id,
    required this.accountId,
    required this.provider,
    required this.title,
    required this.start,
    required this.end,
    this.timeZone,
    this.location,
    this.isOnlineMeeting = false,
    this.onlineMeetingUrl,
    this.attendees = const [],
    this.organizer,
    this.responseStatus = ResponseStatus.none,
    this.bodyPreview,
    this.isPrivate = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'accountId': accountId,
    'provider': provider.name,
    'title': title,
    'start': start,
    'end': end,
    'timeZone': timeZone,
    'location': location,
    'isOnlineMeeting': isOnlineMeeting,
    'onlineMeetingUrl': onlineMeetingUrl,
    'attendees': attendees.map((a) => a.toJson()).toList(),
    'organizer': organizer,
    'responseStatus': responseStatus.name,
    'bodyPreview': bodyPreview,
    'isPrivate': isPrivate,
  };

  factory NormalizedEvent.fromJson(Map<String, dynamic> json) => NormalizedEvent(
    id: json['id'] as String,
    accountId: json['accountId'] as String,
    provider: CalendarProvider.values.byName(json['provider'] as String),
    title: json['title'] as String,
    start: json['start'] as String,
    end: json['end'] as String,
    timeZone: json['timeZone'] as String?,
    location: json['location'] as String?,
    isOnlineMeeting: json['isOnlineMeeting'] as bool? ?? false,
    onlineMeetingUrl: json['onlineMeetingUrl'] as String?,
    attendees: (json['attendees'] as List<dynamic>?)
        ?.map((a) => Attendee.fromJson(a as Map<String, dynamic>))
        .toList() ?? [],
    organizer: json['organizer'] as String?,
    responseStatus: ResponseStatus.values.byName(json['responseStatus'] as String? ?? 'none'),
    bodyPreview: json['bodyPreview'] as String?,
    isPrivate: json['isPrivate'] as bool? ?? false,
  );
}

class Attendee {
  final String email;
  final String? name;
  final ResponseStatus status;

  Attendee({required this.email, this.name, this.status = ResponseStatus.none});

  Map<String, dynamic> toJson() => {'email': email, 'name': name, 'status': status.name};
  factory Attendee.fromJson(Map<String, dynamic> json) => Attendee(
    email: json['email'] as String,
    name: json['name'] as String?,
    status: ResponseStatus.values.byName(json['status'] as String? ?? 'none'),
  );
}

class ActionItem {
  final String id;
  final String text;
  final String? assignee;

  ActionItem({required this.id, required this.text, this.assignee});

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'assignee': assignee};
  factory ActionItem.fromJson(Map<String, dynamic> json) => ActionItem(
    id: json['id'] as String,
    text: json['text'] as String,
    assignee: json['assignee'] as String?,
  );
}

class MeetingRecord {
  final String eventId;
  final String title;
  final String date;
  final String note;
  final List<ActionItem> actionItems;
  final String savedAt;

  MeetingRecord({
    required this.eventId,
    required this.title,
    required this.date,
    required this.note,
    this.actionItems = const [],
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'title': title,
    'date': date,
    'note': note,
    'actionItems': actionItems.map((a) => a.toJson()).toList(),
    'savedAt': savedAt,
  };

  factory MeetingRecord.fromJson(Map<String, dynamic> json) => MeetingRecord(
    eventId: json['eventId'] as String,
    title: json['title'] as String,
    date: json['date'] as String,
    note: json['note'] as String,
    actionItems: (json['actionItems'] as List<dynamic>?)
        ?.map((a) => ActionItem.fromJson(a as Map<String, dynamic>))
        .toList() ?? [],
    savedAt: json['savedAt'] as String,
  );
}
