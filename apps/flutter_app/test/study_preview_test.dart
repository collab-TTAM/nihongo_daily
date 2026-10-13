import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_daily/features/home/data/demo_study_preview_repository.dart';
import 'package:nihongo_daily/shared/models/preview_level.dart';

void main() {
  test('demo allocation matches the frozen seven-block contract', () async {
    final contract =
        jsonDecode(
              File('../../contracts/v0.1/contract.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final plan = contract['default_daily_plan'] as Map<String, dynamic>;
    final expected = plan['blocks'] as List<dynamic>;
    for (final level in PreviewLevel.values) {
      final preview = await const DemoStudyPreviewRepository().load(level);
      expect(preview.level, level);
      expect(preview.totalMinutes, plan['target_minutes']);
      expect(
        preview.blocks
            .map(
              (block) => {
                'type': block.area.wireName,
                'planned_minutes': block.minutes,
              },
            )
            .toList(),
        expected.map((dynamic block) {
          final fields = block as Map<String, dynamic>;
          return {
            'type': fields['type'],
            'planned_minutes': fields['planned_minutes'],
          };
        }).toList(),
      );
      expect(() => preview.blocks.clear(), throwsUnsupportedError);
    }
  });
}
