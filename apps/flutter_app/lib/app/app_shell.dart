import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'navigation.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selected = destinationIndex(path);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nihongo Daily'),
        actions: [
          IconButton(
            tooltip: 'Cài đặt bản xem trước',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (wide) ...[
            NavigationRail(
              extended: true,
              selectedIndex: selected,
              onDestinationSelected: (index) {
                context.go(appDestinations[index].path);
              },
              destinations: [
                for (final destination in appDestinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: scheme.secondaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  child: Text(
                    'BẢN XEM TRƯỚC · Chưa kết nối tài khoản hoặc dữ liệu học thực tế.',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : SafeArea(
              top: false,
              child: NavigationBar(
                selectedIndex: selected,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                onDestinationSelected: (index) {
                  context.go(appDestinations[index].path);
                },
                destinations: [
                  for (final destination in appDestinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      label: destination.label,
                      tooltip: destination.label,
                    ),
                ],
              ),
            ),
    );
  }
}
