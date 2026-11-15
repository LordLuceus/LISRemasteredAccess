import importlib.util,math,struct,tempfile,unittest,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('rewind_audio',ROOT/'scripts/generate_rewind_cues.py')
audio=importlib.util.module_from_spec(spec);spec.loader.exec_module(audio)
class RewindAudioTests(unittest.TestCase):
    def test_original_timing_and_silence(self):
        approach=struct.unpack('<1632h',audio.pcm(False))
        crossed=struct.unpack('<2880h',audio.pcm(True))
        self.assertEqual(audio.RATE,24000)
        self.assertTrue(all(x==0 for x in approach[432:1200]))
        self.assertGreater(max(approach[:432]),10000)
        self.assertGreater(max(approach[1200:]),10000)
        self.assertLessEqual(max(map(abs,crossed)),12000)
        self.assertEqual((approach[0],approach[-1],crossed[0],crossed[-1]),(0,0,0,0))
    def test_generator_preserves_unrelated_and_custom_control_cues(self):
        with tempfile.TemporaryDirectory()as d:
            p=Path(d);(p/'control_back.wav').write_bytes(b'user custom cue')
            audio.generate(p)
            self.assertEqual((p/'control_back.wav').read_bytes(),b'user custom cue')
            for name,n in [('rewind_approach',1632),('rewind_crossed',2880)]:
                with wave.open(str(p/(name+'.wav')),'rb')as w:
                    self.assertEqual((w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getnframes()),(1,2,24000,n))
                    self.assertEqual(w.readframes(n),audio.pcm(name=='rewind_crossed'))
if __name__=='__main__':unittest.main()
