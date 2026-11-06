import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/reading/domain/reading_material.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<ReadingPassage> passages;

  setUpAll(() async {
    final source = await rootBundle.loadString(
      'assets/reading/catalog.json',
    );
    passages = decodeReadingMaterial(source, PreviewLevel.n5);
  });

  test('bundled N5 expansion includes the library study passage', () {
    final passage = passages.singleWhere(
      (entry) => entry.id == 'n5-library-study-01',
    );

    expect(passage.titleJa, '図書館で勉強');
    expect(passage.titleVi, 'Học ở thư viện');
    expect(passage.contentVersion, 1);
    expect(passage.reading, contains('としょかん'));
    expect(passage.vietnamese, contains('thư viện'));
    expect(passage.sourceNoteVi, contains('chưa được giáo viên'));
    expect(passage.questions, hasLength(3));
  });

  test('bundled N5 expansion includes the rainy-day passage', () {
    final passage = passages.singleWhere(
      (entry) => entry.id == 'n5-rainy-day-01',
    );

    expect(passage.titleJa, '雨の日');
    expect(passage.titleVi, 'Ngày mưa');
    expect(passage.contentVersion, 1);
    expect(passage.reading, contains('あめ'));
    expect(passage.vietnamese, contains('trời mưa'));
    expect(passage.sourceNoteVi, contains('chưa được giáo viên'));
    expect(passage.questions, hasLength(3));
  });

  test('new N5 comprehension keys complete deterministic rounds', () {
    for (final id in ['n5-library-study-01', 'n5-rainy-day-01']) {
      final passage = passages.singleWhere((entry) => entry.id == id);
      final round = ReadingRound(passage);
      for (final question in passage.questions) {
        expect(
          round.answer(
            passage.snapshotKey,
            question.id,
            question.correctChoiceId,
          ),
          isTrue,
        );
      }
      expect(round.isComplete, isTrue);
      expect(round.correctCount, 3);
    }
  });
}
