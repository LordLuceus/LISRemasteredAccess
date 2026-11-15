-- Original rewind-marker cases, plus independent control-cue suppression.
package.path='src/?.lua;'..package.path
local P=require('rewind.policy')
local count=0
local function check(v,label)count=count+1;assert(v,label)end
local function at(state,reference,marker)
    return {context=true,valid=true,visible=true,marker_known=true,marker_present=true,
        manager=1,world=2,controller=3,state=state,reference=reference,range=100,marker=marker or 60}
end
local t=P.new()
check(t:update(at(2,100),0)==nil and not t.running,'Scripted paused state does not start rewind')
t:update(at(0,100),.05)
check(t:update(at(1,90),.1)==nil,'Far from mark is silent')
check(t:update(at(1,64),.15)=='approach','Original five-percent approach band')
check(t:update(at(1,63),.2)==nil,'Approach one-shot')
check(t:update(at(1,59,30),.25)=='crossed','Native mark moving earlier cannot evade anchored crossing')
check(t:update(at(1,58,30),.3)==nil,'Crossing one-shot')
check(t:update(at(0,58.1,30),.35)==nil and not t.running,'Release does not repeat the crossed cue')
t:reset();t:update(at(0,100),0)
check(t:update(at(4,50,30),.05)=='crossed','Recent idle sample catches a fast jump')
check(t:update(at(2,50,30),.1)==nil and not t.running,'Paused completion ends a started rewind')
t:reset();t:update(at(1,70),0)
check(t:update(at(0,59,30),.05)=='crossed','Crossing on release is preserved')
t:reset();t:update(at(1,70),0)
check(t:update(at(1,60),.05)=='crossed','Exact marker boundary crosses')
for _,field in ipairs({'marker_known','marker_present'})do
    t:reset();local f=at(1,64);f[field]=false
    check(t:update(f,0)==nil,'Missing/unreadable marker is not invented: '..field)
end
for _,value in ipairs({-1,101,math.huge,0/0})do
    t:reset();local f=at(1,64);f.marker=value
    check(t:update(f,0)==nil,'Invalid marker rejected')
end
for _,field in ipairs({'reference','range'})do
    for _,value in ipairs({-1,math.huge,0/0})do
        t:reset();local f=at(1,64);f[field]=value
        check(t:update(f,0)==nil and not t.running,'Invalid gauge rejects cue: '..field)
    end
end
t:reset();local f=at(1,64);f.range=0
check(t:update(f,0)==nil and not t.running,'Zero denominator rejected')
t:reset();f=at(1,64);f.visible=false
check(t:update(f,0)==nil and not t.running,'Hidden gauge silent')
t:reset();t:update(at(1,80),0);t:update({context=false},.05)
check(not t.running,'Context loss cancels silently')
for _,id in ipairs({'world','manager','controller'})do
    t:reset();t:update(at(1,80),0);f=at(0,50);f[id]=9
    check(t:update(f,.05)==nil and not t.running,'Identity change cannot invent old crossing: '..id)
end
t:reset();t:update(at(1,80),0)
check(t:update(at(0,50),1)==nil,'Stale sampling cancels instead of inventing a crossing')
t:reset();t:update(at(1,80),1)
check(t:update(at(0,50),0)==nil,'Clock reversal cancels')
t:reset();t:update(at(1,80),0)
check(t:update(at(3,85),.05)==nil and t.running,'Fast-forward defers completion')
check(t:update(at(0,90),.1)==nil and not t.running,'Fast-forward restores position without false crossing')
-- A moving range must use the actual timestamp, not a frozen normalized ratio.
t:reset();t:update(at(0,100),0);f=at(1,70);f.range=120;t:update(f,.05)
f=at(1,59,30);f.range=120
check(t:update(f,.1)=='crossed','Absolute starting marker survives native range changes')

local C=require('core.control')
local c=C.new();c:update('control',0);c:update('control',.5)
c:suppress_cues(true);c:update('none',1)
check(c:update('none',1.5)==nil and not c:has_control(),'Muted rewind still tracks actual control loss')
c:suppress_cues(false);c:update('none',2)
c:update('control',2.2)
check(c:update('control',2.7)==nil and c:has_control(),'Stable recovery suppresses the rewind return echo')
c:update('none',4)
check(c:update('none',4.5)=='lost','Subsequent genuine control loss still cues')
c:update('control',5)
check(c:update('control',5.5)=='back','Subsequent genuine return still cues')
-- Rewind begins/ends between the slow control polls.
c:suppress_cues(true);c:suppress_cues(false);c:update('none',6)
check(c:update('none',6.5)==nil and not c:has_control(),'Short rewind latches quiet resynchronization')
c:update('control',8)
check(c:update('control',8.5)=='back','A later cutscene return is not suppressed indefinitely')
c:suppress_cues(true);c:suppress_cues(false);c:update('unknown',9);c:update('none',10)
check(c:update('none',10.5)==nil,'Unknown/menu gap cannot replay stale feedback')
c:reset(11);check(not c.suppressed and not c.resync,'World reset clears rewind suppression')
local Preview=require('core.preview');local seen={}
for _,cue in ipairs(Preview.cues)do seen[cue.file]=cue.key end
check(seen['rewind_approach.wav']=='cue_rewind_approach' and seen['rewind_crossed.wav']=='cue_rewind_crossed','Both restored cues included in existing preview')
local F=require('rewind.feedback');local played,fallback,muted={},{},false
local feedback=F.new({play=function(file)played[#played+1]=file;return true end,
    suppress=function(on)muted=on end,fallback=function(key)fallback[#fallback+1]=key end})
feedback:update(at(0,100),true,0)
check(feedback:update(at(1,64),true,.05)=='approach' and muted and played[1]=='rewind_approach.wav','Actual rewind suppresses control cues and plays original approach')
feedback:update(at(3,65),true,.1);check(muted,'Return through native fast-forward remains part of rewind suppression')
feedback:update(at(0,65),true,.15);check(not muted,'Stable native stop ends suppression request')
feedback:update(at(1,64),false,.2);check(muted and #played==1,'Unfocused/menu-blocked audio stays silent without unmuting rewind control cues')
feedback:update(nil,false,.25);check(not muted,'Missing native context releases mute without stale playback')
feedback.output.play=function()return false end
feedback:update(at(0,100),true,.3);feedback:update(at(4,50,30),true,.35)
check(fallback[1]=='cue_rewind_crossed','Playback failure falls back to the corresponding short spoken warning')
feedback:update(at(2,50),true,.4);check(not muted,'Paused native completion releases mute')
local independent=F.new({suppress=function(on)muted=on end})
independent:update(at(3,50),true,0);check(not muted,'Unrelated native fast-forward does not start a rewind session')
-- Exercise the optional native foreground wrapper without loading a DLL or
-- querying the desktop. Missing/failed native API must not mean focused.
local previous_loadlib,previous_speech=package.loadlib,package.loaded['core.speech']
local native_result=true
package.loadlib=function(_,name)
    if name=='lisr_focused' then return function()if native_result=='error'then error('fixture')end;return native_result end end
    return function()return true end
end
package.loaded['core.speech']=nil
local speech=require('core.speech')
check(speech.focused()==true,'Native foreground true propagated')
native_result=false;check(speech.focused()==false,'Background window rejected')
native_result='error';check(speech.focused()==false,'Foreground read failure fails closed')
package.loadlib=function(_,name)if name=='lisr_focused'then return nil end;return function()return true end end
package.loaded['core.speech']=nil
check(require('core.speech').focused==nil,'Old DLL does not pretend it can identify focus')
package.loadlib,package.loaded['core.speech']=previous_loadlib,previous_speech
print('Rewind feedback: '..count..' checks passed')
return count
