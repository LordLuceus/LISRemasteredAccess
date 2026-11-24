"""Keep source-only authoring instructions discoverable without private memory.

This gate checks local link targets, discovery of the distinct scene mechanisms,
and movie metadata preservation. It cannot certify narrative quality, complete
episode coverage, accurate prose about every runtime rule, or visual review.
"""
from pathlib import Path
import re
import unittest
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
GUIDES = ('closeups.md', 'world-objects.md', 'movies.md', 'scenes.md',
          'journal-photos.md', 'episode2-inventory.md', 'evidence.md', 'languages.md',
          'coverage.md')


def check_local_links(path, text):
    for target in re.findall(r'(?<!!)\[[^\]\n]*\]\(([^)\s]+)\)', text):
        url = urlsplit(target)
        if url.scheme or url.netloc or not url.path:
            continue
        resolved = (path.parent / unquote(url.path)).resolve()
        if not resolved.is_relative_to(ROOT) or not (resolved.is_file() or resolved.is_dir()):
            raise ValueError(f'{path.name}: missing local link {target}')


def check_scene_routes(index):
    # These are separate consumers, not interchangeable episode catalogue forms.
    for target in ('src/cutscenes/registry.lua', 'src/cutscenes/dialogue.lua',
                   'src/descriptions/episode1_rooms.lua', '(coverage.md)', '(languages.md)'):
        if target not in index:
            raise ValueError('Authoring index omits route or standard: ' + target)


class DescriptionAuthoring(unittest.TestCase):
    def test_authoring_index_maps_all_existing_scene_routes(self):
        index = (ROOT/'descriptions/README.md').read_text(encoding='utf-8')
        check_scene_routes(index)
        for target in ('src/cutscenes/dialogue.lua', 'src/descriptions/episode1_rooms.lua',
                       '(coverage.md)'):
            with self.subTest(target=target), self.assertRaisesRegex(ValueError, 'omits route'):
                check_scene_routes(index.replace(target, 'missing-route'))

    def test_agent_entry_point_and_every_category_are_linked(self):
        self.assertIn('(descriptions/README.md)', (ROOT/'AGENTS.md').read_text(encoding='utf-8'))
        index = (ROOT/'descriptions/README.md').read_text(encoding='utf-8')
        for name in GUIDES:
            with self.subTest(guide=name):
                self.assertIn('('+name+')', index)
                self.assertIn('(README.md)', (ROOT/'descriptions'/name).read_text(encoding='utf-8'))

    def test_source_guide_links_resolve(self):
        paths = [ROOT/'AGENTS.md', ROOT/'descriptions/README.md']
        paths += [ROOT/'descriptions'/name for name in GUIDES]
        for path in paths:
            with self.subTest(path=path):
                check_local_links(path, path.read_text(encoding='utf-8'))

    def test_link_gate_rejects_missing_and_escaping_targets(self):
        page = ROOT/'descriptions/README.md'
        check_local_links(page, '[existing](closeups.md)')
        check_local_links(page, '[language folder](../src/lang/en/scenes/episode2/)')
        check_local_links(page, '[external](https://example.com/guide)')
        for target in ('missing-authoring-guide.md', '../src/lang/missing-language/',
                       '../../outside.md', '../../'):
            with self.subTest(target=target), self.assertRaisesRegex(ValueError, 'missing local link'):
                check_local_links(page, '[broken]('+target+')')

    def test_movie_dialogue_relocation_preserves_accepted_intervals(self):
        text = (ROOT/'src/cutscenes/tracks/dialogue.lua').read_text(encoding='utf-8')
        entries = dict(re.findall(r"\['([^']+)'\]\s*=\s*(\{\{[^\n]+\}\}),", text))
        expected = {
            'en/episode01/bik_e1_7a_snowing.mp4': '{{0,74.55},{80.5,97.2}}',
            'en/episode01/bik_e1_6a_dialend.mp4': '{{17.75,23.3},{28.9,36.45}}',
        }
        for movie, intervals in expected.items():
            self.assertEqual(re.sub(r'\s+', '', entries[movie]), intervals)
        self.assertIn("require('cutscenes.tracks.dialogue')",
                      (ROOT/'src/cutscenes/tracks.lua').read_text(encoding='utf-8'))


if __name__ == '__main__':
    unittest.main()
