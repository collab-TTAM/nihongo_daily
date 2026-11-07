/// Display action only. The owned runtime keeps SDK mutation and persistence
/// private; invoking this port never grants profile or study readiness itself.
abstract interface class AccountSessionRefreshAction {
  Future<void> refresh();
}
