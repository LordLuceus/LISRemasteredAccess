-- Engine-free movie-clock scheduler. Never infer a movie from control loss or
-- wall time. An adapter supplies a stable file/playback key and scalar state.
local M={};M.__index=M
local function finite(n)return type(n)=='number' and n==n and math.abs(n)<math.huge end
function M.new()return setmetatable({next=1,blocked=false},M)end
function M:reset()
    self.key,self.time,self.last=nil,nil,nil
    self.next,self.blocked=1,false
end
-- Returns a cue and whether previously owned description speech must stop.
-- A finish time limits starting speech, never cuts off a description in flight.
function M:update(frame,track)
    if not frame or not finite(frame.time) or frame.time<0 or type(frame.key)~='string' then
        local stop=not self.blocked and self.key~=nil
        self.blocked=true;return nil,stop
    end
    local changed=self.key~=frame.key
    local reverse=not changed and self.time and frame.time<self.time-.05
    local stop=changed or reverse
    if changed or reverse then
        self.key,self.next,self.last=frame.key,1,nil
    end
    self.time=frame.time
    local permitted=frame.active==true and frame.playing==true and frame.focused==true and frame.allowed==true
    if not permitted then
        stop=stop or not self.blocked
        self.blocked=true
        while track[self.next] and track[self.next].start<=frame.time do self.next=self.next+1 end
        return nil,stop
    end
    if self.blocked and not changed and not reverse then
        -- Resume after pause/focus/menu: no queue of descriptions from the
        -- obscured interval, including a cue whose window is still open.
        while track[self.next] and track[self.next].start<=frame.time do self.next=self.next+1 end
    end
    self.blocked=false
    while track[self.next] and track[self.next].finish<=frame.time do self.next=self.next+1 end
    local cue=track[self.next]
    if cue and cue.start<=frame.time then
        self.next=self.next+1;self.last=cue.text
        return cue.text,stop
    end
    return nil,stop
end
return M
