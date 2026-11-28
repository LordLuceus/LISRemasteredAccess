package.path='src/?.lua;'..package.path
local baseline=dofile('tests/lua/scene_baseline.lua')
local episode=require('cutscenes.episode1')
local Registry=require('cutscenes.registry')
local registry=Registry.default
local count=0
local function equal(actual,expected,path)
    path=path or 'root'
    count=count+1
    assert(type(actual)==type(expected),path..' type')
    if type(expected)~='table' then assert(actual==expected,path..' value');return end
    for key,value in pairs(expected)do equal(actual[key],value,path..'.'..tostring(key))end
    for key in pairs(actual)do assert(expected[key]~=nil,path..' unexpected '..tostring(key))end
end
equal(episode.timelines,baseline.timelines,'timelines')
equal(episode.groups,baseline.groups,'groups')
equal(episode.actions,baseline.actions,'actions')
local first_ids,first_levels={},{}
for name,data in pairs(registry.ids)do
    if name:match('^E1_')then first_ids[name]=data end
end
for name,data in pairs(registry.levels)do
    if name:match('^E1_')then first_levels[name]=data end
end
equal(first_ids,baseline.compiled,'compiled')
equal(first_levels,baseline.levels,'levels')
assert(registry.startup==episode.groups.classroom)
for _,stage in pairs(episode.groups.classroom.stages)do
    assert(registry.ids[stage.actor].data==registry.startup,'linked stages share one policy')
end
assert(registry.levels.E2_1A and not next(Registry.new({}).levels))
local function fname(name)return {ToString=function()return name end}end
local world_name='E1_6B'
local world={IsValid=function()return true end,GetAddress=function()return 1 end,
    GetFName=function()return fname(world_name)end}
local language='en'
local controller={IsValid=function()return true end,GetWorld=function()return world end,
    GetCurrentLanguage=function()return language end}
local actor_name='E1_6B_CliffFuture_LD_Doe_RunToTheLightHouse'
local actor={IsValid=function()return true end,GetWorld=function()return world end,
    GetFName=function()return fname(actor_name)end,bIsPlaying=true,InterpPosition=.1}
local old_find=FindAllOf
FindAllOf=function()return {actor}end
local heard={}
local function say(text,interrupt)assert(interrupt==false);heard[#heard+1]=text end
-- Execute the real main_step action dispatch, not a rewritten approximation.
local file=assert(io.open('src/main.lua','rb'));local main=file:read('*a');file:close()
local start=assert(main:find('local action_ok,action_error=',1,true))
local finish=assert(main:find('local ok,lines=pcall(shooting.tick,c0)',start,true))
local focused,menu,choice,timed,movie=true,false,false,false,false
local env=setmetatable({c0=controller,say=say,
    l10n={language=function()return language end},speech={focused=function()return focused end},
    in_menu=function()return menu end,choices={options=function()return choice or nil end},
    scene_descriptions={},cutscenes={},log=function(e)error(e)end},{__index=_G})
local callback=assert(load(main:sub(start,finish-1),'actual action dispatch','t',env))
local function tick()
    env.scene_descriptions.active=timed;env.cutscenes.active=movie;callback()
end
for name,text in pairs(baseline.actions)do
    require('cutscenes.actions').tick(controller,false,say)
    actor_name=name;world_name=assert(name:match('^(E1_%d%u)_'))
    local n=#heard;tick();tick();assert(#heard==n+1 and heard[#heard]==text)
end
for _,gate in ipairs({'focus','menu','choice','timed','movie','language'})do
    require('cutscenes.actions').tick(controller,false,say)
    focused=gate~='focus';menu=gate=='menu';choice=gate=='choice';timed=gate=='timed';movie=gate=='movie'
    language=gate=='language' and 'fr' or 'en'
    local n=#heard;tick();assert(#heard==n,'action gating '..gate)
end
focused,menu,choice,timed,movie,language=true,false,false,false,false,'en'
world_name='E2_1A';actor_name='E2_1A_CliffFuture_LD_Doe_RunToTheLightHouse'
local n=#heard;tick();assert(#heard==n,'unregistered Episode 2 action rejected')
assert(not next(require('cutscenes.scene').sample(controller,{all=FindAllOf}).stages),'unregistered Episode 2 actor rejected')
assert(not require('cutscenes.scene').belongs(actor,world,actor_name),'unregistered identity rejected even in same world')
-- A registered world does not license arbitrary actors or two unrelated readers.
world_name='E1_2A'
local function segment(name,address)
    return {IsValid=function()return true end,GetWorld=function()return world end,
        GetFName=function()return fname(name)end,GetAddress=function()return address end,
        bIsPlaying=true,InterpPosition=5,PlayRate=1}
end
local first=segment('E1_2A_ArtClass_LD_MaxAwake_01',11)
local second=segment('E1_2A_ArtClass_LD_Polaroid_Picture01',12)
local sample=require('cutscenes.scene').sample
assert(sample(controller,{all=function()return {first,second}end})==nil,'unrelated concurrent scenes rejected')
local unknown=segment('E1_2A_ArtClass_LD_Unregistered',13)
local frame=assert(sample(controller,{all=function()return {unknown}end}))
assert(not next(frame.stages),'unregistered actor in registered world rejected')
-- Check the normal matcher with reordered answers, including fact-dependent
-- sets. A shared signature must not identify a speaker the HUD cannot identify.
local dialogue = require("cutscenes.dialogue")
local english = require("lang.en")
require("cutscenes.episode2_choices")(function(level, key, ...)
    for _, answers in ipairs({...}) do
        local options = {}
        for i = #answers, 1, -1 do options[#options + 1] = {text=answers[i]} end
        world_name = level
        equal(dialogue.key(function() return controller end, options), key, "Episode 2 prompt")
        assert(type(english[key]) == "string" and english[key] ~= "")
        world_name = "E3_1A"
        equal(dialogue.key(function() return controller end, options), nil, "other episode")
    end
end)
for name, timeline in pairs(require("cutscenes.episode2").timelines) do
    for _, window in ipairs(timeline.windows) do
        assert(english[window[3]], name .. " has missing narration")
    end
end
local demo = require("cutscenes.episode2").timelines
local first_view = demo.E2_2A_Diner_LD_Puzzle02_PredictionSequence.windows
local replay = demo.E2_2A_Diner_LD_Puzzle02_PredictionSequenceRTC.windows
for i, event in ipairs({"mug", "radio", "partner", "scuffle", "roach"}) do
    equal(first_view[i][3], "scene_e2_diner_" .. event, "first demonstration")
    equal(replay[i + 1][3], first_view[i][3], "prediction replay")
    assert(first_view[i][1] ~= replay[i + 1][1], "distinct native clocks")
end
-- The instant-camera shot starts on the cut out of the railroad conversation.
local camera_shot = demo.E2_3B_Railroad_LD_Insertion_ChloeTrapped_Part01.windows[1]
equal(camera_shot[3], "scene_e2_3b_railroad_insertion_chloetrapped_part01_1", "railroad camera shot")
assert(camera_shot[1] < 1 and camera_shot[2] < 3.663, "camera cue before Max speaks")
-- Pushing after removing the wedge plays Interact01. Pushing against the
-- wedge plays Interact02, although both native actions are labelled Push.
equal(demo.E2_3B_Railroad_LD_CableDrum_Interact01.windows[1][3],
    "scene_e2_3b_railroad_cabledrum_interact01_1", "rolling drum")
equal(demo.E2_3B_Railroad_LD_CableDrum_Interact02.windows[1][3],
    "scene_e2_3b_railroad_cabledrum_interact02_1", "blocked drum")
FindAllOf=old_find
print('Scene registry: '..count..' exhaustive content/policy comparisons passed')
return count
