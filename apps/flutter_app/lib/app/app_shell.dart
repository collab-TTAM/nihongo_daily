import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/account_controller.dart';
import '../features/auth/application/account_provider.dart';
import 'navigation.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.path, required this.child});

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = destinationIndex(path);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final scheme = Theme.of(context).colorScheme;
    final configured = ref.watch(accountRuntimeProvider) != null;
    final account = ref.watch(accountStateProvider);
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
                    _connectionStatus(configured: configured, state: account),
                    key: const Key('app-connection-status'),
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

String _connectionStatus({
  required bool configured,
  required AccountState state,
}) {
  if (!configured) {
    return 'BẢN XEM TRƯỚC · Chưa cấu hình tài khoản. Không có tiến độ giả lập.';
  }
  return switch (state.phase) {
    AccountPhase.signedOut =>
      'TÀI KHOẢN ĐÃ CẤU HÌNH · Chưa đăng nhập. Tiến độ học đang bị khóa.',
    AccountPhase.signingIn =>
      'ĐANG ĐĂNG NHẬP · Các phần học cần tài khoản chưa sẵn sàng.',
    AccountPhase.loadingProfile =>
      'ĐANG TẢI HỒ SƠ · Tiến độ học chưa sẵn sàng.',
    AccountPhase.ready =>
      state.profile == null
          ? 'HỒ SƠ CHƯA SẴN SÀNG · Tải lại hồ sơ trước khi học.'
          : 'PHIÊN SẴN SÀNG · Hồ sơ ${state.profile!.level} · Múi giờ ${state.profile!.timezone}.',
    AccountPhase.signInError =>
      'ĐĂNG NHẬP CHƯA THÀNH CÔNG · Kiểm tra thông tin và thử lại.',
    AccountPhase.profileError =>
      'HỒ SƠ CHƯA SẴN SÀNG · Tải lại hồ sơ trước khi học.',
    AccountPhase.signingOut => 'ĐANG ĐĂNG XUẤT · Tiến độ học đang bị khóa.',
    AccountPhase.signOutError =>
      'CHƯA XÁC NHẬN ĐĂNG XUẤT · Tiến độ học đang bị khóa.',
    AccountPhase.unavailable =>
      'KẾT NỐI KHÔNG KHẢ DỤNG · Không thể xác minh phiên học.',
  };
}
