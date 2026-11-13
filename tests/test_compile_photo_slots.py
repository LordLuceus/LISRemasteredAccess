import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('compile_photo_slots', ROOT / 'scripts/compile_photo_slots.py')
compiler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compiler)


class PhotoSlotsTests(unittest.TestCase):
    def setUp(self):
        self.rows = json.loads(compiler.SOURCE.read_text(encoding='utf-8'))

    def test_native_coverage_order_and_fixture(self):
        compiler.validate(self.rows)
        self.assertEqual([(r['episode'], r['index']) for r in self.rows],
                         [(f'Episode{ep}', i) for ep in range(1, 6) for i in range(10)])
        first = '/Game/Packages/Gameplay/Collectible/E1/TX_Collectible_E1/TX_E1_2A_ArtClass_DanielTable'
        self.assertEqual(self.rows[0]['locked'], first + '_Locked.TX_E1_2A_ArtClass_DanielTable_Locked')
        self.assertEqual(self.rows[0]['unlocked'], first + '_Unlocked.TX_E1_2A_ArtClass_DanielTable_Unlocked')
        self.assertIn('VicRoom_Photos', self.rows[2]['locked'])
        self.assertIn('LONGPHOTO_Unlocked', self.rows[41]['unlocked'])
        self.assertNotIn('LONGPHOTO', self.rows[41]['locked'])
        self.assertEqual(len({r[s].lower() for r in self.rows for s in ('locked', 'unlocked')}), 100)
        self.assertTrue(all(set(r) == {'episode', 'index', 'locked', 'unlocked'} for r in self.rows))

    def test_matches_private_manifest_when_available(self):
        path = ROOT / 'artifacts/journal-photos/inventory/manifest.json'
        if not path.exists():
            self.skipTest('optional offline extraction evidence not shipped')
        manifest = json.loads(path.read_text(encoding='utf-8'))
        expected = [{'episode': r['episode_name'], 'index': r['index'],
                     'locked': r['states']['locked']['object_path'],
                     'unlocked': r['states']['unlocked']['object_path']} for r in manifest['rows']]
        self.assertEqual(self.rows, expected)

    def test_generated_exact_and_check(self):
        self.assertEqual(compiler.OUTPUT.read_bytes(), compiler.render(self.rows).encode('utf-8'))
        subprocess.run([sys.executable, str(ROOT / 'scripts/compile_photo_slots.py'), '--check'], check=True)
        self.assertEqual(compiler.render(self.rows), compiler.render(copy.deepcopy(self.rows)))

    def test_invalid_metadata(self):
        for field, value in [('index', -1), ('index', 10), ('index', True), ('index', 0.5),
                             ('episode', 'Episode6'), ('locked', 'basename'),
                             ('locked', '/Game//X.X'), ('locked', '/Game/../X.X'),
                             ('locked', '/Engine/X.X'), ('locked', None)]:
            rows = copy.deepcopy(self.rows)
            rows[0][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                compiler.validate(rows)
        for change in ('duplicate', 'collision', 'order', 'count', 'extra'):
            rows = copy.deepcopy(self.rows)
            if change == 'duplicate': rows[1]['index'] = 0
            if change == 'collision': rows[0]['unlocked'] = rows[1]['locked']
            if change == 'order': rows[0], rows[1] = rows[1], rows[0]
            if change == 'count': rows.pop()
            if change == 'extra': rows[0]['private_path'] = 'not shipped'
            with self.subTest(change=change), self.assertRaises(ValueError):
                compiler.validate(rows)


if __name__ == '__main__':
    unittest.main()
