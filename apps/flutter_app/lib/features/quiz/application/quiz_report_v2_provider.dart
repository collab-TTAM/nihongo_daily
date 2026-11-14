import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/account_controller.dart';
import '../../auth/application/account_provider.dart';
import '../data/quiz_report_v2_transport.dart';

/// Only an explicitly configured, caller-owned startup may publish this source.
final quizReportV2TransportSourceProvider =
    Provider<QuizReportV2TransportSource?>((ref) => null);

/// No transport is visible until the persisted Auth session and own profile are
/// ready. The transport repeats this fence for every captured request.
final quizReportV2TransportProvider = Provider<QuizReportV2Submitter?>((
  ref,
) {
  final state = ref.watch(accountStateProvider);
  final account = ref.watch(accountRuntimeProvider);
  final source = ref.watch(quizReportV2TransportSourceProvider);
  if (state.phase != AccountPhase.ready ||
      state.profile == null ||
      account?.readySession == null ||
      account?.readyRuntime == null) {
    return null;
  }
  try {
    return source?.quizReportV2Transport;
  } on Object {
    return null;
  }
});
