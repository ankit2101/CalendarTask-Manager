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
    // Named loopback / special hostnames
    if (h == 'localhost' || h == 'broadcasthost') return true;
    // IPv6 loopback
    if (h == '::1' || h == '::' || h.startsWith('[::')) return true;

    // Try dotted-decimal IPv4
    final parts = h.split('.');
    if (parts.length == 4) {
      final octets = parts.map(int.tryParse).toList();
      if (octets.every((o) => o != null && o >= 0 && o <= 255)) {
        final a = octets[0]!, b = octets[1]!;
        if (a == 0) return true;                        // 0.x.x.x
        if (a == 10) return true;                       // 10/8
        if (a == 127) return true;                      // 127/8 loopback
        if (a == 169 && b == 254) return true;          // 169.254/16 link-local / APIPA / cloud metadata
        if (a == 172 && b >= 16 && b <= 31) return true; // 172.16-31/12
        if (a == 192 && b == 168) return true;          // 192.168/16
        if (a == 198 && (b == 18 || b == 19)) return true; // 198.18-19/15 benchmarking
        if (a == 255) return true;                      // broadcast
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

    // Block private/loopback hosts to prevent SSRF
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

          // ICS / Webcal section
          _SectionHeader(
              title: 'ICS / Webcal',
              icon: Icons.link,
              color: CatppuccinMocha.peach),
          if (ics.isEmpty)
            const _EmptyHint('No ICS feeds added.')
          else
            ...ics.map((a) => _AccountTile(account: a)),
          const SizedBox(height: 12),
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

class _AccountTile extends ConsumerWidget {
  final CalendarAccount account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CatppuccinMocha.surface0,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.displayName,
                    style: const TextStyle(
                        color: CatppuccinMocha.text,
                        fontWeight: FontWeight.w600)),
                Text(account.email,
                    style: const TextStyle(
                        color: CatppuccinMocha.overlay0, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: CatppuccinMocha.red),
            onPressed: () {
              ref.read(accountsProvider.notifier).removeAccount(account.id);
              ref.read(eventsProvider.notifier).refresh();
            },
          ),
        ],
      ),
    );
  }
}
