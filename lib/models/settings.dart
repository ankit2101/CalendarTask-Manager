/// Available Claude models shown in the Settings dropdown.
class ClaudeModel {
  final String id;       // API model ID
  final String label;    // Display name
  final String tier;     // 'Opus' | 'Sonnet' | 'Haiku'
  const ClaudeModel({required this.id, required this.label, required this.tier});
}

const kClaudeModels = [
  ClaudeModel(id: 'claude-opus-4-5-20251101',    label: 'Claude Opus 4.5',       tier: 'Opus'),
  ClaudeModel(id: 'claude-sonnet-4-5-20251115',  label: 'Claude Sonnet 4.5',     tier: 'Sonnet'),
  ClaudeModel(id: 'claude-sonnet-4-20250514',    label: 'Claude Sonnet 4',       tier: 'Sonnet'),
  ClaudeModel(id: 'claude-3-5-sonnet-20241022',  label: 'Claude 3.5 Sonnet',     tier: 'Sonnet'),
  ClaudeModel(id: 'claude-3-5-haiku-20241022',   label: 'Claude 3.5 Haiku',      tier: 'Haiku'),
  ClaudeModel(id: 'claude-3-haiku-20240307',     label: 'Claude 3 Haiku',        tier: 'Haiku'),
];

const kDefaultClaudeModelId = 'claude-sonnet-4-20250514';

class AppSettings {
  final int pollingIntervalSeconds;
  final int promptDelayMinutes;
  final int minimumAttendeesForPrompt;
  final bool launchAtLogin;
  final bool showDockIcon;
  final String globalShortcutQuickNote;
  final String globalShortcutToggleApp;
  final String claudeModelId;

  const AppSettings({
    this.pollingIntervalSeconds = 30,
    this.promptDelayMinutes = 2,
    this.minimumAttendeesForPrompt = 2,
    this.launchAtLogin = true,
    this.showDockIcon = false,
    this.globalShortcutQuickNote = 'CommandOrControl+Shift+N',
    this.globalShortcutToggleApp = 'CommandOrControl+Shift+M',
    this.claudeModelId = kDefaultClaudeModelId,
  });

  AppSettings copyWith({
    int? pollingIntervalSeconds, int? promptDelayMinutes,
    int? minimumAttendeesForPrompt, bool? launchAtLogin,
    bool? showDockIcon, String? globalShortcutQuickNote,
    String? globalShortcutToggleApp, String? claudeModelId,
  }) => AppSettings(
    pollingIntervalSeconds: pollingIntervalSeconds ?? this.pollingIntervalSeconds,
    promptDelayMinutes: promptDelayMinutes ?? this.promptDelayMinutes,
    minimumAttendeesForPrompt: minimumAttendeesForPrompt ?? this.minimumAttendeesForPrompt,
    launchAtLogin: launchAtLogin ?? this.launchAtLogin,
    showDockIcon: showDockIcon ?? this.showDockIcon,
    globalShortcutQuickNote: globalShortcutQuickNote ?? this.globalShortcutQuickNote,
    globalShortcutToggleApp: globalShortcutToggleApp ?? this.globalShortcutToggleApp,
    claudeModelId: claudeModelId ?? this.claudeModelId,
  );

  Map<String, dynamic> toJson() => {
    'pollingIntervalSeconds': pollingIntervalSeconds,
    'promptDelayMinutes': promptDelayMinutes,
    'minimumAttendeesForPrompt': minimumAttendeesForPrompt,
    'launchAtLogin': launchAtLogin,
    'showDockIcon': showDockIcon,
    'globalShortcutQuickNote': globalShortcutQuickNote,
    'globalShortcutToggleApp': globalShortcutToggleApp,
    'claudeModelId': claudeModelId,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    pollingIntervalSeconds: json['pollingIntervalSeconds'] as int? ?? 30,
    promptDelayMinutes: json['promptDelayMinutes'] as int? ?? 2,
    minimumAttendeesForPrompt: json['minimumAttendeesForPrompt'] as int? ?? 2,
    launchAtLogin: json['launchAtLogin'] as bool? ?? true,
    showDockIcon: json['showDockIcon'] as bool? ?? false,
    globalShortcutQuickNote: json['globalShortcutQuickNote'] as String? ?? 'CommandOrControl+Shift+N',
    globalShortcutToggleApp: json['globalShortcutToggleApp'] as String? ?? 'CommandOrControl+Shift+M',
    claudeModelId: json['claudeModelId'] as String? ?? kDefaultClaudeModelId,
  );
}
