-- Native route planning and bounded multi-leg following for explicit test waypoints.
-- Uses only the game's navigation queries and SimpleMoveToLocation via follow_probe.
local M={legs=nil,index=0,done=false}
local function valid(o)return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end
local function point(p)return {X=p.X,Y=p.Y,Z=p.Z}end
local function dist(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)end
local function context(controller)
    local system,mesh
    for _,n in ipairs(FindAllOf("NavigationSystemV1") or {}) do
        if valid(n) and n:GetWorld():GetAddress()==controller:GetWorld():GetAddress() then system=n;break end
    end
    if not system then error("No current navigation system") end
    system.NavDataSet:ForEach(function(_,v)local n=v:get();if valid(n) and n:IsA("/Script/NavigationSystem.RecastNavMesh") then mesh=n end end)
    if not mesh then error("No registered native mesh") end
    return system,mesh
end
local function feet(pawn)
    local c=pawn.CapsuleComponent;local p=point(c:K2_GetComponentLocation());p.Z=p.Z-c:GetScaledCapsuleHalfHeight();return p
end
function M.project(controller,wanted)
    local system,mesh=context(controller)
    local out={X=0,Y=0,Z=0}
    local ok=system:K2_ProjectPointToNavigation(controller,wanted,out,mesh,nil,{X=50,Y=50,Z=200})
    return ok,out
end
function M.query(controller,pawn,label,from,goal,emit)
    local system,mesh=context(controller)
    local path=system:FindPathToLocationSynchronously(controller,from,goal,pawn,nil)
    if not valid(path) then emit("route_query="..label.." object=false");return false end
    local is_valid=StaticFindObject("/Script/NavigationSystem.NavigationPath:IsValid")(path)
    local partial=StaticFindObject("/Script/NavigationSystem.NavigationPath:IsPartial")(path)
    local pts={};path.PathPoints:ForEach(function(_,v)pts[#pts+1]=point(v:get())end)
    local length=0;for i=2,#pts do length=length+dist(pts[i-1],pts[i]) end
    local err=#pts>0 and dist(pts[#pts],goal) or -1
    local complete=is_valid and not partial and #pts>=2 and err>=0 and err<=5
    local chain={};for i,p in ipairs(pts) do chain[#chain+1]=string.format("%.0f,%.0f,%.0f",p.X,p.Y,p.Z) end
    emit(string.format("route_query=%s valid=%s partial=%s complete=%s points=%d length=%.1f end_error=%.1f chain=%s",
        label,tostring(is_valid),tostring(partial),tostring(complete),#pts,length,err,table.concat(chain,";")))
    return complete,length,pts
end
-- Query every candidate from Max's current position; log only, no movement.
function M.survey(controller,pawn,candidates,emit)
    local ok,start=M.project(controller,feet(pawn))
    emit(string.format("route_start projected=%s position=%.1f,%.1f,%.1f",tostring(ok),start.X,start.Y,start.Z))
    if not ok then return end
    for i,c in ipairs(candidates) do
        local wanted={X=c[1],Y=c[2],Z=c[3]}
        local pok,goal=M.project(controller,wanted)
        emit(string.format("route_candidate=%d wanted=%.0f,%.0f,%.0f projected=%s goal=%.1f,%.1f,%.1f shift=%.1f",
            i,c[1],c[2],c[3],tostring(pok),goal.X,goal.Y,goal.Z,pok and dist(wanted,goal) or -1))
        if pok then M.query(controller,pawn,tostring(i),start,goal,emit) end
    end
end
-- Sequential legs. Each leg must be a complete native path from Max's current feet.
function M.begin(controller,pawn,waypoints,emit)
    M.legs={};M.index=0;M.done=false;M.controller=controller;M.pawn=pawn;M.emit=emit
    for i,w in ipairs(waypoints) do M.legs[i]={X=w[1],Y=w[2],Z=w[3]} end
    emit("route_legs="..#M.legs)
end
function M.next(follow,result)
    if M.done or not M.legs then return end
    if M.index>0 and result~="arrived_test_region" then
        M.done=true;M.emit("route_end=failed leg="..M.index.." result="..tostring(result));return
    end
    if M.index>=#M.legs then M.done=true;M.emit("route_end=arrived legs="..#M.legs);return end
    M.index=M.index+1
    local ok,start=M.project(M.controller,feet(M.pawn))
    local gok,goal=M.project(M.controller,M.legs[M.index])
    if not ok or not gok then M.done=true;M.emit("route_end=unprojected leg="..M.index);return end
    if not M.query(M.controller,M.pawn,"leg"..M.index,start,goal,M.emit) then
        M.done=true;M.emit("route_end=no_complete_path leg="..M.index);return
    end
    M.emit(string.format("route_leg=%d goal=%.1f,%.1f,%.1f",M.index,goal.X,goal.Y,goal.Z))
    follow.start(M.controller,M.pawn,goal,M.emit,true)
end
return M
