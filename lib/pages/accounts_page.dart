import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/theme/catppuccin_mocha.dart';
import '../models/account.dart';
import '../providers/app_providers.dart';
import '../services/calendar/calendar_manager.dart';

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

  void _addIcsAccount() {
    final url = _icsUrlController.text.trim();
    final name = _icsNameController.text.trim();
    if (url.isEmpty) return;

    ref.read(accountsProvider.notifier).addAccount(CalendarAccount(
      id: const Uuid().v4(),
      email: url,
      displayName: name.isEmpty ? 'ICS Calendar' : name,
      provider: 'ics',
      icsUrl: url,
    ));
    _icsUrlController.clear();
    _icsNameController.clear();

    // Refresh events after adding account
    ref.read(eventsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final microsoft = accounts.where((a) => a.provider == 'microsoft').toList();
    final google = accounts.where((a) => a.provider == 'google').toList();
    final ics = accounts.where((a) => a.provider == 'ics').toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text('Accounts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: CatppuccinMocha.text)),
          const SizedBox(height: 20),

          // Microsoft section
          _SectionHeader(title: 'Microsoft', icon: Icons.window, color: CatppuccinMocha.blue),
          if (microsoft.isEmpty)
            const _EmptyHint('No Microsoft accounts connected.')
          else
            ...microsoft.map((a) => _AccountTile(account: a)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final account = await CalendarManager.getInstance().connectMicrosoftAccount();
                await ref.read(accountsProvider.notifier).addAccount(CalendarAccount(
                  id: const Uuid().v4(),
                  email: account.email,
                  displayName: account.displayName,
                  provider: 'microsoft',
                ));
                ref.read(eventsProvider.notifier).refresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Microsoft sign-in failed: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Microsoft Account'),
          ),
          const SizedBox(height: 24),

          // Google section
          _SectionHeader(title: 'Google', icon: Icons.circle, color: CatppuccinMocha.green),
          if (google.isEmpty)
            const _EmptyHint('No Google accounts connected.')
          else
            ...google.map((a) => _AccountTile(account: a)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                final email = await CalendarManager.getInstance().connectGoogleAccount();
                await ref.read(accountsProvider.notifier).addAccount(CalendarAccount(
                  id: const Uuid().v4(),
                  email: email,
                  displayName: email,
                  provider: 'google',
                ));
                ref.read(eventsProvider.notifier).refresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Google sign-in failed: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Google Account'),
          ),
          const SizedBox(height: 24),

          // ICS section
          _SectionHeader(title: 'ICS / Webcal', icon: Icons.link, color: CatppuccinMocha.peach),
          if (ics.isEmpty)
            const _EmptyHint('No ICS feeds added.')
          else
            ...ics.map((a) => _AccountTile(account: a)),
          const SizedBox(height: 12),
          TextField(
            controller: _icsNameController,
            decoration: const InputDecoration(hintText: 'Display name (optional)', isDense: true),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _icsUrlController,
                  decoration: const InputDecoration(hintText: 'ICS feed URL', isDense: true),
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
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
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
      child: Text(text, style: const TextStyle(color: CatppuccinMocha.overlay0, fontSize: 13)),
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
                Text(account.displayName, style: const TextStyle(color: CatppuccinMocha.text, fontWeight: FontWeight.w600)),
                Text(account.email, style: const TextStyle(color: CatppuccinMocha.overlay0, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: CatppuccinMocha.red),
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
