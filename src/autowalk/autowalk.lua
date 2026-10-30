-- Autowalk to the selected scanner entry, using the game's own navigation:
-- * route from Max's feet to the entry's stand point (the game's authored
--   approach point for objects, the floor of a goal volume);
-- * the door-aware planner detours through an open doorway when the direct
--   route crosses a closed one;
-- * each leg is walked by the proven follower, which stands down when a
--   cutscene, dialogue or pause takes control, when Max makes no progress,
--   or after a time limit scaled to the distance.
-- Announcements: the start, then arrival, stop, hand-over or blockage.
local M={active=nil}
local follow=require("nav.follow")
local route=require("nav.route")
local doors=require("nav.doors")
local plan=require("autowalk.plan")
local offmesh=require("nav.offmesh")
M.say=function(_)end
M.log=function(_)end
M.text=function(key,p)return key end
-- Movement input (WASD, arrows, left stick) cancels a walk. Supplied by the
-- caller; returns true while the player is moving Max by hand.
M.moving=function()return false end
-- in_reach(controller,entry) -> true when the game lists the object as actionable.
M.in_reach=function()return nil end
-- The follower reports how each leg ended as "follow_end=<reason>".
local last_result,last_remaining=nil,nil
local function emit(line)
    local r=line:match("^follow_end=(%S+)")
    if r then last_result=r end
    local d=line:match("^follow_progress .-remaining=([%d%.]+)")
    if d then last_remaining=tonumber(d) end
    M.log("autowalk "..line)
end
local function point(p)return {X=p.X,Y=p.Y,Z=p.Z}end
local function feet(pawn)
    local c=pawn.CapsuleComponent;local p=point(c:K2_GetComponentLocation());p.Z=p.Z-c:GetScaledCapsuleHalfHeight();return p
end
local function speak(key,params)if key=="" then return end;M.say(M.text(key,params))end
-- Point `extra` cm past `centre`, continuing the horizontal line from `from`.
function M.beyond(from,centre,extra)
    local dx,dy=centre.X-from.X,centre.Y-from.Y
    local len=math.sqrt(dx*dx+dy*dy)
    if len<1 then return centre end
    return {X=centre.X+dx/len*extra,Y=centre.Y+dy/len*extra,Z=centre.Z}
end
function M.walking()return M.active~=nil end
-- Guide walks (the ending nightmare): on arrival, the next step is fetched
-- and walked straight away, until a step that waits (the shelter), the end,
-- a failure or the player stopping it. M.next_guide(controller) supplies the
-- fresh guide entry.
M.next_guide=function(_)return nil end
-- stalled_guide(entry,result) -> message key to say instead of the usual
-- failure for a guide walk (caught by a hazard), or nil.
M.stalled_guide=function(_,_)return nil end
-- fact_active(controller,name) -> true/false (the game's story facts).
M.fact_active=function(_,_)return true end
local guide_chain=nil
local function chain_after(entry,result,controller)
    if not (entry and entry.kind=="guide") then return false end
    if result~="arrived_test_region" and result~="arrived" then guide_chain=nil;return false end
    local nxt=M.next_guide(controller)
    if not nxt or nxt.step==entry.step then
        guide_chain=nil
        -- What to say instead of "Arrived": the shelter waits, the newspaper ends.
        if nxt and nxt.step_id=="shelter" then return "guide_wait" end
        if nxt and nxt.step_id=="newspaper" then return "guide_done" end
        return nil
    end
    guide_chain=nxt
    return nil
end
M.pending_guide=function()local g=guide_chain;guide_chain=nil;return g end
-- Where the level's navigation mesh does not cover the ground (or has no route
-- across it), plan on our own grid (nav/grid.lua via nav/offmesh.lua) and
-- steer Max through it. Planning is spread over frames; if it takes longer than
-- a second the player hears that a way is being looked for.
local function start_offmesh(controller,pawn,entry,target,why,quiet)
    offmesh.moving=M.moving
    offmesh.log=function(line)M.log("autowalk "..line)end
    local from=feet(pawn)
    -- Without the game's standing spot, the target is the actor's own origin -
    -- for a person, the middle of the body, about 1.3 m up. Arrival compares
    -- ground heights, so measure from the ground under it.
    if not entry.stand then
        local gz=offmesh.ground_below(controller,pawn,target)
        if gz then target={X=target.X,Y=target.Y,Z=gz} end
    end
    emit(string.format("offmesh_plan reason=%s from=%.0f,%.0f,%.0f target=%.0f,%.0f,%.0f",why,from.X,from.Y,from.Z,target.X,target.Y,target.Z))
    -- The game's standing spot is a point to stand ON; an actor's centre is
    -- inside its own collision, so stand next to it instead.
    -- A guide leg is short and runs along the doe's route: search a corridor
    -- around it (quick), not the whole cliff.
    local corridor=entry.kind=="guide" and 600 or nil
    local p=offmesh.planner(controller,pawn,from,target,entry.reach or (entry.stand and 60 or 150),corridor)
    local s={controller=controller,pawn=pawn,offmesh=true,planning=true,armed=not M.moving()}
    M.active=s
    local t0,told=os.clock(),false
    local handle
    handle=LoopInGameThreadWithDelay(1,function()
        if M.active~=s then CancelDelayedAction(handle);return end
        local moving=M.moving()
        if not s.armed then s.armed=not moving
        elseif moving then CancelDelayedAction(handle);M.active=nil;speak("walk_stopped");return end
        local ok,st=pcall(function()return p:step(20)end)
        if not ok then CancelDelayedAction(handle);emit("offmesh_plan_error="..tostring(st));M.active=nil;speak("walk_no_route",{name=entry.name});return end
        if st=="running" then
            if not told and os.clock()-t0>1 then told=true;speak("walk_finding",{name=entry.name}) end
            return
        end
        CancelDelayedAction(handle)
        emit(string.format("offmesh_plan result=%s reason=%s samples=%d retried=%s waypoints=%d secs=%.2f",st,tostring(p.reason),p.g.samples+(p.first and p.first.samples or 0),tostring(p.retried),p.waypoints and #p.waypoints or 0,os.clock()-t0))
        if st~="found" then
            pcall(function()
                for _,line in ipairs(p.reports or {}) do emit("first_"..line) end
                for _,line in ipairs(p.g:report(100)) do emit(line) end
            end)
            -- A guide step whose way opens and closes with a hazard: keep
            -- looking, every 0.3 s, until there is a way, the player stops
            -- it, or the step changes (a rewind moved Max).
            if entry.persist and entry.kind=="guide" then
                if not s.waiting_told then s.waiting_told=true;speak("guide_waiting") end
                local again=os.clock()+0.3
                local retry
                retry=LoopInGameThreadWithDelay(100,function()
                    if M.active~=s then CancelDelayedAction(retry);return end
                    if os.clock()<again then return end
                    CancelDelayedAction(retry)
                    local nxt=M.next_guide(controller)
                    -- The step changed (a rewind or the player moved Max): carry on
                    -- with the new step rather than retrying the old one.
                    if not nxt then M.active=nil;return end
                    if nxt.step~=entry.step then M.active=nil;guide_chain=nxt;speak("guide_next",{name=nxt.step_name,index=nxt.step,count=nxt.steps});return end
                    M.active=nil
                    emit("guide_retry step="..tostring(entry.step))
                    local ok2=pcall(start_offmesh,controller,pawn,nxt,{X=nxt.stand.X,Y=nxt.stand.Y,Z=nxt.stand.Z},"guide_retry",true)
                    if ok2 and M.active then M.active.waiting_told=true end
                end)
                return
            end
            M.active=nil;speak("walk_no_route",{name=entry.name});return
        end
        s.planning=false
        if quiet~=true then speak("walk_start",{name=entry.name}) end
        offmesh.walk(controller,pawn,p.waypoints,function(result,remaining)
            if M.active~=s then return end
            M.active=nil
            local w=plan.new(entry.name,{p.waypoints[#p.waypoints]});w:next_leg()
            local outcome=w:leg_result(result,remaining)
            emit("leg_end result="..result.." leg=offmesh")
            if entry.kind=="guide" and result~="arrived_test_region" and result~="arrived" and result~="cancelled" then
                local key,params=M.stalled_guide(entry,result)
                if key then speak(key,params);return end
            end
            if entry.kind=="guide" and (result=="arrived_test_region" or result=="arrived") then
                local instead=chain_after(entry,result,controller)
                if guide_chain then speak("guide_next",{name=guide_chain.step_name,index=guide_chain.step,count=guide_chain.steps});return end
                if instead then speak(instead);return end
            end
            if outcome.say then speak(outcome.say,outcome.params) end
        end)
    end)
    return true
end
-- Stops any walk without announcing it (the guide speaks instead).
function M.cancel_quiet()
    local s=M.active
    if not s then return false end
    M.active=nil
    if s.offmesh then pcall(offmesh.cancel) else pcall(follow.stop,"cancelled") end
    return true
end
-- Stops a walk the player cancelled (pressing the key again).
function M.cancel()
    if not M.active then return false end
    if M.active.offmesh then
        if M.active.planning then M.active=nil;speak("walk_stopped") else offmesh.cancel() end
        return true
    end
    follow.stop("cancelled")
    return true
end
local function start_leg(s)
    local leg=s.walk:next_leg()
    if not leg then return end
    local ok,goal=route.project(s.controller,leg)
    if not ok then M.active=nil;speak("walk_no_route",{name=s.walk.target});return end
    last_result,last_remaining=nil,nil
    follow.start(s.controller,s.pawn,goal,emit,false)
    if not follow.active then
        -- The follower refused (it logs why); report it plainly.
        M.active=nil;speak("walk_not_now")
    end
end
-- Starts walking to an entry {name,stand,pos}. Returns false when refused.
function M.start(controller,entry,quiet)
    if M.active then speak(plan.refusal("busy"));return false end
    if not entry then speak(plan.refusal("no_target"));return false end
    -- Every message names the target; an entry built outside the scanner list
    -- may only have its label.
    if not entry.name then entry.name=entry.label or "?" end
    -- A guide step that opens on a story fact (the lighthouse crossing):
    -- wait for it, checking every 0.1 s, then walk at once.
    if entry.kind=="guide" and entry.wait_fact and not M.fact_active(controller,entry.wait_fact) then
        local s={controller=controller,pawn=controller.Pawn,offmesh=true,planning=true,entry=entry}
        M.active=s
        speak("guide_waiting")
        emit("guide_wait_fact fact="..entry.wait_fact)
        local h
        h=LoopInGameThreadWithDelay(100,function()
            if M.active~=s then CancelDelayedAction(h);return end
            if M.moving() then CancelDelayedAction(h);M.active=nil;speak("walk_stopped");return end
            if not M.fact_active(controller,entry.wait_fact) then return end
            CancelDelayedAction(h)
            M.active=nil
            emit("guide_wait_fact_done fact="..entry.wait_fact)
            local nxt=M.next_guide(controller) or entry
            nxt.wait_fact=nil
            M.start(controller,nxt,true)
        end)
        return true
    end
    local pawn=controller.Pawn
    local ready,reason=follow.ready(controller,pawn)
    if not ready then speak(plan.refusal(reason));emit("refused reason="..tostring(reason));return false end
    -- Already within reach of the object (the game lists it as actionable):
    -- there is nothing to walk to. 29 Oct (Episode 3 dorm): next to objects
    -- against walls the route search ran and was cancelled, or failed, while
    -- the player could already use the object.
    if entry.actor and quiet~=true and entry.kind=="interaction" then
        local rok,near=pcall(M.in_reach,controller,entry)
        if rok and near==true then emit("start target="..entry.name.." already_in_reach");speak("walk_in_reach",{name=entry.name});return false end
    end
    local sok,start=route.project(controller,feet(pawn))
    local target=entry.stand or entry.pos
    -- Pass-through goals: aim `through` cm beyond the centre, along the line
    -- from Max to it, so she crosses the trigger instead of stopping in it.
    if entry.through then target=M.beyond(feet(pawn),target,entry.through) end
    local gok,goal=route.project(controller,target)
    if not gok and entry.through then gok,goal=route.project(controller,entry.stand or entry.pos) end
    if not sok or not gok then
        emit("navmesh_unavailable start="..tostring(sok).." goal="..tostring(gok))
        return start_offmesh(controller,pawn,entry,target,"unprojected",quiet)
    end
    -- Direct route, or a detour around a closed door; false means no route.
    -- An exit only needs Max inside its volume: a partial route that ends in it will do.
    local accept=nil
    if entry.kind=="exit" and entry.extent then accept=function(p)return doors.inside(p,entry,20) end end
    local ok,legs=pcall(doors.plan,controller,pawn,start,goal,emit,accept)
    if not ok then emit("plan_error="..tostring(legs));legs=nil end
    if legs==false then return start_offmesh(controller,pawn,entry,target,"no_navmesh_route",quiet) end
    local list={}
    if legs then for _,l in ipairs(legs) do list[#list+1]={X=l[1],Y=l[2],Z=l[3]} end
    else list={goal} end
    -- Movement already held when the walk starts must be released first, so
    -- it is never mistaken for a cancel.
    M.active={controller=controller,pawn=pawn,entry=entry,walk=plan.new(entry.name,list,entry.through and entry.through+plan.NEAR or nil),armed=not M.moving()}
    emit("start target="..entry.name.." legs="..#list)
    if quiet~=true then speak(#list>1 and "walk_start_detour" or "walk_start",{name=entry.name}) end
    start_leg(M.active)
    return true
end
-- Called regularly on the game thread.
function M.tick()
    local s=M.active
    if s and s.offmesh then return end -- driven by its own per-frame loop
    if s then
        local moving=M.moving()
        if not s.armed then s.armed=not moving
        elseif moving and follow.active then follow.stop("cancelled") end
    end
    follow.tick()
    if not s or follow.active then return end
    local result=last_result or "observation_error";last_result=nil
    local outcome=s.walk:leg_result(result,last_remaining)
    emit("leg_end result="..result.." leg="..s.walk.index)
    if outcome.continue then start_leg(s);return end
    M.active=nil
    if s.entry and s.entry.kind=="guide" and result~="arrived_test_region" and result~="arrived" and result~="cancelled" then
        local key,params=M.stalled_guide(s.entry,result)
        if key then speak(key,params);return end
    end
    if s.entry and s.entry.kind=="guide" and (result=="arrived_test_region" or result=="arrived") then
        local instead=chain_after(s.entry,result,s.controller)
        if guide_chain then speak("guide_next",{name=guide_chain.step_name,index=guide_chain.step,count=guide_chain.steps});return end
        if instead then speak(instead);return end
    end
    if outcome.say then speak(outcome.say,outcome.params) end
end
-- Starts the walk to the next guide step queued by an arrival. Called on
-- the game-thread loop (never from inside the walk that just ended).
function M.continue_guide(controller)
    if M.active then return end
    local g=M.pending_guide()
    if g then M.start(controller,g,true) end
end
return M
