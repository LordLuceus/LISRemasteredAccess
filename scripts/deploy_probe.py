"""Deploy the mod into the installed UE4SS Mods folder, verifying hashes first.

Mirrors src/ into ue4ss/Mods/LISRemasteredAccess/Scripts (subfolders kept, so
require("core.speech") resolves) plus the built speech DLL. Every installed file
is recorded in the install manifest; a recorded file whose source no longer
exists is removed, so renames never leave stale modules behind. The game must be
closed, and any owned file that changed since installation stops the deployment
before anything is written.
"""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, uuid

root = Path(__file__).resolve().parents[1]
MOD = 'LISRemasteredAccess'
SCRIPTS = Path('ue4ss/Mods') / MOD / 'Scripts'
# Written by the test runner per session; owned by the manifest, not by src/.
RUNTIME_OWNED = {str(SCRIPTS / 'LISNavRequest.lua')}
manifest = root / 'artifacts/ue4ss-install/installation/manifest.json'
runtime = root / 'artifacts/runtime'
runtime.mkdir(exist_ok=True)
claim = runtime / 'operator-owner'
claim.mkdir(exist_ok=False)
token = uuid.uuid4().hex
(claim / 'claim.json').write_text(json.dumps({'token': token, 'operator_pid': os.getpid(), 'purpose': 'mod deployment'}))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
try:
    listing = subprocess.check_output(['tasklist', '/FI', 'IMAGENAME eq LiS-Win64-Shipping.exe', '/FO', 'CSV', '/NH'],
                                      creationflags=subprocess.CREATE_NO_WINDOW).decode(errors='replace')
    if 'lis-win64-shipping.exe' in listing.lower():
        raise RuntimeError('Close the remaster before deployment')
    data = json.loads(manifest.read_text(encoding='utf-8-sig'))
    game = Path(data['game']).resolve()
    # A test run that was interrupted can leave its session request installed;
    # a normal launch would then start a test session. Put the neutral request
    # back (no claim is held here, so no run owns it) and say so.
    neutral = "return {scene='inspect'}"
    request = game / SCRIPTS / 'LISNavRequest.lua'
    if request.exists() and request.read_text(encoding='utf-8-sig') != neutral:
        request.write_bytes(neutral.encode('utf-8'))
        for f in data['files']:
            if f['relative'] == str(SCRIPTS / 'LISNavRequest.lua'):
                f['installed_sha256'] = sha(request)
        manifest.write_text(json.dumps(data, indent=4), encoding='utf-8')
        print('Leftover test-session request found and reset to neutral')
    sources = [(s, SCRIPTS / s.relative_to(root / 'src')) for s in sorted((root / 'src').rglob('*.lua'))]
    native = root / 'artifacts/build-native/Release/lisr_speech.dll'
    if not native.exists():
        raise RuntimeError('Build the speech module first (see README)')
    sources.append((native, SCRIPTS / 'lisr_speech.dll'))
    # Cue sounds (provider audio, git-ignored): installed when present locally.
    for wav in sorted((root / 'assets' / 'audio').glob('*.wav')):
        sources.append((wav, SCRIPTS / 'audio' / wav.name))
    wanted = {str(rel) for _, rel in sources}
    prefix = str(SCRIPTS) + os.sep
    # Check everything before changing anything.
    stale = [f for f in data['files'] if f['relative'].startswith(prefix)
             and f['relative'] not in wanted and f['relative'] not in RUNTIME_OWNED]
    for f in stale:
        p = game / f['relative']
        if f['previous_sha256'] is not None or sha(p) != f['installed_sha256']:
            raise RuntimeError(f'Stale file changed or pre-existing; inspect: {p}')
    operations = []
    for source, rel in sources:
        target = game / rel
        if not target.resolve().is_relative_to(game):
            raise RuntimeError('Unsafe target')
        item = next((f for f in data['files'] if f['relative'] == str(rel)), None)
        if item:
            if sha(target) != item['installed_sha256']:
                raise RuntimeError(f'Installed file changed: {target}')
        elif target.exists():
            raise RuntimeError(f'Unowned target: {target}')
        operations.append((source, rel, target, item))
    for f in stale:
        (game / f['relative']).unlink()
        data['files'].remove(f)
        print('removed stale', f['relative'])
    for source, rel, target, item in operations:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        digest = sha(target)
        if item:
            item['installed_sha256'] = digest
        else:
            data['files'].append({'relative': str(rel), 'installed_sha256': digest, 'previous_sha256': None})
    manifest.write_text(json.dumps(data, indent=2), encoding='utf-8')
    print('Mod deployed and hash-verified:', len(operations), 'files,', len(stale), 'stale removed')
finally:
    history = runtime / 'operator-history'
    history.mkdir(exist_ok=True)
    claim.rename(history / ('deploy-' + token))
