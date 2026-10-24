-- Doorway-aware route choice. Read-only queries plus a planned waypoint list.
-- Doorways come from wall meshes; passability from a step-aware capsule sweep
-- with mutual live collision responses. No collision, door or fact changes.
local M={}
local function valid(o)return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end
local function name(o)return valid(o) and o:GetFullName() or "none" end
local function d2(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)end
local route=require("route_probe")

local function bounds(actor)
    local o,e={X=0,Y=0,Z=0},{X=0,Y=0,Z=0}
    local ok=pcall(function()actor:GetActorBounds(true,o,e,false)end)
    if not ok then ok=pcall(function()actor:GetActorBounds(true,o,e)end) end
    return ok,o,e
end
function M.doorways(emit)
    local raw={}
    local actors=FindAllOf("StaticMeshActor") or {}
    local seen,named,matched,bounded=0,0,0,0
    for _,a in ipairs(actors) do
        if valid(a) then
            seen=seen+1
            local ok,mesh=pcall(function()return a.StaticMeshComponent.StaticMesh:GetFName():ToString()end)
            if ok and type(mesh)=="string" then named=named+1 end
            if ok and type(mesh)=="string" and string.find(mesh,"ST_Walls_",1,true) and string.find(mesh,"Door",1,true) then
                matched=matched+1
                local bok,o,e=bounds(a)
                if not bok then emit("door_bounds_error actor="..a:GetFName():ToString()) end
                if bok and (e.X>0 or e.Y>0) then
                    bounded=bounded+1
                    local p=a:K2_GetActorLocation()
                    local nx,ny=1,0;if e.X>e.Y then nx,ny=0,1 end
                    raw[#raw+1]={centre={X=o.X,Y=o.Y,Z=p.Z},nx=nx,ny=ny,mesh=mesh,actor=a:GetFName():ToString()}
                end
            end
        end
    end
    emit(string.format("door_search found=%d valid=%d named=%d matched=%d bounded=%d",#actors,seen,named,matched,bounded))
    -- Double-sided walls describe one doorway: merge nearby, same orientation.
    local list={}
    for _,w in ipairs(raw) do
        local merged=false
        for _,d in ipairs(list) do
            if d.nx==w.nx and math.abs(d.centre.Z-w.centre.Z)<60 and d2(d.centre,w.centre)<40 then
                merged=true;d.walls=d.walls..","..w.actor
            end
        end
        if not merged then w.walls=w.actor;list[#list+1]=w end
    end
    emit("door_candidates walls="..#raw.." doorways="..#list)
    return list
end
local function blockers(controller,pawn,from,to)
    local capsule=pawn.CapsuleComponent
    local radius=capsule:GetScaledCapsuleRadius();local half=capsule:GetScaledCapsuleHalfHeight()
    local step=pawn.CharacterMovement.MaxStepHeight
    -- Raise the capsule bottom by the step height so thresholds the character
    -- steps over do not count; the top keeps Max's real height.
    local h=half-step/2
    local a={X=from.X,Y=from.Y,Z=from.Z+step+h+1};local b={X=to.X,Y=to.Y,Z=to.Z+step+h+1}
    local channel=capsule:GetCollisionObjectType()
    local hits={}
    StaticFindObject("/Script/Engine.Default__KismetSystemLibrary"):CapsuleTraceMultiForObjects(
        controller,a,b,radius,h,{0,1,3,4,5},false,{pawn},0,hits,true,{R=1,G=0,B=0,A=1},{R=0,G=1,B=0,A=1},0)
    local found={}
    for _,v in ipairs(hits) do
        local hit=v:get();local c=hit.Component:Get()
        if valid(c) and capsule:GetCollisionResponseToChannel(c:GetCollisionObjectType())==2 and c:GetCollisionResponseToChannel(channel)==2 then
            found[#found+1]=name(hit.Actor:Get())
        end
    end
    return found
end
function M.survey(controller,pawn,emit)
    local list=M.doorways(emit)
    for i,d in ipairs(list) do
        local s1={X=d.centre.X+d.nx*80,Y=d.centre.Y+d.ny*80,Z=d.centre.Z+10}
        local s2={X=d.centre.X-d.nx*80,Y=d.centre.Y-d.ny*80,Z=d.centre.Z+10}
        local ok1,p1=route.project(controller,s1);local ok2,p2=route.project(controller,s2)
        d.index=i;d.sides={p1,p2}
        if not ok1 or not ok2 then
            d.state="unprojected"
        else
            local b=blockers(controller,pawn,p1,p2)
            d.state=#b==0 and "open" or "blocked";d.blocker=b[1]
        end
        emit(string.format("doorway=%d state=%s centre=%.0f,%.0f,%.0f normal=%d,%d walls=%s blocker=%s",
            i,d.state,d.centre.X,d.centre.Y,d.centre.Z,d.nx,d.ny,d.walls,tostring(d.blocker)))
    end
    return list
end
local function crosses(points,d)
    -- 2D segment intersection with the doorway line (opening half-width 42).
    local tx,ty=-d.ny,d.nx
    local ax,ay=d.centre.X-tx*42,d.centre.Y-ty*42;local bx,by=d.centre.X+tx*42,d.centre.Y+ty*42
    for i=2,#points do
        local p,q=points[i-1],points[i]
        if math.abs((p.Z+q.Z)/2-d.centre.Z)<100 then
            local function side(x1,y1,x2,y2,x,y)return (x2-x1)*(y-y1)-(y2-y1)*(x-x1)end
            local s1=side(ax,ay,bx,by,p.X,p.Y);local s2=side(ax,ay,bx,by,q.X,q.Y)
            local s3=side(p.X,p.Y,q.X,q.Y,ax,ay);local s4=side(p.X,p.Y,q.X,q.Y,bx,by)
            if s1*s2<0 and s3*s4<0 then return true end
        end
    end
    return false
end
local function closed_crossing(points,list)
    for _,d in ipairs(list) do if d.state=="blocked" and crosses(points,d) then return d end end
    return nil
end
-- Returns nil for the direct native path, a waypoint list for a detour, or false.
function M.plan(controller,pawn,start,goal,emit)
    local list=M.survey(controller,pawn,emit)
    local ok,len,pts=route.query(controller,pawn,"direct",start,goal,emit)
    if not ok then emit("door_plan=no_direct_path");return false end
    local closed=closed_crossing(pts,list)
    if not closed then emit("door_plan=direct length="..string.format("%.0f",len));return nil end
    emit("door_plan=direct_crosses_closed doorway="..closed.index.." blocker="..tostring(closed.blocker))
    local best,best_len=nil,math.huge
    for _,d in ipairs(list) do
        if d.state=="open" then
            for order=1,2 do
                local near,far=d.sides[order],d.sides[3-order]
                -- Lua's `a and f()` keeps only f's first result, so query explicitly.
                local ok1,l1,p1=route.query(controller,pawn,"via"..d.index.."a"..order,start,near,emit)
                local ok2,l2,p2,ok3,l3,p3=false
                if ok1 then ok2,l2,p2=route.query(controller,pawn,"via"..d.index.."b"..order,near,far,emit) end
                if ok2 then ok3,l3,p3=route.query(controller,pawn,"via"..d.index.."c"..order,far,goal,emit) end
                local clear=ok3 and not closed_crossing(p1,list) and not closed_crossing(p2,list) and not closed_crossing(p3,list)
                emit("door_option doorway="..d.index.." order="..order.." complete="..tostring(ok3==true).." avoids_closed="..tostring(clear==true))
                if clear then
                    local total=l1+l2+l3
                    if total<best_len then best_len=total;best={near,far,goal,doorway=d.index} end
                end
            end
        end
    end
    if not best then emit("door_plan=no_open_detour");return false end
    emit(string.format("door_plan=detour doorway=%d length=%.0f",best.doorway,best_len))
    return {{best[1].X,best[1].Y,best[1].Z},{best[2].X,best[2].Y,best[2].Z},{best[3].X,best[3].Y,best[3].Z}}
end
return M
