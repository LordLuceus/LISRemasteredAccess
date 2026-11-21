"""Offline deployment fixtures: no real game, DLL loading, or runtime claims."""
from pathlib import Path
import hashlib
import io
import json
import sys
import tempfile
import unittest
from unittest.mock import patch
import wave

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import deploy_probe as D


def wav(frames=b'\0\0' * 8):
    stream = io.BytesIO()
    with wave.open(stream, 'wb') as audio:
        audio.setparams((1, 2, 24000, 0, 'NONE', 'not compressed'))
        audio.writeframes(frames)
    return stream.getvalue()


class DeployTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.root, self.inputs, self.owner, self.game = [base / n for n in ('source', 'inputs', 'primary', 'game')]
        self.manifest = self.owner / 'artifacts/ue4ss-install/installation/manifest.json'
        self.files = []
        self.put(self.root / 'src/main.lua', b'return {}')
        for name in D.REQUIRED_TRACKS:
            self.put(self.root / name, b'1\n00:00:01,000 --> 00:00:02,000\nDescription\n')
        for name in D.CUES:
            self.put(self.inputs / 'assets/audio' / (name + '.wav'), wav())
            self.installed(D.SCRIPTS / 'audio' / (name + '.wav'), wav())
        for name in D.BINDINGS:
            self.put(self.inputs / 'artifacts/build-native/Release' / name, b'fake DLL')
        self.installed(D.REQUEST, b"return {scene='test-session'}")
        self.installed(D.SCRIPTS / 'obsolete.lua', b'return 1')
        self.installed(D.SCRIPTS / 'main.lua', b'old main')
        self.put(self.manifest, json.dumps({'game': str(self.game), 'files': self.files}).encode())
        for target, value in [('check_game_closed', None), ('validate_exports', None), ('git', '')]:
            mock = patch.object(D, target, return_value=value)
            setattr(self, target, mock.start())
            self.addCleanup(mock.stop)

    def put(self, path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)

    def installed(self, relative, content):
        self.put(self.game / relative, content)
        self.files.append({'relative': str(relative), 'installed_sha256': hashlib.sha256(content).hexdigest(),
                           'previous_sha256': None})

    def snapshot(self):
        return (self.manifest.read_bytes(), {str(p.relative_to(self.game)): p.read_bytes()
                for p in self.game.rglob('*') if p.is_file()})

    def deploy(self):
        D.deploy(self.root, self.inputs, self.owner)

    def fails_unchanged(self):
        before = self.snapshot()
        with self.assertRaises((RuntimeError, OSError)):
            self.deploy()
        self.assertEqual(before, self.snapshot())
        self.assertFalse((self.owner / 'artifacts/runtime/operator-owner').exists())
        self.assertFalse((self.root / 'artifacts/runtime').exists())
        self.assertFalse((self.inputs / 'artifacts/runtime').exists())

    def test_each_missing_cue_preserves_every_installed_file_and_request(self):
        for name in D.CUES:
            with self.subTest(cue=name):
                path = self.inputs / 'assets/audio' / (name + '.wav')
                path.unlink()
                self.fails_unchanged()
                path.write_bytes(wav())

    def test_empty_malformed_zero_frame_and_truncated_wav(self):
        path = self.inputs / 'assets/audio' / (D.CUES[0] + '.wav')
        for content in (b'', b'not wave', wav(b''), wav()[:-2]):
            with self.subTest(content=content):
                path.write_bytes(content)
                self.fails_unchanged()

    def test_each_required_track_missing(self):
        for name in D.REQUIRED_TRACKS:
            with self.subTest(track=name):
                path = self.root / name
                content = path.read_bytes()
                path.unlink()
                self.fails_unchanged()
                path.write_bytes(content)

    def test_additional_tracked_track_missing(self):
        self.git.return_value = 'src/cutscenes/tracks/en/episode01/future.mp4.ad.srt\0'
        self.fails_unchanged()

    def test_empty_required_track(self):
        (self.root / next(iter(D.REQUIRED_TRACKS))).write_bytes(b'')
        self.fails_unchanged()

    def test_dll_export_failure_preserves_game(self):
        self.validate_exports.side_effect = RuntimeError('missing export')
        self.fails_unchanged()

    def test_missing_dll_preserves_game(self):
        (self.inputs / 'artifacts/build-native/Release/lisr_speech.dll').unlink()
        self.fails_unchanged()

    def test_installed_hash_failure_does_not_reset_request(self):
        (self.game / D.SCRIPTS / 'main.lua').write_bytes(b'user edited')
        self.fails_unchanged()

    def test_stale_asset_is_not_silently_deleted(self):
        for name in ('audio/old.wav', 'cutscenes/tracks/en/episode01/old.mp4.ad.srt'):
            with self.subTest(asset=name):
                self.installed(D.SCRIPTS / name, b'old asset')
                self.put(self.manifest, json.dumps({'game': str(self.game), 'files': self.files}).encode())
                self.fails_unchanged()

    def test_success_resets_request_and_removes_obsolete_lua(self):
        self.deploy()
        self.assertEqual((self.game / D.REQUEST).read_bytes(), D.NEUTRAL)
        self.assertFalse((self.game / D.SCRIPTS / 'obsolete.lua').exists())
        data = json.loads(self.manifest.read_text())
        for item in data['files']:
            self.assertEqual(D.sha(self.game / item['relative']), item['installed_sha256'])
        for name in D.CUES:
            self.assertEqual((self.game / D.SCRIPTS / 'audio' / (name + '.wav')).read_bytes(), wav())

    def test_existing_owner_claim_blocks_deployment(self):
        claim = self.owner / 'artifacts/runtime/operator-owner'
        claim.mkdir(parents=True)
        before = self.snapshot()
        with self.assertRaises(FileExistsError):
            self.deploy()
        self.assertEqual(before, self.snapshot())
        self.assertTrue(claim.exists())

    def test_cli_uses_primary_owner_and_explicit_input_root(self):
        with patch.object(D, 'canonical_root', return_value=self.owner), patch.object(D, 'deploy') as deploy:
            D.main(['--inputs-root', str(self.inputs)])
        deploy.assert_called_once_with(D.ROOT, self.inputs.resolve(), self.owner)


class ExportTests(unittest.TestCase):
    def test_missing_library_and_missing_exports(self):
        for failure in (OSError('missing DLL'), AttributeError('missing export')):
            with self.subTest(failure=failure), patch.object(D.ctypes, 'CDLL', side_effect=failure):
                with self.assertRaisesRegex(RuntimeError, 'Rebuild lisr_speech.dll'):
                    D.validate_exports(Path('offline'))

    def test_every_export_is_required(self):
        for dll, symbols in D.BINDINGS.items():
            for symbol in symbols:
                class Library:
                    def __getattr__(self, name):
                        if name == 'lisr_' + symbol:
                            raise AttributeError(name)
                        return object()
                with self.subTest(dll=dll, symbol=symbol), patch.object(D.ctypes, 'CDLL', return_value=Library()):
                    with self.assertRaises(RuntimeError):
                        D.validate_exports(Path('offline'))

    def test_canonical_owner_uses_common_git_directory(self):
        with patch.object(D, 'git', return_value=str(Path.cwd() / '.git')):
            self.assertEqual(D.canonical_root(Path('linked-worktree')), Path.cwd().resolve())


if __name__ == '__main__':
    unittest.main()
