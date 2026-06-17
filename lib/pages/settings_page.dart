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

          // Claude Model
          const Text('Claude Model', style: TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
          const SizedBox(height: 4),
          const Text(
            'Select the model used for AI-powered action item extraction.',
            style: TextStyle(fontSize: 13, color: CatppuccinMocha.overlay0),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final models = ref.watch(availableModelsProvider);
            final validId = models.any((m) => m.id == settings.claudeModelId)
                ? settings.claudeModelId
                : kDefaultClaudeModelId;
            return DropdownButtonFormField<String>(
              value: validId,
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
              items: models.map((model) {
                final tierColor = switch (model.tier) {
                  'Fable'  => CatppuccinMocha.pink,
                  'Opus'   => CatppuccinMocha.mauve,
                  'Sonnet' => CatppuccinMocha.blue,
                  'Haiku'  => CatppuccinMocha.teal,
                  _        => CatppuccinMocha.overlay0,
                };
                return DropdownMenuItem(
                  value: model.id,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          model.tier,
                          style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(model.label, style: const TextStyle(color: CatppuccinMocha.text)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                ref.read(settingsProvider.notifier).update(
                  settings.copyWith(claudeModelId: val),
                );
              },
            );
          }),
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
    _progressSub = WhisperService.instance.progressStream.listen((p) {
      if (!mounted) return;
      setState(() {
        if (p.status == WhisperStatus.downloadingModel) {
          _downloading = true;
          _downloadProgress = p.downloadProgress ?? 0;
        } else if (p.status == WhisperStatus.done || p.status == WhisperStatus.error) {
          _downloading = false;
        }
      });
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
      if (mounted) {
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
          Text(
            _downloadProgress > 0 ? 'Downloading… ${(_downloadProgress * 100).round()}%' : 'Downloading…',
            style: const TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0),
          ),
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
