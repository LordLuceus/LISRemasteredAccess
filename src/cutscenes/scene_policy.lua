-- Pure, scene-local narration policy. No wall-clock scheduling or native objects.
local M={};M.__index=M
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function M.new(data)
    return setmetatable({data=data,seen={},previous={},active=false,blocked=true},M)
end
function M:request(key)self.requested=key or true end
function M:update(frame,request)
    local stop=false
    if not frame or type(frame.world)~='string' then
        -- Preserve consumed cues through a transient missing observation. A new
        -- world/actor or an actual restart below resets them, not a read failure.
        self.last=nil;self.active=false;self.blocked=true;self.requested=nil;self.suspended=true
        return nil,true
    end
    local stages=frame.stages or {}
    local stage=stages.returning and 'returning' or 'intro'
    local intro=stages[stage];local old=self.previous[stage]
    local restart=intro and (not old or intro.key~=old.key or
        (finite(intro.time)and finite(old.time)and intro.time<.5 and old.time>1 and not intro.reverse))
    local reset=self.world~=frame.world or restart
    if reset then
        self.seen={};self.previous={};self.last=nil;self.requested=nil;stop=true
    end
    self.world=frame.world
    local active,suspended=false,frame.allowed~=true
    local protected,invalid=false,false
    for _,id in ipairs(self.data.order)do
        local s=stages[id];local definition=self.data.stages[id]
        if s then
            active=true
            if not finite(s.time)or s.time<0 or s.time>definition.length+.25 or s.reverse or s.rate~=1 then suspended=true;invalid=true
            else
                local prev=self.previous[id]
                if prev and finite(prev.time)and s.time<prev.time-.05 then suspended=true;invalid=true end
                for _,span in ipairs(definition.protect)do
                    if s.time>=span[1]and s.time<span[2]then protected=true end
                end
            end
        end
    end
    self.active=active
    if not active then self.requested=nil;self.last=nil end
    if frame.allowed~=true then self.requested=nil end
    if invalid then self.requested=nil;self.last=nil end
    if request and active and frame.allowed==true and not invalid then self.requested=request end
    local blocked=suspended or protected
    local resumed=self.suspended and not reset
    local cue
    for _,id in ipairs(self.data.order)do
        local s=stages[id]
        if s and finite(s.time)then
            for i,c in ipairs(self.data.stages[id].cues)do
                local key=id..':'..i
                if s.time>=c.start and not self.seen[key]then
                    -- Missed/obscured cues are consumed, never replayed as backlog.
                    self.seen[key]=true
                    if not blocked and not resumed and s.time<c.finish then cue=c.key end
                end
            end
        end
    end
    -- Absence is not a new playback generation. Retain scalar identity/position
    -- across an empty sample, just as across a failed sample.
    for id,s in pairs(stages)do self.previous[id]={key=s.key,time=s.time}end
    self.blocked=blocked or not active
    self.suspended=suspended
    if self.blocked then return nil,true end
    if cue then self.last=cue end
    if self.requested then
        local request=self.requested
        if request~=true or self.last then
            self.requested=nil
            return request==true and self.last or request,stop
        end
    end
    return cue,stop
end
return M
