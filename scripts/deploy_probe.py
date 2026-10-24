"""Deploy owned probe sources only, verifying previous hashes first."""
from pathlib import Path
import hashlib,json,shutil,subprocess,os,uuid
root=Path(__file__).resolve().parents[1]
manifest=root/'artifacts/ue4ss-install/installation/manifest.json'
runtime=root/'artifacts/runtime';runtime.mkdir(exist_ok=True)
claim=runtime/'operator-owner';claim.mkdir(exist_ok=False)
token=uuid.uuid4().hex
(claim/'claim.json').write_text(json.dumps({'token':token,'operator_pid':os.getpid(),'purpose':'probe deployment'}))
try:
    listing=subprocess.check_output(['tasklist','/FI','IMAGENAME eq LiS-Win64-Shipping.exe','/FO','CSV','/NH'],creationflags=subprocess.CREATE_NO_WINDOW).decode(errors='replace')
    if 'lis-win64-shipping.exe' in listing.lower():raise RuntimeError('Close the remaster before deployment')
    data=json.loads(manifest.read_text(encoding='utf-8-sig'))
    game=Path(data['game']).resolve();operations=[]
    sources=[(s,Path('ue4ss/Mods/EngineTickProbe/Scripts')/s.name) for s in (root/'probes/EngineTickProbe').glob('*.lua')]
    native=root/'artifacts/build-native/Release/lisr_speech.dll'
    if native.exists():sources.append((native,Path('ue4ss/Mods/EngineTickProbe/Scripts/lisr_speech.dll')))
    for source,relative in sources:
        relative=str(relative)
        target=game/relative
        if not target.resolve().is_relative_to(game):raise RuntimeError('Unsafe target')
        item=next((f for f in data['files'] if f['relative']==relative),None)
        if item:
            if hashlib.sha256(target.read_bytes()).hexdigest()!=item['installed_sha256']:raise RuntimeError(f'Installed file changed: {target}')
        elif target.exists():raise RuntimeError(f'Unowned target: {target}')
        operations.append((source,relative,target,item))
    for source,relative,target,item in operations:
        shutil.copy2(source,target)
        digest=hashlib.sha256(target.read_bytes()).hexdigest()
        if item:item['installed_sha256']=digest
        else:data['files'].append({'relative':relative,'installed_sha256':digest,'previous_sha256':None})
    manifest.write_text(json.dumps(data,indent=2),encoding='utf-8')
    print('Owned prototype sources deployed and hash-verified:',len(operations),'files')
finally:
    history=runtime/'operator-history';history.mkdir(exist_ok=True)
    claim.rename(history/('deploy-'+token))
