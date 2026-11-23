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
equal(registry.ids,baseline.compiled,'compiled')
equal(registry.levels,baseline.levels,'levels')
assert(registry.startup==episode.groups.classroom)
for _,stage in pairs(episode.groups.classroom.stages)do
    assert(registry.ids[stage.actor].data==registry.startup,'linked stages share one policy')
end
assert(not registry.levels.E2_1A and not next(Registry.new({}).levels))
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
assert(require('cutscenes.scene').sample(controller,{all=FindAllOf})==nil,'unregistered Episode 2 world rejected')
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
FindAllOf=old_find
print('Scene registry: '..count..' exhaustive content/policy comparisons passed')
return count
