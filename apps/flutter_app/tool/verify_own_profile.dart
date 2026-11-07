import 'dart:convert';
import 'dart:io';
import 'package:nihongo_daily/features/auth/data/own_profile_repository.dart';
import 'package:nihongo_daily/features/srs/data/review_repository.dart';
import '../test/features/srs/own_profile_fixtures.dart' as fixture;

Future<void> main(List<String> args) async {
  for (final scenario in fixture.scenarios) {
    await fixture.verifyProfile(scenario);
  }
  if (args.isNotEmpty) {
    final bundle =
        jsonDecode(await File(args.single).readAsString())
            as Map<String, Object?>;
    fixture.check(
      bundle['version'] == 'nd-own-profile-1',
      'wrong profile SQL export version',
    );
    final cases = bundle['cases']! as List<Object?>;
    fixture.check(cases.length == 5, 'incomplete native profile export');
    for (final entry in cases) {
      final item = entry! as Map<String, Object?>;
      final auth = fixture.Auth()
        ..currentSession = ReviewSession(userId: item['owner']! as String);
      final transport = fixture.Transport()..result = item['response'];
      final repository = RpcOwnProfileRepository(
        auth: auth,
        transport: transport,
      );
      if (item['name'] == 'invalid-fields') {
        await fixture.expectCode(
          repository.ensure(),
          ReviewErrorCode.validationFailure,
        );
      } else if (item['name'] == 'no-identity') {
        await fixture.expectCode(
          repository.ensure(),
          ReviewErrorCode.unauthorized,
        );
      } else {
        final result = await repository.ensure();
        fixture.check(
          result.id == item['owner'],
          'SQL projection crossed account',
        );
        fixture.check(
          jsonEncode(result.toJson()) ==
              jsonEncode(
                decodeOwnProfile(item['response'], result.id).toJson(),
              ),
          'SQL projection changed data',
        );
      }
    }
    stdout.writeln(
      'PASS: five actual SQL-role profile responses decoded by Dart captured-session adapter. Not hosted JWT/login evidence.',
    );
  } else {
    stdout.writeln(
      'PASS: seven own-profile fixture scenarios; not actual SQL/hosted Auth evidence.',
    );
  }
}
