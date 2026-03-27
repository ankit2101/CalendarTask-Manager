class AppSettings {
  final int pollingIntervalSeconds;
  final int promptDelayMinutes;
  final int minimumAttendeesForPrompt;
  final bool launchAtLogin;
  final bool showDockIcon;
  final String globalShortcutQuickNote;
  final String globalShortcutToggleApp;

  const AppSettings({
    this.pollingIntervalSeconds = 30,
    this.promptDelayMinutes = 2,
    this.minimumAttendeesForPrompt = 2,
    this.launchAtLogin = true,
    this.showDockIcon = false,
    this.globalShortcutQuickNote = 'CommandOrControl+Shift+N',
    this.globalShortcutToggleApp = 'CommandOrControl+Shift+M',
  });

  AppSettings copyWith({
    int? pollingIntervalSeconds, int? promptDelayMinutes,
    int? minimumAttendeesForPrompt, bool? launchAtLogin,
    bool? showDockIcon, String? globalShortcutQuickNote,
    String? globalShortcutToggleApp,
  }) => AppSettings(
    pollingIntervalSeconds: pollingIntervalSeconds ?? this.pollingIntervalSeconds,
    promptDelayMinutes: promptDelayMinutes ?? this.promptDelayMinutes,
    minimumAttendeesForPrompt: minimumAttendeesForPrompt ?? this.minimumAttendeesForPrompt,
    launchAtLogin: launchAtLogin ?? this.launchAtLogin,
    showDockIcon: showDockIcon ?? this.showDockIcon,
    globalShortcutQuickNote: globalShortcutQuickNote ?? this.globalShortcutQuickNote,
    globalShortcutToggleApp: globalShortcutToggleApp ?? this.globalShortcutToggleApp,
  );

  Map<String, dynamic> toJson() => {
    'pollingIntervalSeconds': pollingIntervalSeconds,
    'promptDelayMinutes': promptDelayMinutes,
    'minimumAttendeesForPrompt': minimumAttendeesForPrompt,
    'launchAtLogin': launchAtLogin,
    'showDockIcon': showDockIcon,
    'globalShortcutQuickNote': globalShortcutQuickNote,
    'globalShortcutToggleApp': globalShortcutToggleApp,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    pollingIntervalSeconds: json['pollingIntervalSeconds'] as int? ?? 30,
    promptDelayMinutes: json['promptDelayMinutes'] as int? ?? 2,
    minimumAttendeesForPrompt: json['minimumAttendeesForPrompt'] as int? ?? 2,
    launchAtLogin: json['launchAtLogin'] as bool? ?? true,
    showDockIcon: json['showDockIcon'] as bool? ?? false,
    globalShortcutQuickNote: json['globalShortcutQuickNote'] as String? ?? 'CommandOrControl+Shift+N',
    globalShortcutToggleApp: json['globalShortcutToggleApp'] as String? ?? 'CommandOrControl+Shift+M',
  );
}
