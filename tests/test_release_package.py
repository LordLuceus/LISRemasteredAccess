"""Engine-free package gates, with deliberately bad inputs. Never loads a DLL."""
from pathlib import Path
import io,sys,tempfile,unittest,zipfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
import package_release as P
from build_docs import validate_html
from release_notices import inputs as notice_inputs

class PackageTests(unittest.TestCase):
    def minimal(self):return {P.MOD+'LISNavRequest.lua':b"return {scene='inspect'}\n"}
    def test_safe_member_names(self):
        for name in ('../save.sav','/secret','C:/secret','a\\b','a/../b','a//b'):
            with self.subTest(name=name),self.assertRaises(ValueError):P.safe_name(name)
        P.safe_name('files/ue4ss/Mods/LISRemasteredAccess/Scripts/main.lua')
    def test_no_game_or_debug_payload(self):
        for name in ('files/save.sav','files/personal.json',P.MOD+'dev/probe.lua',P.MOD+'private.log',P.MOD+'audio/raw.pcm',P.MOD+'foo.dll'):
            payload=self.minimal();payload[name]=b'test'
            with self.subTest(name=name),self.assertRaises(ValueError):P.validate_payload(payload)
    def test_non_neutral_request_rejected(self):
        payload=self.minimal();payload[P.MOD+'LISNavRequest.lua']=b"return {expected_saved_directory='test'}"
        with self.assertRaises(ValueError):P.validate_payload(payload)
    def test_private_machine_path_rejected(self):
        payload=self.minimal();payload[P.MOD+'main.lua']=str(Path.home()/'private').encode()
        with self.assertRaises(ValueError):P.validate_payload(payload)
    def test_pe_architecture_gate(self):
        for b in (b'',b'not a DLL',b'MZ'+bytes(100)):
            with self.assertRaises(ValueError):P.check_pe(b,'bad.dll')
    def test_notice_catalog_and_checksum(self):
        import hashlib,json
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);cache=root/'cache';cache.mkdir();(root/'release').mkdir()
            with self.assertRaisesRegex(ValueError,'blocker'):notice_inputs(root,cache)
            data=b'Fixture licence';h=hashlib.sha256(data).hexdigest();(cache/h).write_bytes(data)
            spec={'reviewed':True,'entries':[{'kind':'raw','name':'fixture/LICENSE','url':'https://invalid.example/LICENSE','sha256':h}]}
            (root/'release/third-party-notices.json').write_text(json.dumps(spec))
            self.assertEqual(notice_inputs(root,cache)['licenses/UE4SS-dependencies/fixture/LICENSE'],data)
            (cache/h).write_bytes(b'corrupt')
            with self.assertRaisesRegex(ValueError,'checksum'):notice_inputs(root,cache)
    def test_deterministic_zip(self):
        a,b=io.BytesIO(),io.BytesIO();payload={'b.txt':b'b','a.txt':b'a'}
        P.write_zip(a,payload);P.write_zip(b,dict(reversed(list(payload.items()))))
        self.assertEqual(a.getvalue(),b.getvalue())
        with zipfile.ZipFile(io.BytesIO(a.getvalue())) as z:self.assertEqual(z.namelist(),['a.txt','b.txt'])
    def test_loader_settings(self):
        text='[Hooks]\nEngineTickResolveMethod=Scan\n'+''.join(n+'=1\n' for n in sorted(P.HOOKS|{'HookLoadMap','HookBeginPlay'}))+'[Debug]\nConsoleEnabled=1\nGuiConsoleEnabled=1\nGuiConsoleVisible=1\n'
        result=P.loader_settings(text.encode()).decode()
        self.assertIn('HookLoadMap = 0',result);self.assertIn('ConsoleEnabled = 0',result)
        self.assertIn('HookUObjectProcessEvent = 1',result)
    def test_zip_inventory_fault(self):
        with tempfile.TemporaryDirectory() as temp:
            f=Path(temp)/'bad.zip';P.write_zip(f,{'extra.sav':b'private'})
            with self.assertRaisesRegex(ValueError,'inventory'):P.verify_zip(f,{})
    def test_roundtrip_and_manifest_fault(self):
        import json
        payload=self.minimal()
        for n in P.DOCUMENTS:
            payload['docs/'+n]=b'# Guide'
            payload['docs/'+Path(n).with_suffix('.html').name]=b'<html lang="en"><a href="#main">Skip</a><nav>Contents</nav><main id="main"><h1>Guide</h1></main></html>'
        manifest={'files':{n:{'sha256':P.digest(b),'bytes':len(b)} for n,b in payload.items()}}
        payload['package-manifest.json']=json.dumps(manifest).encode()
        with tempfile.TemporaryDirectory() as temp:
            f=Path(temp)/'fixture.zip';P.write_zip(f,payload);P.verify_zip(f,payload)
            manifest['files']['docs/README.md']['sha256']='0'*64
            payload['package-manifest.json']=json.dumps(manifest).encode();P.write_zip(f,payload)
            with self.assertRaisesRegex(ValueError,'Manifest hash'):P.verify_zip(f,payload)
    def test_html_faults(self):
        md='| Key | Action |\n| --- | --- |\n| Home | Read |'
        good='<html lang="en"><a href="#main">Skip</a><nav>Contents</nav><main id="main"><h1>Guide</h1><table><tr><th scope="col">Key</th><th scope="col">Action</th></tr><tr><td>Home</td><td>Read</td></tr></table></main></html>'
        self.assertEqual(validate_html(good,md,set())['table_rows'],2)
        for bad in (good.replace(' scope="col"',''),good.replace('<tr><td>Home</td><td>Read</td></tr>',''),
                    good.replace('href="#main"','href="#missing"'),good.replace('<h1>','<h3>').replace('</h1>','</h3>')):
            with self.assertRaises(ValueError):validate_html(bad,md,set())

if __name__=='__main__':unittest.main()
