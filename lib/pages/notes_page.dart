import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme/catppuccin_mocha.dart';
import '../providers/app_providers.dart';

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
          const Text('Meeting Notes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: CatppuccinMocha.text)),
          const SizedBox(height: 4),
          Text('${sorted.length} note${sorted.length != 1 ? 's' : ''} saved',
              style: const TextStyle(color: CatppuccinMocha.overlay0, fontSize: 13)),
          const SizedBox(height: 16),
          Expanded(
            child: sorted.isEmpty
                ? const Center(
                    child: Text('No meeting notes yet.\nAdd notes from the Today tab after meetings end.',
                        textAlign: TextAlign.center, style: TextStyle(color: CatppuccinMocha.overlay0)),
                  )
                : ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final record = sorted[index];
                      final savedDate = DateTime.tryParse(record.savedAt);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CatppuccinMocha.surface0,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(record.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600, color: CatppuccinMocha.text)),
                                ),
                                if (savedDate != null)
                                  Text(DateFormat('MMM d, h:mm a').format(savedDate),
                                      style: const TextStyle(fontSize: 12, color: CatppuccinMocha.overlay0)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(record.note,
                                style: const TextStyle(color: CatppuccinMocha.subtext1, fontSize: 13),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis),
                            if (record.actionItems.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('${record.actionItems.length} action item${record.actionItems.length != 1 ? 's' : ''}',
                                  style: const TextStyle(color: CatppuccinMocha.blue, fontSize: 12)),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
