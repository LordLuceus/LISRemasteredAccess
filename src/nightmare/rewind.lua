-- Rewind cues for the guide (pure; offline tested).
-- Measured in the ending nightmare (27 Oct, test sessions): a hazard's own
-- animation shows the rewind. When Max is caught it freezes (rate 0); while
-- rewinding it plays backwards; after the rewind it plays forward again.
-- Rewinding does not move Max - except that rewinding the lighthouse back
-- past the moment its tree falls makes the game put her before the tree,
-- which is the start that gets across (her first walk is caught at the hole;
-- from the game's restart point the same walk reaches the newspaper).
local M={}
-- Observation of a hazard sequence: {pos=seconds, playing=bool,
-- reverse=bool, rate=number}. Returns "caught", "rewinding" or "running".
function M.state(o)
    if not o or o.pos==nil then return nil end
    if o.reverse then return "rewinding" end
    if o.playing and (o.rate or 1)==0 then return "caught" end
    return "running"
end
-- Tracks one hazard's rewinds. update(obs) returns an event: "caught",
-- "rewind_started", "rewind_done", or nil.
function M.tracker()
    local t={last=nil}
    function t:update(o)
        local s=M.state(o)
        local prev=self.last;self.last=s
        if not s or s==prev then return nil end
        if s=="caught" then return "caught" end
        if s=="rewinding" then return "rewind_started" end
        if s=="running" and prev=="rewinding" then return "rewind_done" end
        return nil
    end
    return t
end
return M
