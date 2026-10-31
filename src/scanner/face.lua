-- Facing the selected scanner object, using the active game camera's own
-- one-shot rotation request (the engine's controller rotation is overwritten
-- by this camera every frame).
-- The camera orbits Max rather than turning in place, so one request aimed from
-- the camera's starting position misses (the original measured 15-25 degrees,
-- enough to miss the game's focus cone). As in the original, the aim is
-- corrected from the camera's ACTUAL new position: up to MAX_CORRECTIONS more
-- requests within LIMIT seconds. Success is the game focusing the object, never
-- our own angle measurement.
local M={}
M.say=function(_)end
M.log=function(_)end
M.text=function(key,p)return key end
-- 31 Oct (pool, Chloe 0.5 m away): each correction turned the camera only
-- 5-10 degrees because the camera orbits Max, and a 60-degree turn to a close
-- target ran out of corrections (8) still converging. Now: as many corrections
-- as keep reducing the error, up to MAX_CORRECTIONS, within LIMIT seconds.
M.MAX_CORRECTIONS=24
M.LIMIT=6
M.STALL_STEPS=3 -- give up when the yaw error has not shrunk for this many steps
M.SETTLE_TICKS=0 -- extra ticks before re-measuring (the loop already waits 250 ms)
M.clock=os.clock
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid()end)
    return ok and r==true
end
local pending=nil
-- What to say when facing finishes. Pure function, covered by offline tests.
-- in_reach: the game lists the object in its inner (actionable) zone.
function M.outcome(entry,focused,camera_ok,in_reach)
    if not camera_ok then return "face_unsupported",{name=entry.name} end
    if entry.kind=="goal" or entry.kind=="exit" then return "face_turned",{name=entry.name} end
    if focused then return nil end -- the focused-object announcement speaks
    return "face_turned_unfocused",{name=entry.name}
end
-- The original's correction, in degrees. The camera does not land where it is
-- asked (it orbits Max and its pitch mapping is offset and nonlinear), so each
-- correction measures the error between where the camera ACTUALLY points and
-- the direction from its actual position to the target, and adds that error
-- to the previous request. Re-asking for the same absolute angle never
-- converges. Returns the next request and the remaining error. Pure.
local function wrap(a)return (a+180)%360-180 end
M.wrap=wrap
function M.correct(requested,actual,desired)
    local dyaw=wrap(desired.Yaw-actual.Yaw)
    local dpitch=desired.Pitch-actual.Pitch
    local pitch=requested.Pitch+dpitch
    if pitch>89 then pitch=89 elseif pitch<-89 then pitch=-89 end
    return {Pitch=pitch,Yaw=wrap(requested.Yaw+dyaw),Roll=0},dyaw,dpitch
end
-- Whether another correction should be sent. Pure, offline tested.
function M.should_correct(state,focused,now)
    if focused then return false end
    if state.corrections>=M.MAX_CORRECTIONS then return false end
    if now-state.started>=M.LIMIT then return false end
    if state.stalled and state.stalled>=M.STALL_STEPS then return false end
    return true
end
-- Pure: track whether the yaw error is still shrinking. Returns the new
-- stalled count.
function M.progress(stalled,best,err)
    err=math.abs(err)
    if best==nil or err<best-0.5 then return 0,err end
    return (stalled or 0)+1,best
end
local function behaviour_of(controller)
    local b=nil
    pcall(function()b=controller.PlayerCameraManager.CamBhv_Current end)
    local ok=false
    pcall(function()ok=valid(b) and b:IsA("/Script/LiS.CBA_3RD_Basic")end)
    return ok and b or nil
end
-- One rotation request aimed from where the camera is right now.
-- Rotations cross into the game only as the game's own FRotator values (the
-- one FindLookAtRotation returns, with its fields set): assigning a plain Lua
-- table to the camera's rotation field crashed the loader. Maths stays in Lua.
local function look_at(controller,target)
    local camera=controller.PlayerCameraManager
    local location=camera:GetCameraLocation()
    local r=StaticFindObject("/Script/Engine.Default__KismetMathLibrary"):FindLookAtRotation(location,target)
    return {Pitch=r.Pitch,Yaw=r.Yaw,Roll=0,native=r},location
end
local function send(behaviour,rotation,carrier)
    local r=carrier or rotation.native
    r.Pitch=rotation.Pitch
    r.Yaw=rotation.Yaw
    r.Roll=0
    behaviour.NextWantedCameraRotationForced=r
    behaviour.WantNextCameraRotationRemainingTick=1
    behaviour.bWantNextCameraRotationForced=true
end
local function request(controller,behaviour,target)
    local rotation,location=look_at(controller,target)
    send(behaviour,rotation)
    return rotation,location
end
local function component(controller)
    for _,c in ipairs(FindAllOf("LiSInteractionComponent") or {}) do
        local ok,own=pcall(function()return valid(c) and c:GetOwner():GetAddress()==controller:GetAddress()end)
        if ok and own then return c end
    end
end
-- Whether the game focuses this entry's object, and whether it is in reach.
local function judge(controller,entry)
    local focused,in_reach=false,nil
    local c=component(controller)
    if not c or not entry.actor then return false,nil end
    pcall(function()
        local f=c.ActorInteractionFocused
        focused=valid(f) and f:GetAddress()==entry.actor:GetAddress()
    end)
    pcall(function()
        local list={}
        c.InnerZoneActorsCurrentlyActionable:ForEach(function(_,v)local ok,o=pcall(function()return v:get()end);if ok then list[#list+1]=o end end)
        in_reach=false
        for _,o in ipairs(list) do if valid(o) and o:GetAddress()==entry.actor:GetAddress() then in_reach=true end end
    end)
    return focused,in_reach
end
-- Whether the game already lists the entry's object as within reach (its
-- inner, actionable zone). nil when unknown.
function M.in_reach(controller,entry)
    local ok,_,r=pcall(judge,controller,entry)
    if ok then return r end
end
-- Turns the camera toward the entry. Returns false when refused.
function M.start(controller,entry)
    if not entry then M.say(M.text("walk_no_target"));return false end
    local behaviour=behaviour_of(controller)
    if not behaviour then
        local key,p=M.outcome(entry,false,false)
        M.say(M.text(key,p));M.log("face refused reason=unsupported_camera");return false
    end
    local rotation,location=request(controller,behaviour,entry.pos)
    M.log(string.format("face requested target=%s pitch=%.1f yaw=%.1f from=%.0f,%.0f,%.0f",entry.name,rotation.Pitch,rotation.Yaw,location.X,location.Y,location.Z))
    pending={controller=controller,entry=entry,started=M.clock(),corrections=0,wait=M.SETTLE_TICKS,requested=rotation}
    if M.watch then M.watch(controller,entry) end
    return true
end
local function finish(p,focused,in_reach,camera_ok)
    pending=nil
    local key,params=M.outcome(p.entry,focused,camera_ok,in_reach)
    if key then M.say(M.text(key,params))
    elseif M.focused_announce then M.focused_announce(p.controller) end
    M.log(string.format("face result=%s corrections=%d secs=%.2f",tostring(key or "focused"),p.corrections,M.clock()-p.started))
end
-- Turn Max's body (yaw only) toward the entry. The rotation crosses into the
-- game as the game's own FRotator (MakeRotator), never a Lua table.
function M.turn_body(p)
    local ok,err=pcall(function()
        local pawn=p.controller.Pawn
        local from=pawn:K2_GetActorLocation()
        local math_lib=StaticFindObject("/Script/Engine.Default__KismetMathLibrary")
        local look=math_lib:FindLookAtRotation(from,p.entry.pos)
        local before=pawn:K2_GetActorRotation().Yaw
        local r=math_lib:MakeRotator(0,0,look.Yaw)
        pawn:K2_SetActorRotation(r,false)
        local after=pawn:K2_GetActorRotation().Yaw
        M.log(string.format("face body_turn target=%s yaw_before=%.1f yaw_after=%.1f wanted=%.1f",p.entry.name,before,after,look.Yaw))
    end)
    if not ok then M.log("face body_turn_error="..tostring(err)) end
end
-- Called regularly on the game thread.
function M.tick()
    local p=pending
    if not p then return end
    if p.wait>0 then p.wait=p.wait-1;return end
    -- A goal has no interaction to focus: one turn is the whole job.
    if p.entry.kind=="goal" or p.entry.kind=="exit" or not p.entry.actor then return finish(p,false,nil,true) end
    local focused,in_reach=judge(p.controller,p.entry)
    if not M.should_correct(p,focused,M.clock()) then return finish(p,focused,in_reach,true) end
    local behaviour=behaviour_of(p.controller)
    if not behaviour then return finish(p,false,in_reach,false) end
    local desired,location=look_at(p.controller,p.entry.pos)
    local actual=nil
    pcall(function()local r=p.controller.PlayerCameraManager:GetCameraRotation();actual={Pitch=r.Pitch,Yaw=r.Yaw}end)
    if not actual then return finish(p,false,in_reach,true) end
    local rotation,dyaw,dpitch=M.correct(p.requested,actual,desired)
    -- Aimed (within 1 degree) or at the camera's tilt limit: stop turning, but
    -- keep watching for focus until the time limit.
    local limited=p.last_actual and math.abs(actual.Pitch-p.last_actual.Pitch)<0.05 and math.abs(dyaw)<=1 and p.corrections>0
    if (math.abs(dyaw)<=1 and math.abs(dpitch)<=1) or limited or p.holding then
        if limited and not p.holding then M.log(string.format("face pitch_limit target=%s actual=%.1f wanted=%.1f",p.entry.name,actual.Pitch,desired.Pitch)) end
        -- The camera points at it and the game still has not focused it:
        -- turn Max's body to it too (31 Oct, Chloe at the pool: the camera
        -- converged to within a degree, 11 corrections, and nothing; her
        -- pop-up only came while walking, when the body turns). Once.
        if not p.holding then M.turn_body(p) end
        p.holding=true
        return
    end
    p.last_actual=actual
    p.stalled,p.best_error=M.progress(p.stalled,p.best_error,dyaw)
    if p.stalled>=M.STALL_STEPS then return finish(p,false,in_reach,true) end
    send(behaviour,rotation,desired.native)
    p.requested=rotation
    p.corrections=p.corrections+1
    p.wait=M.SETTLE_TICKS
    M.log(string.format("face correction=%d target=%s actual=%.1f,%.1f desired=%.1f,%.1f error=%.1f,%.1f request=%.1f,%.1f",
        p.corrections,p.entry.name,actual.Pitch,actual.Yaw,desired.Pitch,desired.Yaw,dpitch,dyaw,rotation.Pitch,rotation.Yaw))
end
return M
