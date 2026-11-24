"""Nested authored language files stay in the release, test fixtures stay out."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import package_release as package


class LanguagePackaging(unittest.TestCase):
    def test_complete_language_tree_is_packaged_verbatim(self):
        # Model the new modules being tracked, without staging a developer's work.
        files = sorted((ROOT / 'src/lang').rglob('*.lua'))
        self.assertTrue(any('scenes/episode2/' in p.as_posix() for p in files))
        names = [p.relative_to(ROOT).as_posix() for p in files]
        with patch.object(package, 'git', return_value='\0'.join(names)):
            payload = package.collect_scripts(ROOT)
        self.assertEqual(len(payload), len(files))
        for path, name in zip(files, names):
            self.assertEqual(payload[package.MOD + name.removeprefix('src/')], path.read_bytes())
        self.assertFalse(any('baseline' in name for name in payload))


if __name__ == '__main__':
    unittest.main()
