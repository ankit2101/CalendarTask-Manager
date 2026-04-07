import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/catppuccin_mocha.dart';
import '../core/time_utils.dart';
import '../models/calendar_event.dart';
import '../models/todo_task.dart';
import '../providers/app_providers.dart';

class QuickNoteDialog extends ConsumerStatefulWidget {
  final NormalizedEvent event;
  /// When provided the dialog opens in edit mode pre-filled with this record.
  final MeetingRecord? existingRecord;

  const QuickNoteDialog({super.key, required this.event, this.existingRecord});

  @override
  ConsumerState<QuickNoteDialog> createState() => _QuickNoteDialogState();
}

class _QuickNoteDialogState extends ConsumerState<QuickNoteDialog> {
  final _noteController = TextEditingController();
  bool _isExtracting = false;
  bool _isSaving = false;
  String? _extractError;
  List<_EditableActionItem> _actionItems = [];
  final Set<String> _selectedActionIds = {};

  bool get _isEditMode => widget.existingRecord != null;

  bool get _isActive {
    final now = DateTime.now();
    final start = parseToLocal(widget.event.start);
    final end = parseToLocal(widget.event.end);
    return now.isAfter(start) && now.isBefore(end);
  }

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _noteController.text = widget.existingRecord!.note;
      _actionItems = widget.existingRecord!.actionItems
          .map((a) => _EditableActionItem.fromActionItem(a))
          .toList();
      _selectedActionIds.addAll(_actionItems.map((i) => i.id));
    }
    _noteController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final item in _actionItems) {
      item.controller.dispose();
    }
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
      // Dispose old controllers
      for (final item in _actionItems) {
        item.controller.dispose();
      }
      setState(() {
        _actionItems = items.map((a) => _EditableActionItem.fromActionItem(a)).toList();
        _selectedActionIds
          ..clear()
          ..addAll(_actionItems.map((i) => i.id));
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
      );

      await ref.read(meetingHistoryProvider.notifier).saveRecord(record);

      // Sync todos: remove old ones from this meeting, re-add selected
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

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('EEEE, MMMM d');
    final start = parseToLocal(event.start);
    final canSave = _noteController.text.trim().isNotEmpty && !_isSaving;
    final canExtract = _noteController.text.trim().isNotEmpty && !_isExtracting;

    return Dialog(
      backgroundColor: CatppuccinMocha.base,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, minWidth: 420, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: CatppuccinMocha.text,
                            ),
                          ),
                        ),
                        if (_isEditMode) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: CatppuccinMocha.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: CatppuccinMocha.blue.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit, size: 10, color: CatppuccinMocha.blue),
                                SizedBox(width: 4),
                                Text('EDITING', style: TextStyle(color: CatppuccinMocha.blue, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ] else if (_isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: CatppuccinMocha.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: CatppuccinMocha.green.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 7, color: CatppuccinMocha.green),
                                SizedBox(width: 4),
                                Text('LIVE', style: TextStyle(color: CatppuccinMocha.green, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFormat.format(start)}  ·  '
                      '${timeFormat.format(start)} \u2013 ${timeFormat.format(parseToLocal(event.end))} ${event.timeZone ?? start.timeZoneName}'
                      '${event.attendees.length > 1 ? '  ·  ${event.attendees.length} attendees' : ''}',
                      style: const TextStyle(color: CatppuccinMocha.subtext0, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: CatppuccinMocha.surface1),
                    const SizedBox(height: 16),

                    // Notes area
                    const Text(
                      'Meeting Notes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CatppuccinMocha.subtext1, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 8,
                      minLines: 5,
                      autofocus: !_isEditMode,
                      style: const TextStyle(color: CatppuccinMocha.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _isActive
                            ? 'Capture notes as the meeting progresses — decisions, topics, action items...'
                            : 'What happened in this meeting? Decisions made, topics discussed...',
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

                    // Extract button
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

                    // Error
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
                                              hintText: 'Action item text...',
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

            // Sticky footer
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
                    onPressed: canSave ? _save : null,
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
}

/// Mutable wrapper around an ActionItem for inline editing.
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

  factory _EditableActionItem.fromActionItem(ActionItem item) {
    return _EditableActionItem(
      id: item.id,
      controller: TextEditingController(text: item.text),
      assignee: item.assignee,
    );
  }
}
