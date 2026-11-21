-- Read-only Episode 1 scene adapter. Reacquire actor wrappers on the game thread;
-- retain only scalar identities/times. Never walk GroupInst/InterpTracks live.
local Data=require('cutscenes.classroom')
local Policy=require('cutscenes.scene_policy')
local M={};M.__index=M
local ids,levels={},{}
for id,stage in pairs(Data.stages)do
    ids[stage.actor]={id=id,data=Data}
    levels[Data.level]=true
end
for actor,definition in pairs(require('cutscenes.episode1'))do
    local level=assert(actor:match('^(E1_%d%u)_'))
    local stage={length=definition.length,protect={},cues={},loop=definition.loop,
        after_first_loop=definition.after_first_loop}
    local last=0
    for _,window in ipairs(definition.windows)do
        local start,finish,key=table.unpack(window)
        assert(last<=start and start<finish and finish<=stage.length,actor)
        if last<start then table.insert(stage.protect,{last,start})end
        table.insert(stage.cues,{start=start,finish=math.min(start+.8,finish),key=key})
        last=finish
    end
    table.insert(stage.protect,{last,stage.length+.25})
    ids[actor]={id='intro',data={order={'intro'},stages={intro=stage}}}
    levels[level]=true
end
local function valid(o)return o and o:IsValid()end
local function text(v)return type(v)=='string'and v or v:ToString()end
-- UE4SS returns a streamed actor's package world on the remaster. Match the
-- level loaded by the controller's world, as well as actors in that world itself.
local function belongs(actor,world,actor_name)
    local aw=actor:GetWorld()
    if not valid(aw)then return false end
    if aw:GetAddress()==world:GetAddress()then return true end
    local package=actor_name:match('^(E1_%d%u_.-_LD%d*)_')
    if not package or not aw.GetFName or aw:GetFName():ToString()~=package then return false end
    local matched=false
    world.StreamingLevels:ForEach(function(_,item)
        local level=item:get()
        if valid(level) and level:IsLevelVisible() then
            local loaded=level.LoadedLevel
            if valid(loaded) and loaded:GetAddress()==aw.PersistentLevel:GetAddress() then matched=true end
        end
    end)
    return matched
end
function M.sample(controller,api)
    api=api or {all=FindAllOf,find=StaticFindObject}
    local ok,frame=pcall(function()
        if not valid(controller)then return nil end
        local world=controller:GetWorld()
        if not valid(world)or not levels[world:GetFName():ToString()] then return nil end
        -- Do not use the mod catalog's English fallback as a language detector.
        if text(controller:GetCurrentLanguage())~='en'then return nil end
        local wid=world:GetAddress();local stages={};local selected
        for _,a in ipairs(api.all('MatineeActor')or{})do
            if valid(a)then
                local actor=a:GetFName():ToString()
                local entry=ids[actor]
                if entry and a.bIsPlaying==true and actor:match('^(E1_%d%u)_')==world:GetFName():ToString() then
                    if belongs(a,world,actor) then
                        if selected and selected~=entry.data then return nil end
                        selected=entry.data
                        local id=entry.id
                        assert(not stages[id],'ambiguous scene segment')
                        stages[id]={key=tostring(a:GetAddress()),time=a.InterpPosition,
                            reverse=a.bReversePlayback==true,rate=a.PlayRate}
                    end
                end
            end
        end
        if not next(stages)then return {world=tostring(wid),stages=stages,allowed=false}end
        local statics=api.find('/Script/Engine.Default__GameplayStatics')
        assert(valid(statics),'pause state unavailable')
        local paused=statics:IsGamePaused(controller)
        assert(type(paused)=='boolean','invalid pause state')
        return {world=tostring(wid),stages=stages,data=selected,allowed=not paused}
    end)
    if not ok then return nil,tostring(frame)end
    return frame
end
function M.new(o)
    return setmetatable({o=o,policy=Policy.new(Data),owner={},active=false,errors={}},M)
end
function M:cancel()
    self.o.stop(self.owner);self.policy:update(nil);self.active=false;self.last_spoken_key=nil
end
function M:tick(request)
    local frame,why
    if self.o.sample then frame,why=self.o.sample()
    else frame,why=M.sample(self.o.controller())end
    if frame and frame.data and frame.data~=self.policy.data then
        -- A repeat may be the first observation of a branch change.
        if request and request==self.last_spoken_key then request=true end
        self:cancel()
        self.policy=Policy.new(frame.data)
    end
    if frame then frame={world=frame.world,stages=frame.stages,
        allowed=frame.allowed and self.o.focused()==true and self.o.allowed()==true}end
    local key,stop=self.policy:update(frame,request)
    self.active=self.policy.active and frame~=nil and frame.allowed==true
    if stop then self.o.stop(self.owner)end
    if key then
        self.last_spoken_key=key
        -- Never queue old visual descriptions behind a newer visual event.
        local queued=self.o.say(self.o.text(key),true,self.owner)
        if self.o.log then self.o.log('scene_description key='..key..' queued='..tostring(queued))end
    end
    if why and not self.errors[why]then
        self.errors[why]=true;self.o.log('scene_description_error='..why)
    end
    return self.active
end
function M:reread()return self:tick(true)end
function M:help(gamepad)return self:tick(gamepad and 'scene_help_pad'or'scene_help_keys')end
function M:repeat_owned(owner)
    if owner~=self.owner then return false end
    -- Expired scene descriptions cannot be replayed over unrelated Max speech.
    self:tick(self.last_spoken_key or true);return true
end
return M
