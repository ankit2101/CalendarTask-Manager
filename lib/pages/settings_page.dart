import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import '../core/theme/catppuccin_mocha.dart';
import '../providers/app_providers.dart';
import '../models/settings.dart';
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
          DropdownButtonFormField<String>(
            value: kClaudeModels.any((m) => m.id == settings.claudeModelId)
                ? settings.claudeModelId
                : kDefaultClaudeModelId,
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
            items: kClaudeModels.map((model) {
              final tierColor = model.tier == 'Opus'
                  ? CatppuccinMocha.mauve
                  : model.tier == 'Sonnet'
                      ? CatppuccinMocha.blue
                      : CatppuccinMocha.teal;
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
              // claudeClientProvider watches settingsProvider and rebuilds
              // automatically — no manual invalidate needed here.
              ref.read(settingsProvider.notifier).update(
                settings.copyWith(claudeModelId: val),
              );
            },
          ),
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
                    await AppDatabase.changeDataDirectory(picked);
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sync folder set. Data file: $newPath'),
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
