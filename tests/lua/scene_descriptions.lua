package.path='src/?.lua;'..package.path
local Data=require('cutscenes.episode1').groups.classroom
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
do
    local loop=Policy.new({order={'intro'},stages={intro={loop=true,length=5,protect={},
        cues={{start=1,finish=2,key='quiet-room'}}}}})
    check(loop:update(frame(1))=='quiet-room','idle sequence speaks on entry')
    for cycle=1,2 do
        loop:update(frame(4.9))
        loop:update(frame(.1))
        check(not loop:update(frame(1.1)),'idle sequence stays quiet on wrap')
    end
    local nextVisit=frame(1.1)
    nextVisit.stages.intro.key='new-actor'
    check(loop:update(nextVisit)=='quiet-room','new actor re-arms idle description')
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
-- The remaster returns the streamed package world for a playing scene actor.
-- A visible level in the controller's world must own that exact instance.
do
    local visible=true
    local package_level=obj({GetAddress=function()return 57 end})
    local stream=obj({LoadedLevel=package_level,IsLevelVisible=function()return visible end})
    local streamed=obj({GetAddress=function()return 100 end,
        GetFName=function()return {ToString=function()return 'E1_2A_ArtClass_LD' end} end,
        PersistentLevel=package_level})
    world.StreamingLevels={ForEach=function(_,visit)visit(1,{get=function()return stream end})end}
    a.GetWorld=function()return streamed end
    check(Runtime.sample(c,api).stages.intro~=nil,'streamed classroom belongs to controller world')
    visible=false
    check(not next(Runtime.sample(c,api).stages),'hidden sublevel excluded')
    visible=true;stream.LoadedLevel=obj({GetAddress=function()return 81 end})
    check(not next(Runtime.sample(c,api).stages),'same package from earlier load excluded')
    a.GetWorld=function()return world end
end
-- In normal gameplay these starts can coincide with earlier free-roam
-- thoughts. The tree's later shot and the door's scanner readout carry them.
do
    local tracks=require('cutscenes.episode1').timelines
    check(not tracks.E1_3A_CampusA_LD_Tree_ZenStart and tracks.E1_3A_CampusA_LD_Tree_ZenLoop,
        'Warren reminder stays clear when Max sits at the tree')
    check(not tracks.E1_5B_LivingRoom_LD_BayWindow_Interact01 and
        require('descriptions.episode1_rooms').objects.E1_5B_LivingRoom_LD.LiSInteractionActor_BayWindow_87,
        'yard description available without interrupting living-room thought')
end
-- Named story beats survive catalogue edits. Iterating the remaining tracks
-- alone would still pass if an entire chapter or a choice outcome disappeared.
do
    local tracks=require('cutscenes.episode1').timelines
    local beats={
        E1_1A_CliffFuture={'IntroStorm','LighthouseBreak'},
        E1_2A_ArtClass={'BellRing','MaxAnswers'},
        E1_2A_Toilets={'Butterfly_Photo','NathanAndChloe','FireAlarm_Interact01'},
        E1_2A_Corridor={'DenounceNathan','ProtectNathan'},
        E1_3A_CampusA={'Insertion_CampusAReveal','CHTrevor_Fail','CHTrevor_SuccessMax'},
        E1_3B_CampusB={'VictoriaDeniesAccess','VIctoria_Comfort','VIctoria_TakePhoto',
            'AlyssaHurt','AlyssaMoveSit02','KateDavid_TakePhoto','KateDavid_Intervene'},
        E1_3C_Corridor={'JulietLocksDoor','JulietUnlocksDana'},
        E1_3C_DanaRoom={'USBKey_Take'},
        E1_3D_CampusPark={'IntroDialWarren_RTC','NathanArrives_Part02'},
        E1_4A_ChloeCar={'FirstReunion','BrokenCamera'},
        E1_5A_ChloeRoom={'RepairFail','FriendAgain','DavidFurious_BlameChloe','DavidFurious_TakeBlame'},
        E1_6A_CliffNow={'Insertion_Reveal00','CHChloe_Photo'},
        E1_6B_CliffFuture={'Reveal01','Doe_JumpOverHole','Ending_Part01'},
    }
    for location,scenes in pairs(beats) do
        for _,scene in ipairs(scenes) do
            local name=location..'_LD_'..scene
            check(tracks[name] and #tracks[name].windows>0,'missing story beat '..name)
        end
    end
end
-- Sample every authored Episode 1 actor through the runtime entry point.
for actor,definition in pairs(require('cutscenes.episode1').timelines)do
    local level=actor:match('^(E1_%d%u)_')
    local location=obj({GetAddress=function()return 123 end,
        GetFName=function()return{ToString=function()return level end}end})
    local player=obj({GetWorld=function()return location end,GetCurrentLanguage=function()return 'en'end})
    local segment=obj({GetWorld=function()return location end,GetAddress=function()return 456 end,
        GetFName=function()return{ToString=function()return actor end}end,
        InterpPosition=0,bIsPlaying=true,PlayRate=1})
    local api={all=function()return{segment}end,find=function()return obj({IsGamePaused=function()return false end})end}
    local heard,stopped={},false
    local reader=Runtime.new({sample=function()return Runtime.sample(player,api)end,
        allowed=function()return true end,focused=function()return true end,
        text=function(k)return assert(require('lang.en')[k])end,
        say=function(line)heard[#heard+1]=line;stopped=false end,stop=function()stopped=true end})
    reader:tick()
    if definition.after_first_loop then
        segment.InterpPosition=definition.windows[1][1]+.05;reader:tick()
        reader:reread();check(#heard==0,'recorded dialogue owns the first loop')
        segment.InterpPosition=0;reader:tick()
        segment.InterpPosition=definition.windows[1][1]+.05;reader:tick()
        check(#heard==0,'early restart does not release voice protection')
        segment.InterpPosition=definition.length-.1;reader:tick()
        segment.InterpPosition=.05;reader:tick()
        segment.InterpPosition=.15;reader:tick()
    end
    for i,window in ipairs(definition.windows)do
        segment.InterpPosition=window[1]+.05;reader:tick()
        check(#heard==i and heard[i]==require('lang.en')[window[3]],'scheduled cue '..actor)
        reader:tick();check(#heard==i,'held clock '..actor)
        segment.InterpPosition=window[2]+.01;reader:tick()
        check(stopped,'end narration at window boundary '..actor)
    end
end
-- The principal talks through the available windows. Keep Max's English
-- voice events independent of cue edits (Matinee onset plus recording length).
local principal_lines={
    DenounceNathan={{.122,4.833},{8.259,6.716},{20.394,4.895},{44.036,6.636},{58.575,2.378}},
    ProtectNathan={{.108,3.596},{9.313,3.769},{15.524,4.880}},
}
for branch,lines in pairs(principal_lines)do
    local track=require('cutscenes.episode1').timelines['E1_2A_Corridor_LD_'..branch]
    for _,window in ipairs(track.windows)do
        for _,line in ipairs(lines)do
            check(window[2]<=line[1]-.55 or window[1]>=line[1]+line[2]+.5,
                branch..' cue preserves Max voice margins')
        end
    end
end
-- When Ctrl+Home samples a new branch first, the old branch's text expires.
do
    local function branch(key)
        return {order={'intro'},stages={intro={length=4,protect={},
            cues={{start=.2,finish=1,key=key}}}}}
    end
    local observed=frame(.4);observed.data=branch('first')
    local heard={}
    local reader=Runtime.new({sample=function()return observed end,
        focused=function()return true end,allowed=function()return true end,
        stop=function()end,text=function(key)return key end,say=function(line)heard[#heard+1]=line end})
    reader:tick()
    observed=frame(.4);observed.data=branch('second')
    reader:repeat_owned(reader.owner)
    check(table.concat(heard,',')=='first,second','literal repeat belongs to the new branch')
end
-- The explicit scanner readout adds the setting once and keeps the selection first.
do
    local sources=require('scanner.sources')
    local collect,room,find=sources.collect,sources.room,FindAllOf
    local position={X=0,Y=0,Z=0}
    local pawn=obj({K2_GetActorLocation=function()return position end})
    local player=obj({Pawn=pawn,GetControlRotation=function()return {Yaw=0}end})
    FindAllOf=function()return {player}end
    local scanner=dofile('src/scanner/scanner.lua')
    local heard,language='', 'en'
    scanner.say=function(text)heard=text end
    scanner.language=function()return language end
    local location='E1_5B_Garden_LD'
    sources.collect=function()
        sources.room=location
        return {{id='swing',label='Swing',pos=position}}
    end
    scanner.command('next')
    check(not heard:find('backyard',1,true),'cycling objects stays brief')
    scanner.command('describe')
    check(heard:find('Swing',1,true)==1 and heard:find('backyard',1,true),'explicit readout includes room')
    scanner.command('describe')
    check(not heard:find('backyard',1,true),'repeated readout keeps only the object')
    location='E1_5B_Garage_LD';scanner.command('previous')
    location='E1_5B_Garden_LD';language='fr';scanner.command('describe')
    check(not heard:find('backyard',1,true),'room readout respects language')
    language='en';scanner.command('describe')
    check(heard:find('backyard',1,true),'returning to a room restores its description')
    sources.collect=function()
        sources.room='E1_2A_Toilets_LD'
        return {{id='Map:PersistentLevel.LiSInteractionActor_Graffiti_3',
            label='Graffiti',sublevel=sources.room,pos=position}}
    end
    scanner.command('describe');scanner.command('describe')
    check(heard:find('eye at its center',1,true),'optional close-up can be described before Max speaks')
    scanner.command('next')
    check(not heard:find('eye at its center',1,true),'close-up detail only on explicit readout')
    local actions=require('scanner.actions')
    local available,look=actions.available,'Look01'
    actions.available=function()return {{name=look}}end
    sources.collect=function()
        sources.room='E1_3C_VicRoom_LD'
        return {{id='Map:PersistentLevel.LiSInteractionActor_Photos_21',
            label='Photos',sublevel=sources.room,pos=position}}
    end
    scanner.command('describe')
    check(heard:find('neat grid',1,true) and not heard:find('middle finger',1,true),'original photo arrangement')
    look='Look02';scanner.command('describe')
    check(heard:find('middle finger',1,true),'rearranged photos follow the native action')
    look='Look01';scanner.command('describe')
    check(heard:find('neat grid',1,true),'rewinding restores the original grid')
    actions.available=available
    sources.collect,sources.room,FindAllOf=collect,room,find
end
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
