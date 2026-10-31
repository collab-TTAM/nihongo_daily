import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/account_controller.dart';
import '../../auth/application/account_provider.dart';
import '../data/daily_plan_repository.dart';
import '../data/durable_study_session_repository.dart';

/// No default SDK/configuration or fabricated plan in preview mode.
final dailyPlanSourceProvider = Provider<DailyPlanRepositorySource?>(
  (ref) => null,
);

/// Rebuilt on every account barrier; never reuses a previous owner's lease.
final dailyPlanRepositoryProvider = Provider<DailyPlanRepository?>((ref) {
  final account = ref.watch(accountStateProvider);
  final runtime = ref.watch(accountRuntimeProvider);
  final source = ref.watch(dailyPlanSourceProvider);
  if (account.phase != AccountPhase.ready ||
      account.profile == null ||
      runtime?.readyRuntime == null ||
      source == null) {
    return null;
  }
  try {
    return source.createDailyPlanRepository();
  } on Object {
    return null;
  }
});

/// Null by default; only owned startup installs this borrowed capability.
final durableStudySourceProvider = Provider<DurableStudySessionSource?>(
  (ref) => null,
);
final durableStudyRepositoryProvider = Provider<DurableStudySessionRepository?>(
  (ref) {
    final account = ref.watch(accountStateProvider);
    final runtime = ref.watch(accountRuntimeProvider);
    final source = ref.watch(durableStudySourceProvider);
    if (account.phase != AccountPhase.ready ||
        account.profile == null ||
        runtime?.readyRuntime == null ||
        source == null) {
      return null;
    }
    try {
      return source.createDurableStudySessionRepository();
    } on Object {
      return null;
    }
  },
);
