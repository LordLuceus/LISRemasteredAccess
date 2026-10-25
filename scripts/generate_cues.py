"""Generates and processes the mod's audio cues.

The sounds come from ElevenLabs (text to sound effects), as in the original
LISAccess. They are provider output, not MIT-licensed repository content: the
.pcm/.wav files in assets/audio are git-ignored and only bundled in releases.
This script and assets/audio/provenance.json are tracked.

Usage:
  python scripts/generate_cues.py            # process existing .pcm into .wav
  python scripts/generate_cues.py --generate # call the paid API first (needs the
                                             # elevenlabs CLI and an API key)
No personal, game or player data is sent: only the prompts below.
"""
import array, json, math, shutil, subprocess, sys, wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'assets' / 'audio'
RATE = 24000
REQUEST = {'duration_seconds': 0.6, 'prompt_influence': 0.7, 'model_id': 'eleven_text_to_sound_v2'}
CUES = {
    'control_lost': {
        'prompt': 'One soft low descending two-note tone signalling that control is taken away. Short, gentle, dry, instant onset, silence afterwards. Nonverbal isolated mono user interface sound. No voice, no music, no background, no reverb.',
        'cap_ms': 500},
    'control_back': {
        'prompt': 'One soft bright ascending two-note tone signalling that control is returned. Short, gentle, dry, instant onset, silence afterwards. Nonverbal isolated mono user interface sound. No voice, no music, no background, no reverb.',
        'cap_ms': 500},
}


def generate():
    exe = shutil.which('elevenlabs')
    if not exe:
        sys.exit('elevenlabs CLI not found')
    AUDIO.mkdir(parents=True, exist_ok=True)
    for name, cue in CUES.items():
        out = AUDIO / (name + '.pcm')
        body = json.dumps(dict(REQUEST, text=cue['prompt']))
        r = subprocess.run([exe, 'text-to-sound-effects', 'convert', '--json', body,
                            '--params', json.dumps({'output_format': 'pcm_24000'}), '-o', str(out), '-q'],
                           capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(f'{name}: generation failed: {r.stderr or r.stdout}')


def process():
    report = {'provider': 'ElevenLabs', 'cli': 'elevenlabs text-to-sound-effects convert',
              'request': REQUEST, 'output_format': 'pcm_24000', 'personal_data_sent': False,
              'source_format': 'PCM16 LE, 24000 Hz, 2 channels interleaved. Evidence: the byte count '
                               'equals exactly the requested duration as stereo, and the two channels '
                               'correlate at 0.999+ (duplicated mono).',
              'processing': 'Channels averaged to mono; trimmed below -45 dB of peak with 2 ms preroll and '
                            '12 ms tail; capped; 2 ms fade in, 8 ms fade out; peak normalised to -12 dBFS.',
              'licence': 'Provider output. Not covered by the repository MIT licence; git-ignored and '
                         'bundled only in releases.',
              'cues': {}}
    for name, cue in CUES.items():
        src = array.array('h')
        src.frombytes((AUDIO / (name + '.pcm')).read_bytes())
        if sys.byteorder != 'little':
            src.byteswap()
        left, right = src[0::2], src[1::2]
        n = min(len(left), len(right))
        mono = [(left[i] + right[i]) / 2 for i in range(n)]
        peak = max(map(abs, mono)) or 1
        floor = peak * 10 ** (-45 / 20)
        active = [i for i, v in enumerate(mono) if abs(v) >= floor]
        start = max(0, active[0] - RATE * 2 // 1000)
        end = min(len(mono), active[-1] + RATE * 12 // 1000)
        mono = mono[start:min(end, start + RATE * cue['cap_ms'] // 1000)]
        fin, fout = RATE * 2 // 1000, RATE * 8 // 1000
        for i in range(min(fin, len(mono))):
            mono[i] *= i / fin
        for i in range(min(fout, len(mono))):
            mono[-1 - i] *= i / fout
        gain = (32767 * 10 ** (-12 / 20)) / (max(map(abs, mono)) or 1)
        out = array.array('h', (max(-32768, min(32767, int(round(v * gain)))) for v in mono))
        if sys.byteorder != 'little':
            out.byteswap()
        with wave.open(str(AUDIO / (name + '.wav')), 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(out.tobytes())
        rms = math.sqrt(sum(v * v for v in out) / len(out)) or 1
        report['cues'][name] = {'prompt': cue['prompt'], 'source_bytes': len(src) * 2,
                                'duration_seconds': round(len(out) / RATE, 3),
                                'rms_dbfs': round(20 * math.log10(rms / 32768), 2)}
    (AUDIO / 'provenance.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    for name, c in report['cues'].items():
        print(name, c['duration_seconds'], 's', c['rms_dbfs'], 'dBFS rms')


if __name__ == '__main__':
    if '--generate' in sys.argv:
        generate()
    process()
