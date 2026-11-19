"""Independent c141ab07 native instruction fixtures; no installed game needed.

Captured from the pinned executable, not generated from movie_time.h. The exec
thunk keeps RCX=player, sets RDX to its stack output and copies eight bytes from
RAX to reflected result. Getter calls facade GetTime and returns that RDX buffer.
"""
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
GETTER = bytes.fromhex('40534883ec20488b8910010000488bdae8cbb0fcff488bc34883c4205bc3')
THUNK = bytes.fromhex('40534883ec20488b42204533c94885c0498bd8410f95c14c03c84c894a20488d542438e8987affff488b0848890b4883c4205bc3')
CLASS_LOAD = bytes.fromhex('488b054f5b8601')  # 0x1e6246a
CLASS_NAME = bytes.fromhex('488d15783ff900')  # 0x1e6249b -> UTF16 MediaPlayer

class MovieAddresses(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT/'native/src/movie_time.h').read_text(encoding='utf-8')
        self.constants = {n: int(v, 16) for n, v in re.findall(
            r'constexpr uintptr_t (\w+) = (0x[0-9a-f]+);', self.source)}

    def test_getter_entire_signature_is_independently_pinned(self):
        body = self.source.split('getter_bytes[] = {', 1)[1].split('}', 1)[0]
        self.assertEqual(bytes(int(v, 16) for v in re.findall(r'0x[0-9a-f]+', body)), GETTER)

    def test_thunk_calls_getter_with_owned_eight_byte_output(self):
        self.assertEqual(THUNK[30:35], bytes.fromhex('488d542438'))  # lea rdx,[rsp+38]
        self.assertEqual(THUNK[35], 0xe8)
        self.assertEqual(0x1e66070 + 40 + struct.unpack('<i', THUNK[36:40])[0], self.constants['getter_rva'])
        self.assertEqual(THUNK[40:46], bytes.fromhex('488b0848890b'))  # copy qword [rax]
        self.assertEqual(GETTER[6:13], bytes.fromhex('488b8910010000'))  # facade +110
        self.assertEqual(GETTER[13:16], bytes.fromhex('488bda'))  # preserve output
        self.assertEqual(0x1e5db30 + 21 + struct.unpack('<i', GETTER[17:21])[0], 0x1e28c10)
        self.assertEqual(GETTER[21:24], bytes.fromhex('488bc3'))  # return output

    def test_media_player_class_global(self):
        self.assertEqual(0x1e6246a + 7 + struct.unpack('<i', CLASS_LOAD[3:])[0], self.constants['class_rva'])
        self.assertEqual(0x1e6249b + 7 + struct.unpack('<i', CLASS_NAME[3:])[0], 0x2df641a)

if __name__ == '__main__':
    unittest.main()
