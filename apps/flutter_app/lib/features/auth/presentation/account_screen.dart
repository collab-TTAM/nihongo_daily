import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/page_body.dart';
import '../../daily_plan/application/daily_plan_provider.dart';
import '../application/account_controller.dart';
import '../application/account_provider.dart';
import '../application/account_session_notice.dart';
import '../application/account_session_notice_provider.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _refreshing = false;
  bool _refreshFailed = false;

  Future<void> _refresh() async {
    final action = ref.read(accountSessionRefreshActionProvider);
    final runtime = ref.read(accountRuntimeProvider);
    final session = runtime?.readySession;
    final acceptedState = runtime?.state;
    if (_refreshing || action == null || session == null) return;
    _email.clear();
    _password.clear();
    setState(() {
      _refreshing = true;
      _refreshFailed = false;
    });
    try {
      await action.refresh();
    } on Object {
      if (mounted &&
          identical(ref.read(accountSessionRefreshActionProvider), action) &&
          identical(ref.read(accountRuntimeProvider), runtime) &&
          identical(runtime?.readySession, session) &&
          identical(runtime?.state, acceptedState)) {
        _refreshFailed = true;
      }
      // The owned persistence/notice path handles failed storage or Auth.
      // Late/replaced/logout responses cannot add a message to another session.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _submit() {
    final email = _email.text;
    final password = _password.text;
    _email.clear();
    _password.clear();
    ref.read(accountStateProvider.notifier).signIn(email, password);
  }

  @override
  void dispose() {
    _email.clear();
    _password.clear();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountStateProvider);
    final notice = ref.watch(accountSessionNoticeProvider);
    final refreshAction = ref.watch(accountSessionRefreshActionProvider);
    final runtime = ref.watch(accountRuntimeProvider);
    final plan = ref.watch(dailyPlanRepositoryProvider);
    final study = ref.watch(durableStudyRepositoryProvider);
    final checking = notice == AccountSessionNotice.checking || _refreshing;
    ref.listen(accountSessionNoticeProvider, (_, next) {
      if (next != AccountSessionNotice.none) {
        _email.clear();
        _password.clear();
      }
    });
    ref.listen(accountStateProvider, (_, next) {
      if (next.phase != AccountPhase.ready) _refreshFailed = false;
      if (!const {
        AccountPhase.signedOut,
        AccountPhase.signInError,
      }.contains(next.phase)) {
        _email.clear();
        _password.clear();
      }
    });
    final ready = state.phase == AccountPhase.ready && !checking;
    final login =
        const {
          AccountPhase.signedOut,
          AccountPhase.signInError,
        }.contains(state.phase) &&
        !checking;
    final busy =
        checking ||
        const {
          AccountPhase.signingIn,
          AccountPhase.loadingProfile,
          AccountPhase.signingOut,
        }.contains(state.phase);
    final logout =
        (_refreshing && runtime != null) ||
        const {
          AccountPhase.ready,
          AccountPhase.profileError,
          AccountPhase.signOutError,
        }.contains(state.phase);
    return PageBody(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tài khoản',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                if (state.phase == AccountPhase.unavailable)
                  const Text('Đăng nhập hiện chưa khả dụng.'),
                if (busy) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(switch (state.phase) {
                    AccountPhase.loadingProfile =>
                      'Đang chuẩn bị hồ sơ học tập…',
                    AccountPhase.signingOut => 'Đang kết thúc phiên đăng nhập…',
                    _ =>
                      checking
                          ? 'Đang xác nhận phiên đăng nhập…'
                          : 'Đang đăng nhập…',
                  }),
                ],
                if (notice == AccountSessionNotice.needsLogin &&
                    state.messageVi == null) ...[
                  const Text(
                    'Không thể xác nhận phiên đăng nhập. Vui lòng đăng nhập lại.',
                    key: Key('account-session-notice'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (state.messageVi != null) ...[
                  Text(
                    state.messageVi!,
                    key: const Key('account-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_refreshFailed) ...[
                  const Text(
                    'Chưa thể làm mới phiên. Bạn có thể thử lại.',
                    key: Key('account-refresh-error'),
                  ),
                  const SizedBox(height: 16),
                ],
                // EditableText registers lifecycle listeners. Keep the form
                // mounted across revocation while an OS exit snapshot drains;
                // hidden fields are disabled, unfocusable and cleared above.
                Offstage(
                  key: const Key('account-login-form'),
                  offstage: !login,
                  child: ExcludeFocus(
                    excluding: !login,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          key: const Key('account-email'),
                          enabled: login,
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: const InputDecoration(labelText: 'Email'),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('account-password'),
                          enabled: login,
                          controller: _password,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu',
                          ),
                          onSubmitted: login ? (_) => _submit() : null,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: login ? _submit : null,
                          child: const Text('Đăng nhập'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (ready) ...[
                  Text(
                    state.profile!.displayName.isEmpty
                        ? 'Đã đăng nhập'
                        : state.profile!.displayName,
                    key: const Key('account-profile-name'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Trình độ ${state.profile!.level} · ${state.profile!.dailyTargetMinutes} phút/ngày',
                  ),
                  const SizedBox(height: 20),
                  if (plan != null) ...[
                    FilledButton.tonal(
                      onPressed: () => context.go('/plan'),
                      child: const Text('Kế hoạch học'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (study != null) ...[
                    OutlinedButton(
                      key: const Key('study-recovery-open'),
                      onPressed: () => context.go('/study-recovery'),
                      child: const Text('Buổi học chờ đồng bộ'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: () => context.go('/srs'),
                    child: const Text('Ôn tập'),
                  ),
                  if (refreshAction != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('account-refresh'),
                      onPressed: _refresh,
                      child: const Text('Làm mới phiên'),
                    ),
                  ],
                ],
                if (state.phase == AccountPhase.profileError)
                  OutlinedButton(
                    onPressed: () =>
                        ref.read(accountStateProvider.notifier).retryProfile(),
                    child: const Text('Tải lại hồ sơ'),
                  ),
                if (logout) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: state.phase == AccountPhase.signingOut
                        ? null
                        : () =>
                              ref.read(accountStateProvider.notifier).signOut(),
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
