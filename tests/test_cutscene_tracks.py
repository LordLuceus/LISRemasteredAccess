"""Bundled description coverage and ZIP boundaries; no installed game required."""
from pathlib import Path
import re,sys,unittest,tempfile
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
import package_release as package

class CutsceneTracks(unittest.TestCase):
    def test_collector_includes_tracks_but_not_overrides(self):
        paths=['src/main.lua','src/cutscenes/tracks/en/episode01/movie.mp4.ad.srt',
               'src/cutscenes/overrides/en/episode01/movie.mp4.ad.srt','src/dev/probe.lua']
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            for name in paths:
                path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(b'test')
            with patch.object(package,'git',return_value='\0'.join(paths)+'\0'):
                payload=package.collect_scripts(root)
            self.assertIn(package.MOD+'cutscenes/tracks/en/episode01/movie.mp4.ad.srt',payload)
            self.assertNotIn(package.MOD+'cutscenes/overrides/en/episode01/movie.mp4.ad.srt',payload)
            self.assertNotIn(package.MOD+'dev/probe.lua',payload)

    def test_windows_english_inventory_and_windows(self):
        limits={'bik_e1_6a_dialend.mp4.ad.srt':45.133333,
                'bik_e1_7a_snowing.mp4.ad.srt':189.066667}
        self.check_windows('episode01', limits)

    def test_episode_two_story_tracks(self):
        limits = {
            'bik_e2_3a_vision.mp4.ad.srt': 5.7,
            'bik_e2_3b_vision.mp4.ad.srt': 15.766667,
            'bik_e2_7a_eclipse1.mp4.ad.srt': 79.133333,
            'bik_e2_7a_eclipse2a.mp4.ad.srt': 15.066667,
            'bik_e2_7a_eclipse2b.mp4.ad.srt': 15.066667,
            'bik_e2_7a_eclipse3.mp4.ad.srt': 63.666667,
            'bik_e2_7a_eclipsekatealive.mp4.ad.srt': 157.867643,
            'bik_e2_7a_eclipsekatedead.mp4.ad.srt': 157.867643,
            'bik_previously_e2.mp4.ad.srt': 69.799930,
            'bik_teaser_e2.mp4.ad.srt': 9.033324,
        }
        self.check_windows('episode02', limits)

    def check_windows(self, episode, limits):
        tracks=ROOT/'src/cutscenes/tracks/en'/episode
        self.assertEqual({p.name for p in tracks.glob('*.srt')},set(limits))
        for name,duration in limits.items():
            with self.subTest(name=name):
                text=(tracks/name).read_text(encoding='utf-8')
                blocks=text.strip().split('\n\n');previous=0
                for index,block in enumerate(blocks,1):
                    lines=block.splitlines();self.assertEqual(int(lines[0]),index)
                    match=re.fullmatch(r'(\d\d):(\d\d):(\d\d),(\d{3}) --> (\d\d):(\d\d):(\d\d),(\d{3})',lines[1])
                    self.assertIsNotNone(match)
                    v=list(map(int,match.groups()))
                    start=v[0]*3600+v[1]*60+v[2]+v[3]/1000
                    end=v[4]*3600+v[5]*60+v[6]+v[7]/1000
                    self.assertGreaterEqual(start,previous);self.assertGreater(end,start);self.assertLessEqual(end,duration)
                    self.assertTrue(' '.join(lines[2:]).strip());previous=end

    def test_ending_montage_preserves_unintroduced_identities(self):
        track=ROOT/'src/cutscenes/tracks/en/episode01/bik_e1_7a_snowing.mp4.ad.srt'
        text=track.read_text(encoding='utf-8')
        cue=text.strip().split('\n\n')[6].splitlines()
        self.assertEqual(cue[1],'00:02:18,000 --> 00:02:19,000')
        self.assertEqual(' '.join(cue[2:]),
            'A man holding a bong opens the RV door and hushes the barking dog.')
        self.assertNotRegex(text,r'(?i)\b(?:Frank|Pompidou)\b')

    def test_episode_two_ending_segments_and_outcomes(self):
        root = ROOT / 'src/cutscenes/tracks/en/episode02'

        def captions(segment):
            path = root / f'bik_e2_7a_eclipse{segment}.mp4.ad.srt'
            return [block.splitlines()[2:] for block in path.read_text().strip().split('\n\n')]

        for ending, middle in [('katealive', '2a'), ('katedead', '2b')]:
            with self.subTest(ending=ending):
                self.assertEqual(captions(ending), captions('1') + captions(middle) + captions('3'))
        self.assertNotEqual(captions('2a'), captions('2b'))

    def test_episode2_written_messages_and_location(self):
        root = ROOT / 'src/cutscenes/tracks/en/episode02'
        # Installed BIK_E2_7A_Eclipse3_en.vtt, confirmed against the movie phone shot.
        messages = "Chloe texts Max, 'Sorry about Kate. I hope you're ok. This eclipse freaks me out...'"
        for segment in ('3', 'katealive', 'katedead'):
            text = (root / f'bik_e2_7a_eclipse{segment}.mp4.ad.srt').read_text(encoding='utf-8')
            self.assertIn(messages, text)
            self.assertIn("Max replies, 'Let's find out what's going on! Together!'", text)
        for segment in ('1', 'katealive', 'katedead'):
            text = (root / f'bik_e2_7a_eclipse{segment}.mp4.ad.srt').read_text(encoding='utf-8')
            self.assertIn("Outside Chloe's house, Joyce and David stand holding hands.", text)
            self.assertNotIn('Through the doorway', text)

    def test_strict_packaged_track_paths(self):
        good='cutscenes/tracks/en/episode01/bik_e1_7a_snowing.mp4.ad.srt'
        self.assertTrue(package.description_track(good))
        for bad in ('cutscenes/overrides/en/episode01/movie.mp4.ad.srt',
                    'cutscenes/tracks/en/episode01/../../private.mp4.ad.srt',
                    'cutscenes/tracks/en/episode01/movie.mp4','dev/movie.mp4.ad.srt',
                    'cutscenes/tracks/en/episode01/log.txt'):
            self.assertFalse(package.description_track(bad),bad)
        payload={package.MOD+'LISNavRequest.lua':b"return {scene='inspect'}\n",package.MOD+good:b''}
        package.validate_payload(payload)
        for bad in ('cutscenes/overrides/en/episode01/movie.mp4.ad.srt','dev/movie.mp4.ad.srt'):
            with self.assertRaises(ValueError):package.validate_payload({**payload,package.MOD+bad:b'private'})

if __name__=='__main__':unittest.main()
