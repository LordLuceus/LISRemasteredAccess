-- Tracks whether the player has control of Max, for the scanner/autowalk gate
-- and the two cues. Game-independent (offline tested).
-- update(state, now): state is "control", "none" (a cutscene or the game
-- ignoring movement) or "unknown" (loading, no Max, a menu). Returns "lost" or
-- "back" when a change has lasted SETTLE seconds, so brief flickers are quiet.
-- The first known state after start is adopted silently.
local M={}
M.__index=M
M.SETTLE=0.4
-- After a new world loads, changes are adopted silently for GRACE seconds: a
-- loading level briefly frees Max before its opening cutscene takes her.
M.GRACE=5
function M.new()return setmetatable({current=nil,pending=nil,since=0,quiet_until=-1},M)end
function M:reset(now)
    self.current,self.pending,self.quiet_until=nil,nil,now+M.GRACE
    self.suppressed,self.resync,self.resync_state=false,false,nil
end
-- Silence feedback, not control-state tracking/navigation gates. A fast rewind
-- can fit between control polls, so latch the need to adopt a stable post-rewind
-- state quietly rather than replaying a delayed lost/back cue after release.
function M:suppress_cues(on)
    self.suppressed=on==true
    if self.suppressed then self.resync=true;self.resync_state=nil end
end
function M:update(state,now)
    if state=="unknown" then self.pending=nil;self.resync_state=nil;return nil end
    local muted=self.suppressed or self.resync
    if self.resync and not self.suppressed then
        if self.resync_state~=state then self.resync_state,self.resync_since=state,now
        elseif now-self.resync_since>=M.SETTLE then self.resync=false;self.resync_state=nil end
    end
    if state==self.current then self.pending=nil;return nil end
    if self.pending~=state then self.pending,self.since=state,now;return nil end
    if now-self.since<M.SETTLE then return nil end
    local quiet=self.current==nil or now<self.quiet_until or muted
    self.current,self.pending=state,nil
    if quiet then return nil end
    return state=="control" and "back" or "lost"
end
function M:has_control()return self.current=="control" end
return M
