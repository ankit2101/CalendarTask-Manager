import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/theme/catppuccin_mocha.dart';
import '../core/time_utils.dart';

/// Shows a searchable list of IANA timezones.
/// Returns the selected TZID string, or null if the user chose "Reset to auto".
Future<String?> showTimezonePickerDialog(
    BuildContext context, String? currentTzid) {
  return showDialog<String?>(
    context: context,
    builder: (_) => _TimezonePickerDialog(currentTzid: currentTzid),
  );
}

class _TimezonePickerDialog extends StatefulWidget {
  final String? currentTzid;
  const _TimezonePickerDialog({this.currentTzid});

  @override
  State<_TimezonePickerDialog> createState() => _TimezonePickerDialogState();
}

class _TimezonePickerDialogState extends State<_TimezonePickerDialog> {
  late final List<String> _allZones;
  late List<String> _filtered;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _allZones = tz.timeZoneDatabase.locations.keys.toList()..sort();
    _filtered = _allZones;
    _controller.addListener(_onSearch);
  }

  void _onSearch() {
    final q = _controller.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allZones
          : _allZones.where((z) => z.toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CatppuccinMocha.mantle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Select Timezone',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CatppuccinMocha.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: const TextStyle(color: CatppuccinMocha.text),
                decoration: InputDecoration(
                  hintText: 'Search timezones...',
                  hintStyle:
                      const TextStyle(color: CatppuccinMocha.overlay0),
                  prefixIcon: const Icon(Icons.search,
                      color: CatppuccinMocha.overlay0, size: 18),
                  filled: true,
                  fillColor: CatppuccinMocha.surface0,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // "Reset to auto" option
            InkWell(
              onTap: () => Navigator.of(context).pop(null),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.refresh,
                        size: 16, color: CatppuccinMocha.blue),
                    const SizedBox(width: 8),
                    const Text('Reset to auto',
                        style: TextStyle(
                            color: CatppuccinMocha.blue, fontSize: 13)),
                  ],
                ),
              ),
            ),
            Divider(
                color: CatppuccinMocha.surface1, height: 1, thickness: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final tzid = _filtered[i];
                  final isSelected = tzid == widget.currentTzid;
                  final label = tzDisplayLabel(tzid);
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(tzid),
                    child: Container(
                      color: isSelected
                          ? CatppuccinMocha.blue.withValues(alpha: 0.15)
                          : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tzid,
                              style: TextStyle(
                                color: isSelected
                                    ? CatppuccinMocha.blue
                                    : CatppuccinMocha.text,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            label,
                            style: const TextStyle(
                                color: CatppuccinMocha.overlay0,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(widget.currentTzid),
                child: const Text('Cancel',
                    style: TextStyle(color: CatppuccinMocha.overlay0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
