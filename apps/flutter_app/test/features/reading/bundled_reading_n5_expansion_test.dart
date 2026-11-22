import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/reading/domain/reading_material.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<ReadingPassage> passages;

  setUpAll(() async {
    final source = await rootBundle.loadString('assets/reading/catalog.json');
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

  test('bundled N5 expansion includes the birthday passage', () {
    final passage = passages.singleWhere(
      (entry) => entry.id == 'n5-birthday-01',
    );

    expect(passage.titleJa, '誕生日の一日');
    expect(passage.titleVi, 'Một ngày sinh nhật');
    expect(passage.contentVersion, 1);
    expect(passage.reading, contains('たんじょうび'));
    expect(passage.vietnamese, contains('sinh nhật'));
    expect(passage.sourceNoteVi, contains('chưa được giáo viên'));
    expect(passage.questions, hasLength(3));
  });

  test('bundled N5 expansion includes the Sunday lunch passage', () {
    final passage = passages.singleWhere(
      (entry) => entry.id == 'n5-sunday-meal-01',
    );

    expect(passages, hasLength(10));
    expect(passage.titleJa, '日曜日の昼ごはん');
    expect(passage.titleVi, 'Bữa trưa Chủ nhật');
    expect(passage.contentVersion, 1);
    expect(passage.reading, contains('にちようび'));
    expect(passage.reading, contains('ぎゅうにゅう'));
    expect(passage.vietnamese, contains('Bữa trưa'));
    expect(passage.sourceNoteVi, contains('chưa được giáo viên'));
    expect(passage.questions, hasLength(3));
  });

  test('bundled N5 expansion includes the bus commute passage', () {
    final passage = passages.singleWhere(
      (entry) => entry.id == 'n5-bus-commute-01',
    );

    expect(passage.titleJa, 'バスで会社へ行きます');
    expect(passage.titleVi, 'Đi làm bằng xe buýt');
    expect(passage.contentVersion, 1);
    expect(passage.reading, contains('バスてい'));
    expect(passage.reading, contains('しちじじゅうごふん'));
    expect(passage.vietnamese, contains('xe buýt'));
    expect(passage.sourceNoteVi, contains('chưa được giáo viên'));
    expect(passage.questions, hasLength(3));
  });

  test('bundled N5 expansion includes the friend-house passage', () {
    final passage = passages.singleWhere(
      (entry) => entry.id == 'n5-friend-house-01',
    );

    expect(passage.titleJa, '友達の家で');
    expect(passage.titleVi, 'Ở nhà bạn');
    expect(passage.contentVersion, 1);
    expect(passage.reading, contains('ともだちのいえ'));
    expect(passage.reading, contains('しゅくだい'));
    expect(passage.vietnamese, contains('cà ri'));
    expect(passage.sourceNoteVi, contains('chưa được giáo viên'));
    expect(passage.questions, hasLength(3));
  });

  test('bundled N5 expansion includes the supermarket passage', () {
    final passage = passages.singleWhere(
      (entry) => entry.id == 'n5-supermarket-01',
    );

    expect(passage.titleJa, 'スーパーで買い物');
    expect(passage.titleVi, 'Mua sắm ở siêu thị');
    expect(passage.contentVersion, 1);
    expect(passage.reading, contains('どようび'));
    expect(passage.reading, contains('ぎゅうにゅう'));
    expect(passage.vietnamese, contains('siêu thị'));
    expect(passage.sourceNoteVi, contains('chưa được giáo viên'));
    expect(passage.questions, hasLength(3));
  });

  test('new N5 comprehension keys complete deterministic rounds', () {
    for (final id in [
      'n5-library-study-01',
      'n5-rainy-day-01',
      'n5-sunday-meal-01',
      'n5-bus-commute-01',
      'n5-friend-house-01',
      'n5-birthday-01',
      'n5-supermarket-01',
    ]) {
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
