import 'package:flutter/material.dart';
import '../core/theme/catppuccin_mocha.dart';

class AppScaffold extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final Widget child;

  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.child,
  });

  static const _navItems = [
    (icon: Icons.today, label: 'Today'),
    (icon: Icons.checklist, label: 'To-Do'),
    (icon: Icons.people, label: 'Accounts'),
    (icon: Icons.note_alt, label: 'Notes'),
    (icon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopSidebar(
              currentIndex: currentIndex,
              onTabChanged: onTabChanged,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTabChanged,
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Material(
        color: CatppuccinMocha.mantle,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28), // macOS title bar space
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'CalendarTask',
                  style: TextStyle(
                    color: CatppuccinMocha.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...List.generate(AppScaffold._navItems.length, (i) {
                final item = AppScaffold._navItems[i];
                final selected = i == currentIndex;
                return InkWell(
                  onTap: () => onTabChanged(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? CatppuccinMocha.surface0 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: selected ? CatppuccinMocha.blue : CatppuccinMocha.overlay0,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: selected ? CatppuccinMocha.blue : CatppuccinMocha.overlay0,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
