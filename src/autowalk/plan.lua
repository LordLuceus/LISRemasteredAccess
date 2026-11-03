-- Autowalk decisions, independent of the game (covered by offline tests).
-- A walk is a list of legs (from the door-aware planner: the direct route, or a
-- detour through an open doorway). Each leg ends with a follower result; this
-- module decides what happens next and what to say.
local M={}
M.__index=M
-- Follower results that mean "this leg reached its point".
local ARRIVED={arrived_test_region=true,arrived=true}
-- Results that mean the game took over (a cutscene, a dialogue, the pause
-- menu): stop quietly with a short reason instead of reporting a failure.
local HANDED_OVER={cinematic_movement_track="cutscene",input_ignored="game",paused="paused"}
-- near: how close (cm) to the final point a cutscene counts as arrival; a
-- pass-through goal aims past the trigger, so its cutscene starts further out.
function M.new(target,legs,near)
    return setmetatable({target=target,legs=legs,index=0,finished=false,near=near},M)
end
-- Next leg to walk, or nil when there are none left.
function M:next_leg()
    if self.finished then return nil end
    self.index=self.index+1
    return self.legs[self.index]
end
-- Interprets a finished leg. Returns an outcome:
--   {continue=true}                       walk the next leg
--   {done=true,say=key,params=...}        finished; speak the catalog key
-- remaining: horizontal centimetres to the leg's point when it ended (optional).
-- A cutscene that takes over within NEAR of the final point counts as arrival:
-- reaching a story goal is usually what starts its cutscene.
M.NEAR=150
M.STALL_ARRIVED=60
-- A stall far from the point is retried from where Max stopped, while each
-- try gets closer (3 Nov, pool: three walks to the hall stalled at corners
-- and the fourth arrived; every one started from where the last had stopped).
-- Only when a try makes no progress is the way reported as blocked.
M.RETRIES=3
M.RETRY_MOVED=50 -- cm Max must have moved since the previous stall
-- Pure: should a stalled walk be tried again? moved: cm Max moved since the
-- previous stall (nil on the first stall); tries: retries so far. Progress is
-- distance MOVED, not distance left: the 3 Nov route wound round, and a stop
-- only 30 cm "closer" was 107 cm further along it.
function M.retry_stall(moved,tries)
    if tries>=M.RETRIES then return false end
    if moved and moved<M.RETRY_MOVED then return false end
    return true
end
function M:leg_result(result,remaining)
    if self.finished then return {done=true} end
    if HANDED_OVER[result] and remaining and remaining<=(self.near or M.NEAR) and self.index>=#self.legs then result="arrived" end
    -- Stopped by a wall or furniture just short of the final point: that is
    -- arriving. 29 Oct (Episode 3 dorm): 13 of 18 "blocked" walks ended 32-40
    -- cm from the point, against the object, which the player could use.
    if result=="stalled" and remaining and remaining<=M.STALL_ARRIVED and self.index>=#self.legs then result="arrived" end
    if ARRIVED[result] then
        if self.index<#self.legs then return {continue=true} end
        self.finished=true
        return {done=true,say="walk_arrived",params={name=self.target}}
    end
    self.finished=true
    if result=="cancelled" then return {done=true,say="walk_stopped"} end
    if HANDED_OVER[result] then return {done=true,say="walk_interrupted"} end
    if result=="stalled" then return {done=true,say="walk_blocked",params={name=self.target}} end
    if result=="timeout" then return {done=true,say="walk_timeout",params={name=self.target}} end
    return {done=true,say="walk_failed",params={name=self.target}}
end
-- Why a walk could not start, as a catalog key.
function M.refusal(reason)
    local keys={no_target="walk_no_target",no_route="walk_no_route",unprojected="walk_no_route",
        cinematic_movement_track="walk_not_now",input_ignored="walk_not_now",paused="walk_not_now",
        no_pawn="walk_not_now",busy="walk_busy"}
    return keys[reason] or "walk_no_route"
end
return M
