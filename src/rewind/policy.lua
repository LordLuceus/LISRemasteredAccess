-- Marker cue policy ported from LISAccess features/rewind/policy.h.
-- Frames contain scalar identities/timestamps, never engine objects. The
-- adapter must supply the native gauge's reference, range and marker times.
-- Scripted paused state alone never begins a rewind. No automatic stopping.
local M={}
M.__index=M
local function finite(n)return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function position(f)return f.valid and finite(f.reference) and f.reference>=0 and finite(f.range) and f.range>0 end
local function same(a,b)return a.manager==b.manager and a.world==b.world and a.controller==b.controller end
function M.rewinding(f)return f and (f.state==1 or f.state==4) or false end
function M.new()return setmetatable({},M)end
function M:reset()
    self.previous,self.previous_at,self.last,self.anchor=nil,nil,nil,nil
    self.running,self.warned,self.crossed,self.forwarded=false,false,false,false
end
function M:check(from,to)
    local a=self.anchor
    if not a.marker_known or not a.marker_present then return nil end
    if not self.crossed and from>a.marker and to<=a.marker then
        self.crossed,self.warned=true,true;return 'crossed'
    end
    if not self.warned and not self.crossed and to>a.marker and to<=from and (to-a.marker)/self.scale<=0.05 then
        self.warned=true;return 'approach'
    end
end
local function copy(f)local out={};for k,v in pairs(f)do out[k]=v end;return out end
function M:update(f,now)
    if not f or not f.context then self:reset();return nil end
    if self.previous_at and (now<self.previous_at or now-self.previous_at>0.5 or not same(self.previous,f))then self:reset()end
    if M.rewinding(f) and not f.visible then self.running=false;self.previous_at=nil;return nil end
    if not f.valid or not finite(f.reference) or f.reference<0 or not finite(f.state) or f.state%1~=0 or f.state<0 or f.state>4
        or (M.rewinding(f) and not position(f))then
        self.running=false;self.previous_at=nil;return nil
    end
    local cue
    if M.rewinding(f) then
        if not self.running then
            local p=self.previous
            local idle=self.previous_at and now-self.previous_at<=0.15 and same(p,f)
                and (p.state==0 or p.state==2) and p.reference>=f.reference
            self.anchor=copy(idle and p or f)
            self.scale,self.last,self.running=f.range,copy(f),true
            self.warned,self.crossed,self.forwarded=false,false,false
            local a=self.anchor
            if a.marker_present and (not finite(a.marker) or a.marker<0 or a.marker>self.scale)then
                a.marker_known,a.marker_present=false,false
            end
            cue=self:check(idle and p.reference or f.reference,f.reference)
        else
            self.scale=f.range;cue=self:check(self.last.reference,f.reference);self.last=copy(f)
        end
    elseif self.running and (f.state==0 or f.state==2)then
        local stop=self.forwarded and f.reference or math.min(self.last.reference,f.reference)
        cue=self:check(self.last.reference,stop);self.running=false
    end
    if self.running and f.state==3 then self.forwarded=true end
    self.previous,self.previous_at=copy(f),now
    return cue
end
return M
