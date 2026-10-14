import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/page_body.dart';
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
    final checking = notice == AccountSessionNotice.checking;
    ref.listen(accountSessionNoticeProvider, (_, next) {
      if (next != AccountSessionNotice.none) {
        _email.clear();
        _password.clear();
      }
    });
    ref.listen(accountStateProvider, (_, next) {
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
    final logout = const {
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
                if (login) ...[
                  TextField(
                    key: const Key('account-email'),
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('account-password'),
                    controller: _password,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(labelText: 'Mật khẩu'),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Đăng nhập'),
                  ),
                ],
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
                  FilledButton(
                    onPressed: () => context.go('/srs'),
                    child: const Text('Ôn tập'),
                  ),
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
                    onPressed: () =>
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
