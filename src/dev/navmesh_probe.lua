-- Development probe (test sessions only, read-only): which navigation data the
-- level has, how it is generated, which sublevels are loaded, and a coverage
-- grid of the area checked against every nav data object. Run twice, some
-- seconds apart, to see whether coverage changes over time.
local M={}
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local function str(v)
    if type(v)=="userdata" then
        local ok,s=pcall(function()return v:ToString()end);if ok then return s end
        ok,s=pcall(function()return v:GetFullName()end);if ok then return s end
    end
    return tostring(v)
end
local function field(o,f)local ok,v=pcall(function()return o[f]end);if ok then return str(v) end;return "?" end
function M.describe(controller,emit)
    local world=controller:GetWorld()
    local system=nil
    for _,n in ipairs(FindAllOf("NavigationSystemV1") or {}) do
        if valid(n) and n:GetWorld():GetAddress()==world:GetAddress() then system=n end
    end
    if not system then emit("navprobe system=none");return nil end
    local list={}
    pcall(function()system.NavDataSet:ForEach(function(i,v)local d=v:get();if valid(d) then list[#list+1]=d end end)end)
    emit("navprobe navdataset count="..#list.." main="..field(system,"MainNavData"))
    for i,d in ipairs(list) do
        emit(string.format("navprobe data i=%d name=%s class=%s",i,d:GetFullName(),d:GetClass():GetFName():ToString()))
        local fields={"RuntimeGeneration","bForceRebuildOnLoad","bRebuildAtRuntime","TileSizeUU","CellSize","CellHeight",
            "AgentRadius","AgentHeight","AgentMaxStepHeight","AgentMaxSlope","bFixedTilePoolSize","TilePoolSize",
            "MaxSimultaneousTileGenerationJobsCount","bDoFullyAsyncNavDataGathering","bEnableDrawing","bIsWorldPartitioned"}
        local parts={}
        for _,f in ipairs(fields) do local v=field(d,f);if v~="nil" and v~="?" then parts[#parts+1]=f.."="..v end end
        emit("navprobe data_fields i="..i.." "..table.concat(parts," "))
        pcall(function()
            local cfg=d.NavDataConfig
            emit(string.format("navprobe data_config i=%d name=%s radius=%s height=%s",i,field(cfg,"Name"),field(cfg,"AgentRadius"),field(cfg,"AgentHeight")))
        end)
    end
    emit("navprobe system_fields "..table.concat({
        "bGenerateNavigationOnlyAroundNavigationInvokers="..field(system,"bGenerateNavigationOnlyAroundNavigationInvokers"),
        "bAutoCreateNavigationData="..field(system,"bAutoCreateNavigationData"),
        "DataGatheringMode="..field(system,"DataGatheringMode"),
        "bInitialBuildingLocked="..field(system,"bInitialBuildingLocked"),
        "bWholeWorldNavigable="..field(system,"bWholeWorldNavigable")}," "))
    local inv=FindAllOf("NavigationInvokerComponent") or {}
    emit("navprobe invokers="..#inv)
    for i,c in ipairs(inv) do if i<=5 and valid(c) then emit("navprobe invoker "..c:GetFullName().." gen="..field(c,"TileGenerationRadius").." rem="..field(c,"TileRemovalRadius")) end end
    local vols=FindAllOf("NavMeshBoundsVolume") or {}
    emit("navprobe bounds_volumes="..#vols)
    for i,v in ipairs(vols) do
        if valid(v) then
            local ok,o,e=pcall(function()local origin,extent={X=0,Y=0,Z=0},{X=0,Y=0,Z=0};v:GetActorBounds(false,origin,extent,false);return origin,extent end)
            emit(string.format("navprobe bounds i=%d %s %s",i,v:GetFullName():match("[^.]+$") or "",ok and string.format("origin=%.0f,%.0f,%.0f extent=%.0f,%.0f,%.0f",o.X,o.Y,o.Z,e.X,e.Y,e.Z) or "bounds=?"))
        end
    end
    local levels={}
    pcall(function()world.StreamingLevels:ForEach(function(_,v)local l=v:get();if valid(l) then
        local loaded=false;pcall(function()loaded=l:IsLevelLoaded()end)
        local vis=false;pcall(function()vis=l:IsLevelVisible()end)
        levels[#levels+1]=string.format("%s(loaded=%s,visible=%s)",field(l,"PackageNameToLoad"):match("[^/]+$") or "?",tostring(loaded),tostring(vis))
    end end)end)
    emit("navprobe streaming count="..#levels.." "..table.concat(levels," "))
    return system,list
end
-- Coverage of a grid around (cx,cy): one character per cell, # = navigable on
-- that nav data, . = not. Rows run from north (high X) to south.
function M.grid(controller,system,list,cx,cy,z,emit,tag)
    local step,half=250,12
    for i,d in ipairs(list) do
        local rows={}
        local covered=0
        for gx=half,-half,-1 do
            local row={}
            for gy=-half,half do
                local p={X=cx+gx*step,Y=cy+gy*step,Z=z}
                local ok=false
                pcall(function()local out={X=0,Y=0,Z=0};ok=system:K2_ProjectPointToNavigation(controller,p,out,d,nil,{X=60,Y=60,Z=300})
                    if ok and (math.abs(out.X-p.X)>60 or math.abs(out.Y-p.Y)>60) then ok=false end end)
                row[#row+1]=ok and "#" or "."
                if ok then covered=covered+1 end
            end
            rows[#rows+1]=table.concat(row)
        end
        emit(string.format("navprobe grid tag=%s data=%d centre=%.0f,%.0f step=%d covered=%d/%d",tag,i,cx,cy,step,covered,(2*half+1)^2))
        for r,row in ipairs(rows) do emit(string.format("navprobe grid_row tag=%s data=%d r=%02d %s",tag,i,r,row)) end
    end
end
-- Can the engine's own navmesh builder fill the gaps? Lists the relevant
-- functions, reads the bounds volume, switches the mesh to dynamic generation
-- and asks for a rebuild by every route available, logging each result.
-- (Test sessions only; changes the level's navigation for that session.)
function M.rebuild(controller,system,list,emit)
    local mesh=list[1]
    local world=controller:GetWorld()
    for _,o in ipairs({system,mesh}) do
        local names={}
        pcall(function()o:GetClass():ForEachFunction(function(f)local n=f:GetFName():ToString()
            if n:find("Build") or n:find("Bound") or n:find("Invoker") or n:find("Generat") or n:find("Rebuild") or n:find("Dirty") then names[#names+1]=n end end)end)
        emit("navprobe functions class="..o:GetClass():GetFName():ToString().." "..table.concat(names,","))
    end
    local vol=nil;for _,v in ipairs(FindAllOf("NavMeshBoundsVolume") or {}) do if valid(v) then vol=v end end
    if vol then
        local ok,o,e=pcall(function()local origin,extent={X=0,Y=0,Z=0},{X=0,Y=0,Z=0};vol:GetActorBounds(false,origin,extent);return origin,extent end)
        emit(string.format("navprobe bounds_volume %s",ok and string.format("origin=%.0f,%.0f,%.0f extent=%.0f,%.0f,%.0f",o.X,o.Y,o.Z,e.X,e.Y,e.Z) or ("error="..tostring(o))))
        local s=nil;pcall(function()local l=vol:K2_GetActorLocation();local sc=vol:GetActorScale3D();s=string.format("location=%.0f,%.0f,%.0f scale=%.2f,%.2f,%.2f",l.X,l.Y,l.Z,sc.X,sc.Y,sc.Z)end)
        emit("navprobe bounds_volume_transform "..tostring(s))
    end
    local before=nil;pcall(function()before=mesh.RuntimeGeneration end)
    local sok,serr=pcall(function()mesh.RuntimeGeneration=2 end)
    local after=nil;pcall(function()after=mesh.RuntimeGeneration end)
    emit("navprobe set_runtime_generation before="..tostring(before).." ok="..tostring(sok).." after="..tostring(after)..(sok and "" or " err="..tostring(serr)))
    pcall(function()mesh.bRebuildAtRuntime=true end)
    if vol then
        local ok,err=pcall(function()system:OnNavigationBoundsUpdated(vol)end)
        emit("navprobe OnNavigationBoundsUpdated ok="..tostring(ok)..(ok and "" or " err="..tostring(err)))
    end
    local ok2,err2=pcall(function()mesh:RebuildAll()end)
    emit("navprobe RebuildAll ok="..tostring(ok2)..(ok2 and "" or " err="..tostring(err2)))
    local lib=StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    local ok3,err3=pcall(function()lib:ExecuteConsoleCommand(world,"RebuildNavigation",controller)end)
    emit("navprobe console_RebuildNavigation ok="..tostring(ok3)..(ok3 and "" or " err="..tostring(err3)))
end
function M.building(controller,emit,tag)
    local nav=StaticFindObject("/Script/NavigationSystem.Default__NavigationSystemV1")
    local ok,v=pcall(function()return nav:IsNavigationBeingBuilt(controller)end)
    emit("navprobe building tag="..tag.." ok="..tostring(ok).." value="..tostring(v))
end
return M
