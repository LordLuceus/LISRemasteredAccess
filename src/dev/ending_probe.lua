-- DIAGNOSTIC (test sessions only, read-only): the episode 1 ending nightmare
-- (E1_6B). Records where the authored landmarks are in the remaster (the
-- doe's waypoint triggers, the hazards' trigger and danger volumes, the logs
-- refuge, the newspaper), whether the story facts that mark each hazard's
-- danger can be read, and Max's position, so a guide can be designed from
-- measured data. Then logs Max's position and every danger/safe fact change
-- twice a second while the session runs (the player stays still in a test).
local M={}
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local FACTS={"RollingRock01Danger","TreeFalling01Danger","RollingLogsDanger","RollingLogsBegin","SafePlace",
    "LighthouseDebrisDanger","LighthouseFallingDanger","E1_6B_CliffFuture_Newspaper_Interact01_Triggered"}
local function bounds(a)
    local o,e={X=0,Y=0,Z=0},{X=0,Y=0,Z=0}
    local ok=pcall(function()a:GetActorBounds(false,o,e)end)
    if not ok then local l=a:K2_GetActorLocation();o={X=l.X,Y=l.Y,Z=l.Z} end
    return o,e
end
function M.run(controller,emit)
    local pawn=controller.Pawn
    local p=pawn:K2_GetActorLocation()
    emit(string.format("ending start max=%.0f,%.0f,%.0f world=%s",p.X,p.Y,p.Z,controller:GetWorld():GetFName():ToString()))
    for _,cls in ipairs({"FaceTrigger","DNEVolume","DNEVolumeDynamic","LiSInteractionActor","DynamicBlockingVolume"}) do
        for _,a in ipairs(FindAllOf(cls) or {}) do
            pcall(function()
                if not valid(a) then return end
                local full=a:GetFullName()
                if not full:find("E1_6B",1,true) then return end
                local o,e=bounds(a)
                local r=a:K2_GetActorRotation()
                local extra=""
                pcall(function()extra=" hidden="..tostring(a.bHidden).." collide="..tostring(a:GetActorEnableCollision())end)
                emit(string.format("ending actor class=%s name=%s at=%.0f,%.0f,%.0f extent=%.0f,%.0f,%.0f yaw=%.0f%s",
                    cls,a:GetFName():ToString(),o.X,o.Y,o.Z,e.X,e.Y,e.Z,r.Yaw,extra))
            end)
        end
    end
    local parts={}
    for _,f in ipairs(FACTS) do
        local ok,v=pcall(function()return controller:IsFactActive(FName(f))end)
        parts[#parts+1]=f.."="..(ok and tostring(v) or "error")
    end
    emit("ending facts "..table.concat(parts," "))
    -- Navigation coverage along the scene: is any of it on the walking map?
    local okn,proj=pcall(function()local ok,out=require("nav.route").project(controller,{X=p.X,Y=p.Y,Z=p.Z-90});return ok end)
    emit("ending navmesh_at_start="..tostring(okn and proj))
end
local last=nil
function M.tick(controller,emit)
    local parts={}
    pcall(function()
        local p=controller.Pawn:K2_GetActorLocation()
        parts[#parts+1]=string.format("max=%.0f,%.0f,%.0f",p.X,p.Y,p.Z)
    end)
    for _,f in ipairs(FACTS) do
        local ok,v=pcall(function()return controller:IsFactActive(FName(f))end)
        if ok and v==true then parts[#parts+1]=f end
    end
    local line=table.concat(parts," ")
    if line~=last then last=line;emit("ending tick "..line) end
end
return M
