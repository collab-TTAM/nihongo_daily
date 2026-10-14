import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/app/staging_bootstrap.dart';
import 'package:nihongo_daily/features/auth/presentation/account_startup_app.dart';
import 'account_startup_test.dart' show Owner;
import 'account_widget_test.dart' show Harness;

const configured = StagingBuildSettings(
  mode: 'staging',
  projectUrl: 'https://example.supabase.invalid',
  publicKey: 'sb_publishable_TEST_ONLY_1234567890',
);

void main() {
  test('staging settings validate before any resource construction', () {
    final valid = configured.configuration();
    expect(valid.automaticRefresh, isFalse);
    for (final settings in [
      const StagingBuildSettings(mode: 'other'),
      const StagingBuildSettings(mode: 'staging'),
      const StagingBuildSettings(
        mode: 'staging',
        projectUrl: 'http://local.invalid',
        publicKey: 'sb_publishable_TEST_ONLY_1234567890',
      ),
      const StagingBuildSettings(
        mode: 'staging',
        projectUrl: 'https://example.supabase.invalid',
        publicKey: 'sb_secret_PRIVATE',
      ),
      const StagingBuildSettings(
        mode: 'staging',
        projectUrl: 'https://example.supabase.invalid',
        publicKey: 'sb_publishable_TEST_ONLY_1234567890',
        automaticRefresh: 'yes',
      ),
    ]) {
      expect(
        settings.configuration,
        throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
      );
    }
  });
  test('automatic refresh activation is an explicit build choice', () {
    final settings = StagingBuildSettings(
      mode: 'staging',
      projectUrl: configured.projectUrl,
      publicKey: configured.publicKey,
      automaticRefresh: 'true',
    );
    expect(settings.configuration().automaticRefresh, isTrue);
  });
  testWidgets(
    'empty build preserves preview and never opens configured resources',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        selectBootstrapApp(
          const StagingBuildSettings(),
          open: (_) async {
            opens++;
            throw StateError('PRIVATE');
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(opens, 0);
      expect(find.byType(AccountStartupApp), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'invalid selected staging is redacted and never falls back to preview',
    (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        selectBootstrapApp(
          const StagingBuildSettings(
            mode: 'staging',
            publicKey: 'PRIVATE_TOKEN',
          ),
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
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets('unsupported platform fails before disk or Auth assembly', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    var opens = 0;
    await tester.pumpWidget(
      selectBootstrapApp(
        configured,
        open: (_) async {
          opens++;
          throw StateError('PRIVATE');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(opens, 0);
    expect(find.textContaining('chỉ hỗ trợ Windows'), findsOneWidget);
  });
  testWidgets(
    'configured Windows selects owned startup and existing account route',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final harness = Harness();
      final owner = Owner(harness.runtime);
      await tester.pumpWidget(
        selectBootstrapApp(
          configured,
          open: (settings) async {
            expect(settings.projectUrl, configured.projectUrl);
            expect(settings.publicKey, configured.publicKey);
            return owner;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-email')), findsOneWidget);
      expect(owner.starts, 1);
      final widget = tester.widget<AccountStartupApp>(
        find.byType(AccountStartupApp),
      );
      await tester.pumpWidget(const SizedBox());
      await widget.controller.close();
      expect(owner.closes, 1);
      await harness.close();
    },
  );
}
