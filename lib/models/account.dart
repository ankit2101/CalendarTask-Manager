class CalendarAccount {
  final String id;
  final String email;
  final String displayName;
  final String provider; // 'microsoft', 'google', 'ics'
  final String? icsUrl; // only for ICS accounts

  CalendarAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
    this.icsUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'email': email, 'displayName': displayName,
    'provider': provider, 'icsUrl': icsUrl,
  };

  factory CalendarAccount.fromJson(Map<String, dynamic> json) => CalendarAccount(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    provider: json['provider'] as String,
    icsUrl: json['icsUrl'] as String?,
  );
}
