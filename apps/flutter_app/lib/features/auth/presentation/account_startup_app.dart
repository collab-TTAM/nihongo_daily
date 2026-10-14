import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/app.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../srs/application/srs_study_runtime.dart';
import '../application/account_controller.dart';
import '../application/account_provider.dart';
import '../application/account_startup_controller.dart';
import '../application/account_session_notice_provider.dart';

/// Explicit configured entrypoint. Captures one owner for its entire lifetime.
/// Caller may await controller.close() before unmount/replacement; disposal also
/// starts safe async cleanup and reports failure through a fixed callback.
class AccountStartupApp extends StatefulWidget {
  const AccountStartupApp({
    super.key,
    required this.controller,
    this.onCleanupFailed,
  });
  final AccountStartupController<AccountController<SrsStudyRuntime>> controller;
  final VoidCallback? onCleanupFailed;
  @override
  State<AccountStartupApp> createState() => _AccountStartupAppState();
}

class _AccountStartupAppState extends State<AccountStartupApp>
    with WidgetsBindingObserver {
  late final _controller = widget.controller;
  StreamSubscription<AccountStartupPhase>? _subscription;
  Future<AppExitResponse>? _exitRequest;
  bool _exitStarted = false;
  bool _exitFailed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _controller.changes.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.resume();
  }

  /// A cancelable OS close must await the same owned drain as explicit cleanup.
  /// Forced termination still relies on write-before-dispatch, never this hook.
  @override
  Future<AppExitResponse> didRequestAppExit() {
    return _exitRequest ??= _drainForExit();
  }

  Future<AppExitResponse> _drainForExit() async {
    if (mounted) {
      setState(() {
        _exitStarted = true;
        _exitFailed = false;
      });
    }
    try {
      await _controller.close();
      return AppExitResponse.exit;
    } on Object {
      if (mounted) setState(() => _exitFailed = true);
      return AppExitResponse.cancel;
    } finally {
      _exitRequest = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    final report = widget.onCleanupFailed;
    unawaited(
      _controller.close().catchError((Object _) {
        report?.call();
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _controller.account;
    if (account != null && !_exitStarted) {
      return ProviderScope(
        overrides: [
          accountRuntimeProvider.overrideWithValue(account),
          accountSessionNoticeSourceProvider.overrideWithValue(
            _controller.noticeSource,
          ),
        ],
        child: const _StartedApp(),
      );
    }
    final phase = _controller.phase;
    final loading = _exitStarted
        ? !_exitFailed
        : phase == AccountStartupPhase.loading ||
              phase == AccountStartupPhase.idle;
    return MaterialApp(
      title: 'Nihongo Daily',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nihongo Daily',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    if (loading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        _exitStarted
                            ? 'Đang đóng phiên an toàn…'
                            : 'Đang khôi phục phiên đăng nhập…',
                      ),
                    ] else ...[
                      Text(
                        _exitFailed
                            ? 'Chưa thể đóng phiên an toàn. Bạn có thể thử đóng cửa sổ lại.'
                            : switch (phase) {
                                AccountStartupPhase.restoreError =>
                                  'Không thể khôi phục phiên đăng nhập. Bạn có thể đăng nhập lại hoặc thử khởi động lại.',
                                AccountStartupPhase.cleanupError =>
                                  'Chưa thể đóng phiên trước. Hãy thử lại trước khi tiếp tục.',
                                AccountStartupPhase.closed => 'Phiên đã đóng.',
                                _ =>
                                  'Chưa thể khởi động tài khoản. Hãy thử lại.',
                              },
                      ),
                      const SizedBox(height: 20),
                      if (!_exitStarted && _controller.canOfferLogin)
                        FilledButton(
                          onPressed: _controller.offerLogin,
                          child: const Text('Đăng nhập lại'),
                        ),
                      if (!_exitStarted && phase != AccountStartupPhase.closed)
                        OutlinedButton(
                          onPressed: () => unawaited(_controller.retry()),
                          child: const Text('Thử khởi động lại'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartedApp extends ConsumerStatefulWidget {
  const _StartedApp();
  @override
  ConsumerState<_StartedApp> createState() => _StartedAppState();
}

class _StartedAppState extends ConsumerState<_StartedApp> {
  @override
  void initState() {
    super.initState();
    ref.read(routerProvider).go('/auth');
  }

  @override
  Widget build(BuildContext context) => const NihongoDailyApp();
}
