// Trusted build choices only; these tests do not open a live project.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/staging_bootstrap.dart';

StagingBuildSettings settings(String flag, {String mode = 'staging'}) =>
    StagingBuildSettings(
      mode: mode,
      projectUrl: 'https://example.supabase.invalid',
      publicKey: 'sb_publishable_TEST_ONLY_1234567890',
      grammarHistory: flag,
    );
void main() {
  test(
    'grammar staging defaults off including legacy configuration constructor',
    () {
      const build = StagingBuildSettings(
        mode: 'staging',
        projectUrl: 'https://example.supabase.invalid',
        publicKey: 'sb_publishable_TEST_ONLY_1234567890',
      );
      expect(build.configuration().grammarHistoryEnabled, isFalse);
      expect(
        const StagingConfiguration(
          'https://example.supabase.invalid',
          'sb_publishable_TEST_ONLY_1234567890',
          false,
        ).grammarHistoryEnabled,
        isFalse,
      );
      expect(build.configuration().automaticRefresh, isFalse);
    },
  );
  test(
    'grammar staging true is explicit and independent of automatic refresh',
    () {
      expect(settings('true').configuration().grammarHistoryEnabled, isTrue);
      expect(settings('true').configuration().automaticRefresh, isFalse);
      expect(settings('false').configuration().grammarHistoryEnabled, isFalse);
    },
  );
  test('grammar staging rejects nonliteral boolean flags', () {
    for (final flag in ['', 'TRUE', 'yes', '1', ' true', 'false ']) {
      expect(settings(flag).configuration, throwsFormatException);
    }
  });
  testWidgets(
    'invalid grammar opt in fails before configured resource opener',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        selectBootstrapApp(
          settings('yes'),
          open: (_) async {
            opens++;
            throw StateError('PRIVATE');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(opens, 0);
      expect(find.textContaining('PRIVATE'), findsNothing);
      expect(find.textContaining('kiểm tra cấu hình'), findsOneWidget);
    },
  );
  testWidgets(
    'preview ignores grammar opt in and never opens account resources',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        selectBootstrapApp(
          settings('true', mode: 'preview'),
          open: (_) async {
            opens++;
            throw StateError('PRIVATE');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(opens, 0);
      expect(find.byType(TextField), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
