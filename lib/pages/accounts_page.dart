import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/catppuccin_mocha.dart';
import '../models/account.dart';
import '../providers/app_providers.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  final _icsUrlController = TextEditingController();
  final _icsNameController = TextEditingController();

  @override
  void dispose() {
    _icsUrlController.dispose();
    _icsNameController.dispose();
    super.dispose();
  }

  /// Returns true if [host] resolves to a private, loopback, or link-local
  /// address that must not be reachable from a user-supplied ICS URL (SSRF guard).
  bool _isPrivateHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h == 'broadcasthost') return true;
    if (h == '::1' || h == '::' || h.startsWith('[::')) return true;

    final parts = h.split('.');
    if (parts.length == 4) {
      final octets = parts.map(int.tryParse).toList();
      if (octets.every((o) => o != null && o >= 0 && o <= 255)) {
        final a = octets[0]!, b = octets[1]!;
        if (a == 0) return true;
        if (a == 10) return true;
        if (a == 127) return true;
        if (a == 169 && b == 254) return true;
        if (a == 172 && b >= 16 && b <= 31) return true;
        if (a == 192 && b == 168) return true;
        if (a == 198 && (b == 18 || b == 19)) return true;
        if (a == 255) return true;
      }
    }
    return false;
  }

  void _addIcsAccount() {
    final url = _icsUrlController.text.trim();
    final name = _icsNameController.text.trim();
    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    if (uri == null || uri.host.isEmpty || !{'https', 'webcal', 'http'}.contains(scheme)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid https:// or webcal:// URL')),
      );
      return;
    }

    if (_isPrivateHost(uri.host)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Private or local network addresses are not allowed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (scheme == 'http') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warning: this feed uses plain HTTP — calendar data will not be encrypted in transit'),
          duration: Duration(seconds: 4),
        ),
      );
    }

    ref.read(accountsProvider.notifier).addAccount(CalendarAccount(
      id: const Uuid().v4(),
      email: url,
      displayName: name.isEmpty ? 'ICS Calendar' : name,
      provider: 'ics',
      icsUrl: url,
    ));
    _icsUrlController.clear();
    _icsNameController.clear();

    ref.read(eventsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final ics = accounts.where((a) => a.provider == 'ics').toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text('Accounts',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: CatppuccinMocha.text)),
          const SizedBox(height: 20),

          _SectionHeader(
              title: 'ICS / Webcal',
              icon: Icons.link,
              color: CatppuccinMocha.peach),
          if (ics.isEmpty)
            const _EmptyHint('No ICS feeds added.')
          else
            ...ics.map((a) => _AccountTile(account: a)),
          const SizedBox(height: 12),

          // Add new feed form
          TextField(
            controller: _icsNameController,
            decoration: const InputDecoration(
                hintText: 'Display name (optional)', isDense: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _icsUrlController,
                  decoration: const InputDecoration(
                      hintText: 'ICS feed URL (https:// or webcal://)',
                      isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _addIcsAccount, child: const Text('Add')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account tile with inline colour picker
// ─────────────────────────────────────────────────────────────────────────────

class _AccountTile extends ConsumerStatefulWidget {
  final CalendarAccount account;
  const _AccountTile({required this.account});

  @override
  ConsumerState<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends ConsumerState<_AccountTile> {
  bool _pickerOpen = false;
  bool _renameOpen = false;
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color get _currentColor =>
      accountColor(widget.account.id, customHex: widget.account.color);

  void _pickColor(Color color) {
    final hex = colorToHex(color);
    ref.read(accountsProvider.notifier).updateAccount(
          widget.account.copyWith(color: hex),
        );
    setState(() => _pickerOpen = false);
    // Refresh calendar events so card borders update immediately.
    ref.read(eventsProvider.notifier).refresh();
  }

  void _submitRename() {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && newName != widget.account.displayName) {
      ref.read(accountsProvider.notifier).updateAccount(
            widget.account.copyWith(displayName: newName),
          );
    }
    setState(() => _renameOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = _currentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: CatppuccinMocha.surface0,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Colour swatch button
                Tooltip(
                  message: 'Change calendar colour',
                  child: GestureDetector(
                    onTap: () => setState(() => _pickerOpen = !_pickerOpen),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _pickerOpen
                              ? CatppuccinMocha.text
                              : color.withValues(alpha: 0.5),
                          width: _pickerOpen ? 2 : 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name + URL
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.account.displayName,
                          style: const TextStyle(
                              color: CatppuccinMocha.text,
                              fontWeight: FontWeight.w600)),
                      Text(widget.account.email,
                          style: const TextStyle(
                              color: CatppuccinMocha.overlay0, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),

                // Rename button
                Tooltip(
                  message: 'Rename account',
                  child: IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: _renameOpen
                          ? CatppuccinMocha.text
                          : CatppuccinMocha.overlay0,
                    ),
                    onPressed: () {
                      setState(() {
                        _renameOpen = !_renameOpen;
                        if (_renameOpen) {
                          _nameController.text = widget.account.displayName;
                          _pickerOpen = false;
                        }
                      });
                    },
                  ),
                ),

                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: CatppuccinMocha.red),
                  onPressed: () {
                    ref
                        .read(accountsProvider.notifier)
                        .removeAccount(widget.account.id);
                    ref.read(eventsProvider.notifier).refresh();
                  },
                ),
              ],
            ),
          ),

          // Inline rename field (shown when edit icon tapped)
          if (_renameOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: CatppuccinMocha.surface1, height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Rename account',
                    style: TextStyle(
                        color: CatppuccinMocha.overlay0,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          style: const TextStyle(
                              color: CatppuccinMocha.text, fontSize: 14),
                          decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Display name'),
                          onSubmitted: (_) => _submitRename(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _submitRename,
                        child: const Text('Save'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _renameOpen = false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Inline colour picker (shown when swatch tapped)
          if (_pickerOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: CatppuccinMocha.surface1, height: 1),
                  const SizedBox(height: 10),
                  const Text(
                    'Calendar colour',
                    style: TextStyle(
                        color: CatppuccinMocha.overlay0,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: calendarColorPalette.map((entry) {
                      final (label, paletteColor) = entry;
                      final isSelected = colorToHex(paletteColor) ==
                          (widget.account.color ??
                              colorToHex(accountColor(widget.account.id)));
                      return Tooltip(
                        message: label,
                        child: GestureDetector(
                          onTap: () => _pickColor(paletteColor),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: paletteColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? CatppuccinMocha.text
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: paletteColor.withValues(alpha: 0.5),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style: const TextStyle(
              color: CatppuccinMocha.overlay0, fontSize: 13)),
    );
  }
}
