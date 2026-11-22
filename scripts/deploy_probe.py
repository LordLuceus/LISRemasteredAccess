"""Deploy validated mod inputs while holding the primary checkout's runtime claim.

Source Lua/tracks come from this checkout; --inputs-root explicitly selects local
DLL/audio inputs. The manifest and operator lock always belong to the primary
checkout, including when this script runs in a linked worktree. Never launches.
"""
from pathlib import Path
import argparse
import ctypes
import hashlib
import io
import json
import os
import subprocess
import uuid
import wave

from deployment_inventory import CUES

ROOT = Path(__file__).resolve().parents[1]
MOD = 'LISRemasteredAccess'
SCRIPTS = Path('ue4ss/Mods') / MOD / 'Scripts'
REQUEST = SCRIPTS / 'LISNavRequest.lua'
NEUTRAL = b"return {scene='inspect'}"
BINDINGS = {
    'lisr_speech.dll': ('speak', 'stop', 'status', 'pad', 'move', 'keys', 'tick',
                        'tick_load', 'play', 'focused'),
    'lisr_reflection.dll': ('reflection_read', 'movie_time', 'rewind', 'rewind_view_read', 'padlock_read'),
}
REQUIRED_TRACKS = {
    'src/cutscenes/tracks/en/episode01/bik_e1_6a_dialend.mp4.ad.srt',
    'src/cutscenes/tracks/en/episode01/bik_e1_7a_snowing.mp4.ad.srt',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args],
        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)).decode('utf-8').strip()


def canonical_root(root):
    # A linked worktree's common git directory is the primary checkout's .git.
    common = Path(git(root, 'rev-parse', '--path-format=absolute', '--git-common-dir'))
    if common.name != '.git':
        raise RuntimeError('Cannot identify primary checkout for runtime ownership')
    return common.parent.resolve()


def check_game_closed():
    listing = subprocess.check_output(
        ['tasklist', '/FI', 'IMAGENAME eq LiS-Win64-Shipping.exe', '/FO', 'CSV', '/NH'],
        creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)).decode(errors='replace')
    if 'lis-win64-shipping.exe' in listing.lower():
        raise RuntimeError('Close the remaster before deployment')


def validate_exports(build):
    for name, symbols in BINDINGS.items():
        try:
            # Inspect without resolving game imports or running DllMain.
            library = ctypes.CDLL(str(build / name), winmode=0x1)
            for symbol in symbols:
                getattr(library, 'lisr_' + symbol)
        except (OSError, AttributeError) as error:
            raise RuntimeError(f'Rebuild {name} before deployment: {error}') from error


def collect_inputs(root, inputs_root):
    """Read and validate the complete inventory before any installed file changes."""
    build = inputs_root / 'artifacts/build-native/Release'
    tracks = REQUIRED_TRACKS | {name for name in
        git(root, 'ls-files', '-z', '--', 'src/cutscenes/tracks').split('\0')
        if name.endswith('.ad.srt')}
    sources = [(p, SCRIPTS / p.relative_to(root / 'src'))
               for p in sorted((root / 'src').rglob('*.lua'))]
    for name in sorted(tracks):
        path = root / name
        if not path.is_file() or not path.read_bytes().strip():
            raise RuntimeError('Missing or empty bundled track: ' + name)
        sources.append((path, SCRIPTS / path.relative_to(root / 'src')))
    for name in BINDINGS:
        sources.append((build / name, SCRIPTS / name))
    for name in CUES:
        sources.append((inputs_root / 'assets/audio' / (name + '.wav'),
                        SCRIPTS / 'audio' / (name + '.wav')))
    payload = {}
    for source, relative in sources:
        if source.is_symlink():
            raise RuntimeError('Source symlink not permitted: ' + str(source))
        content = source.read_bytes()
        if not content:
            raise RuntimeError('Empty deployment input: ' + str(source))
        if source.suffix == '.wav':
            try:
                with wave.open(io.BytesIO(content)) as audio:
                    frames = audio.getnframes()
                    if ((audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) != (1, 2, 24000)
                            or frames <= 0 or len(audio.readframes(frames)) != frames * 2):
                        raise ValueError('Expected nonempty complete mono 16-bit 24000 Hz PCM')
            except (wave.Error, EOFError, ValueError) as error:
                raise RuntimeError('Invalid cue WAV: ' + str(source)) from error
        payload[relative] = content
    if SCRIPTS / 'main.lua' not in payload:
        raise RuntimeError('Missing source main.lua')
    validate_exports(build)
    return payload


def deploy(root, inputs_root, owner_root):
    """Explicit roots allow offline fixtures; CLI always resolves the canonical owner."""
    manifest = owner_root / 'artifacts/ue4ss-install/installation/manifest.json'
    runtime = owner_root / 'artifacts/runtime'
    runtime.mkdir(parents=True, exist_ok=True)
    claim = runtime / 'operator-owner'
    claim.mkdir(exist_ok=False)
    token = uuid.uuid4().hex
    try:
        (claim / 'claim.json').write_text(json.dumps({
            'token': token, 'operator_pid': os.getpid(), 'purpose': 'mod deployment'}))
        check_game_closed()
        data = json.loads(manifest.read_text(encoding='utf-8-sig'))
        game = Path(data['game']).resolve()
        payload = collect_inputs(root, inputs_root)
        # Session requests are runtime-owned: reset only after ALL validation.
        request = game / REQUEST
        if request.exists():
            payload[REQUEST] = NEUTRAL
        wanted = {str(rel) for rel in payload}
        prefix = str(SCRIPTS) + os.sep
        stale = [f for f in data['files'] if f['relative'].startswith(prefix)
                 and f['relative'] not in wanted and f['relative'] != str(REQUEST)]
        for item in stale:
            p = game / item['relative']
            if not p.resolve().is_relative_to(game):
                raise RuntimeError('Unsafe stale target')
            # Missing optional/previously bundled assets must never mean deletion.
            if p.suffix.lower() == '.wav' or p.name.endswith('.ad.srt'):
                raise RuntimeError('Missing previously installed asset input: ' + str(p))
            if item['previous_sha256'] is not None or sha(p) != item['installed_sha256']:
                raise RuntimeError('Stale file changed or pre-existing; inspect: ' + str(p))
        operations = []
        for rel, content in payload.items():
            target = game / rel
            if not target.resolve().is_relative_to(game):
                raise RuntimeError('Unsafe target')
            item = next((f for f in data['files'] if f['relative'] == str(rel)), None)
            if item:
                if rel != REQUEST and sha(target) != item['installed_sha256']:
                    raise RuntimeError('Installed file changed: ' + str(target))
            elif target.exists():
                raise RuntimeError('Unowned target: ' + str(target))
            operations.append((content, target, rel, item))
        for item in stale:
            (game / item['relative']).unlink()
            data['files'].remove(item)
            print('removed stale', item['relative'])
        for content, target, rel, item in operations:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
            digest = sha(target)
            if item:
                item['installed_sha256'] = digest
            else:
                data['files'].append({'relative': str(rel), 'installed_sha256': digest,
                                      'previous_sha256': None})
        manifest.write_text(json.dumps(data, indent=2), encoding='utf-8')
        print('Mod deployed and hash-verified:', len(operations), 'files,', len(stale), 'stale removed')
    finally:
        history = runtime / 'operator-history'
        history.mkdir(exist_ok=True)
        claim.rename(history / ('deploy-' + token))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inputs-root', type=Path, default=ROOT,
                        help='Checkout with complete built DLLs and all eight local cue WAVs')
    args = parser.parse_args(argv)
    deploy(ROOT, args.inputs_root.resolve(), canonical_root(ROOT))


if __name__ == '__main__':
    main()
