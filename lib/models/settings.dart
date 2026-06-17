/// Available Claude models shown in the Settings dropdown.
class ClaudeModel {
  final String id;
  final String label;
  final String tier;  // 'Fable' | 'Opus' | 'Sonnet' | 'Haiku'
  const ClaudeModel({required this.id, required this.label, required this.tier});

  static String tierFromId(String id) {
    if (id.contains('fable'))  return 'Fable';
    if (id.contains('opus'))   return 'Opus';
    if (id.contains('sonnet')) return 'Sonnet';
    if (id.contains('haiku'))  return 'Haiku';
    return 'Other';
  }

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'tier': tier};

  factory ClaudeModel.fromJson(Map<String, dynamic> json) => ClaudeModel(
    id:    json['id']    as String,
    label: json['label'] as String,
    tier:  json['tier']  as String,
  );
}

/// Static fallback list used before the first successful API sync.
const kClaudeModels = [
  ClaudeModel(id: 'claude-fable-5',            label: 'Claude Fable 5',        tier: 'Fable'),
  ClaudeModel(id: 'claude-opus-4-8',           label: 'Claude Opus 4.8',       tier: 'Opus'),
  ClaudeModel(id: 'claude-sonnet-4-6',         label: 'Claude Sonnet 4.6',     tier: 'Sonnet'),
  ClaudeModel(id: 'claude-haiku-4-5-20251001', label: 'Claude Haiku 4.5',      tier: 'Haiku'),
  ClaudeModel(id: 'claude-opus-4-7',           label: 'Claude Opus 4.7',       tier: 'Opus'),
  ClaudeModel(id: 'claude-opus-4-6',           label: 'Claude Opus 4.6',       tier: 'Opus'),
  ClaudeModel(id: 'claude-sonnet-4-5-20250929',label: 'Claude Sonnet 4.5',     tier: 'Sonnet'),
];

const kDefaultClaudeModelId = 'claude-sonnet-4-6';

/// Allowed auto-refresh intervals in minutes.
const kAutoRefreshIntervalOptions = [15, 60, 240, 480, 720];

String autoRefreshIntervalLabel(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  return '$h ${h == 1 ? 'hour' : 'hours'}';
}

class AppSettings {
  final int pollingIntervalSeconds;
  final int promptDelayMinutes;
  final int minimumAttendeesForPrompt;
  final bool launchAtLogin;
  final bool showDockIcon;
  final String globalShortcutQuickNote;
  final String globalShortcutToggleApp;
  final String claudeModelId;
  final int autoRefreshIntervalMinutes;
  // Recording
  final String audioCaptureModeStr; // 'screenCapture' | 'mic' | 'blackhole'
  final String whisperModelId;       // WhisperModel.id
  final bool keepAudioFiles;

  const AppSettings({
    this.pollingIntervalSeconds = 30,
    this.promptDelayMinutes = 2,
    this.minimumAttendeesForPrompt = 2,
    this.launchAtLogin = true,
    this.showDockIcon = false,
    this.globalShortcutQuickNote = 'CommandOrControl+Shift+N',
    this.globalShortcutToggleApp = 'CommandOrControl+Shift+M',
    this.claudeModelId = kDefaultClaudeModelId,
    this.autoRefreshIntervalMinutes = 15,
    this.audioCaptureModeStr = 'screenCapture',
    this.whisperModelId = 'base',
    this.keepAudioFiles = false,
  });

  AppSettings copyWith({
    int? pollingIntervalSeconds, int? promptDelayMinutes,
    int? minimumAttendeesForPrompt, bool? launchAtLogin,
    bool? showDockIcon, String? globalShortcutQuickNote,
    String? globalShortcutToggleApp, String? claudeModelId,
    int? autoRefreshIntervalMinutes,
    String? audioCaptureModeStr, String? whisperModelId, bool? keepAudioFiles,
  }) => AppSettings(
    pollingIntervalSeconds: pollingIntervalSeconds ?? this.pollingIntervalSeconds,
    promptDelayMinutes: promptDelayMinutes ?? this.promptDelayMinutes,
    minimumAttendeesForPrompt: minimumAttendeesForPrompt ?? this.minimumAttendeesForPrompt,
    launchAtLogin: launchAtLogin ?? this.launchAtLogin,
    showDockIcon: showDockIcon ?? this.showDockIcon,
    globalShortcutQuickNote: globalShortcutQuickNote ?? this.globalShortcutQuickNote,
    globalShortcutToggleApp: globalShortcutToggleApp ?? this.globalShortcutToggleApp,
    claudeModelId: claudeModelId ?? this.claudeModelId,
    autoRefreshIntervalMinutes: autoRefreshIntervalMinutes ?? this.autoRefreshIntervalMinutes,
    audioCaptureModeStr: audioCaptureModeStr ?? this.audioCaptureModeStr,
    whisperModelId: whisperModelId ?? this.whisperModelId,
    keepAudioFiles: keepAudioFiles ?? this.keepAudioFiles,
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
    'autoRefreshIntervalMinutes': autoRefreshIntervalMinutes,
    'audioCaptureModeStr': audioCaptureModeStr,
    'whisperModelId': whisperModelId,
    'keepAudioFiles': keepAudioFiles,
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
    autoRefreshIntervalMinutes: json['autoRefreshIntervalMinutes'] as int? ?? 15,
    audioCaptureModeStr: json['audioCaptureModeStr'] as String? ?? 'screenCapture',
    whisperModelId: json['whisperModelId'] as String? ?? 'base',
    keepAudioFiles: json['keepAudioFiles'] as bool? ?? false,
  );
}
