import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme/catppuccin_mocha.dart';
import '../models/calendar_event.dart';
import '../providers/app_providers.dart';
import '../widgets/quick_note_dialog.dart';

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(meetingHistoryProvider);
    final sorted = List.of(history)..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Meeting Notes',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: CatppuccinMocha.text)),
          const SizedBox(height: 4),
          Text('${sorted.length} note${sorted.length != 1 ? 's' : ''} saved',
              style: const TextStyle(color: CatppuccinMocha.overlay0, fontSize: 13)),
          const SizedBox(height: 16),
          Expanded(
            child: sorted.isEmpty
                ? const Center(
                    child: Text(
                      'No meeting notes yet.\nAdd notes from the Today tab after meetings end.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: CatppuccinMocha.overlay0),
                    ),
                  )
                : ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) =>
                        _NoteCard(record: sorted[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends ConsumerStatefulWidget {
  final MeetingRecord record;
  const _NoteCard({required this.record});

  @override
  ConsumerState<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<_NoteCard> {
  bool _expanded = false;

  Future<void> _openEdit(BuildContext context) async {
    // Build a minimal NormalizedEvent stub so QuickNoteDialog can display
    // the meeting title / time and link new todos back to the event.
    final event = NormalizedEvent(
      id: widget.record.eventId,
      title: widget.record.title,
      start: widget.record.date,
      end: widget.record.date, // end not stored; reuse start as stub
      attendees: [],
      provider: CalendarProvider.ics,
      accountId: '',
    );

    await showDialog(
      context: context,
      builder: (_) => QuickNoteDialog(
        event: event,
        existingRecord: widget.record,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CatppuccinMocha.surface0,
        title: const Text('Delete note?', style: TextStyle(color: CatppuccinMocha.text)),
        content: Text(
          'This will delete the note for "${widget.record.title}" and all its linked to-do items.',
          style: const TextStyle(color: CatppuccinMocha.subtext1),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: CatppuccinMocha.overlay0)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CatppuccinMocha.red, foregroundColor: CatppuccinMocha.base),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(todosProvider.notifier).deleteTodosByMeetingId(widget.record.eventId);
      await ref.read(meetingHistoryProvider.notifier).deleteRecord(widget.record.eventId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final savedDate = DateTime.tryParse(record.savedAt);
    final isLongNote = record.note.length > 200;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: CatppuccinMocha.surface0,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.title,
                          style: const TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
                      const SizedBox(height: 2),
                      if (savedDate != null)
                        Text(
                          DateFormat('EEE, MMM d · h:mm a').format(savedDate),
                          style: const TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0),
                        ),
                    ],
                  ),
                ),
                // Edit button
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  color: CatppuccinMocha.blue,
                  tooltip: 'Edit note',
                  onPressed: () => _openEdit(context),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: CatppuccinMocha.red,
                  tooltip: 'Delete note',
                  onPressed: () => _confirmDelete(context),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            ),
          ),

          // Note body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(
              record.note,
              style: const TextStyle(color: CatppuccinMocha.subtext1, fontSize: 13),
              maxLines: _expanded ? null : 4,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          ),

          if (isLongNote)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: CatppuccinMocha.overlay0,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  textStyle: const TextStyle(fontSize: 12),
                  minimumSize: Size.zero,
                ),
                child: Text(_expanded ? 'Show less' : 'Show more'),
              ),
            ),

          // Action items summary
          if (record.actionItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: record.actionItems.map((item) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CatppuccinMocha.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CatppuccinMocha.blue.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    item.text,
                    style: const TextStyle(color: CatppuccinMocha.blue, fontSize: 11),
                  ),
                )).toList(),
              ),
            ),
          ],

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
