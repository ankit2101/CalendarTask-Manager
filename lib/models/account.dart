class CalendarAccount {
  final String id;
  final String email;
  final String displayName;
  final String provider; // 'microsoft', 'google', 'ics'
  final String? icsUrl; // only for ICS accounts
  /// User-chosen calendar colour as a hex string (e.g. '#89B4FA').
  /// Null means use the auto-generated palette colour.
  final String? color;

  CalendarAccount({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
    this.icsUrl,
    this.color,
  });

  CalendarAccount copyWith({
    String? id,
    String? email,
    String? displayName,
    String? provider,
    String? icsUrl,
    Object? color = _sentinel,
  }) {
    return CalendarAccount(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      provider: provider ?? this.provider,
      icsUrl: icsUrl ?? this.icsUrl,
      color: color == _sentinel ? this.color : color as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'provider': provider,
    'icsUrl': icsUrl,
    'color': color,
  };

  factory CalendarAccount.fromJson(Map<String, dynamic> json) => CalendarAccount(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: json['displayName'] as String,
    provider: json['provider'] as String,
    icsUrl: json['icsUrl'] as String?,
    color: json['color'] as String?,
  );
}

// Sentinel object used in copyWith to distinguish "not passed" from explicit null.
const _sentinel = Object();
