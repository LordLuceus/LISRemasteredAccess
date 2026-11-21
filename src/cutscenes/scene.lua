-- Read-only first-classroom adapter. Reacquire actor wrappers on the game thread;
-- retain only scalar identities/times. Never walk GroupInst/InterpTracks live.
local Data=require('cutscenes.classroom')
local Policy=require('cutscenes.scene_policy')
local M={};M.__index=M
local ids={};for id,s in pairs(Data.stages)do ids[s.actor]=id end
local function valid(o)return o and o:IsValid()end
local function text(v)return type(v)=='string'and v or v:ToString()end
function M.sample(controller,api)
    api=api or {all=FindAllOf,find=StaticFindObject}
    local ok,frame=pcall(function()
        if not valid(controller)then return nil end
        local world=controller:GetWorld()
        if not valid(world)or world:GetFName():ToString()~=Data.level then return nil end
        -- Do not use the mod catalog's English fallback as a language detector.
        if text(controller:GetCurrentLanguage())~='en'then return nil end
        local wid=world:GetAddress();local stages={}
        for _,a in ipairs(api.all('MatineeActor')or{})do
            if valid(a)then
                local id=ids[a:GetFName():ToString()]
                if id and a.bIsPlaying==true then
                    local aw=a:GetWorld()
                    if valid(aw)and aw:GetAddress()==wid then
                        assert(not stages[id],'ambiguous classroom segment')
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
        return {world=tostring(wid),stages=stages,allowed=not paused}
    end)
    if not ok then return nil,tostring(frame)end
    return frame
end
function M.new(o)
    return setmetatable({o=o,policy=Policy.new(Data),owner={},active=false,errors={}},M)
end
function M:cancel()
    self.o.stop(self.owner);self.policy:update(nil);self.active=false
end
function M:tick(request)
    local frame,why
    if self.o.sample then frame,why=self.o.sample()
    else frame,why=M.sample(self.o.controller())end
    if frame then frame={world=frame.world,stages=frame.stages,
        allowed=frame.allowed and self.o.focused()==true and self.o.allowed()==true}end
    local key,stop=self.policy:update(frame,request)
    self.active=self.policy.active and frame~=nil and frame.allowed==true
    if stop then self.o.stop(self.owner)end
    if key then
        self.last_spoken_key=key
        -- Never queue old visual descriptions behind a newer visual event.
        self.o.say(self.o.text(key),true,self.owner)
        if self.o.log then self.o.log('scene_description key='..key)end
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
