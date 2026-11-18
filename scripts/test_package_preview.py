import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

from scripts.package_preview import MANIFEST, README, package, verify, verify_ci


class PreviewPackageTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = 'a' * 40
        self.checkout = 'b' * 40
        self.run = 'https://github.com/collab-TTAM/nihongo_daily/actions/runs/123'

    def build(self, platform='web'):
        (self.root / ('index.html' if platform == 'web' else 'nihongo_daily.exe')).write_bytes(b'BUILD FIXTURE')
        (self.root / 'data').mkdir()
        (self.root / 'data' / 'fixture.bin').write_bytes(b'PUBLIC TEST ONLY')

    def package(self, platform='web', **overrides):
        args = dict(root=self.root, platform=platform, source=self.source,
                    checkout=self.checkout, run_url=self.run, attempt=2)
        return package(**(args | overrides))

    def test_both_platforms_preserve_source_checkout_and_actual_bytes(self):
        for platform in ['web', 'windows']:
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as temp:
                self.root = Path(temp)
                self.build(platform)
                before = {p.relative_to(self.root): p.read_bytes()
                          for p in self.root.rglob('*') if p.is_file()}
                result = self.package(platform)
                self.assertEqual(result['source_head_sha'], self.source)
                self.assertEqual(result['checkout_sha'], self.checkout)
                self.assertEqual(result['ci_run_url'], self.run)
                self.assertEqual(result['run_attempt'], 2)
                self.assertTrue(result['preview_only'])
                self.assertEqual(result, verify(self.root))
                for path, content in before.items():
                    self.assertEqual((self.root / path).read_bytes(), content)
                for item in result['files']:
                    content = (self.root / item['path']).read_bytes()
                    self.assertEqual(item['sha256'], hashlib.sha256(content).hexdigest())
                    self.assertEqual(item['size'], len(content))
                self.assertIn(README, [item['path'] for item in result['files']])
                self.assertNotIn(MANIFEST, [item['path'] for item in result['files']])

    def test_modified_missing_and_extra_files_fail_verification(self):
        for mutation in ['modify', 'missing', 'extra', 'readme']:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temp:
                self.root = Path(temp)
                self.build()
                self.package()
                if mutation == 'modify':
                    (self.root / 'index.html').write_bytes(b'CHANGED')
                elif mutation == 'missing':
                    (self.root / 'data' / 'fixture.bin').unlink()
                elif mutation == 'extra':
                    (self.root / 'extra.js').write_bytes(b'EXTRA')
                else:
                    (self.root / README).write_text('CHANGED', encoding='utf-8')
                with self.assertRaisesRegex(ValueError, 'inventory mismatch'):
                    verify(self.root)

    def test_invalid_provenance_never_writes_metadata(self):
        self.build()
        for args in [dict(source='bad'), dict(checkout='A' * 40),
                     dict(run_url='https://example.invalid/run/1'), dict(attempt=True),
                     dict(attempt=0)]:
            with self.subTest(args=args), self.assertRaises(ValueError):
                self.package(**args)
            self.assertFalse((self.root / MANIFEST).exists())
            self.assertFalse((self.root / README).exists())

    def test_missing_entrypoint_and_duplicate_packaging_fail(self):
        with self.assertRaises(ValueError):
            self.package()
        self.build()
        self.package()
        with self.assertRaisesRegex(ValueError, 'already packaged'):
            self.package()

    def test_symlinks_rejected_and_hidden_files_match_artifact_exclusion(self):
        self.build()
        (self.root / 'linked').symlink_to(self.root / 'index.html')
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.package()
        (self.root / 'linked').unlink()
        (self.root / '.last_build_id').write_text('TEST ONLY')
        result = self.package()
        self.assertNotIn('.last_build_id', [item['path'] for item in result['files']])
        self.assertEqual(verify(self.root), result)

    def test_zip_roundtrip_binds_expected_ci_identity_for_both_platforms(self):
        for platform in ['web', 'windows']:
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as temp:
                self.root = Path(temp) / 'build'
                self.root.mkdir()
                self.build(platform)
                original = self.package(platform)
                archive = Path(temp) / 'artifact.zip'
                with zipfile.ZipFile(archive, 'w') as bundle:
                    for path in self.root.rglob('*'):
                        if path.is_file():
                            bundle.write(path, path.relative_to(self.root))
                extracted = Path(temp) / 'download'
                with zipfile.ZipFile(archive) as bundle:
                    bundle.extractall(extracted)
                self.assertEqual(original, verify_ci(extracted, platform, self.source,
                                                     self.checkout, self.run, 2))
                for key, value in [('source_head_sha', 'c' * 40),
                                   ('checkout_sha', 'd' * 40),
                                   ('ci_run_url', self.run + '4'), ('run_attempt', 3),
                                   ('platform', 'windows' if platform == 'web' else 'web')]:
                    with self.subTest(key=key):
                        path = extracted / MANIFEST
                        modified = original | {key: value}
                        path.write_text(json.dumps(modified), encoding='utf-8')
                        self.assertEqual(verify(extracted), modified)
                        with self.assertRaisesRegex(ValueError, 'provenance mismatch'):
                            verify_ci(extracted, platform, self.source,
                                      self.checkout, self.run, 2)
                        path.write_text(json.dumps(original), encoding='utf-8')

    def test_manifest_cannot_redirect_inventory_reads_outside_bundle(self):
        self.build()
        self.package()
        path = self.root / MANIFEST
        manifest = json.loads(path.read_text(encoding='utf-8'))
        manifest['files'][0]['path'] = '../outside-bundle'
        path.write_text(json.dumps(manifest), encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'inventory mismatch'):
            verify(self.root)

    def test_ci_cli_and_standalone_download_verification(self):
        self.build()
        repo = Path(__file__).resolve().parents[1]
        script = repo / 'scripts' / 'package_preview.py'
        env = os.environ | {
            'ND_PREVIEW_SOURCE_SHA': self.source,
            'GITHUB_REPOSITORY': 'collab-TTAM/nihongo_daily',
            'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '2',
        }
        subprocess.run([sys.executable, str(script), '--root', str(self.root),
                        '--platform', 'web'], cwd=repo, env=env, check=True,
                       capture_output=True)
        result = verify(self.root)
        self.assertEqual(result['source_head_sha'], self.source)
        self.assertEqual(result['checkout_sha'], subprocess.check_output(
            ['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip())
        subprocess.run([sys.executable, str(script), '--root', str(self.root),
                        '--verify'], env={}, check=True, capture_output=True)
        verified = subprocess.run([sys.executable, str(script), '--root', str(self.root),
                                   '--platform', 'web', '--verify-ci'], cwd=repo, env=env,
                                  capture_output=True)
        self.assertEqual(verified.returncode, 0, verified.stderr)
        rejected = subprocess.run([sys.executable, str(script), '--root', str(self.root),
                                   '--platform', 'web', '--verify-ci'], cwd=repo,
                                  env=env | {'GITHUB_RUN_ATTEMPT': '3'}, capture_output=True)
        self.assertNotEqual(rejected.returncode, 0)
        self.assertIn(b'Preview provenance mismatch', rejected.stderr)



if __name__ == '__main__':
    unittest.main()
