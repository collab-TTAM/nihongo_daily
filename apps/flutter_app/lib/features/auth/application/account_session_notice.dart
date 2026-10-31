import 'dart:async';

/// Display-only states, never authorization or credentials.
enum AccountSessionNotice { none, checking, needsLogin }

abstract interface class AccountSessionNoticeSource {
  AccountSessionNotice get notice;
  Stream<AccountSessionNotice> get noticeChanges;
}
