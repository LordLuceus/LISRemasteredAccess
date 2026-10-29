"""One-time reversible upgrade from the verified stable installation."""
from pathlib import Path
import hashlib, json, re, shutil, uuid, os

ROOT = Path(__file__).resolve().parents[1]
RECORD = ROOT/'artifacts/ue4ss-experimental-83330635'
STAGE = RECORD/'staged'
MANIFEST = ROOT/'artifacts/ue4ss-install/installation/manifest.json'
old = json.loads(MANIFEST.read_text(encoding='utf-8'))
GAME = Path(old['game']).resolve()
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert old['release'] == 'UE4SS v3.0.1'
assert sha(RECORD/'UE4SS_v3.0.1-1181-g83330635.zip') == 'b9a166a756605b21058a64cde93bcaab1a855dba3553e5c7e6ce0fa8fdfad7b9'
backup = RECORD/'stable-backup'
backup.mkdir(exist_ok=False)
(backup/'owner.json').write_text(json.dumps({'token':uuid.uuid4().hex,'pid':os.getpid(),'purpose':'UE4SS loader upgrade only'}),encoding='utf-8')
shutil.copy2(MANIFEST,backup/'manifest.json')
for item in old['files']:
    p=GAME/item['relative']
    assert p.resolve().is_relative_to(GAME)
    assert item['previous_sha256'] is None, 'Unexpected pre-existing file; needs a different migration'
    assert sha(p)==item['installed_sha256'],p
    q=backup/'files'/item['relative'];q.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(p,q);assert sha(q)==sha(p)

ini=STAGE/'ue4ss/UE4SS-settings.ini'
s=ini.read_text(encoding='utf-8-sig')
s=re.sub(r'(?m)^(Hook\w+)[ \t]*=[ \t]*1[ \t]*$',r'\1 = 0',s)
s=s.replace('HookEngineTick = 0','HookEngineTick = 1')
# Script hooks (RegisterHook on Blueprint functions, used by the dialogue
# choice reader) need these three; with ProcessInternal alone no hook fires
# (measured 29 Oct). HookLoadMap stays off: it broke startup.
for h in ('HookProcessInternal','HookProcessLocalScriptFunction','HookUObjectProcessEvent'):
    s=s.replace(h+' = 0',h+' = 1')
assert 'DefaultExecuteInGameThreadMethod = EngineTick' in s
assert 'EngineTickResolveMethod = Scan' in s
ini.write_text(s,encoding='utf-8')
mods=STAGE/'ue4ss/Mods'
for name in ('mods.txt','mods.json'):
    p=mods/name
    if name.endswith('.txt'):
        s=re.sub(r'(?m)^([ \t]*[^;\r\n]+:[ \t]*)[01][ \t]*$',r'\g<1>0',p.read_text())
        p.write_text(s+'\nLISRemasteredAccess : 1\n',encoding='utf-8')
    else:
        data=json.loads(p.read_text())
        for mod in data:mod['mod_enabled']=False
        data.append({'mod_name':'LISRemasteredAccess','mod_enabled':True})
        p.write_text(json.dumps(data,indent=2),encoding='utf-8')
probe=mods/'LISRemasteredAccess/Scripts/main.lua';probe.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(ROOT/'src/main.lua',probe)
assert not list(mods.rglob('enabled.txt'))
old_names={item['relative'] for item in old['files']}
new=[]
for p in STAGE.rglob('*'):
    if not p.is_file():continue
    rel=p.relative_to(STAGE);target=GAME/rel
    assert target.resolve().is_relative_to(GAME)
    assert not target.exists() or str(rel) in old_names,target
    new.append({'relative':str(rel),'installed_sha256':sha(p),'previous_sha256':None})
(RECORD/'upgrade-plan.json').write_text(json.dumps(new,indent=2),encoding='utf-8')
# All existing files have been verified and backed up before retiring anything.
for item in old['files']:(GAME/item['relative']).unlink()
for item in new:
    p=GAME/item['relative'];p.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(STAGE/item['relative'],p);assert sha(p)==item['installed_sha256']
old.update(release='UE4SS v3.0.1-1181-g83330635',files=new,probe_enabled=True,
           loader_log='ue4ss/UE4SS.log',stable_rollback=str(backup),
           diagnostic_changes=['EngineTick hook only; explicit EngineTick dispatcher',
                               'All bundled mods disabled in mods.txt and mods.json'])
MANIFEST.write_text(json.dumps(old,indent=2),encoding='utf-8')
print('Experimental EngineTick probe installed:',len(new),'files. Stable loader/configuration preserved:',backup)
