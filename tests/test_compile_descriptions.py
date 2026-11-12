import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('compiler', ROOT / 'scripts/compile_descriptions.py')
compiler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compiler)


class Captions(unittest.TestCase):
    def setUp(self):
        self.rows = json.loads((ROOT / 'descriptions/episode1.en.json').read_text(encoding='utf-8'))

    def test_shipping_catalog_is_current(self):
        self.assertEqual(compiler.render(self.rows).encode('utf-8'),
                         (ROOT / 'src/descriptions/data.lua').read_bytes())

    def test_draft_rejected(self):
        self.rows[0]['status'] = 'draft'
        with self.assertRaisesRegex(ValueError, 'Draft'):
            compiler.render(self.rows)

    def test_private_evidence_and_transcriptions_rejected(self):
        for field in ('transcription', 'evidence', 'filename'):
            with self.subTest(field=field):
                row = dict(self.rows[0], **{field: 'private'})
                with self.assertRaisesRegex(ValueError, 'only caption'):
                    compiler.render([row])

    def test_bad_paths_rejected(self):
        for asset in ('Photo', '/Engine/Default.Default', '/Game//X.X', '/Game/../X.X', '/Game/X/.Y'):
            with self.subTest(asset=asset), self.assertRaises(ValueError):
                compiler.render([dict(self.rows[0], asset=asset)])

    def test_case_insensitive_duplicates_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            compiler.render([self.rows[0], dict(self.rows[0], asset=self.rows[0]['asset'].upper())])

    def test_locale_aliases_rejected_as_duplicates(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            compiler.render([dict(self.rows[0], language='pt_BR'), dict(self.rows[0], language='pt-br')])

    def test_invalid_hash_rejected(self):
        with self.assertRaisesRegex(ValueError, 'hash'):
            compiler.render([dict(self.rows[0], image_sha256='unknown')])

    def test_escape_and_utf8(self):
        self.assertEqual(compiler.lua_string('"caf\u00e9"\\'), '"\\"caf\u00e9\\"\\\\"')
        with self.assertRaises(ValueError):
            compiler.render([dict(self.rows[0], text='line\nbreak')])

    def test_deterministic_order(self):
        self.assertEqual(compiler.render(self.rows), compiler.render(list(reversed(self.rows))))

    def test_check_mode_rejects_stale_file(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / 'data.lua'
            target.write_text('return {}\n')
            command = [sys.executable, str(ROOT / 'scripts/compile_descriptions.py'),
                       '--records', str(ROOT / 'descriptions/episode1.en.json'),
                       '--output', str(target), '--check']
            options = dict(capture_output=True, text=True,
                           creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
            bad = subprocess.run(command, **options)
            self.assertNotEqual(bad.returncode, 0)
            self.assertIn('stale', bad.stderr)
            target.write_bytes(compiler.render(self.rows).encode('utf-8'))
            good = subprocess.run(command, **options)
            self.assertEqual(good.returncode, 0, good.stderr)

    def test_hash_verification_and_path_escape(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'image.png').write_bytes(b'corrupted image')
            record = self.rows[0]
            asset = dict(object_path=record['asset'], status='decoded',
                         png_sha256=record['image_sha256'], png='image.png')
            manifest = root / 'manifest.json'
            def write():
                manifest.write_text(json.dumps(dict(scope='fixture', assets=[asset])))
            write()
            with self.assertRaisesRegex(ValueError, 'hash mismatch'):
                compiler.coverage([record], manifest)
            asset['png'] = '../outside.png';write()
            with self.assertRaisesRegex(ValueError, 'escapes'):
                compiler.coverage([record], manifest)


if __name__ == '__main__':
    unittest.main()
