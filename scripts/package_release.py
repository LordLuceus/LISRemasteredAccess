"""Build a deterministic, fresh-install tester ZIP. Never installs or launches anything.

Inputs are explicit: the pinned upstream loader ZIP, built native DLL directory,
the six approved processed audio cues, and the pinned Prism source archive.
--preflight checks inputs and renders docs, but produces no release ZIP.
Packaging does not compile: build native/ in Release first (see README).
"""
from pathlib import Path,PurePosixPath
import argparse,configparser,hashlib,io,json,os,re,struct,subprocess,tempfile,zipfile
from build_docs import build,DOCUMENTS,validate_html
from release_notices import inputs as dependency_notices

ROOT=Path(__file__).resolve().parents[1]
LOADER_ZIP_SHA='b9a166a756605b21058a64cde93bcaab1a855dba3553e5c7e6ce0fa8fdfad7b9'
LOADER_DLL_SHA='ce5e3c46a920cc00b2817ac61e438c9162830290379d0b5b9c4dfc2b29459290'
PRISM_SHA='c5d3f0be06bd34fea0478f1c38ce4de85cd3a21dbd2a1ed869b21c8a0a80ebaf'
MOD='files/ue4ss/Mods/LISRemasteredAccess/Scripts/'
HOOKS={'HookEngineTick','HookProcessInternal','HookProcessLocalScriptFunction','HookUObjectProcessEvent'}
CUES=('control_lost','control_back','sneak_spotted','sneak_hidden','focus_tick_a','focus_tick_b')

def digest(data):return hashlib.sha256(data).hexdigest()
def git(root,*args):
    p=subprocess.run(['git','-C',str(root),*args],check=True,capture_output=True,
        creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0),timeout=30)
    return p.stdout.decode('utf-8').strip()
def safe_name(name):
    p=PurePosixPath(name)
    if not name or '\\' in name or ':' in name or p.is_absolute() or '..' in p.parts or str(p)!=name:
        raise ValueError('Unsafe archive member: '+name)
def pinned(path,expected):
    data=Path(path).read_bytes()
    if digest(data)!=expected:raise ValueError('Wrong pinned input: '+Path(path).name)
    return data
def check_pe(data,name):
    if len(data)<64 or data[:2]!=b'MZ':raise ValueError('Not a native DLL: '+name)
    pe=struct.unpack_from('<I',data,60)[0]
    if pe+6>len(data) or data[pe:pe+4]!=b'PE\0\0' or struct.unpack_from('<H',data,pe+4)[0]!=0x8664:
        raise ValueError('Expected x64 PE: '+name)
def private_path(data):
    home=str(Path.home()).replace('\\','/').lower()
    for value in {home,home.replace('/','\\')}:
        if len(value)>4 and any(value.encode(enc) in data.lower() for enc in ('utf-8','utf-16le')):return True
    return False
def loader_settings(data):
    c=configparser.ConfigParser(interpolation=None);c.optionxform=str
    c.read_string(data.decode('utf-8-sig').replace('\r',''))
    for name in c['Hooks']:
        if name.startswith('Hook'):c['Hooks'][name]='1' if name in HOOKS else '0'
    for name in ('ConsoleEnabled','GuiConsoleEnabled','GuiConsoleVisible'):c['Debug'][name]='0'
    if c['Hooks']['EngineTickResolveMethod']!='Scan':raise ValueError('Unexpected loader dispatcher')
    enabled={k for k,v in c['Hooks'].items() if k.startswith('Hook') and v=='1'}
    if enabled!=HOOKS:raise ValueError('Loader hook inventory changed')
    out=io.StringIO();c.write(out);return out.getvalue().encode('utf-8')

def collect(args,root=ROOT):
    root=Path(root);payload={}
    provenance=json.loads((root/'native/third_party/reflection-source.json').read_text(encoding='utf-8'))
    catalog=json.loads((root/'release/third-party-notices.json').read_text(encoding='utf-8'))
    if provenance['loader_sha256']!=LOADER_DLL_SHA or catalog['loader_revision']!=provenance['loader_commit']:
        raise ValueError('Loader/native/notice pins disagree')
    if PRISM_SHA not in (root/'native/CMakeLists.txt').read_text(encoding='utf-8'):
        raise ValueError('Prism source pin disagrees with the native build')
    def add(name,data):
        safe_name(name)
        if name in payload:raise ValueError('Duplicate package member '+name)
        payload[name]=data
    loader=pinned(args.loader_zip,LOADER_ZIP_SHA)
    with zipfile.ZipFile(io.BytesIO(loader)) as z:
        for name in ('dwmapi.dll','ue4ss/UE4SS.dll','ue4ss/Mods/shared/UEHelpers/UEHelpers.lua'):
            add('files/'+name,z.read(name))
        if digest(payload['files/ue4ss/UE4SS.dll'])!=LOADER_DLL_SHA:raise ValueError('Loader DLL changed')
        add('files/ue4ss/UE4SS-settings.ini',loader_settings(z.read('ue4ss/UE4SS-settings.ini')))
        add('licenses/UE4SS.txt',z.read('ue4ss/LICENSE'))
    add('files/ue4ss/VTableLayout.ini',(root/'compatibility/VTableLayout.ini').read_bytes())
    add('files/ue4ss/Mods/mods.txt',b'LISRemasteredAccess : 1\n')
    add('files/ue4ss/Mods/mods.json',b'[{"mod_name":"LISRemasteredAccess","mod_enabled":true}]\n')
    tracked=git(root,'ls-files','-z','--','src').split('\0')
    for name in tracked:
        if not name or not name.endswith('.lua') or name.startswith('src/dev/'):continue
        p=root/name
        if p.is_symlink():raise ValueError('Source symlink not permitted: '+name)
        add(MOD+name[4:],p.read_bytes())
    add(MOD+'LISNavRequest.lua',b"return {scene='inspect'}\n")
    for name in ('lisr_speech.dll','lisr_reflection.dll'):
        data=(Path(args.native_dir)/name).read_bytes();check_pe(data,name);add(MOD+name,data)
    import wave
    for name in CUES:
        data=(Path(args.audio_dir)/(name+'.wav')).read_bytes()
        with wave.open(io.BytesIO(data)) as w:
            if (w.getnchannels(),w.getsampwidth(),w.getframerate())!=(1,2,24000):raise ValueError('Unexpected audio format '+name)
        add(MOD+'audio/'+name+'.wav',data)
    for name in ('LICENSE-fmt','ue4ss/LICENSE-LuaMadeSimple','ue4ss/LICENSE-LuaRaw'):
        add('licenses/'+Path(name).name+'.txt',(root/'native/third_party'/name).read_bytes())
    header=(root/'native/third_party/ue4ss/include/lua.h').read_text(encoding='utf-8-sig')
    lua_notice=re.search(r'/\*{10,}\n(\* Copyright.*?)[*]{10,}/',header,re.S)
    if not lua_notice:raise ValueError('Lua copyright notice not found in pinned header')
    add('licenses/Lua.txt',('\n'.join(line.lstrip('* ') for line in lua_notice[1].splitlines())+'\n').encode('utf-8'))
    for name,data in dependency_notices(root,root/'artifacts/release-notice-cache').items():add(name,data)
    add('licenses/UE4SS-dependencies/NOTICE-AUDIT.md',(root/'release/NOTICE-AUDIT.md').read_bytes())
    # Exact covered source plus the complete modified translation unit and recipe.
    prism=pinned(args.prism_archive,PRISM_SHA);add('licenses/Prism-source.zip',prism)
    with zipfile.ZipFile(io.BytesIO(prism)) as z:
        prefix=z.namelist()[0].split('/')[0]+'/'
        for n in z.namelist():
            rel=n.removeprefix(prefix)
            if not n.endswith('/') and (rel in ('LICENSE','NOTICE') or rel.startswith('LICENSES/')):
                add('licenses/Prism/'+rel,z.read(n))
        sapi=z.read(prefix+'source/backends/sapi.cpp').decode('utf-8')
        before='      flags |= SPF_IS_XML;\n    }\n    return SapiSpeakParams{.text = std::move(wtext), .flags = flags};'
        after='      flags |= SPF_IS_XML;\n    } else {\n      // LISAccess: plain announcements must not be autodetected as XML.\n      flags |= SPF_IS_NOT_XML;\n    }\n    return SapiSpeakParams{.text = std::move(wtext), .flags = flags};'
        recipe=(root/'native/cmake/prism-sapi-literal.cmake').read_text(encoding='utf-8')
        if sapi.count(before)!=1 or before not in recipe or after not in recipe:raise ValueError('SAPI patch/source agreement changed')
        add('licenses/prism-sapi.cpp',sapi.replace(before,after).encode('utf-8'))
        add('licenses/prism-sapi-literal.cmake',recipe.encode('utf-8'))
    for name in DOCUMENTS:add('docs/'+name,(root/name).read_bytes())
    with tempfile.TemporaryDirectory(prefix='lisr-docs-') as temp:
        build(root,Path(temp),args.pandoc)
        for name in DOCUMENTS:
            n=Path(name).with_suffix('.html').name;add('docs/'+n,(Path(temp)/n).read_bytes())
    add('READ-ME-FIRST.txt',b'Life is Strange Remastered accessibility tester package\n\nOpen docs/README.html for the player guide: requirements, installation,\ncontrols, limitations, removal and reporting problems.\nThe changelog and third-party licences are also in docs/.\nPackage version and file hashes are in package-manifest.json.\n')
    validate_payload(payload)
    return payload

def validate_payload(payload):
    fixed={'files/dwmapi.dll','files/ue4ss/UE4SS.dll','files/ue4ss/UE4SS-settings.ini',
           'files/ue4ss/VTableLayout.ini','files/ue4ss/Mods/mods.txt','files/ue4ss/Mods/mods.json',
           'files/ue4ss/Mods/shared/UEHelpers/UEHelpers.lua'}
    for name,data in payload.items():
        safe_name(name)
        if name.startswith('files/'):
            tail=name.removeprefix(MOD)
            allowed=name in fixed or (name.startswith(MOD) and
                (tail.endswith('.lua') and not tail.startswith('dev/') or
                 tail in ('lisr_speech.dll','lisr_reflection.dll') or
                 tail in {'audio/'+n+'.wav' for n in CUES}))
            if not allowed:raise ValueError('Unexpected private/debug/game runtime payload: '+name)
        if name.endswith(('.lua','.dll','.md','.html','.json','.txt')) and private_path(data):
            raise ValueError('Personal machine path in '+name)
    request=payload.get(MOD+'LISNavRequest.lua')
    if request!=b"return {scene='inspect'}\n":raise ValueError('Non-neutral test-session request')
    if any(n.startswith(MOD+'dev/') for n in payload):raise ValueError('Development modules included')

def write_zip(path,payload):
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name in sorted(payload):
            info=zipfile.ZipInfo(name,date_time=(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
            info.create_system=3;info.external_attr=0o100644<<16
            z.writestr(info,payload[name],compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)

def verify_zip(path,payload):
    with zipfile.ZipFile(path) as z:
        names=z.namelist()
        if len(names)!=len(set(names)) or set(names)!=set(payload):raise ValueError('ZIP member inventory differs')
        if z.testzip():raise ValueError('ZIP CRC failure')
        for name,data in payload.items():
            if z.read(name)!=data:raise ValueError('ZIP content mismatch: '+name)
        manifest=json.loads(z.read('package-manifest.json'))['files']
        if set(manifest)!=set(names)-{'package-manifest.json'}:raise ValueError('Manifest inventory differs')
        for name,meta in manifest.items():
            data=z.read(name)
            if meta!={'sha256':digest(data),'bytes':len(data)}:raise ValueError('Manifest hash/size mismatch: '+name)
        for name in DOCUMENTS:
            validate_html(z.read('docs/'+Path(name).with_suffix('.html').name).decode('utf-8'),
                          z.read('docs/'+name).decode('utf-8'),{Path(x).with_suffix('.html').name for x in DOCUMENTS})

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--inputs-root',type=Path,default=ROOT,help='Checkout containing the local binary/audio/source inputs')
    for name in ('loader-zip','native-dir','audio-dir','prism-archive'):p.add_argument('--'+name,type=Path)
    p.add_argument('--version',required=True);p.add_argument('--output',type=Path,default=ROOT/'artifacts/releases')
    p.add_argument('--pandoc');p.add_argument('--preflight',action='store_true');args=p.parse_args()
    defaults={'loader_zip':'artifacts/ue4ss-experimental-83330635/UE4SS_v3.0.1-1181-g83330635.zip',
              'native_dir':'artifacts/build-native/Release','audio_dir':'assets/audio',
              'prism_archive':'artifacts/build-native/_deps/prism-subbuild/prism-populate-prefix/src/archive.tar'}
    for name,relative in defaults.items():
        if getattr(args,name) is None:setattr(args,name,args.inputs_root/relative)
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,70}',args.version):p.error('Unsafe version label')
    if not args.preflight and git(ROOT,'status','--porcelain'):raise ValueError('Commit/review source changes before packaging')
    payload=collect(args)
    manifest={'format':1,'version':args.version,'source_commit':git(ROOT,'rev-parse','HEAD'),
              'game':'Life is Strange Remastered, Windows Steam build11330282',
              'loader':'UE4SS3.0.1-1181-g83330635','native_binaries':'prebuilt Release inputs; hashes recorded below',
              'files':{n:{'sha256':digest(b),'bytes':len(b)} for n,b in sorted(payload.items())}}
    payload['package-manifest.json']=(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n').encode('utf-8')
    if args.preflight:
        print(json.dumps({'preflight':'passed','files':len(payload),'uncompressed_bytes':sum(map(len,payload.values()))}));return
    args.output.mkdir(parents=True,exist_ok=True);out=args.output/('LISRemasteredAccess-'+args.version+'.zip')
    if out.exists():raise ValueError('Refusing to overwrite existing release '+str(out))
    temp=out.with_suffix('.zip.partial')
    if temp.exists():raise ValueError('Partial package already exists; inspect it before retrying')
    with temp.open('xb') as stream:write_zip(stream,payload)
    verify_zip(temp,payload);temp.rename(out)
    report={'file':out.name,'sha256':digest(out.read_bytes()),'bytes':out.stat().st_size,'files':len(payload),'source_commit':manifest['source_commit']}
    out.with_suffix('.verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
