import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/catppuccin_mocha.dart';
import '../models/calendar_event.dart';
import '../models/todo_task.dart';
import '../providers/app_providers.dart';

class QuickNoteDialog extends ConsumerStatefulWidget {
  final NormalizedEvent event;

  const QuickNoteDialog({super.key, required this.event});

  @override
  ConsumerState<QuickNoteDialog> createState() => _QuickNoteDialogState();
}

class _QuickNoteDialogState extends ConsumerState<QuickNoteDialog> {
  final _noteController = TextEditingController();
  bool _isExtracting = false;
  bool _isSaving = false;
  String? _extractError;
  List<ActionItem> _actionItems = [];
  final Set<String> _selectedActionIds = {};

  @override
  void initState() {
    super.initState();
    _noteController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _extractActions() async {
    setState(() {
      _isExtracting = true;
      _extractError = null;
    });
    try {
      final client = await ref.read(claudeClientProvider.future);
      final items = await client.extractActionItems(_noteController.text, widget.event);
      setState(() {
        _actionItems = items;
        _selectedActionIds
          ..clear()
          ..addAll(items.map((i) => i.id));
      });
    } catch (e) {
      setState(() {
        _extractError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() => _isExtracting = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final record = MeetingRecord(
        eventId: widget.event.id,
        title: widget.event.title,
        date: widget.event.start,
        note: _noteController.text.trim(),
        actionItems: _actionItems,
        savedAt: DateTime.now().toIso8601String(),
      );
      await ref.read(meetingHistoryProvider.notifier).saveRecord(record);

      const uuid = Uuid();
      final now = DateTime.now().toIso8601String();
      for (final item in _actionItems) {
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

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('EEEE, MMMM d');
    final start = DateTime.parse(event.start);
    final canSave = _noteController.text.trim().isNotEmpty && !_isSaving;
    final canExtract = _noteController.text.trim().isNotEmpty && !_isExtracting;

    return Dialog(
      backgroundColor: CatppuccinMocha.base,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, minWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: CatppuccinMocha.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${dateFormat.format(start)}  ·  '
                '${timeFormat.format(start)} \u2013 ${timeFormat.format(DateTime.parse(event.end))}'
                '${event.attendees.length > 1 ? '  ·  ${event.attendees.length} attendees' : ''}',
                style: const TextStyle(color: CatppuccinMocha.subtext0, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(color: CatppuccinMocha.surface1),
              const SizedBox(height: 16),

              // Notes area
              const Text(
                'Meeting Notes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CatppuccinMocha.subtext1,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 8,
                minLines: 5,
                autofocus: true,
                style: const TextStyle(color: CatppuccinMocha.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'What happened in this meeting? Decisions made, topics discussed...',
                  hintStyle: const TextStyle(color: CatppuccinMocha.overlay0, fontSize: 14),
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
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),

              // Extract button row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isExtracting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: CatppuccinMocha.mauve),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: canExtract ? _extractActions : null,
                    icon: const Icon(Icons.auto_awesome, size: 14),
                    label: const Text('Extract Action Items'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CatppuccinMocha.surface1,
                      foregroundColor: CatppuccinMocha.mauve,
                      textStyle: const TextStyle(fontSize: 13),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),

              // Error display
              if (_extractError != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: CatppuccinMocha.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CatppuccinMocha.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _extractError!,
                    style: const TextStyle(color: CatppuccinMocha.red, fontSize: 13),
                  ),
                ),
              ],

              // Action items list
              if (_actionItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Action Items',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CatppuccinMocha.subtext1,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Checked items will be added as todos',
                  style: TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: CatppuccinMocha.surface0,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CatppuccinMocha.surface2),
                  ),
                  child: Column(
                    children: _actionItems.map((item) {
                      final isLast = item == _actionItems.last;
                      return Column(
                        children: [
                          CheckboxListTile(
                            value: _selectedActionIds.contains(item.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedActionIds.add(item.id);
                              } else {
                                _selectedActionIds.remove(item.id);
                              }
                            }),
                            title: Text(
                              item.text,
                              style: const TextStyle(color: CatppuccinMocha.text, fontSize: 13),
                            ),
                            subtitle: item.assignee != null
                                ? Text(
                                    item.assignee!,
                                    style: const TextStyle(color: CatppuccinMocha.subtext0, fontSize: 12),
                                  )
                                : null,
                            activeColor: CatppuccinMocha.mauve,
                            checkColor: CatppuccinMocha.base,
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          ),
                          if (!isLast) const Divider(height: 1, color: CatppuccinMocha.surface1),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Divider(color: CatppuccinMocha.surface1),
              const SizedBox(height: 12),

              // Footer buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: CatppuccinMocha.overlay0),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: canSave ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CatppuccinMocha.mauve,
                      foregroundColor: CatppuccinMocha.base,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: CatppuccinMocha.base),
                          )
                        : const Text('Save Note'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
