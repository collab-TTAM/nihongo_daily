import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'account_session_notice.dart';

final accountSessionNoticeSourceProvider =
    Provider<AccountSessionNoticeSource?>((ref) => null);
final accountSessionNoticeProvider =
    StateNotifierProvider<AccountSessionNoticeNotifier, AccountSessionNotice>(
      (ref) => AccountSessionNoticeNotifier(
        ref.watch(accountSessionNoticeSourceProvider),
      ),
    );

final class AccountSessionNoticeNotifier
    extends StateNotifier<AccountSessionNotice> {
  AccountSessionNoticeNotifier(AccountSessionNoticeSource? source)
    : super(_initial(source)) {
    try {
      _subscription = source?.noticeChanges.listen(
        (notice) {
          if (!_disposed) state = notice;
        },
        onError: (Object _, StackTrace __) {
          if (!_disposed) state = AccountSessionNotice.needsLogin;
        },
        onDone: () {
          if (!_disposed) state = AccountSessionNotice.none;
        },
      );
    } on Object {
      state = AccountSessionNotice.needsLogin;
    }
  }
  static AccountSessionNotice _initial(AccountSessionNoticeSource? source) {
    try {
      return source?.notice ?? AccountSessionNotice.none;
    } on Object {
      return AccountSessionNotice.needsLogin;
    }
  }

  StreamSubscription<AccountSessionNotice>? _subscription;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
