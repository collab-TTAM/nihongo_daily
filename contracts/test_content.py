"""Mutation regressions: invalid exports must fail before any publishing step."""
import json
import shutil
import tempfile
import unittest
from pathlib import Path

from contracts.validate import ContractError
from contracts.validate_content import CONTENT_ROOT, validate_content


class ContentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'data'
        shutil.copytree(CONTENT_ROOT, self.root)

    def change(self, path, edit):
        file = self.root / path
        value = json.loads(file.read_text())
        edit(value)
        file.write_text(json.dumps(value, ensure_ascii=False))

    def fails(self):
        with self.assertRaises((ContractError, ValueError)):
            validate_content(self.root)

    def test_seed_passes_with_observed_counts(self):
        self.assertEqual(validate_content(self.root), dict(vocabulary=142, kanji=41, grammar=56, examples=372))

    def test_n4_vocabulary_and_kanji_meanings_are_localized(self):
        # Short Vietnamese meanings must not contain accidental Japanese headwords.
        # Longer usage/explanation fields may intentionally quote Japanese forms.
        for model in ('vocabulary', 'kanji'):
            records = json.loads((self.root / f'n4/{model}.json').read_text(encoding='utf-8'))
            for item in records:
                with self.subTest(model=model, item_id=item['id']):
                    self.assertNotRegex(item['meaning_vi'], r'[぀-ヿ㐀-鿿豈-﫿]')

    def test_unknown_wire_field(self):
        self.change('n5/vocabulary.json', lambda v: v[0].update(user_id='forged'))
        self.fails()

    def test_required_nullable_field_cannot_disappear(self):
        self.change('n5/kanji.json', lambda v: v[0].pop('stroke_data_ref'))
        self.fails()

    def test_wrong_scalar_and_empty_arrays(self):
        for value in [True, '4', 0]:
            with self.subTest(value=value):
                self.change('n5/kanji.json', lambda v: v[0].update(stroke_count=value))
                self.fails()
        self.change('n5/kanji.json', lambda v: v[0].update(stroke_count=4))
        self.change('n5/vocabulary.json', lambda v: v[0].update(examples=[]))
        self.fails()

    def test_duplicate_id_across_models(self):
        vocab = json.loads((self.root / 'n5/vocabulary.json').read_text())
        self.change('n5/kanji.json', lambda v: v[0].update(id=vocab[0]['id'].upper()))
        self.fails()

    def test_duplicate_normalized_natural_key(self):
        self.change('n5/grammar.json', lambda v: v[1].update(pattern=v[0]['pattern'].replace('N', 'Ｎ')))
        self.fails()

    def test_duplicate_tags_and_examples(self):
        self.change('n5/vocabulary.json', lambda v: v[0].update(tags=['people', 'ＰＥＯＰＬＥ']))
        self.fails()
        self.change('n5/vocabulary.json', lambda v: v[0].update(tags=['people'], examples=v[0]['examples']*2))
        self.fails()

    def test_unknown_wrong_type_self_reference(self):
        vocab = json.loads((self.root / 'n5/vocabulary.json').read_text())
        for target in ['aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', vocab[0]['id']]:
            self.change('n5/grammar.json', lambda v: v[0].update(related_grammar_ids=[target]))
            self.fails()
        self.change('n5/grammar.json', lambda v: v[0].update(related_grammar_ids=[v[0]['id']]))
        self.fails()

    def test_wrong_level_version_and_retired_content(self):
        for fields in [dict(jlpt_level='N4'), dict(jlpt_level='N5', content_version=2), dict(content_version=1, is_active=False)]:
            self.change('n5/vocabulary.json', lambda v: v[0].update(**fields))
            self.fails()

    def test_blank_and_invisible_text(self):
        for text in ['   ', ' text', 'text\u200b', 'text\x00', 'a\u0301']:
            self.change('n5/vocabulary.json', lambda v: v[0].update(meaning_vi=text))
            self.fails()

    def test_reading_and_character_checks(self):
        for text in ['water', '水', '123']:
            self.change('n5/vocabulary.json', lambda v: v[0].update(reading=text))
            self.fails()
        self.change('n5/vocabulary.json', lambda v: v[0].update(reading='わたし'))
        self.change('n5/kanji.json', lambda v: v[0].update(character='あ'))
        self.fails()

    def test_counts_cannot_claim_extra_coverage(self):
        self.change('manifest.json', lambda v: v['counts']['N5'].update(vocabulary=800))
        self.fails()

    def test_scope_assets_and_levels_cannot_be_fabricated(self):
        for field, value in [('scope', 'complete'), ('scope', 'original_seed_not_full_curriculum')]:
            self.change('manifest.json', lambda v: v.update(**{field:value}))
            if value=='complete':
                self.fails()
        self.change('manifest.json', lambda v: v.update(audio_available=True))
        self.fails()
        self.change('manifest.json', lambda v: v.update(audio_available=False, stroke_assets_available=True))
        self.fails()
        self.change('manifest.json', lambda v: v.update(stroke_assets_available=False, levels=['N5', 'N5']))
        self.fails()

    def test_extra_json_or_nonarray_export(self):
        (self.root / 'n5/unvalidated.json').write_text('{}')
        self.fails()
        (self.root / 'n5/unvalidated.json').unlink()
        (self.root / 'n5/vocabulary.json').write_text('{}')
        self.fails()

    def test_duplicate_json_members_are_rejected(self):
        file = self.root / 'n5/vocabulary.json'
        file.write_text(file.read_text().replace('"difficulty": 0.2', '"difficulty": 0.2, "difficulty": 0.3', 1))
        self.fails()

    def test_fullwidth_romaji_cannot_bypass_reading_check(self):
        self.change('n5/vocabulary.json', lambda v: v[0].update(reading='わたしＡ'))
        self.fails()

    def test_nonfinite_numbers_are_rejected(self):
        file = self.root / 'n5/vocabulary.json'
        file.write_text(file.read_text().replace('0.2', 'NaN', 1))
        self.fails()


if __name__ == '__main__':
    unittest.main()

