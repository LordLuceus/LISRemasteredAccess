-- Development probe (test sessions only): can the mod (a) find open ground,
-- the ground height and obstacles with Max-sized collision checks where the
-- level has no navigation mesh, and (b) steer Max there with movement input?
-- Logs only; the steering step moves Max a few metres in a test session.
local M={}
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local function name(a)local ok,s=pcall(function()return a:GetFName():ToString()end);return ok and s or "?" end
local LIB=function()return StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")end
M.steer_delay_ms=1 -- every engine tick (input is consumed each frame)
local OBJECTS={0,1,3,4,5} -- WorldStatic, WorldDynamic, PhysicsBody, Vehicle, Destructible (as doors.lua)
local function dims(pawn)
    local c=pawn.CapsuleComponent
    return c,c:GetScaledCapsuleRadius(),c:GetScaledCapsuleHalfHeight(),pawn.CharacterMovement.MaxStepHeight
end
-- Ground below (x,y): a line down from `top`; returns Z and the actor hit.
-- True when this hit's component physically blocks Max (both directions), so
-- invisible volumes (lighting, post-process, sound) are ignored.
local function blocks_pawn(pawn,hit)
    local c=pawn.CapsuleComponent
    local comp=nil;pcall(function()comp=hit.Component:Get()end)
    if not valid(comp) then return false end
    local r=false
    pcall(function()r=c:GetCollisionResponseToChannel(comp:GetCollisionObjectType())==2 and comp:GetCollisionResponseToChannel(c:GetCollisionObjectType())==2 end)
    return r
end
M.blocks_pawn=blocks_pawn
-- Ground below (x,y): the first surface Max would stand on, tracing down from
-- `top`. Returns Z, the actor's name and the surface normal's Z.
function M.ground(controller,pawn,x,y,top)
    local hits={}
    pcall(function()LIB():LineTraceMultiForObjects(controller,{X=x,Y=y,Z=top},{X=x,Y=y,Z=top-800},OBJECTS,false,{pawn},0,hits,true,{R=1,G=0,B=0,A=1},{R=0,G=1,B=0,A=1},0)end)
    for _,v in ipairs(hits) do
        local h=v:get()
        if blocks_pawn(pawn,h) then
            local z=nil;pcall(function()z=h.ImpactPoint.Z end)
            local nz=nil;pcall(function()nz=h.ImpactNormal.Z end)
            if z then return z,name(h.Actor:Get()),nz end
        end
    end
    return nil
end
-- Would Max's capsule fit standing at (x,y,ground)? Bottom raised by the step height.
function M.blocked(controller,pawn,p)
    local c,radius,half,step=dims(pawn)
    local h=half-step/2
    local centre={X=p.X,Y=p.Y,Z=p.Z+step+h+1}
    local hits={}
    pcall(function()LIB():CapsuleTraceMultiForObjects(controller,centre,{X=centre.X,Y=centre.Y,Z=centre.Z+1},radius,h,OBJECTS,false,{pawn},0,hits,true,{R=1,G=0,B=0,A=1},{R=0,G=1,B=0,A=1},0)end)
    for _,v in ipairs(hits) do
        local hit=v:get()
        if blocks_pawn(pawn,hit) then return name(hit.Actor:Get()) end
    end
    return nil
end
-- Grid around a centre: '#' open ground, 'X' blocked, '?' no ground found,
-- 'P' the centre cell. Also logs the ground actor and height range.
function M.survey(controller,pawn,cx,cy,emit,tag)
    local step,half=100,12
    local c,_,halfh=dims(pawn)
    local top=pawn:K2_GetActorLocation().Z-halfh+300 -- 3 m above Max's feet
    local counts={open=0,blocked=0,none=0}
    local blockers,grounds={}, {}
    local zmin,zmax=math.huge,-math.huge
    for gx=half,-half,-1 do
        local row={}
        for gy=-half,half do
            local x,y=cx+gx*step,cy+gy*step
            local z,g,nz=M.ground(controller,pawn,x,y,top)
            local ch="?"
            if z then
                zmin=math.min(zmin,z);zmax=math.max(zmax,z);grounds[g]=(grounds[g] or 0)+1
                local b=M.blocked(controller,pawn,{X=x,Y=y,Z=z})
                if b then ch="X";counts.blocked=counts.blocked+1;blockers[b]=(blockers[b] or 0)+1
                else ch="#";counts.open=counts.open+1 end
            else counts.none=counts.none+1 end
            if gx==0 and gy==0 then ch="P" end
            row[#row+1]=ch
        end
        emit(string.format("offmesh grid_row tag=%s r=%02d %s",tag,half-gx+1,table.concat(row)))
    end
    local function top3(t)local l={};for k,v in pairs(t) do l[#l+1]={k,v} end;table.sort(l,function(a,b)return a[2]>b[2] end)
        local s={};for i=1,math.min(6,#l) do s[#s+1]=l[i][1].."="..l[i][2] end;return table.concat(s,",") end
    emit(string.format("offmesh grid tag=%s centre=%.0f,%.0f step=%d open=%d blocked=%d noground=%d z=%.0f..%.0f grounds=%s blockers=%s",
        tag,cx,cy,step,counts.open,counts.blocked,counts.none,zmin,zmax,top3(grounds),top3(blockers)))
end
-- Steering: hold movement input toward `goal` for up to `secs`, logging the
-- position each half second. Returns through the callback when done.
function M.steer(controller,pawn,goal,secs,emit,done)
    local start=pawn:K2_GetActorLocation()
    local t=0
    local h
    emit(string.format("offmesh steer_start from=%.0f,%.0f,%.0f goal=%.0f,%.0f",start.X,start.Y,start.Z,goal.X,goal.Y))
    local t0=os.clock()
    h=LoopInGameThreadWithDelay(M.steer_delay_ms,function()
        t=t+1
        local ok,err=pcall(function()
            local p=pawn:K2_GetActorLocation()
            local dx,dy=goal.X-p.X,goal.Y-p.Y
            local d=math.sqrt(dx*dx+dy*dy)
            if d<40 or os.clock()-t0>secs then
                CancelDelayedAction(h)
                local el=os.clock()-t0
                local moved=math.sqrt((p.X-start.X)^2+(p.Y-start.Y)^2)
                emit(string.format("offmesh steer_end reason=%s delay_ms=%d position=%.0f,%.0f,%.0f remaining=%.0f moved=%.0f secs=%.1f speed_avg=%.0f calls_per_sec=%.0f",
                    d<40 and "arrived" or "timeout",M.steer_delay_ms,p.X,p.Y,p.Z,d,moved,el,moved/math.max(el,0.01),t/math.max(el,0.01)))
                if done then done() end
                return
            end
            pawn:AddMovementInput({X=dx/d,Y=dy/d,Z=0},1.0,false)
            if t%math.max(1,math.floor(500/math.max(M.steer_delay_ms,16)))==0 then
                local v=pawn:GetVelocity()
                emit(string.format("offmesh steer t=%.1f position=%.0f,%.0f,%.0f remaining=%.0f speed=%.0f mode=%s",
                    os.clock()-t0,p.X,p.Y,p.Z,d,math.sqrt(v.X*v.X+v.Y*v.Y),tostring(pawn.CharacterMovement.MovementMode)))
            end
        end)
        if not ok then CancelDelayedAction(h);emit("offmesh steer_error="..tostring(err));if done then done() end end
    end)
end
function M.run(controller,emit)
    local pawn=controller.Pawn
    local p=pawn:K2_GetActorLocation()
    local c,radius,half,step=dims(pawn)
    emit(string.format("offmesh start position=%.0f,%.0f,%.0f radius=%.1f half=%.1f step=%.1f",p.X,p.Y,p.Z,radius,half,step))
    -- The pump and the lawn between it and the covered path.
    M.survey(controller,pawn,-1846,2122,emit,"pump")
    M.survey(controller,pawn,-600,1300,emit,"lawn")
    -- Steer: three metres toward the uncovered lawn, then back.
    local g1={X=p.X+0,Y=p.Y+300}
    local z,gname=M.ground(controller,pawn,g1.X,g1.Y,p.Z)
    emit(string.format("offmesh steer_target ground=%s actor=%s blocked=%s",tostring(z),tostring(gname),tostring(z and M.blocked(controller,pawn,{X=g1.X,Y=g1.Y,Z=z}))))
    M.steer_delay_ms=1
    M.steer(controller,pawn,g1,6,emit,function()
        M.steer(controller,pawn,{X=p.X,Y=p.Y},6,emit,function()emit("offmesh done") end)
    end)
end
return M
