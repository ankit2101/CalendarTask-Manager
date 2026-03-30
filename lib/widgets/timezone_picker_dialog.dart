import 'package:flutter/material.dart';
import '../core/theme/catppuccin_mocha.dart';

/// Shows a dialog to correct the start and end times of a meeting.
/// [currentStart] and [currentEnd] are the currently displayed local DateTimes.
/// Returns a record with the corrected {start, end} as UTC ISO 8601 strings,
/// or null if the user cancelled.
Future<({String start, String end})?> showTimeEditDialog(
    BuildContext context, DateTime currentStart, DateTime currentEnd) {
  return showDialog<({String start, String end})>(
    context: context,
    builder: (_) => _TimeEditDialog(
        currentStart: currentStart, currentEnd: currentEnd),
  );
}

class _TimeEditDialog extends StatefulWidget {
  final DateTime currentStart;
  final DateTime currentEnd;
  const _TimeEditDialog({required this.currentStart, required this.currentEnd});

  @override
  State<_TimeEditDialog> createState() => _TimeEditDialogState();
}

class _TimeEditDialogState extends State<_TimeEditDialog> {
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    _start = TimeOfDay.fromDateTime(widget.currentStart);
    _end = TimeOfDay.fromDateTime(widget.currentEnd);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: CatppuccinMocha.blue,
            onPrimary: CatppuccinMocha.base,
            surface: CatppuccinMocha.surface0,
            onSurface: CatppuccinMocha.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CatppuccinMocha.mantle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Meeting Time',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CatppuccinMocha.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Times are in your local timezone',
                style: const TextStyle(
                    fontSize: 12, color: CatppuccinMocha.overlay0),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _TimeTile(
                      label: 'Start',
                      time: _start,
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeTile(
                      label: 'End',
                      time: _end,
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel',
                        style: TextStyle(color: CatppuccinMocha.overlay0)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final base = widget.currentStart;
                      final newStart = DateTime(
                          base.year, base.month, base.day,
                          _start.hour, _start.minute);
                      final newEnd = DateTime(
                          base.year, base.month, base.day,
                          _end.hour, _end.minute);
                      Navigator.of(context).pop((
                        start: newStart.toUtc().toIso8601String(),
                        end: newEnd.toUtc().toIso8601String(),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CatppuccinMocha.blue,
                      foregroundColor: CatppuccinMocha.base,
                    ),
                    child: const Text('Save'),
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

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeTile(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatted = time.format(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CatppuccinMocha.surface0,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CatppuccinMocha.surface1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: CatppuccinMocha.overlay0)),
            const SizedBox(height: 4),
            Text(formatted,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CatppuccinMocha.text)),
          ],
        ),
      ),
    );
  }
}
