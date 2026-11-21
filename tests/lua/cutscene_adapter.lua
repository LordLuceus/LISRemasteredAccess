package.path='src/?.lua;'..package.path
local Native=require('cutscenes.native')
local Runtime=require('cutscenes.runtime')
local count=0
local function check(ok,why)count=count+1;assert(ok,why)end
local function object(t)t=t or {};t.IsValid=function()return true end;return t end
local time,shown,playing=1,true,true
local player=object({GetUrl=function()return './Movies/Episode01/BIK_E1_7A_Snowing.mp4'end,
    IsPlaying=function()return playing end,IsPaused=function()return not playing end,
    GetTime=function()error('opaque Timespan must never cross the Lua bridge')end,GetAddress=function()return 123 end,
    GetClass=function()return {GetAddress=function()return 789 end,GetFName=function()return {ToString=function()return 'MediaPlayer'end}end}end})
local widget=object({IsInViewport=function()return shown end,IsVisible=function()return true end,
    GetRenderOpacity=function()return 1 end,GetAddress=function()return 456 end})
local api={all=function(name)assert(name=='D9MoviePlayerWidget_C');return {widget}end,
    clock=function(p,c)assert(p==123 and c==789,'pass fresh exact identities');return time end,
    find=function(name)
        if name=='/Game/Movies/D9MediaPlayer.D9MediaPlayer' then return player end
        error('unexpected object lookup')
    end}
local f,why=Native.sample(api)
check(f and f.time==1 and f.playing,why or 'native clock copied')
local get_url=player.GetUrl
player.GetUrl=function()return {ToString=function()return get_url()end}end
check(Native.sample(api).url==get_url(),'native FString return copied to a Lua string')
player.GetUrl=get_url
check(Native.parse('LISRMT1|status=ok|seconds=1.25')==1.25,'native scalar packet')
check(Native.parse('LISRMT1|status=ok|seconds=0')==0,'real zero time is valid')
for _,bad in ipairs({'','LISRMT1|status=object','LISRMT1|status=ok|seconds=nan','LISRMT1|status=ok|seconds=-1','LISRMT1|status=ok|seconds=1|extra=2'})do
    check(not Native.parse(bad),'failed or malformed clock never fabricated')
end
for _,v in pairs(f)do check(type(v)~='table' and type(v)~='userdata','only scalar frame survives')end
shown=false;check(not Native.sample(api),'no hidden-player narration');shown=true
playing=false;f=Native.sample(api);check(f and not f.playing and f.active,'paused clock is not an active cue');playing=true
time=0/0;check(not Native.sample(api),'invalid native time rejected');time=1
local original=api.all;api.all=function()return {widget,widget}end
check(not Native.sample(api),'ambiguous visible instance rejected');api.all=original
local events={};local focused,allowed=true,true
local track={key='en/movie',id='episode01/movie.mp4',cues={{start=1,finish=2,text='First.'},{start=4,finish=5,text='Second.'}}}
local runtime=Runtime.new({tracks={load=function()return track end},sample=function()return Native.sample(api)end,
    language=function()return 'en'end,focused=function()return focused end,allowed=function()return allowed end,
    stop=function(owner)events[#events+1]={'stop',owner}end,
    say=function(text,interrupt,owner)events[#events+1]={'say',text,interrupt,owner}end,log=function()end,text=function(k)return k end})
runtime:tick();check(events[#events][2]=='First.' and events[#events][3]==true,'first cue establishes narration')
local owner=events[#events][4]
time=1.1;local n=#events;runtime:tick();check(#events==n,'not repeated every tick')
time=4;runtime:tick();check(events[#events][2]=='Second.' and events[#events][3]==false,'later cue queues')
check(runtime:reread() and events[#events][3]==true,'deliberate reread')
focused=false;runtime:tick();check(events[#events][1]=='stop' and events[#events][2]==owner,'focus loss cancels only narrator owner')
check(not runtime:reread(),'no reread behind another app')
focused=true;allowed=false;check(not runtime:reread(),'reread rechecks a newly opened menu');allowed=true
focused=true;time=4.5;runtime:tick();check(events[#events][1]=='stop','no backlog on return')
shown=false;runtime:tick();check(events[#events][1]=='stop','end/close clears description')
shown=true;time=0;runtime:tick()
check(runtime:reread() and events[#events][2]=='cutscene_not_yet','entry before first cue does not repeat stale world speech')
track.dialogue={{2.5,3.5}}
time=1;runtime:tick()
time=2.51;runtime:tick()
check(events[#events][1]=='stop' and events[#events][2]==owner,'dialogue stops a slow movie readout')
n=#events
check(runtime:reread() and #events==n,'manual reread waits through protected dialogue')
time=3.55;runtime:tick()
check(events[#events][2]=='First.' and events[#events][4]==owner,'reread resumes in the next gap')
local main=assert(io.open('src/main.lua','rb')):read('*a')
local start=assert(main:find('local beat=0',1,true))
local finish=assert(main:find('-- Development test session',start,true))
local callback,ticks,cancelled,errors=nil,0,0,{}
local function noop()end
local fake={tick=function()ticks=ticks+1 end,cancel=function()cancelled=cancelled+1 end}
local env=setmetatable({LoopInGameThreadWithDelay=function(_,fn)callback=fn end,
    padlock={install=noop,check_presence=noop,due=noop},run_keys=noop,picture={poll=noop},run_delayed=noop,
    rewind={tick=noop,cancel=noop},cutscenes=fake,scene_descriptions={tick=noop,cancel=noop},pad_step=noop,lighthouse_fast_step=noop,
    polarewind={tick=noop},menu_step=noop,main_step=noop,face={tick=noop},log=function(e)errors[#errors+1]=e end},{__index=_G})
assert(load(main:sub(start,finish-1),'registered cutscene callback','t',env))()
for _=1,20 do callback()end
check(ticks==20 and #errors==0,'registered callback reaches real movie polling slot')
fake.tick=function()error('injected movie failure')end;callback()
check(cancelled==1 and #errors==1 and errors[1]:find('cutscene_error=',1,true),'registered failure path cancels owned narration')
print('Cutscene native/runtime adapter: '..count..' checks passed')
return count
