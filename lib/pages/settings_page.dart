import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import '../core/theme/catppuccin_mocha.dart';
import '../providers/app_providers.dart';
import '../models/settings.dart';
import '../services/ai/local_llm_service.dart';
import '../services/ai/whisper_service.dart';
import '../services/storage/app_database.dart';
import '../services/auth/token_store.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _apiKeyController = TextEditingController();
  bool _apiKeyObscured = true;
  String? _dataFilePath;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
    _loadDataFilePath();
  }

  Future<void> _loadDataFilePath() async {
    final path = await AppDatabase.getDataFilePath();
    if (mounted) setState(() => _dataFilePath = path);
  }

  Future<void> _loadApiKey() async {
    final key = await TokenStore.instance.loadSecret('claude-api-key');
    if (key != null) _apiKeyController.text = key;
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      await TokenStore.instance.deleteSecret('claude-api-key');
    } else {
      await TokenStore.instance.saveSecret('claude-api-key', key);
    }
    // Force claudeClientProvider to reinitialize with the new key
    ref.invalidate(claudeClientProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key saved')),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: CatppuccinMocha.text)),
          const SizedBox(height: 24),

          // Claude API Key
          const Text('Claude API Key', style: TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
          const SizedBox(height: 4),
          const Text('Required for AI-powered action item extraction.',
              style: TextStyle(fontSize: 13, color: CatppuccinMocha.overlay0)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: _apiKeyObscured,
                  decoration: InputDecoration(
                    hintText: 'sk-ant-...',
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _apiKeyObscured ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                        color: CatppuccinMocha.overlay0,
                      ),
                      onPressed: () => setState(() => _apiKeyObscured = !_apiKeyObscured),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _saveApiKey, child: const Text('Save')),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Task Extraction model — Anthropic (cloud) or on-prem (on-device)
          const _TaskExtractionSettingsSection(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Recording
          const _RecordingSettingsSection(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Polling interval
          const Text('Sync Interval', style: TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: settings.pollingIntervalSeconds.toDouble(),
                  min: 10,
                  max: 300,
                  divisions: 29,
                  label: '${settings.pollingIntervalSeconds}s',
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).update(
                      settings.copyWith(pollingIntervalSeconds: val.round()),
                    );
                  },
                ),
              ),
              Text('${settings.pollingIntervalSeconds}s',
                  style: const TextStyle(color: CatppuccinMocha.text)),
            ],
          ),
          const SizedBox(height: 16),

          // Auto-refresh interval
          const Text('Auto Refresh Interval', style: TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
          const SizedBox(height: 4),
          const Text(
            'How often the calendar automatically refreshes in the background.',
            style: TextStyle(fontSize: 13, color: CatppuccinMocha.overlay0),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: kAutoRefreshIntervalOptions.contains(settings.autoRefreshIntervalMinutes)
                ? settings.autoRefreshIntervalMinutes
                : 15,
            dropdownColor: CatppuccinMocha.surface0,
            style: const TextStyle(color: CatppuccinMocha.text, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: CatppuccinMocha.surface0,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: CatppuccinMocha.surface2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: CatppuccinMocha.surface2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: CatppuccinMocha.mauve),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: kAutoRefreshIntervalOptions.map((minutes) => DropdownMenuItem(
              value: minutes,
              child: Text(autoRefreshIntervalLabel(minutes), style: const TextStyle(color: CatppuccinMocha.text)),
            )).toList(),
            onChanged: (val) {
              if (val == null) return;
              ref.read(settingsProvider.notifier).update(
                settings.copyWith(autoRefreshIntervalMinutes: val),
              );
            },
          ),
          const SizedBox(height: 16),

          // Minimum attendees
          const Text('Minimum Attendees for Note Prompt', style: TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: settings.minimumAttendeesForPrompt.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${settings.minimumAttendeesForPrompt}',
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).update(
                      settings.copyWith(minimumAttendeesForPrompt: val.round()),
                    );
                  },
                ),
              ),
              Text('${settings.minimumAttendeesForPrompt}',
                  style: const TextStyle(color: CatppuccinMocha.text)),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Data management
          const Text('Data', style: TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final db = await AppDatabase.getInstance();
                  final data = db.exportData();
                  final timestamp = DateTime.now()
                      .toIso8601String()
                      .replaceAll(':', '-')
                      .substring(0, 19);
                  final defaultName = 'calendartask-backup-$timestamp.json';

                  // Let the user choose where to save
                  final savePath = await FilePicker.platform.saveFile(
                    dialogTitle: 'Save Backup',
                    fileName: defaultName,
                    allowedExtensions: ['json'],
                    type: FileType.custom,
                  );

                  if (savePath == null) return; // user cancelled

                  await File(savePath).writeAsString(data, flush: true);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Backup saved to $savePath'),
                        duration: const Duration(seconds: 6),
                        action: SnackBarAction(
                          label: 'OK',
                          onPressed: () {},
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export Backup'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json'],
                    allowMultiple: false,
                    withData: true,
                  );
                  if (result == null || result.files.isEmpty) return;
                  final bytes = result.files.first.bytes;
                  if (bytes == null) return;
                  try {
                    final jsonStr = utf8.decode(bytes);
                    final db = await AppDatabase.getInstance();
                    final summary = await db.importData(jsonStr);
                    ref.read(meetingHistoryProvider.notifier).reload();
                    ref.read(todosProvider.notifier).reload();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(
                          'Imported ${summary['meetingHistoryCount']} notes, ${summary['todoTaskCount']} tasks',
                        )),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Import failed: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Import'),
              ),
            ],
          ),

          ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Sync File', style: TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
            const SizedBox(height: 4),
            const Text(
              'Point all your machines to the same folder in OneDrive, iCloud Drive, or Dropbox and the app will sync automatically whenever the file changes.',
              style: TextStyle(fontSize: 13, color: CatppuccinMocha.overlay0),
            ),
            const SizedBox(height: 4),
            const Text(
              'Two files are stored: calendartask_data.json (your data) and calendartask_key.b64 (shared encryption key). Both must be in the same folder on every machine.',
              style: TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: CatppuccinMocha.surface0,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CatppuccinMocha.surface2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_outlined, size: 14, color: CatppuccinMocha.overlay0),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _dataFilePath ?? '…',
                      style: const TextStyle(fontSize: 12, color: CatppuccinMocha.text),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await FilePicker.platform.getDirectoryPath(
                      dialogTitle: 'Choose Sync Folder',
                    );
                    if (picked == null) return;
                    final adoptedExisting = await AppDatabase.changeDataDirectory(picked);
                    // Reload all data providers from new location
                    final db = await AppDatabase.getInstance();
                    // Re-activate watcher on new path
                    ref.read(syncWatcherProvider);
                    ref.read(settingsProvider.notifier).update(db.getSettings());
                    ref.read(meetingHistoryProvider.notifier).reload();
                    ref.read(todosProvider.notifier).reload();
                    ref.read(accountsProvider.notifier).reload();
                    ref.read(dismissedMeetingsProvider.notifier).reload();
                    ref.read(eventTimeOverridesProvider.notifier).reload();
                    final newPath = await AppDatabase.getDataFilePath();
                    setState(() => _dataFilePath = newPath);
                    if (context.mounted) {
                      final message = adoptedExisting
                          ? 'Loaded existing data file from $newPath'
                          : 'Created new data file at $newPath';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          duration: const Duration(seconds: 6),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Choose Folder'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text('System', style: TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Launch at Login', style: TextStyle(color: CatppuccinMocha.text)),
                      SizedBox(height: 2),
                      Text(
                        'Automatically start when you log in to macOS',
                        style: TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: settings.launchAtLogin,
                  onChanged: (val) async {
                    await ref.read(settingsProvider.notifier).update(
                      settings.copyWith(launchAtLogin: val),
                    );
                    if (val) {
                      await LaunchAtStartup.instance.enable();
                    } else {
                      await LaunchAtStartup.instance.disable();
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Lets the user choose between cloud (Claude API) and on-device (bundled LLM)
/// task extraction, and manage the local GGUF model. Mirrors the Whisper model
/// management UI in [_RecordingSettingsSection].
class _TaskExtractionSettingsSection extends ConsumerStatefulWidget {
  const _TaskExtractionSettingsSection();

  @override
  ConsumerState<_TaskExtractionSettingsSection> createState() => _TaskExtractionSettingsSectionState();
}

class _TaskExtractionSettingsSectionState extends ConsumerState<_TaskExtractionSettingsSection> {
  Map<LocalLlmModel, bool> _modelDownloaded = {};
  bool _downloading = false;
  double _downloadProgress = 0;
  bool _backendAvailable = false;
  StreamSubscription<LocalLlmProgress>? _progressSub;

  @override
  void initState() {
    super.initState();
    _checkModels();
    LocalLlmService.instance.isBackendAvailable().then((v) {
      if (mounted) setState(() => _backendAvailable = v);
    });
    _downloading = LocalLlmService.instance.isDownloading;
    _downloadProgress = LocalLlmService.instance.downloadProgress;
    _progressSub = LocalLlmService.instance.progressStream.listen((p) {
      if (!mounted) return;
      if (p.status == LocalLlmStatus.downloadingModel) {
        setState(() {
          _downloading = true;
          _downloadProgress = p.downloadProgress ?? 0;
        });
      } else if (p.status == LocalLlmStatus.done || p.status == LocalLlmStatus.error) {
        if (mounted) setState(() => _downloading = false);
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _checkModels() async {
    final results = <LocalLlmModel, bool>{};
    for (final m in LocalLlmModel.values) {
      results[m] = await LocalLlmService.instance.isModelDownloaded(m);
    }
    if (mounted) setState(() => _modelDownloaded = results);
  }

  Future<void> _downloadModel(LocalLlmModel model) async {
    setState(() { _downloading = true; _downloadProgress = 0; });
    try {
      await LocalLlmService.instance.ensureModel(model);
      await _checkModels();
    } catch (e) {
      if (mounted && !e.toString().contains('cancelled')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _deleteModel(LocalLlmModel model) async {
    await LocalLlmService.instance.deleteModel(model);
    await _checkModels();
  }

  OutlineInputBorder _border(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c));

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  DropdownMenuItem<String> _cloudMenuItem(ClaudeModel model) {
    final tierColor = switch (model.tier) {
      'Fable' => CatppuccinMocha.pink,
      'Opus' => CatppuccinMocha.mauve,
      'Sonnet' => CatppuccinMocha.blue,
      'Haiku' => CatppuccinMocha.teal,
      _ => CatppuccinMocha.overlay0,
    };
    return DropdownMenuItem(
      value: model.id,
      child: Row(children: [
        _badge(model.tier, tierColor),
        const SizedBox(width: 8),
        Flexible(child: Text(model.label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CatppuccinMocha.text))),
      ]),
    );
  }

  DropdownMenuItem<String> _localMenuItem(LocalLlmModel m) {
    final isDownloaded = _modelDownloaded[m] ?? false;
    return DropdownMenuItem(
      value: m.id,
      child: Row(children: [
        _badge('On-prem', CatppuccinMocha.green),
        const SizedBox(width: 8),
        Icon(isDownloaded ? Icons.download_done : Icons.cloud_download_outlined, size: 14,
            color: isDownloaded ? CatppuccinMocha.green : CatppuccinMocha.overlay0),
        const SizedBox(width: 6),
        Flexible(child: Text(m.label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CatppuccinMocha.text))),
      ]),
    );
  }

  Widget _modeChip(String id, String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? CatppuccinMocha.mauve.withValues(alpha: 0.15) : CatppuccinMocha.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? CatppuccinMocha.mauve : CatppuccinMocha.surface2),
          ),
          child: Row(children: [
            Icon(icon, size: 14, color: isSelected ? CatppuccinMocha.mauve : CatppuccinMocha.overlay0),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 13,
              color: isSelected ? CatppuccinMocha.mauve : CatppuccinMocha.subtext1,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isLocal = settings.taskExtractionModeStr == 'local';
    final selectedLocalModel = LocalLlmModel.fromId(settings.localLlmModelId);
    final cloudModels = ref.watch(availableModelsProvider);
    final validCloudId = cloudModels.any((m) => m.id == settings.claudeModelId)
        ? settings.claudeModelId
        : kDefaultClaudeModelId;
    final notifier = ref.read(settingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Task Extraction Model', style: TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
        const SizedBox(height: 4),
        const Text(
          'Model used to extract action items and summaries from meetings.',
          style: TextStyle(fontSize: 13, color: CatppuccinMocha.overlay0),
        ),
        const SizedBox(height: 10),

        // Mode selector
        Row(children: [
          _modeChip('cloud', 'Anthropic', Icons.cloud_outlined, !isLocal,
            () => notifier.update(settings.copyWith(taskExtractionModeStr: 'cloud'))),
          _modeChip('local', 'On-device', Icons.memory_outlined, isLocal,
            () => notifier.update(settings.copyWith(taskExtractionModeStr: 'local'))),
        ]),
        const SizedBox(height: 12),

        if (!isLocal) ...[
          // Cloud model picker
          const Text('Model', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CatppuccinMocha.subtext1)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: validCloudId,
            isExpanded: true,
            dropdownColor: CatppuccinMocha.surface0,
            style: const TextStyle(color: CatppuccinMocha.text, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: CatppuccinMocha.surface0,
              border: _border(CatppuccinMocha.surface2),
              enabledBorder: _border(CatppuccinMocha.surface2),
              focusedBorder: _border(CatppuccinMocha.mauve),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: cloudModels.map(_cloudMenuItem).toList(),
            onChanged: (val) {
              if (val == null) return;
              notifier.update(settings.copyWith(claudeModelId: val));
            },
          ),
        ] else ...[
          // On-device model picker
          const Text('Model', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CatppuccinMocha.subtext1)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: selectedLocalModel.id,
            isExpanded: true,
            dropdownColor: CatppuccinMocha.surface0,
            style: const TextStyle(color: CatppuccinMocha.text, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: CatppuccinMocha.surface0,
              border: _border(CatppuccinMocha.surface2),
              enabledBorder: _border(CatppuccinMocha.surface2),
              focusedBorder: _border(CatppuccinMocha.mauve),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: LocalLlmModel.values.map(_localMenuItem).toList(),
            onChanged: (val) {
              if (val == null) return;
              notifier.update(settings.copyWith(localLlmModelId: val));
            },
          ),
          const SizedBox(height: 10),

          // Engine availability
          Row(children: [
            Icon(_backendAvailable ? Icons.check_circle : Icons.error_outline, size: 14,
                color: _backendAvailable ? CatppuccinMocha.green : CatppuccinMocha.yellow),
            const SizedBox(width: 6),
            Expanded(child: Text(
              _backendAvailable
                  ? 'On-device engine ready (llama.cpp bundled)'
                  : 'On-device engine unavailable in this build — use Anthropic, or rebuild.',
              style: TextStyle(fontSize: 12, color: _backendAvailable ? CatppuccinMocha.text : CatppuccinMocha.yellow),
            )),
          ]),
          const SizedBox(height: 10),

          // Download / progress
          if (_downloading) ...[
            LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              backgroundColor: CatppuccinMocha.surface0,
              color: CatppuccinMocha.teal,
            ),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text(
                _downloadProgress > 0 ? 'Downloading… ${(_downloadProgress * 100).round()}%' : 'Downloading…',
                style: const TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0),
              )),
              TextButton(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                onPressed: () {
                  LocalLlmService.instance.cancelDownload();
                  setState(() => _downloading = false);
                },
                child: const Text('Cancel', style: TextStyle(fontSize: 12, color: CatppuccinMocha.red)),
              ),
            ]),
          ] else
            Row(children: [
              if (!(_modelDownloaded[selectedLocalModel] ?? false))
                ElevatedButton.icon(
                  onPressed: () => _downloadModel(selectedLocalModel),
                  icon: const Icon(Icons.download, size: 14),
                  label: Text('Download ${selectedLocalModel.label}'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                )
              else ...[
                const Icon(Icons.check_circle, size: 14, color: CatppuccinMocha.green),
                const SizedBox(width: 6),
                const Text('Downloaded', style: TextStyle(fontSize: 13, color: CatppuccinMocha.green)),
                const SizedBox(width: 12),
                TextButton(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                  onPressed: () => _deleteModel(selectedLocalModel),
                  child: const Text('Delete', style: TextStyle(fontSize: 12, color: CatppuccinMocha.red)),
                ),
              ],
            ]),
        ],
      ],
    );
  }
}

class _RecordingSettingsSection extends ConsumerStatefulWidget {
  const _RecordingSettingsSection();

  @override
  ConsumerState<_RecordingSettingsSection> createState() => _RecordingSettingsSectionState();
}

class _RecordingSettingsSectionState extends ConsumerState<_RecordingSettingsSection> {
  Map<WhisperModel, bool> _modelDownloaded = {};
  bool _downloading = false;
  double _downloadProgress = 0;
  StreamSubscription<WhisperProgress>? _progressSub;

  @override
  void initState() {
    super.initState();
    _checkModels();
    // Sync with any download already in progress before this widget was mounted.
    _downloading = WhisperService.instance.isDownloading;
    _downloadProgress = WhisperService.instance.downloadProgress;
    _progressSub = WhisperService.instance.progressStream.listen((p) {
      if (!mounted) return;
      if (p.status == WhisperStatus.downloadingModel) {
        setState(() {
          _downloading = true;
          _downloadProgress = p.downloadProgress ?? 0;
        });
      } else if (p.status == WhisperStatus.done || p.status == WhisperStatus.error) {
        // mounted is checked at the top — safe to call setState here
        if (mounted) setState(() => _downloading = false);
      }
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  Future<void> _checkModels() async {
    final results = <WhisperModel, bool>{};
    for (final m in WhisperModel.values) {
      results[m] = await WhisperService.instance.isModelDownloaded(m);
    }
    if (mounted) setState(() => _modelDownloaded = results);
  }

  Future<void> _downloadModel(WhisperModel model) async {
    setState(() { _downloading = true; _downloadProgress = 0; });
    try {
      await WhisperService.instance.ensureModel(model);
      await _checkModels();
    } catch (e) {
      // Don't show an error snackbar when the user explicitly cancelled.
      if (mounted && !e.toString().contains('cancelled')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _deleteModel(WhisperModel model) async {
    await WhisperService.instance.deleteModel(model);
    await _checkModels();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    final captureMode = settings.audioCaptureModeStr;
    final selectedModel = WhisperModel.values.firstWhere(
      (m) => m.id == settings.whisperModelId,
      orElse: () => WhisperModel.base,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recording', style: TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
        const SizedBox(height: 4),
        const Text(
          'Configure audio capture and on-device Whisper transcription for meetings.',
          style: TextStyle(fontSize: 13, color: CatppuccinMocha.overlay0),
        ),
        const SizedBox(height: 16),

        // Audio Capture Mode
        const Text('Audio Capture Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CatppuccinMocha.subtext1)),
        const SizedBox(height: 8),
        _AudioModeSelector(
          selected: captureMode,
          onChanged: (val) {
            ref.read(settingsProvider.notifier).update(settings.copyWith(audioCaptureModeStr: val));
          },
        ),
        if (captureMode == 'screenCapture') ...[
          const SizedBox(height: 6),
          const Text(
            'Screen Recording permission will be requested on first use.',
            style: TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0),
          ),
          const SizedBox(height: 4),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 13, color: CatppuccinMocha.yellow),
            SizedBox(width: 4),
            Expanded(child: Text(
              'ScreenCaptureKit captures audio from ALL applications on your Mac, not only meeting apps. This audio is processed entirely on-device.',
              style: TextStyle(fontSize: 12, color: CatppuccinMocha.yellow),
            )),
          ]),
        ],
        if (captureMode == 'blackhole') ...[
          const SizedBox(height: 6),
          const Text(
            'Install BlackHole 2ch via: brew install blackhole-2ch',
            style: TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0),
          ),
        ],
        const SizedBox(height: 16),

        // Whisper engine status
        const Text('Whisper Engine', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CatppuccinMocha.subtext1)),
        const SizedBox(height: 6),
        const Row(children: [
          Icon(Icons.check_circle, size: 14, color: CatppuccinMocha.green),
          SizedBox(width: 6),
          Text('Bundled (whisper.xcframework v1.9.0)', style: TextStyle(fontSize: 12, color: CatppuccinMocha.text)),
        ]),
        const SizedBox(height: 16),

        // Whisper Model
        const Text('Whisper Model', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CatppuccinMocha.subtext1)),
        const SizedBox(height: 4),
        const Text('Larger models are more accurate but slower and use more disk.', style: TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0)),
        const SizedBox(height: 8),
        DropdownButtonFormField<WhisperModel>(
          value: selectedModel,
          dropdownColor: CatppuccinMocha.surface0,
          style: const TextStyle(color: CatppuccinMocha.text, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: CatppuccinMocha.surface0,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CatppuccinMocha.surface2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CatppuccinMocha.surface2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CatppuccinMocha.mauve)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: WhisperModel.values.map((m) {
            final isDownloaded = _modelDownloaded[m] ?? false;
            return DropdownMenuItem(
              value: m,
              child: Row(children: [
                Icon(isDownloaded ? Icons.download_done : Icons.cloud_download_outlined, size: 14, color: isDownloaded ? CatppuccinMocha.green : CatppuccinMocha.overlay0),
                const SizedBox(width: 8),
                Text(m.label, style: const TextStyle(color: CatppuccinMocha.text)),
              ]),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            ref.read(settingsProvider.notifier).update(settings.copyWith(whisperModelId: val.id));
          },
        ),
        const SizedBox(height: 10),
        if (_downloading) ...[
          LinearProgressIndicator(
            value: _downloadProgress > 0 ? _downloadProgress : null,
            backgroundColor: CatppuccinMocha.surface0,
            color: CatppuccinMocha.teal,
          ),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text(
                _downloadProgress > 0 ? 'Downloading… ${(_downloadProgress * 100).round()}%' : 'Downloading…',
                style: const TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
              onPressed: () {
                WhisperService.instance.cancelDownload();
                setState(() => _downloading = false);
              },
              child: const Text('Cancel', style: TextStyle(fontSize: 12, color: CatppuccinMocha.red)),
            ),
          ]),
        ] else
          Row(children: [
            if (!(_modelDownloaded[selectedModel] ?? false))
              ElevatedButton.icon(
                onPressed: () => _downloadModel(selectedModel),
                icon: const Icon(Icons.download, size: 14),
                label: Text('Download ${selectedModel.label}'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              )
            else ...[
              Row(children: [
                const Icon(Icons.check_circle, size: 14, color: CatppuccinMocha.green),
                const SizedBox(width: 6),
                const Text('Downloaded', style: TextStyle(fontSize: 13, color: CatppuccinMocha.green)),
              ]),
              const SizedBox(width: 12),
              TextButton(
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
                onPressed: () => _deleteModel(selectedModel),
                child: const Text('Delete', style: TextStyle(fontSize: 12, color: CatppuccinMocha.red)),
              ),
            ],
          ]),
        const SizedBox(height: 16),

        // Keep audio files
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Keep Audio Files', style: TextStyle(fontSize: 13, color: CatppuccinMocha.text)),
            SizedBox(height: 2),
            Text('Retain .wav files after transcription (uses disk space)', style: TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0)),
          ])),
          Switch(
            value: settings.keepAudioFiles,
            onChanged: (val) {
              ref.read(settingsProvider.notifier).update(settings.copyWith(keepAudioFiles: val));
            },
          ),
        ]),
      ],
    );
  }
}

class _AudioModeSelector extends StatelessWidget {
  const _AudioModeSelector({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const modes = [
      ('screenCapture', 'ScreenCaptureKit', Icons.screen_share_outlined),
      ('mic', 'Mic Only', Icons.mic_outlined),
      ('blackhole', 'BlackHole', Icons.settings_input_component_outlined),
    ];

    return Row(
      children: modes.map((entry) {
        final (id, label, icon) = entry;
        final isSelected = selected == id;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () => onChanged(id),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? CatppuccinMocha.teal.withValues(alpha: 0.15) : CatppuccinMocha.surface0,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSelected ? CatppuccinMocha.teal : CatppuccinMocha.surface2),
              ),
              child: Row(children: [
                Icon(icon, size: 14, color: isSelected ? CatppuccinMocha.teal : CatppuccinMocha.overlay0),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 13, color: isSelected ? CatppuccinMocha.teal : CatppuccinMocha.subtext1, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                if (id == 'screenCapture') ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: CatppuccinMocha.teal.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3)),
                    child: const Text('★', style: TextStyle(fontSize: 10, color: CatppuccinMocha.teal)),
                  ),
                ],
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}
