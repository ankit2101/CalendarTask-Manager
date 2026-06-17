import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/catppuccin_mocha.dart';
import '../core/time_utils.dart';
import '../models/calendar_event.dart';
import '../models/todo_task.dart';
import '../providers/app_providers.dart';
import '../services/ai/whisper_service.dart';
import '../services/recording/recording_service.dart';

class QuickNoteDialog extends ConsumerStatefulWidget {
  final NormalizedEvent event;
  /// When provided the dialog opens in edit mode pre-filled with this record.
  final MeetingRecord? existingRecord;
  /// Pre-loaded transcription from a dashboard recording session.
  final String? initialTranscription;

  const QuickNoteDialog({
    super.key,
    required this.event,
    this.existingRecord,
    this.initialTranscription,
  });

  @override
  ConsumerState<QuickNoteDialog> createState() => _QuickNoteDialogState();
}

class _QuickNoteDialogState extends ConsumerState<QuickNoteDialog> {
  final _noteController = TextEditingController();
  // Stored controllers so build() never leaks them and user edits survive rebuilds.
  final _transcriptController = TextEditingController();
  final _summaryController = TextEditingController();
  bool _isExtracting = false;
  bool _isSaving = false;
  bool _isSummarizing = false;
  String? _extractError;
  String? _summarizeError;
  List<_EditableActionItem> _actionItems = [];
  final Set<String> _selectedActionIds = {};

  // Recording state
  _RecordingState _recState = _RecordingState.idle;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  // Results
  String? _transcription;
  String? _aiSummary;
  bool _transcriptExpanded = true;
  bool _summaryExpanded = true;

  bool get _isEditMode => widget.existingRecord != null;

  bool get _isActive {
    final now = DateTime.now();
    final start = parseToLocal(widget.event.start);
    final end = parseToLocal(widget.event.end);
    return now.isAfter(start) && now.isBefore(end);
  }

  bool get _canSave =>
      (_noteController.text.trim().isNotEmpty || _transcription != null) && !_isSaving;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _noteController.text = widget.existingRecord!.note;
      _transcription = widget.existingRecord!.transcription;
      _aiSummary = widget.existingRecord!.aiSummary;
      _transcriptController.text = _transcription ?? '';
      _summaryController.text = _aiSummary ?? '';
      _actionItems = widget.existingRecord!.actionItems
          .map((a) => _EditableActionItem.fromActionItem(a))
          .toList();
      _selectedActionIds.addAll(_actionItems.map((i) => i.id));
    } else if (widget.initialTranscription != null) {
      _transcription = widget.initialTranscription;
      WidgetsBinding.instance.addPostFrameCallback((_) => _summarizeTranscript());
    }
    _noteController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _noteController.dispose();
    _transcriptController.dispose();
    _summaryController.dispose();
    _elapsedTimer?.cancel();
    // Issue 9: stop the engine if the dialog is closed mid-recording
    if (_recState == _RecordingState.recording) {
      RecordingService.instance.stopRecording().catchError((_) => '');
    }
    for (final item in _actionItems) {
      item.controller.dispose();
    }
    super.dispose();
  }

  // ─── AI consent ────────────────────────────────────────────────────────────

  Future<bool> _ensureAiConsent() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('claude_ai_consent_given') == true) return true;

    final consented = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: CatppuccinMocha.base,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: CatppuccinMocha.yellow, size: 20),
            SizedBox(width: 8),
            Text('Data Privacy Notice',
                style: TextStyle(color: CatppuccinMocha.text, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To extract action items and generate summaries, the following data will be sent to the Anthropic Claude API:',
              style: TextStyle(color: CatppuccinMocha.subtext0, fontSize: 13),
            ),
            SizedBox(height: 12),
            _BulletRow('Meeting title and date'),
            _BulletRow('Attendee display names (emails are never sent)'),
            _BulletRow('Your meeting notes or transcript'),
            SizedBox(height: 12),
            Text(
              'Audio is transcribed locally using Whisper — it never leaves your machine. This notice is shown once.',
              style: TextStyle(color: CatppuccinMocha.overlay0, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: CatppuccinMocha.overlay0),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CatppuccinMocha.mauve,
              foregroundColor: CatppuccinMocha.base,
            ),
            child: const Text('I Understand — Continue'),
          ),
        ],
      ),
    );

    if (consented == true) {
      await prefs.setBool('claude_ai_consent_given', true);
      return true;
    }
    return false;
  }

  // ─── Recording ─────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final settings = ref.read(settingsProvider);
    final svc = ref.read(recordingServiceProvider);

    try {
      // Guard: ensure a Whisper model is ready before committing to a recording
      final model = WhisperModel.fromId(settings.whisperModelId);
      final whisper = ref.read(whisperServiceProvider);
      if (!await whisper.isModelDownloaded(model)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No Whisper model downloaded. Go to Settings → Recording and download a model first.'),
            duration: Duration(seconds: 5),
          ));
        }
        return;
      }

      // Check/request mic permission
      final perm = await svc.getMicrophonePermission();
      if (perm == 'denied') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Microphone access denied. Enable it in System Settings > Privacy > Microphone.'),
          ));
        }
        return;
      }
      if (perm == 'notDetermined') {
        final granted = await svc.requestMicrophonePermission();
        if (!granted) return;
      }

      // Try preferred mode, fall back to mic-only on failure
      String mode = settings.audioCaptureModeStr;
      try {
        await svc.startRecording(mode);
      } catch (_) {
        if (mode != 'mic') {
          mode = 'mic';
          await svc.startRecording(mode);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('System audio capture unavailable — recording mic only.'),
              duration: Duration(seconds: 3),
            ));
          }
        } else {
          rethrow;
        }
      }

      _elapsedSeconds = 0;
      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSeconds++);
      });
      if (mounted) setState(() => _recState = _RecordingState.recording);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recording failed: $e')));
      }
    }
  }

  Future<void> _stopRecording() async {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    setState(() => _recState = _RecordingState.transcribing);

    try {
      final wavPath = await ref.read(recordingServiceProvider).stopRecording();
      if (wavPath.isEmpty) {
        setState(() => _recState = _RecordingState.idle);
        return;
      }
      await _transcribeFile(wavPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stop failed: $e')));
        setState(() => _recState = _RecordingState.idle);
      }
    }
  }

  Future<void> _transcribeFile(String wavPath) async {
    final settings = ref.read(settingsProvider);
    final model = WhisperModel.fromId(settings.whisperModelId);
    final whisper = ref.read(whisperServiceProvider);

    try {
      final text = await whisper.transcribeFile(wavPath: wavPath, model: model);
      setState(() {
        _transcription = text.isEmpty ? null : text;
        _transcriptController.text = _transcription ?? '';
        _recState = _RecordingState.done;
      });
      if (_transcription != null) await _summarizeTranscript();
    } catch (e) {
      if (mounted) {
        setState(() => _recState = _RecordingState.idle);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transcription failed: $e')));
      }
    } finally {
      // Always clean up the temp WAV — even when transcription throws
      if (!settings.keepAudioFiles) {
        try { await File(wavPath).delete(); } catch (_) {}
      }
    }
  }

  // ─── AI actions ────────────────────────────────────────────────────────────

  Future<void> _summarizeTranscript() async {
    if (_transcription == null) return;
    if (!await _ensureAiConsent()) return;

    setState(() { _isSummarizing = true; _summarizeError = null; });
    try {
      final client = await ref.read(claudeClientProvider.future);
      final result = await client.summarizeTranscript(_transcription!, widget.event);
      for (final item in _actionItems) item.controller.dispose();
      setState(() {
        _aiSummary = result.summary;
        _summaryController.text = _aiSummary ?? '';
        _actionItems = result.actionItems.map((a) => _EditableActionItem.fromActionItem(a)).toList();
        _selectedActionIds
          ..clear()
          ..addAll(_actionItems.map((i) => i.id));
      });
    } catch (e) {
      setState(() => _summarizeError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSummarizing = false);
    }
  }

  Future<void> _extractActions() async {
    if (!await _ensureAiConsent()) return;
    setState(() { _isExtracting = true; _extractError = null; });
    try {
      final client = await ref.read(claudeClientProvider.future);
      final items = await client.extractActionItems(
        widget.event,
        transcript: _transcription,
        summary: _aiSummary,
        notes: _noteController.text.trim().isNotEmpty ? _noteController.text : null,
      );
      for (final item in _actionItems) item.controller.dispose();
      setState(() {
        _actionItems = items.map((a) => _EditableActionItem.fromActionItem(a)).toList();
        _selectedActionIds
          ..clear()
          ..addAll(_actionItems.map((i) => i.id));
      });
    } catch (e) {
      setState(() => _extractError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isExtracting = false);
    }
  }

  // ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final finalItems = _actionItems
          .map((e) => ActionItem(id: e.id, text: e.controller.text.trim(), assignee: e.assignee))
          .where((a) => a.text.isNotEmpty)
          .toList();

      final record = MeetingRecord(
        eventId: widget.event.id,
        title: widget.event.title,
        date: widget.event.start,
        note: _noteController.text.trim(),
        actionItems: finalItems,
        savedAt: _isEditMode
            ? widget.existingRecord!.savedAt
            : DateTime.now().toIso8601String(),
        transcription: _transcription,
        aiSummary: _aiSummary,
      );

      await ref.read(meetingHistoryProvider.notifier).saveRecord(record);
      await ref.read(todosProvider.notifier).deleteTodosByMeetingId(widget.event.id);

      const uuid = Uuid();
      final now = DateTime.now().toIso8601String();
      for (final item in finalItems) {
        if (_selectedActionIds.contains(item.id)) {
          await ref.read(todosProvider.notifier).addTodo(TodoTask(
            id: uuid.v4(),
            title: item.text,
            description: item.assignee != null ? 'Assigned to: ${item.assignee}' : null,
            meetingEventId: widget.event.id,
            createdAt: now,
          ));
        }
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addManualItem() {
    setState(() {
      final item = _EditableActionItem(
        id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
        controller: TextEditingController(),
        assignee: null,
        isNew: true,
      );
      _actionItems.add(item);
      _selectedActionIds.add(item.id);
    });
  }

  void _deleteItem(String id) {
    final item = _actionItems.firstWhere((i) => i.id == id);
    item.controller.dispose();
    setState(() {
      _actionItems.removeWhere((i) => i.id == id);
      _selectedActionIds.remove(id);
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('EEEE, MMMM d');
    final start = parseToLocal(event.start);
    final canExtract = (_noteController.text.trim().isNotEmpty || _transcription != null) && !_isExtracting;

    return Dialog(
      backgroundColor: CatppuccinMocha.base,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, minWidth: 440, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(event, timeFormat, dateFormat, start),
                    const SizedBox(height: 16),
                    const Divider(color: CatppuccinMocha.surface1),
                    const SizedBox(height: 16),

                    // Recording controls
                    _buildRecordingBar(),
                    const SizedBox(height: 16),

                    // Transcript section (shown when available)
                    if (_transcription != null) ...[
                      _buildCollapsibleSection(
                        title: 'Transcript',
                        icon: Icons.mic,
                        iconColor: CatppuccinMocha.teal,
                        expanded: _transcriptExpanded,
                        onToggle: () => setState(() => _transcriptExpanded = !_transcriptExpanded),
                        child: TextField(
                          controller: _transcriptController,
                          maxLines: null,
                          readOnly: false,
                          onChanged: (v) => _transcription = v,
                          style: const TextStyle(color: CatppuccinMocha.text, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: CatppuccinMocha.mantle,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: CatppuccinMocha.surface2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: CatppuccinMocha.surface2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: CatppuccinMocha.teal),
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Summary section
                    if (_aiSummary != null || _isSummarizing) ...[
                      _buildCollapsibleSection(
                        title: 'Summary',
                        icon: Icons.summarize_outlined,
                        iconColor: CatppuccinMocha.blue,
                        expanded: _summaryExpanded,
                        onToggle: () => setState(() => _summaryExpanded = !_summaryExpanded),
                        child: _isSummarizing && _aiSummary == null
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: CatppuccinMocha.blue)),
                                    SizedBox(width: 10),
                                    Text('Generating summary…', style: TextStyle(color: CatppuccinMocha.overlay0, fontSize: 13)),
                                  ],
                                ),
                              )
                            : TextField(
                                controller: _summaryController,
                                maxLines: null,
                                onChanged: (v) => _aiSummary = v,
                                style: const TextStyle(color: CatppuccinMocha.text, fontSize: 13),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: CatppuccinMocha.mantle,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: CatppuccinMocha.surface2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: CatppuccinMocha.surface2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(color: CatppuccinMocha.blue),
                                  ),
                                  contentPadding: const EdgeInsets.all(10),
                                ),
                              ),
                      ),
                      if (_summarizeError != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: CatppuccinMocha.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: CatppuccinMocha.red.withValues(alpha: 0.3)),
                          ),
                          child: Text(_summarizeError!, style: const TextStyle(color: CatppuccinMocha.red, fontSize: 12)),
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],

                    // Manual notes area
                    const Text(
                      'Meeting Notes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CatppuccinMocha.subtext1, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 6,
                      minLines: 3,
                      autofocus: !_isEditMode && widget.initialTranscription == null,
                      style: const TextStyle(color: CatppuccinMocha.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _isActive
                            ? 'Capture notes as the meeting progresses — decisions, topics, action items…'
                            : 'What happened in this meeting? Decisions made, topics discussed…',
                        hintStyle: const TextStyle(color: CatppuccinMocha.overlay0, fontSize: 14),
                        filled: true,
                        fillColor: CatppuccinMocha.surface0,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CatppuccinMocha.surface2)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CatppuccinMocha.surface2)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: CatppuccinMocha.mauve)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Extract action items button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isExtracting)
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: CatppuccinMocha.mauve)),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: canExtract ? _extractActions : null,
                          icon: const Icon(Icons.auto_awesome, size: 14),
                          label: Text(_isEditMode ? 'Re-extract Action Items' : 'Extract Action Items'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CatppuccinMocha.surface1,
                            foregroundColor: CatppuccinMocha.mauve,
                            textStyle: const TextStyle(fontSize: 13),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),

                    if (_extractError != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: CatppuccinMocha.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: CatppuccinMocha.red.withValues(alpha: 0.3)),
                        ),
                        child: Text(_extractError!, style: const TextStyle(color: CatppuccinMocha.red, fontSize: 13)),
                      ),
                    ],

                    // Action items
                    if (_actionItems.isNotEmpty || _isEditMode) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Action Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CatppuccinMocha.subtext1, letterSpacing: 0.3)),
                                SizedBox(height: 2),
                                Text('Checked items will be synced as todos', style: TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0)),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addManualItem,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Add item', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(foregroundColor: CatppuccinMocha.blue, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_actionItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CatppuccinMocha.surface0,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CatppuccinMocha.surface2),
                          ),
                          child: const Center(
                            child: Text('No action items yet. Extract from notes or add manually.',
                                style: TextStyle(color: CatppuccinMocha.overlay0, fontSize: 13)),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: CatppuccinMocha.surface0,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: CatppuccinMocha.surface2),
                          ),
                          child: Column(
                            children: _actionItems.asMap().entries.map((entry) {
                              final item = entry.value;
                              final isLast = entry.key == _actionItems.length - 1;
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Checkbox(
                                          value: _selectedActionIds.contains(item.id),
                                          onChanged: (v) => setState(() {
                                            if (v == true) _selectedActionIds.add(item.id);
                                            else _selectedActionIds.remove(item.id);
                                          }),
                                          activeColor: CatppuccinMocha.mauve,
                                          checkColor: CatppuccinMocha.base,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: item.controller,
                                            style: const TextStyle(color: CatppuccinMocha.text, fontSize: 13),
                                            maxLines: null,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(vertical: 6),
                                              hintText: 'Action item text…',
                                              hintStyle: TextStyle(color: CatppuccinMocha.overlay0),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 14),
                                          color: CatppuccinMocha.overlay0,
                                          tooltip: 'Remove item',
                                          onPressed: () => _deleteItem(item.id),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isLast) const Divider(height: 1, color: CatppuccinMocha.surface1),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Footer
            const Divider(height: 1, color: CatppuccinMocha.surface1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: CatppuccinMocha.overlay0),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _canSave ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CatppuccinMocha.mauve,
                      foregroundColor: CatppuccinMocha.base,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: CatppuccinMocha.base))
                        : Text(_isEditMode ? 'Update Note' : 'Save Note'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildHeader(NormalizedEvent event, DateFormat timeFormat, DateFormat dateFormat, DateTime start) {
    return Row(
      children: [
        Expanded(
          child: Text(event.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CatppuccinMocha.text)),
        ),
        if (_isEditMode) ...[
          const SizedBox(width: 8),
          _badge('EDITING', Icons.edit, CatppuccinMocha.blue, size: 10),
        ] else if (_isActive) ...[
          const SizedBox(width: 8),
          _badge('LIVE', Icons.circle, CatppuccinMocha.green, size: 7),
        ],
        if (_recState == _RecordingState.recording) ...[
          const SizedBox(width: 8),
          _badge('REC', Icons.fiber_manual_record, CatppuccinMocha.red, size: 7),
        ],
      ],
    );
  }

  Widget _badge(String text, IconData icon, Color color, {double size = 10}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CatppuccinMocha.surface0,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _recState == _RecordingState.recording
            ? CatppuccinMocha.red.withValues(alpha: 0.4)
            : CatppuccinMocha.surface2),
      ),
      child: Row(
        children: [
          if (_recState == _RecordingState.idle || _recState == _RecordingState.done) ...[
            const Icon(Icons.mic_outlined, size: 16, color: CatppuccinMocha.overlay0),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _recState == _RecordingState.done ? 'Recording complete' : 'Record this meeting',
                style: TextStyle(
                  color: _recState == _RecordingState.done ? CatppuccinMocha.green : CatppuccinMocha.overlay0,
                  fontSize: 13,
                ),
              ),
            ),
            if (_recState == _RecordingState.idle)
              OutlinedButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.fiber_manual_record, size: 13),
                label: const Text('Record', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CatppuccinMocha.red,
                  side: BorderSide(color: CatppuccinMocha.red.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                ),
              ),
          ] else if (_recState == _RecordingState.recording) ...[
            const _PulsingDot(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _formatElapsed(_elapsedSeconds),
                style: const TextStyle(color: CatppuccinMocha.red, fontSize: 13, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            OutlinedButton(
              onPressed: _stopRecording,
              style: OutlinedButton.styleFrom(
                foregroundColor: CatppuccinMocha.red,
                side: BorderSide(color: CatppuccinMocha.red.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Stop'),
            ),
          ] else if (_recState == _RecordingState.transcribing) ...[
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: CatppuccinMocha.teal)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Transcribing with Whisper…', style: TextStyle(color: CatppuccinMocha.teal, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: iconColor, letterSpacing: 0.3)),
              const Spacer(),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: CatppuccinMocha.overlay0),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 6),
          child,
        ],
      ],
    );
  }

  String _formatElapsed(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

// ─── Recording state enum ────────────────────────────────────────────────────

enum _RecordingState { idle, recording, transcribing, done }

// ─── Pulsing red dot ─────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: CatppuccinMocha.red.withValues(alpha: 0.4 + _ctrl.value * 0.6),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _BulletRow extends StatelessWidget {
  final String text;
  const _BulletRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: CatppuccinMocha.mauve, fontSize: 13)),
          Expanded(child: Text(text, style: const TextStyle(color: CatppuccinMocha.subtext0, fontSize: 13))),
        ],
      ),
    );
  }
}

class _EditableActionItem {
  final String id;
  final TextEditingController controller;
  final String? assignee;
  final bool isNew;

  _EditableActionItem({
    required this.id,
    required this.controller,
    required this.assignee,
    this.isNew = false,
  });

  factory _EditableActionItem.fromActionItem(ActionItem item) => _EditableActionItem(
    id: item.id,
    controller: TextEditingController(text: item.text),
    assignee: item.assignee,
  );
}
