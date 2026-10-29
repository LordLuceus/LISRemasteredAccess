"""Read a game crash minidump: exception, faulting module offset, the crashing
thread's return addresses (UE4SS frames byte-matched into the 1183 dev build in
artifacts/ue4ss-1183-dev, whose PDB names them), and Lua error strings left in
memory. Usage: python scripts/symbolize_crash.py <UE4Minidump.dmp>
Requires: pip install minidump."""
import re
import struct
from minidump.minidumpfile import MinidumpFile
import sys,logging
logging.disable(logging.CRITICAL)
md=MinidumpFile.parse(sys.argv[1]); r=md.get_reader()
mods=[(m.baseaddress,m.size,m.name.split('\\')[-1]) for m in md.modules.modules]
def modof(a):
    for b,s,n in mods:
        if b<=a<b+s: return b,n
    return None,None
exc=md.exception.exception_records[0]
th=[t for t in md.threads.threads if t.ThreadId==exc.ThreadId][0]
stk=th.Stack;base=stk.StartOfMemoryRange;size=stk.MemoryLocation.DataSize
seg=[s for s in md.memory_segments_64.memory_segments if s.start_virtual_address<=base<s.start_virtual_address+s.size] if md.memory_segments_64 else []
data=None
for s in (md.memory_segments.memory_segments if md.memory_segments else []):
    if s.start_virtual_address==base: data=s.read(base,size,open(sys.argv[1],'rb'));break
if data is None:
    f=open(sys.argv[1],'rb');f.seek(stk.MemoryLocation.Rva);data=f.read(size)
er=exc.ExceptionRecord
fb,fn=modof(er.ExceptionAddress)
print('exception',er.ExceptionCode,'in',fn,'+%x'%(er.ExceptionAddress-fb) if fb else '')
print('stack bytes',len(data))
ue=open('artifacts/ue4ss-1183-dev/UE4SS.dll','rb').read()
dump=open(sys.argv[1],'rb').read()
segs=(md.memory_segments.memory_segments if md.memory_segments else [])
def readmem(a,n):
    for s in segs:
        if s.start_virtual_address<=a and a+n<=s.start_virtual_address+s.size:
            return dump[s.start_file_address+(a-s.start_virtual_address):][:n]
    return None
rows=[];seen=set()
for off in range(0,len(data)-8,8):
    v=struct.unpack_from('<Q',data,off)[0];b,n=modof(v)
    if not b or n.lower() not in ('ue4ss.dll','lis-win64-shipping.exe'):continue
    k=(n,v-b)
    if k in seen:continue
    seen.add(k);tag=''
    if n.lower()=='ue4ss.dll':
        pat=readmem(v-24,24);i=ue.find(pat) if pat else -1
        tag=('dev+%x'%(i+24)) if i>=0 else ('nomatch' if pat else 'noimage')
    rows.append((n,v-b,tag))
for row in rows[:90]:print('%-22s +%-8x %s'%row)
# strings near: dialogue/choice field names in the dump around the faulting time
for w in [b'DialogButtons_Array',b'DialogText',b'TextBlock_Choice',b'IsFriendFacts',b'Switcher',b'ConsequencesText',b'NewFactIcon',b'ActorInteractionFocused']:
    print(w.decode(),dump.count(w))

for m in re.finditer(rb'[A-Za-z_]+[/\\][A-Za-z_]+\.?l?u?a?[^\x00]{0,4}lua:\d+: [^\x00]{0,60}|[a-z_]+\\?\S{0,8}lua:\d+: [^\x00]{0,60}',dump):
    print('lua_error',re.sub(rb'[^\x20-\x7e]',b'.',m.group()).decode())
