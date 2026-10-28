-- Walking where the level has no navigation mesh (game side of nav/grid.lua).
-- Proven in a test session (Dormitories, 27 Oct): a downward line trace that
-- keeps only surfaces which physically block Max finds the real ground; a
-- Max-sized capsule (bottom raised by her step height) finds obstacles; and
-- movement input given every frame walks her at normal pace.
--
-- plan(): searches our own grid, a bounded number of cells per call, and
-- returns waypoints. walk(): steers through them every frame, stopping on
-- arrival, when the player moves, when the game takes control (same checks as
-- the navmesh follower), when Max stops making progress, or on a time limit.
local M={}
local grid=require("nav.grid")
local follow=require("nav.follow")
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local function name(a)local ok,s=pcall(function()return a:GetFName():ToString()end);return ok and s or "?" end
local LIB=function()return StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")end
local OBJECTS={0,1,3,4,5} -- WorldStatic, WorldDynamic, PhysicsBody, Vehicle, Destructible
M.log=function(_)end
M.moving=function()return false end

local function blocks_pawn(pawn,hit)
    local c=pawn.CapsuleComponent
    local comp=nil;pcall(function()comp=hit.Component:Get()end)
    if not valid(comp) then return false end
    local r=false
    pcall(function()r=c:GetCollisionResponseToChannel(comp:GetCollisionObjectType())==2 and comp:GetCollisionResponseToChannel(c:GetCollisionObjectType())==2 end)
    return r
end
local function dims(pawn)
    local c=pawn.CapsuleComponent
    return c:GetScaledCapsuleRadius(),c:GetScaledCapsuleHalfHeight(),pawn.CharacterMovement.MaxStepHeight
end
-- Highest blocking surface below `top` at (x,y), or nil.
local function ground(controller,pawn,x,y,top)
    local hits={}
    pcall(function()LIB():LineTraceMultiForObjects(controller,{X=x,Y=y,Z=top},{X=x,Y=y,Z=top-500},OBJECTS,false,{pawn},0,hits,true,{R=1,G=0,B=0,A=1},{R=0,G=1,B=0,A=1},0)end)
    for _,v in ipairs(hits) do
        local h=v:get()
        if blocks_pawn(pawn,h) then
            local z,nz=nil,1
            pcall(function()z=h.ImpactPoint.Z;nz=h.ImpactNormal.Z end)
            -- Too steep to stand on (more than about 45 degrees).
            if z and nz<0.7 then return nil,"steep" end
            return z
        end
    end
    return nil,"noground"
end
-- Ground under a point that may be inside an object (a person, a bench):
-- checks the point itself and a ring 60-120 cm around it, returning the most
-- common ground height near the point's own base, or nil.
function M.ground_below(controller,pawn,p)
    local found={}
    for _,r in ipairs({0,60,120}) do
        for k=0,(r==0 and 0 or 7) do
            local a=k*math.pi/4
            local z=ground(controller,pawn,p.X+math.cos(a)*r,p.Y+math.sin(a)*r,p.Z+50)
            if z and z<=p.Z+20 then found[#found+1]=z end
        end
        if #found>=3 then break end
    end
    if #found==0 then return nil end
    table.sort(found)
    return found[(#found+1)//2]
end
-- First blocking actor in Max's capsule moved from a to b (feet points), or nil.
local function sweep_blocker(controller,pawn,a,b)
    local radius,half,step=dims(pawn)
    local h=half-step/2
    local lift=step+h+1
    local hits={}
    pcall(function()LIB():CapsuleTraceMultiForObjects(controller,{X=a.X,Y=a.Y,Z=a.Z+lift},{X=b.X,Y=b.Y,Z=b.Z+lift+0.1},radius,h,OBJECTS,false,{pawn},0,hits,true,{R=1,G=0,B=0,A=1},{R=0,G=1,B=0,A=1},0)end)
    for _,v in ipairs(hits) do
        local hit=v:get()
        if blocks_pawn(pawn,hit) then return name(hit.Actor:Get()) end
    end
    return nil
end
M.sweep_blocker=sweep_blocker

-- Planner session for start (feet) -> target. Returns an object with :step().
-- reach: arrival radius (cm) - small for the game's own standing spot, larger
-- for an actor's centre, which is inside its own collision (a person).
-- A search that fails having come within NEAR_MISS of the target is retried
-- once on a finer, shifted grid: a narrow gap can fall between 50 cm cells
-- depending on where the search starts. A search that never got close (a
-- walled-off area) is not retried, so a real "no route" stays quick.
M.NEAR_MISS=400
function M.planner(controller,pawn,start,target,reach,corridor)
    local sampler=function(x,y,zref)
        local z,why=ground(controller,pawn,x,y,zref+150)
        if not z then return nil,why end
        local b=sweep_blocker(controller,pawn,{X=x,Y=y,Z=z},{X=x,Y=y,Z=z})
        if b then return nil,"blocked:"..b end
        return z
    end
    local corner=function(a,b)return sweep_blocker(controller,pawn,a,b)==nil end
    local g=grid.new(start,target,{sample=sampler,corner=corner,reach=reach,corridor=corridor})
    local p={g=g,controller=controller,pawn=pawn,retried=false,reports={}}
    -- Returns "running", "found" (p.waypoints) or "failed" (p.reason).
    function p:step(budget)
        local st=self.g:step(budget)
        if st=="failed" and not self.retried and self.g.reason=="no_path" and self.g.best_d<=M.NEAR_MISS then
            self.retried=true
            for _,line in ipairs(self.g:report(100)) do self.reports[#self.reports+1]=line end
            M.log(string.format("offmesh_plan retry closest=%.0f cell=35",self.g.best_d))
            self.first=self.g
            self.g=grid.new(start,target,{sample=sampler,corner=corner,reach=reach,corridor=corridor,cell=35,max_samples=10000})
            return "running"
        end
        if st=="found" then
            self.waypoints=self.g:waypoints(function(a,b)return sweep_blocker(controller,pawn,a,b)==nil end)
        elseif st=="failed" then self.reason=self.g.reason end
        return st
    end
    return p
end

-- Steering ------------------------------------------------------------------
M.active=nil
local function horizontal(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)end
local function feet(pawn)
    local c=pawn.CapsuleComponent;local p=c:K2_GetComponentLocation()
    return {X=p.X,Y=p.Y,Z=p.Z-c:GetScaledCapsuleHalfHeight()}
end
-- done(result, remaining_cm) when the walk ends; result as the navmesh
-- follower's: arrived_test_region, cancelled, stalled, timeout, or a hand-over
-- reason (cinematic_movement_track, input_ignored, paused).
function M.walk(controller,pawn,waypoints,done)
    if M.active then M.stop("busy") end
    local s={controller=controller,pawn=pawn,wps=waypoints,i=1,done=done,t0=os.clock()}
    local total=0;local prev=feet(pawn)
    for _,w in ipairs(waypoints) do total=total+horizontal(prev,w);prev=w end
    s.limit=math.max(15,math.min(120,total/100*2.5))
    s.last=feet(pawn);s.last_progress=os.clock();s.armed=not M.moving()
    M.active=s
    M.log(string.format("offmesh_walk start waypoints=%d length=%.0f limit=%.0f",#waypoints,total,s.limit))
    s.handle=LoopInGameThreadWithDelay(1,function()M.tick()end)
end
function M.stop(reason)
    local s=M.active
    if not s then return end
    M.active=nil
    pcall(function()CancelDelayedAction(s.handle)end)
    local remaining=-1
    pcall(function()remaining=horizontal(feet(s.pawn),s.wps[#s.wps])end)
    M.log(string.format("offmesh_walk end=%s waypoint=%d/%d remaining=%.0f secs=%.1f",reason,s.i,#s.wps,remaining,os.clock()-s.t0))
    if s.done then pcall(s.done,reason,remaining) end
end
function M.cancel()if M.active then M.stop("cancelled");return true end;return false end
function M.tick()
    local s=M.active
    if not s then return end
    local ok,err=pcall(function()
        if not (valid(s.pawn) and valid(s.controller) and valid(s.controller.Pawn) and s.controller.Pawn:GetAddress()==s.pawn:GetAddress()) then M.stop("ownership_changed");return end
        local ready,reason=follow.ready(s.controller,s.pawn)
        if not ready then M.stop(reason);return end
        local moving=M.moving()
        if not s.armed then s.armed=not moving elseif moving then M.stop("cancelled");return end
        local p=feet(s.pawn)
        local w=s.wps[s.i]
        local last=s.i==#s.wps
        local d=horizontal(p,w)
        if d<=(last and 30 or 45) then
            if last then M.stop("arrived_test_region");return end
            s.i=s.i+1;w=s.wps[s.i];d=horizontal(p,w)
        end
        local now=os.clock()
        if horizontal(p,s.last)>=5 then s.last=p;s.last_progress=now end
        if now-s.last_progress>=3 then M.stop("stalled");return end
        if now-s.t0>=s.limit then M.stop("timeout");return end
        s.pawn:AddMovementInput({X=(w.X-p.X)/d,Y=(w.Y-p.Y)/d,Z=0},1.0,false)
    end)
    if not ok then M.log("offmesh_walk error="..tostring(err));M.stop("observation_error") end
end
return M
