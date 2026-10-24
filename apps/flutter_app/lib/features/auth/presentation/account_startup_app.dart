import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/app.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../daily_plan/application/daily_plan_provider.dart';
import '../../quiz/application/quiz_history_provider.dart';
import '../../ai/application/ai_text_view_binding.dart';
import '../../ai/application/ai_conversation_view_binding.dart';
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
  bool _publishedApp = false;
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
    if (account != null) _publishedApp = true;
    if (account != null || (_publishedApp && _exitStarted)) {
      return ProviderScope(
        overrides: [
          aiConversationSourceProvider.overrideWithValue(
            _controller.aiConversationSource,
          ),
          aiTextRepositorySourceProvider.overrideWithValue(
            _controller.aiTextSource,
          ),
          quizHistorySourceProvider.overrideWithValue(
            _controller.quizHistorySource,
          ),
          dailyPlanSourceProvider.overrideWithValue(
            _controller.dailyPlanSource,
          ),
          durableStudySourceProvider.overrideWithValue(
            _controller.durableStudySource,
          ),
          accountRuntimeProvider.overrideWithValue(account),
          accountSessionRefreshActionProvider.overrideWithValue(
            _controller.refreshAction,
          ),
          accountSessionNoticeSourceProvider.overrideWithValue(
            _controller.noticeSource,
          ),
        ],
        child: _StartedApp(
          blockingScreen: _exitStarted ? _statusScreen() : null,
        ),
      );
    }
    return MaterialApp(
      title: 'Nihongo Daily',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      home: _statusScreen(),
    );
  }

  Widget _statusScreen() {
    final phase = _controller.phase;
    final loading = _exitStarted
        ? !_exitFailed
        : phase == AccountStartupPhase.loading ||
              phase == AccountStartupPhase.idle;
    return Scaffold(
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
                              _ => 'Chưa thể khởi động tài khoản. Hãy thử lại.',
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
    );
  }
}

class _StartedApp extends ConsumerStatefulWidget {
  const _StartedApp({this.blockingScreen});
  final Widget? blockingScreen;
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
  Widget build(BuildContext context) => NihongoDailyApp(
    // Keep the router and its lifecycle observers mounted while the binding's
    // exit-observer snapshot is awaiting our drain. Revoke the account override,
    // hide routes and block focus/tickers; never dispose another pending observer.
    builder: (context, child) => Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: widget.blockingScreen != null,
          child: ExcludeFocus(
            excluding: widget.blockingScreen != null,
            child: TickerMode(
              enabled: widget.blockingScreen == null,
              child: child ?? const SizedBox(),
            ),
          ),
        ),
        if (widget.blockingScreen != null) widget.blockingScreen!,
      ],
    ),
  );
}
