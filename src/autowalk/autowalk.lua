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
M.say=function(_)end
M.log=function(_)end
M.text=function(key,p)return key end
-- Movement input (WASD, arrows, left stick) cancels a walk. Supplied by the
-- caller; returns true while the player is moving Max by hand.
M.moving=function()return false end
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
local function speak(key,params)M.say(M.text(key,params))end
-- Point `extra` cm past `centre`, continuing the horizontal line from `from`.
function M.beyond(from,centre,extra)
    local dx,dy=centre.X-from.X,centre.Y-from.Y
    local len=math.sqrt(dx*dx+dy*dy)
    if len<1 then return centre end
    return {X=centre.X+dx/len*extra,Y=centre.Y+dy/len*extra,Z=centre.Z}
end
function M.walking()return M.active~=nil end
-- Stops a walk the player cancelled (pressing the key again).
function M.cancel()
    if not M.active then return false end
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
function M.start(controller,entry)
    if M.active then speak(plan.refusal("busy"));return false end
    if not entry then speak(plan.refusal("no_target"));return false end
    local pawn=controller.Pawn
    local ready,reason=follow.ready(controller,pawn)
    if not ready then speak(plan.refusal(reason));emit("refused reason="..tostring(reason));return false end
    local sok,start=route.project(controller,feet(pawn))
    local target=entry.stand or entry.pos
    -- Pass-through goals: aim `through` cm beyond the centre, along the line
    -- from Max to it, so she crosses the trigger instead of stopping in it.
    if entry.through then target=M.beyond(feet(pawn),target,entry.through) end
    local gok,goal=route.project(controller,target)
    if not gok and entry.through then gok,goal=route.project(controller,entry.stand or entry.pos) end
    if not sok or not gok then
        emit("refused reason=unprojected start="..tostring(sok).." goal="..tostring(gok))
        speak("walk_no_route",{name=entry.name});return false
    end
    -- Direct route, or a detour around a closed door; false means no route.
    local ok,legs=pcall(doors.plan,controller,pawn,start,goal,emit)
    if not ok then emit("plan_error="..tostring(legs));legs=nil end
    if legs==false then speak("walk_no_route",{name=entry.name});return false end
    local list={}
    if legs then for _,l in ipairs(legs) do list[#list+1]={X=l[1],Y=l[2],Z=l[3]} end
    else list={goal} end
    -- Movement already held when the walk starts must be released first, so
    -- it is never mistaken for a cancel.
    M.active={controller=controller,pawn=pawn,walk=plan.new(entry.name,list,entry.through and entry.through+plan.NEAR or nil),armed=not M.moving()}
    emit("start target="..entry.name.." legs="..#list)
    speak(#list>1 and "walk_start_detour" or "walk_start",{name=entry.name})
    start_leg(M.active)
    return true
end
-- Called regularly on the game thread.
function M.tick()
    local s=M.active
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
    if outcome.say then speak(outcome.say,outcome.params) end
end
return M
