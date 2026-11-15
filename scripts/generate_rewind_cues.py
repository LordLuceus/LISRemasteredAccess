"""Generate only LISAccess's two original MIT-authored rewind cues.

Same sample rate, envelopes, frequencies and truncation as
LISAccess/src/output/rewind_audio.h. Never regenerates/replaces other cues.
"""
from pathlib import Path
import argparse,math,struct,wave
RATE=24000
def pcm(crossed):
    samples=2880 if crossed else 1632
    out=bytearray()
    for i in range(samples):
        value=0
        if crossed:
            t=i/RATE
            value=math.sin(math.pi*i/(samples-1))*math.sin(2*math.pi*(1000*t-2500*t*t))
        else:
            local=i if i<432 else i-1200 if i>=1200 else 432
            if local<432:value=math.sin(math.pi*local/431)*math.sin(2*math.pi*1600*local/RATE)
        out+=struct.pack('<h',int(value*12000))
    return bytes(out)
def generate(directory):
    directory.mkdir(parents=True,exist_ok=True)
    for name,crossed in [('rewind_approach',False),('rewind_crossed',True)]:
        with wave.open(str(directory/(name+'.wav')),'wb')as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(pcm(crossed))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'assets/audio')
    generate(p.parse_args().output)
