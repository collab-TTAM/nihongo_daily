"""Pinned real-asset import checks; analytic synthetic paths are explicitly tests."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from scripts import import_kanji_references as importer

ROOT = Path(__file__).resolve().parents[1]


class KanjiReferenceImportTests(unittest.TestCase):
    def test_actual_pinned_output_is_reproducible_and_original_mapping(self):
        generated = importer.generate(ROOT)
        self.assertEqual(generated.encode(), (ROOT/importer.OUTPUT).read_bytes())
        document = json.loads(generated)
        metadata = json.loads((ROOT/'data/n5/kanji.json').read_text())
        self.assertEqual(len(document['entries']), 8)
        for guide, row in zip(document['entries'], metadata):
            self.assertEqual((guide['kanji_id'], guide['character'], guide['content_version']), (row['id'], row['character'], row['content_version']))
            self.assertEqual(len(guide['strokes']), row['stroke_count'])
            for stroke in guide['strokes']:
                self.assertGreaterEqual(len(stroke), 2)
                self.assertLessEqual(len(stroke), 4096)
                self.assertTrue(all(0 <= value <= 1 for point in stroke for value in point))
                self.assertNotEqual(stroke[0], stroke[-1])

    def test_raw_assets_and_license_notices_are_retained(self):
        manifest = json.loads((ROOT/'third_party/kanjivg/n5_manifest.json').read_text())
        for item in manifest['sources']:
            source = (ROOT/'third_party/kanjivg/n5_source'/item['source_file']).read_bytes()
            self.assertEqual(hashlib.sha256(source).hexdigest(), item['sha256'])
            self.assertIn(b'Ulrich Apel', source)
            self.assertIn(b'creativecommons.org/licenses/by-sa/3.0/', source)
        self.assertIn('Attribution', (ROOT/'third_party/kanjivg/COPYING').read_text())
        self.assertEqual(manifest['license'], 'CC-BY-SA-3.0')
        self.assertEqual(hashlib.sha256((ROOT/'third_party/kanjivg/COPYING').read_bytes()).hexdigest(), manifest['license_sha256'])

    def test_actual_n4_output_original_95_mappings_and_bounded_geometry(self):
        document = json.loads(importer.generate(ROOT, 'n4'))
        self.assertEqual(importer.generate(ROOT, 'n4').encode(), (ROOT/importer.LEVELS['n4'][2]).read_bytes())
        metadata = json.loads((ROOT/'data/n4/kanji.json').read_bytes())
        self.assertEqual(len(document['entries']), 95)
        self.assertEqual(document['reference_version'], 'kanjivg-70a0b7ae-n4-1')
        self.assertEqual(sum(len(g['strokes']) for g in document['entries']), 977)
        for guide, row in zip(document['entries'], metadata):
            self.assertEqual((guide['kanji_id'], guide['character'], guide['content_version']), (row['id'], row['character'], row['content_version']))
            self.assertEqual(len(guide['strokes']), row['stroke_count'])
            for stroke in guide['strokes']:
                self.assertTrue(2 <= len(stroke) <= 4096)
                self.assertTrue(all(0 <= value <= 1 for point in stroke for value in point))
                self.assertNotEqual(stroke[0], stroke[-1])

    def test_all_n4_raw_sources_retain_pinned_hash_and_notices(self):
        manifest = json.loads((ROOT/'third_party/kanjivg/n4_manifest.json').read_bytes())
        self.assertEqual(len(manifest['sources']), 95)
        for item in manifest['sources']:
            source = (ROOT/'third_party/kanjivg/n4_source'/item['source_file']).read_bytes()
            self.assertEqual(hashlib.sha256(source).hexdigest(), item['sha256'])
            self.assertIn(b'Ulrich Apel', source)
            self.assertIn(b'creativecommons.org/licenses/by-sa/3.0/', source)
        self.assertEqual(manifest['license_sha256'], hashlib.sha256((ROOT/'third_party/kanjivg/COPYING').read_bytes()).hexdigest())

    def test_n4_version_coverage_identity_paths_and_foreign_level_reject(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT/'third_party', root/'third_party')
            shutil.copytree(ROOT/'data/n4', root/'data/n4')
            path = root/'third_party/kanjivg/n4_manifest.json'
            manifest = json.loads(path.read_bytes())
            for mutation in ['version', 'coverage', 'path', 'id', 'count', 'source', 'license']:
                changed = copy.deepcopy(manifest)
                if mutation == 'version': changed['reference_version'] = importer.VERSION
                if mutation == 'coverage': changed['sources'].pop()
                if mutation == 'path': changed['sources'][0]['source_file'] = '../COPYING'
                if mutation == 'id': changed['sources'][0]['kanji_id'] = 'foreign'
                if mutation == 'count': changed['sources'][0]['stroke_count'] += 1
                if mutation == 'source': changed['source_commit'] = 'future'
                if mutation == 'license': changed['license'] = 'MIT'
                path.write_text(json.dumps(changed), encoding='utf-8')
                with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                    importer.generate(root, 'n4')
            path.write_text(json.dumps(manifest), encoding='utf-8')
            metadata = root/'data/n4/kanji.json'
            rows = json.loads(metadata.read_bytes())
            rows[0]['jlpt_level'] = 'N5'
            metadata.write_text(json.dumps(rows), encoding='utf-8')
            manifest['metadata_sha256'] = hashlib.sha256(metadata.read_bytes()).hexdigest()
            path.write_text(json.dumps(manifest), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'foreign'):
                importer.generate(root, 'n4')
        with self.assertRaisesRegex(ValueError, 'level'):
            importer.generate(ROOT, '../n5')

    def test_n4_source_and_metadata_tamper_reject_before_generation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT/'third_party', root/'third_party')
            shutil.copytree(ROOT/'data/n4', root/'data/n4')
            svg = root/'third_party/kanjivg/n4_source/04f1a.svg'
            original = svg.read_bytes()
            svg.write_bytes(original+b' ')
            with self.assertRaisesRegex(ValueError, 'digest'):
                importer.generate(root, 'n4')
            svg.write_bytes(original)
            metadata = root/'data/n4/kanji.json'
            metadata.write_bytes(metadata.read_bytes()+b' ')
            with self.assertRaisesRegex(ValueError, 'digest'):
                importer.generate(root, 'n4')

    def test_synthetic_absolute_relative_and_smooth_reflection(self):
        absolute = 'M10,10 C20,10 30,20 40,20 C50,20 60,30 70,30'
        relative = 'M10 10 c10 0 20 10 30 10 s20 10 30 10'
        self.assertEqual(importer.normalize_path(absolute), importer.normalize_path(relative))
        points = importer.normalize_path('M0 0 C0 109 109 109 109 0')
        self.assertEqual(points[0], [0, 0])
        self.assertEqual(points[-1], [1, 0])
        self.assertIn([0.5, 0.75], points)

    def test_synthetic_reversal_preserves_direction_and_scale(self):
        forward = importer.normalize_path('M10 20 C20 20 30 20 40 20')
        reverse = importer.normalize_path('M40 20 C30 20 20 20 10 20')
        self.assertEqual(forward[0], reverse[-1])
        self.assertEqual(forward[-1], reverse[0])
        self.assertAlmostEqual(forward[0][0], 10/109, places=8)

    def test_unsupported_truncated_nonfinite_outside_and_degenerate_paths_reject(self):
        for path in ['M1 1 L2 2', 'M1 1 C2 2', 'M1 1 C1e999 2 3 4 5 6', 'M-1 2 C0 2 2 3 4 5', 'M1 1 C1 1 1 1 1 1', 'M1 1 M2 2', 'M1 1 C2 2 3 3 4 4 garbage']:
            with self.subTest(path=path), self.assertRaises(ValueError):
                importer.normalize_path(path)

    def test_original_svg_identity_count_order_canvas_and_transform_reject(self):
        source = (ROOT/'third_party/kanjivg/n5_source/065e5.svg').read_bytes()
        for changed in [source.replace(b'viewBox="0 0 109 109"', b'viewBox="0 0 100 100"'), source.replace(b'element="\xe6\x97\xa5"', b'element="x"'), source.replace(b'id="kvg:065e5-s1"', b'id="kvg:065e5-s9"'), source.replace(b'id="kvg:065e5"', b'id="kvg:065e5" transform="scale(2)"')]:
            with self.assertRaises(ValueError):
                importer.parse_svg(changed, '日', 4)
        with self.assertRaises(ValueError):
            importer.parse_svg(source, '日', 3)

    def test_tampered_source_and_metadata_cannot_be_regenerated_silently(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT/'third_party', root/'third_party')
            (root/'data/n5').mkdir(parents=True)
            shutil.copyfile(ROOT/'data/n5/kanji.json', root/'data/n5/kanji.json')
            svg = root/'third_party/kanjivg/n5_source/065e5.svg'
            original = svg.read_bytes()
            svg.write_bytes(original+b' ')
            with self.assertRaisesRegex(ValueError, 'digest'):
                importer.generate(root)
            svg.write_bytes(original)
            metadata = root/'data/n5/kanji.json'
            metadata.write_bytes(metadata.read_bytes()+b' ')
            with self.assertRaisesRegex(ValueError, 'digest'):
                importer.generate(root)

    def test_source_coverage_version_and_safe_path_are_locked(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(ROOT/'third_party', root/'third_party')
            (root/'data/n5').mkdir(parents=True)
            shutil.copyfile(ROOT/'data/n5/kanji.json', root/'data/n5/kanji.json')
            path = root/'third_party/kanjivg/n5_manifest.json'
            manifest = json.loads(path.read_text())
            for mutation in ['version', 'path', 'id', 'count']:
                changed = copy.deepcopy(manifest)
                if mutation == 'version': changed['reference_version'] = 'future'
                if mutation == 'path': changed['sources'][0]['source_file'] = '../COPYING'
                if mutation == 'id': changed['sources'][0]['kanji_id'] = 'foreign'
                if mutation == 'count': changed['sources'][0]['stroke_count'] = 5
                path.write_text(json.dumps(changed))
                with self.subTest(mutation=mutation), self.assertRaises(ValueError): importer.generate(root)


if __name__ == '__main__':
    unittest.main()
