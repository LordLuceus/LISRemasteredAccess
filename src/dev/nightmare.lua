-- Read-only survey of the opening nightmare (E1_1A): where Max starts, where the
-- scene's gameplay markers are (FaceTrigger, TriggerBoxes, FSMDummies), and
-- whether the game's own navigation gives a complete route to each. No movement
-- is requested here; a bounded walk is a separate, explicit request.
local M={}
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end)
    return ok and r==true
end
local function point(p)return {X=p.X,Y=p.Y,Z=p.Z}end
local function dist(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)end
local function fmt(p)return string.format("%.0f,%.0f,%.0f",p.X,p.Y,p.Z)end
local function bounds(a)
    local o,e={X=0,Y=0,Z=0},{X=0,Y=0,Z=0}
    local ok=pcall(function()a:GetActorBounds(true,o,e,false)end)
    if not ok then ok=pcall(function()a:GetActorBounds(true,o,e)end) end
    return ok,o,e
end
-- Returns the farthest reachable marker (best route goal), or nil.
function M.survey(controller,pawn,emit)
    local route=require("nav.route")
    local c=pawn.CapsuleComponent;local f=point(c:K2_GetComponentLocation());f.Z=f.Z-c:GetScaledCapsuleHalfHeight()
    local sok,start=route.project(controller,f)
    emit(string.format("nightmare_start feet=%s projected=%s point=%s",fmt(f),tostring(sok),fmt(start)))
    if not sok then return nil end
    local markers={}
    for _,class in ipairs({"FaceTrigger","TriggerBox","FSMDummy","LiSPlayerStart","BlockingVolume"}) do
        for _,a in ipairs(FindAllOf(class) or {}) do
            if valid(a) and not a:GetFullName():find("Default__",1,true) and a:GetFullName():find("E1_1A",1,true) then
                local p=point(a:K2_GetActorLocation())
                local bok,o,e=bounds(a)
                markers[#markers+1]={class=class,name=a:GetFName():ToString(),level=a:GetFullName():match("E1_1A[%w_]*"),pos=p,centre=bok and point(o) or p,extent=bok and point(e) or nil}
            end
        end
    end
    emit("nightmare_markers count="..#markers)
    local best,best_d=nil,0
    for _,m in ipairs(markers) do
        local ext=m.extent and fmt(m.extent) or "?"
        emit(string.format("nightmare_marker class=%s name=%s level=%s pos=%s centre=%s extent=%s straight=%.0f",m.class,m.name,tostring(m.level),fmt(m.pos),fmt(m.centre),ext,dist(start,m.centre)))
        if m.class~="BlockingVolume" and m.class~="LiSPlayerStart" then
            local gok,goal=route.project(controller,m.centre)
            if not gok then
                -- Volumes can sit above the walkable surface; try its floor.
                local floor={X=m.centre.X,Y=m.centre.Y,Z=m.centre.Z-(m.extent and m.extent.Z or 0)}
                gok,goal=route.project(controller,floor)
            end
            emit(string.format("nightmare_goal name=%s projected=%s point=%s",m.name,tostring(gok),fmt(goal)))
            if gok then
                local ok,len=route.query(controller,pawn,m.name,start,goal,emit)
                if ok and dist(start,goal)>best_d then best,best_d={name=m.name,goal=goal,length=len},dist(start,goal) end
            end
        end
    end
    if best then emit(string.format("nightmare_best name=%s straight=%.0f length=%.0f",best.name,best_d,best.length)) end
    return best
end
return M
