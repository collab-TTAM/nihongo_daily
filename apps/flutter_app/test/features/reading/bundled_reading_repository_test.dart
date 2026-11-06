import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/reading/data/bundled_reading_repository.dart';
import 'package:nihongo_daily/features/reading/domain/reading_repository.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

final class _FailingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw StateError('PRIVATE asset path: $key');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled catalog contains original N5 passages and no N4 fallback',
    () async {
      final source = await rootBundle.loadString(
        BundledReadingRepository.assetPath,
      );
      expect(utf8.encode(source).length, lessThanOrEqualTo(262144));

      final repository = BundledReadingRepository();
      final n5 = await repository.load(PreviewLevel.n5);
      final n4 = await repository.load(PreviewLevel.n4);

      expect(n5.map((passage) => passage.id), [
        'n5-daily-routine-01',
        'n5-saturday-park-01',
        'n5-station-shop-01',
      ]);
      expect(n4, isEmpty);
      expect(n5.every((passage) => passage.contentVersion == 1), isTrue);
      expect(
        n5.every(
          (passage) => passage.sourceNoteVi.contains(
            'chưa được giáo viên hoặc người bản ngữ thẩm định',
          ),
        ),
        isTrue,
      );
      expect(
        n5.fold<int>(0, (total, passage) => total + passage.questions.length),
        9,
      );
      for (final passage in n5) {
        expect(passage.reading, isNotEmpty);
        expect(passage.vietnamese, isNotEmpty);
        expect(passage.questions, isNotEmpty);
        for (final question in passage.questions) {
          expect(question.choices.length, greaterThanOrEqualTo(2));
          expect(
            question.choices.any(
              (choice) => choice.id == question.correctChoiceId,
            ),
            isTrue,
          );
        }
      }

      final first = n5.first;
      expect(await repository.find(PreviewLevel.n5, first.id, 1), same(first));
      expect(await repository.find(PreviewLevel.n5, first.id, 2), isNull);
    },
  );

  test('bundle read errors are fixed and do not expose asset paths', () async {
    final repository = BundledReadingRepository(bundle: _FailingBundle());
    await expectLater(
      repository.load(PreviewLevel.n5),
      throwsA(
        isA<ReadingLoadException>().having(
          (error) => error.failure,
          'failure',
          ReadingLoadFailure.unavailable,
        ),
      ),
    );
  });
}
