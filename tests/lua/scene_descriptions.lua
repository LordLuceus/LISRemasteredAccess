package.path='src/?.lua;'..package.path
local Data=require('cutscenes.classroom')
local Policy=require('cutscenes.scene_policy')
local Runtime=require('cutscenes.scene')
local count=0
local function check(v,label)count=count+1;assert(v,label)end
local function frame(t,id,allowed)
    id=id or'intro'
    return {world='classroom-world',allowed=allowed~=false,stages={[id]={key=id..'-actor',time=t,reverse=false,rate=1}}}
end
do
    local replay=Policy.new(Data)
    check(not replay:update(frame(11.21,'returning')),'return visit protects Max')
    check(replay:update(frame(16.65,'returning'))=='scene_classroom_return','return cue in measured gap')
    local _,stop=replay:update(frame(19.11,'returning'))
    check(stop,'stop return cue before Max speaks again')
end
local p=Policy.new(Data)
for _,t in ipairs({0,.5,2.1,4.4})do local s,stop=p:update(frame(t));check(not s and stop,'protect first Max lines')end
check(p:update(frame(4.5))=='scene_classroom_room','room after Max')
check(not p:update(frame(4.6)),'room once')
local _,stop=p:update(frame(9.61));check(stop,'stop slow room speech BEFORE reassurance')
p:request();check(not p:update(frame(10.2)),'requested repeat waits for Max')
check(p:update(frame(15.91))=='scene_classroom_room','repeat becomes available after Max')
check(p:update(frame(15.96))=='scene_classroom_pen','late pen describes actual retrieval')
check(p:update(frame(18.51))=='scene_classroom_paper','paper at visible wind-up, not animation start')
local key,halt=p:update(frame(.15,'ending'));check(not key and not halt,'authored handover preserves unfinished paper speech')
_,halt=p:update(frame(4.71,'ending'));check(halt,'stop slow paper speech before next Max thought')
p:request();check(not p:update(frame(6,'ending')),'repeat never speaks over continuation thought')
_,halt=p:update({world='classroom-world',allowed=true,stages={}})
check(halt and not p.active and not p.requested,'end clears pending repeat')
p:update(frame(0));check(p:update(frame(4.5))=='scene_classroom_room','real restart re-arms')
for _,reason in ipairs({'focus','pause','menu','choices'})do
    p=Policy.new(Data);p:update(frame(4.4));p:update(frame(4.51,nil,false))
    check(not p:update(frame(4.8)),reason..' resume does not replay missed cue')
    check(p:update(frame(15.96))=='scene_classroom_pen',reason..' does not disable future cues')
end
p=Policy.new(Data);p:update(frame(18.51));p:update(nil)
check(not p:update(frame(18.8)),'temporary sampling failure does not duplicate paper')
p=Policy.new(Data);p:update(frame(4.5));p:update({world='classroom-world',allowed=false,stages={}})
check(not p:update(frame(4.8)),'empty snapshot does not invent a new playback generation')
p=Policy.new(Data);local f=frame(18.6);f.stages.intro.reverse=true
check(not p:update(f),'reverse never narrates');f.stages.intro.reverse=false
check(not p:update(f),'reverse return has no backlog')
for _,bad in ipairs({0,2,math.huge})do
    p=Policy.new(Data);f=frame(18.6);f.stages.intro.rate=bad
    check(not p:update(f),'changed/invalid speed cannot use normal voice bounds')
end
p=Policy.new(Data);f=frame(18.6);f.stages.intro.time=0/0
check(not p:update(f),'invalid position fails silent rather than guessing')
p=Policy.new(Data);p:update(frame(4.5));f=frame(18.6);f.stages.ending=frame(5,'ending').stages.ending
check(not p:update(f),'protect Max on every concurrent supported segment')
-- Dense forward playback and deliberately slow speech: protection stops owned
-- output even though no TTS completion callback is available.
p=Policy.new(Data);local speaking=false;local seen={}
for _,id in ipairs(Data.order)do
    local def=Data.stages[id]
    for step=0,math.floor(def.length*20)do
        local t=step/20;local cue,cancel=p:update(frame(t,id))
        if cancel then speaking=false end
        if cue then speaking=true;seen[#seen+1]=cue end
        for _,span in ipairs(def.protect)do
            if t>=span[1]and t<span[2]then check(not speaking,'no long-reader overlap inside Max protection')end
        end
    end
end
check(table.concat(seen,',')=='scene_classroom_room,scene_classroom_pen,scene_classroom_paper,scene_classroom_return','first visit and return emit four ordered descriptions')
-- Exercise native producer prerequisites, not only ideal policy snapshots.
local function obj(t)t=t or{};t.IsValid=function()return true end;return t end
local world=obj({GetAddress=function()return 42 end,GetFName=function()return{ToString=function()return'E1_2A'end}end})
local lang='en';local paused=false
local c=obj({GetWorld=function()return world end,GetCurrentLanguage=function()return lang end})
local a=obj({GetWorld=function()return world end,GetAddress=function()return 7 end,
    GetFName=function()return{ToString=function()return Data.stages.intro.actor end}end,
    bIsPlaying=true,InterpPosition=18.6,bReversePlayback=false,PlayRate=1})
local api={all=function(name)check(name=='MatineeActor','only actor-level enumeration');return{a}end,
    find=function(path)check(path=='/Script/Engine.Default__GameplayStatics','known pause getter');return obj({IsGamePaused=function()return paused end})end}
f=assert(Runtime.sample(c,api));check(f.stages.intro.time==18.6 and f.allowed,'live-style scalar producer')
for _,v in pairs(f.stages.intro)do check(type(v)~='table'and type(v)~='userdata','no native wrapper retained')end
lang='fr';check(not Runtime.sample(c,api),'actual game language, not fallback catalog');lang='en'
paused=true;check(not Runtime.sample(c,api).allowed,'native paused flag');paused=nil
local missing,why=Runtime.sample(c,api);check(not missing and why,'unknown pause state is not permission');paused=false
api.all=function()return{a,a}end;missing,why=Runtime.sample(c,api);check(not missing and why,'duplicate active identity rejected')
api.all=function()return{a}end;a.GetWorld=function()return obj({GetAddress=function()return 99 end})end
check(not next(Runtime.sample(c,api).stages),'old-world actors excluded')
a.GetWorld=function()return world end
-- Actual runtime, owned cancellation, contextual requests and stale repeats.
local current=frame(4.5);local events={};local focused,allowed=true,true
local r=Runtime.new({sample=function()return current end,focused=function()return focused end,
    allowed=function()return allowed end,text=function(k)return k end,log=function()end,
    say=function(t,interrupt,owner)events[#events+1]={'say',t,owner};check(interrupt,'new cues replace stale narration')end,
    stop=function(owner)events[#events+1]={'stop',owner}end})
r:tick();check(events[#events][2]=='scene_classroom_room','runtime narrates')
current=frame(10.2);r:tick();check(events[#events][1]=='stop','runtime protects next thought')
local n=#events;check(r:reread(),'reread is handled during Max');check(events[#events][1]=='stop','no competing acknowledgement')
current=frame(15.91);r:tick();check(events[#events][2]=='scene_classroom_room','queued request delivered after thought')
r:help(false);check(events[#events][2]=='scene_help_keys','contextual keyboard help')
r:repeat_owned(r.owner);check(events[#events][2]=='scene_help_keys','literal repeat retains help, not previous description')
current=frame(18.6);r:tick();current=frame(16);r:reread()
check(events[#events][1]=='stop','input cannot bypass backward-clock suspension through a second policy update')
current=frame(16.1);n=#events;r:tick();check(#events==n,'a request during rewind does not replay a future visual on resume')
current=frame(18.6);r:tick();current=frame(4.8,'ending')
r:repeat_owned(r.owner);check(events[#events][1]=='stop','literal repeat cannot bypass Max guard')
current=nil;r:tick();n=#events;r:repeat_owned(r.owner)
for i=n+1,#events do check(events[i][1]~='say','expired scene cannot replay over unrelated Max speech')end
check(not r:repeat_owned({}),'unrelated speech ownership unchanged')
-- Execute the actual registered game-thread callback, including its catch path.
local file=assert(io.open('src/main.lua','rb'));local main=file:read('*a');file:close()
local start=assert(main:find('local beat=0',1,true));local finish=assert(main:find('-- Development test session',start,true))
local callback,ticks,cancels,errors=nil,0,0,{}
local function noop()end
local fake={tick=function()ticks=ticks+1 end,cancel=function()cancels=cancels+1 end}
local env=setmetatable({LoopInGameThreadWithDelay=function(_,fn)callback=fn end,
    padlock={install=noop,check_presence=noop,due=noop},run_keys=noop,picture={poll=noop},run_delayed=noop,
    rewind={tick=noop,cancel=noop},cutscenes={tick=noop,cancel=noop},scene_descriptions=fake,
    pad_step=noop,lighthouse_fast_step=noop,polarewind={tick=noop},menu_step=noop,main_step=noop,
    face={tick=noop},log=function(e)errors[#errors+1]=e end},{__index=_G})
assert(load(main:sub(start,finish-1),'registered classroom callback','t',env))()
for _=1,20 do callback()end
check(ticks==20 and #errors==0,'classroom reader runs in registered 50ms loop')
fake.tick=function()error('injected classroom error')end;callback()
check(cancels==1 and #errors==1,'registered failure cancels narration')
print('Classroom descriptions: '..count..' checks passed')
return count
