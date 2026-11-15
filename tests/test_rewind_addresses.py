"""Independently decode pinned native instruction bytes, not fake-memory constants.

Captured from SHA256 c141ab07aa9b7f77adde733fc0481042fe3e63724639701322e659d611519cf2.
The first reader and its fixture shared three wrong class RVAs. These instruction
fixtures detect that transcription error without needing game files in CI.
This checks global addresses, not runtime visibility, ownership or cue acceptance.
"""
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]
# (instruction RVA, exact bytes): target = end of instruction + signed disp32.
INSTRUCTIONS = {
    'manager_class': (0x79C9CA, '488b05cf3bdb02'),
    'marker_class': (0x79D41A, '488b051f32db02'),
    'widget_class': (0x79DF7A, '488b059727db02'),
    'manager_weak': (0x6E1E16, '488d0db3dfcf02'),
    'widget_manager_weak': (0x725EF0, '488d0d11c8be02'),
    'object_count': (0xA658CF, '3b0547e0b302'),
    'object_chunks': (0xA658F0, '488b0511e0b302'),
}

def mismatches(source):
    constants = {name: int(value, 16) for name, value in
                 re.findall(r'constexpr uintptr_t (\w+) = (0x[0-9a-f]+);', source)}
    failures = []
    for name, (rva, encoded) in INSTRUCTIONS.items():
        instruction = bytes.fromhex(encoded)
        actual = rva + len(instruction) + struct.unpack('<i', instruction[-4:])[0]
        if constants.get(name) != actual:
            failures.append(name)
    return failures

class RewindAddresses(unittest.TestCase):
    def test_all_global_addresses_match_native_instructions(self):
        source = (ROOT/'native/src/rewind_snapshot.h').read_text(encoding='utf-8')
        self.assertEqual(mismatches(source), [])

    def test_original_transcription_failure_is_rejected(self):
        source = (ROOT/'native/src/rewind_snapshot.h').read_text(encoding='utf-8')
        broken = source.replace('0x35505a0', '0x33505a0').replace('0x3550640', '0x3350640').replace('0x3550718', '0x3350718')
        self.assertEqual(mismatches(broken), ['manager_class', 'marker_class', 'widget_class'])

    def test_missing_global_cannot_silently_skip_the_check(self):
        self.assertEqual(set(mismatches('')), set(INSTRUCTIONS))

if __name__ == '__main__':
    unittest.main()
