-- Native route queries only. No movement, interaction, mesh generation or registration.
local M = {}
local function xyz(p) return {X=p.X,Y=p.Y,Z=p.Z} end
local function distance(a,b)
    return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)
end
local function usable(o)
    return o ~= nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed | EObjectFlags.RF_FinishDestroyed)
end
function M.run(controller, map, emit)
    local world=controller:GetWorld()
    if not usable(world) or world:GetFName():ToString() ~= map then return false end
    local players={}
    for _,p in ipairs(FindAllOf("Pawn") or {}) do
        if usable(p) and p:GetWorld():GetAddress()==world:GetAddress()
            and string.find(p:GetClass():GetFullName(),"MaxCharacter_BP_C",1,true)
            and usable(p.Controller) and p.Controller:GetAddress()==controller:GetAddress() then
            players[#players+1]=p
        end
    end
    if #players~=1 then emit("nav_wait=ambiguous_player count="..#players);return false end
    local player=players[1]
    local system,mesh
    for _,s in ipairs(FindAllOf("NavigationSystemV1") or {}) do
        if usable(s) and s:GetWorld():GetAddress()==world:GetAddress() then system=s;break end
    end
    if not system then emit("nav_wait=no_current_world_system");return false end
    system.NavDataSet:ForEach(function(_,value)
        local candidate=value:get()
        if usable(candidate) and candidate:IsA("/Script/NavigationSystem.RecastNavMesh")
            and candidate:GetWorld():GetAddress()==world:GetAddress() then mesh=candidate end
    end)
    if not mesh then emit("nav_wait=no_registered_recast");return false end
    emit("nav_data="..mesh:GetFullName().." registered="..system.NavDataSet:GetArrayNum())
    local main=system.MainNavData
    emit("nav_main="..(usable(main) and main:GetFullName() or "none"))
    local origin=xyz(player:K2_GetActorLocation())
    local source="actor_origin"
    local dimensions_ok,dimensions_error=pcall(function()
        local capsule=player.CapsuleComponent
        if not usable(capsule) then return end
        local center=xyz(capsule:K2_GetComponentLocation())
        local half=capsule:GetScaledCapsuleHalfHeight()
        local radius=capsule:GetScaledCapsuleRadius()
        origin={X=center.X,Y=center.Y,Z=center.Z-half};source="capsule_bottom"
        emit(string.format("capsule radius=%.3f half_height=%.3f nav_radius=%.3f nav_height=%.3f",radius,half,mesh.AgentRadius,mesh.AgentHeight))
    end)
    if not dimensions_ok then emit("capsule_metadata_error="..tostring(dimensions_error)) end
    local movement_ok,movement=pcall(function()return player.CharacterMovement.MovementMode end)
    emit("movement_mode="..(movement_ok and tostring(movement) or "unknown").." start_source="..source)
    local start={X=0,Y=0,Z=0}
    local start_ok=system:K2_ProjectPointToNavigation(controller,origin,start,mesh,nil,{X=50,Y=50,Z=200})
    emit(string.format("nav_start projected=%s actor=%.3f,%.3f,%.3f point=%.3f,%.3f,%.3f",tostring(start_ok),origin.X,origin.Y,origin.Z,start.X,start.Y,start.Z))
    if not start_ok then return true end
    -- Avoid the UObject:IsValid name collision: explicitly call the path UFunction.
    local valid_fn=StaticFindObject("/Script/NavigationSystem.NavigationPath:IsValid")
    local partial_fn=StaticFindObject("/Script/NavigationSystem.NavigationPath:IsPartial")
    local complete_count,bent_count=0,0
    local selected_goal
    local selected_label=map=="E1_5B" and "5" or "9"
    local function query(label,goal,negative)
        local path=system:FindPathToLocationSynchronously(controller,start,goal,mesh,nil)
        if not usable(path) then emit("native_path="..label.." object=false");return end
        local valid=valid_fn(path)
        local partial=partial_fn(path)
        local points={}
        path.PathPoints:ForEach(function(_,value)points[#points+1]=xyz(value:get()) end)
        local length=0
        for i=2,#points do length=length+distance(points[i-1],points[i]) end
        local end_error=#points>0 and distance(points[#points],goal) or -1
        local complete=valid and not partial and #points>=2 and end_error>=0 and end_error<=5
        if not negative and complete then complete_count=complete_count+1;if #points>2 then bent_count=bent_count+1 end end
        if complete and not negative and label==selected_label then selected_goal=xyz(goal) end
        emit(string.format("native_path=%s valid=%s partial=%s points=%d length=%.3f end_error=%.3f complete=%s negative=%s goal=%.3f,%.3f,%.3f",label,tostring(valid),tostring(partial),#points,length,end_error,tostring(complete),tostring(negative),goal.X,goal.Y,goal.Z))
        for i,p in ipairs(points) do
            emit(string.format("native_point=%s index=%d position=%.3f,%.3f,%.3f",label,i,p.X,p.Y,p.Z))
        end
    end
    for i,offset in ipairs({{300,0},{-300,0},{0,300},{0,-300},{600,0},{-600,0},{0,600},{0,-600},{600,600},{-600,600},{600,-600},{-600,-600}}) do
        local goal={X=0,Y=0,Z=0}
        local wanted={X=start.X+offset[1],Y=start.Y+offset[2],Z=start.Z}
        local projected=system:K2_ProjectPointToNavigation(controller,wanted,goal,mesh,nil,{X=100,Y=100,Z=100})
        if projected and distance(start,goal)>=100 then query(tostring(i),goal,false)
        else emit("native_goal="..i.." projected="..tostring(projected).." useful="..tostring(projected and distance(start,goal)>=100)) end
    end
    local outside={X=start.X+1000000,Y=start.Y+1000000,Z=start.Z}
    local ignored={X=0,Y=0,Z=0}
    local outside_projected=system:K2_ProjectPointToNavigation(controller,outside,ignored,mesh,nil,{X=50,Y=50,Z=100})
    emit("offmesh_projection="..tostring(outside_projected).." expected=false")
    query("offmesh",outside,true)
    if selected_goal then
        local player_path=system:FindPathToLocationSynchronously(controller,start,selected_goal,player,nil)
        if usable(player_path) then
            emit("player_context_path valid="..tostring(valid_fn(player_path)).." partial="..tostring(partial_fn(player_path)).." points="..player_path.PathPoints:GetArrayNum())
        else emit("player_context_path=none") end
        local raw_path=system:FindPathToLocationSynchronously(controller,origin,selected_goal,controller,nil)
        if usable(raw_path) then
            emit("raw_controller_path valid="..tostring(valid_fn(raw_path)).." partial="..tostring(partial_fn(raw_path)).." points="..raw_path.PathPoints:GetArrayNum())
        else emit("raw_controller_path=none") end
    end
    emit("native_summary complete="..complete_count.." bent="..bent_count.." movement_tested=false")
    return true,selected_goal,player
end
return M
