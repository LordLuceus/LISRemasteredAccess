-- Explicit named-target experiment, using the game's registered interaction list.
-- No action activation, visibility overrides, actor relocation or story-state edits.
local M={}
local function valid(o)return o and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end
local function point(p)return {X=p.X,Y=p.Y,Z=p.Z}end
local function name(o)return valid(o) and o:GetFullName() or "none" end
local function text(v)return type(v)=="string" and v or v:ToString()end
local function dist(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)end
local function contains(array,target)
    local found=false
    array:ForEach(function(_,v)local o=v:get();if valid(o) and o:GetAddress()==target:GetAddress() then found=true end end)
    return found
end
function M.snapshot(s,phase,emit)
    if not valid(s.actor) or not valid(s.component) or not valid(s.player) then error("Target observation lost its objects") end
    local c,a=s.component,s.actor
    local pos=s.player:K2_GetActorLocation();local view=c.LastViewRotation;local control=s.controller:GetControlRotation()
    local camera=s.controller.PlayerCameraManager;local camera_pos=camera:GetCameraLocation();local camera_rot=camera:GetCameraRotation()
    emit(string.format("target_camera phase=%s class=%s position=%.3f,%.3f,%.3f rotation=%.3f,%.3f",phase,camera:GetClass():GetFullName(),camera_pos.X,camera_pos.Y,camera_pos.Z,camera_rot.Pitch,camera_rot.Yaw))
    if phase=="before" then
        local behaviour=camera.CamBhv_Current
        if valid(behaviour) then
            emit("camera_behaviour="..behaviour:GetFullName())
            local kind=behaviour:GetClass()
            for depth=1,3 do
                if not valid(kind) then break end
                kind:ForEachProperty(function(p)
                    emit("behaviour_property="..p:GetFullName())
                    local key=p:GetFName():ToString();local v=behaviour[key]
                    if type(v)=="number" or type(v)=="boolean" then emit("behaviour_value="..key.." value="..tostring(v)) end
                end)
                kind:ForEachFunction(function(f)
                    emit("behaviour_function="..f:GetFullName());f:ForEachProperty(function(p)emit("behaviour_parameter="..p:GetFullName())end)
                end)
                kind=kind:GetSuperStruct()
            end
        end
        local kind=camera:GetClass()
        for depth=1,3 do
            if not valid(kind) then break end
            kind:ForEachProperty(function(p)emit("camera_property="..p:GetFullName())end)
            kind:ForEachFunction(function(f)
                emit("camera_function="..f:GetFullName());f:ForEachProperty(function(p)emit("camera_parameter="..p:GetFullName())end)
            end)
            kind=kind:GetSuperStruct()
        end
    end
    emit(string.format("target_snapshot phase=%s target=%s player=%.3f,%.3f,%.3f actor_distance=%.3f zone=%s inner=%s visible=%s far=%s focused=%s current=%s active_focus=%s view=%.3f,%.3f control=%.3f,%.3f",
        phase,a:GetFName():ToString(),pos.X,pos.Y,pos.Z,dist(pos,a:K2_GetActorLocation()),tostring(a.CurrentZoneStatus),
        tostring(contains(c.InnerZoneActorsCurrentlyActionable,a)),tostring(contains(c.VisibleZoneActorsCurrentlyActionable,a)),
        tostring(contains(c.TooFarZoneActorsCurrentlyActionable,a)),name(c.ActorInteractionFocused),name(c.CurrentInteraction),tostring(c.bIsActiveFocus),view.Pitch,view.Yaw,control.Pitch,control.Yaw))
    for _,key in ipairs({"bIsRegistered","bNeedToHide","bObjectInDisplay","bLook01Enabled","bTake01Enabled","bInteract01Enabled","bInteract02Enabled","bRestrainOnAngleRange","RestrainAngleRange","OverrideInnerZoneRadius","OverrideOuterZoneRadius","FSMOverrideInnerZoneRadius","useVisibilityAngle","ValidAngleFromForward"}) do
        emit("target_value phase="..phase.." property="..key.." value="..tostring(a[key]))
    end
    a.Actions:ForEach(function(i,v)
        local action=v:get()
        local ok,result=pcall(function()return "name="..text(action.ActionName).." enabled="..tostring(action.bEnabled) end)
        emit("target_action phase="..phase.." index="..i.." "..(ok and result or "read_error="..tostring(result)))
    end)
end
function M.resolve(controller,player,target_name,emit)
    local component
    for _,c in ipairs(FindAllOf("LiSInteractionComponent") or {}) do
        if valid(c) and valid(c:GetOwner()) and c:GetOwner():GetAddress()==controller:GetAddress() then
            if component then error("Ambiguous owned interaction component") end
            component=c
        end
    end
    if not component then error("No owned interaction component") end
    local actor,count=nil,0
    emit("target_registered_count="..component.RegisteredActors:GetArrayNum())
    component.RegisteredActors:ForEach(function(_,v)
        local a=v:get()
        if valid(a) then
            if a:GetFName():ToString()==target_name then actor=a;count=count+1 end
            local label=string.lower(a:GetFName():ToString())
            if string.find(label,"tool",1,true) or string.find(label,"bottle",1,true) or string.find(label,"door",1,true) then
                emit("target_registered="..a:GetFullName().." world="..name(a:GetWorld()))
            end
        end
    end)
    if count~=1 then error("Registered target count="..count.." name="..target_name) end
    local dummy=actor.TapToMoveActor
    if not valid(dummy) then error("Target has no authored TapToMoveActor") end
    local wanted=point(dummy:K2_GetActorLocation());local rotation=dummy:K2_GetActorRotation()
    emit(string.format("target_authored actor=%s dummy=%s position=%.3f,%.3f,%.3f yaw=%.3f",name(actor),name(dummy),wanted.X,wanted.Y,wanted.Z,rotation.Yaw))
    local system,mesh
    for _,n in ipairs(FindAllOf("NavigationSystemV1") or {}) do
        if valid(n) and n:GetWorld():GetAddress()==controller:GetWorld():GetAddress() then system=n;break end
    end
    if not system then error("No current navigation system") end
    system.NavDataSet:ForEach(function(_,v)local n=v:get();if valid(n) and n:IsA("/Script/NavigationSystem.RecastNavMesh") then mesh=n end end)
    if not mesh then error("No registered native mesh") end
    local capsule=player.CapsuleComponent;local feet=point(capsule:K2_GetComponentLocation());feet.Z=feet.Z-capsule:GetScaledCapsuleHalfHeight()
    local start,goal={X=0,Y=0,Z=0},{X=0,Y=0,Z=0}
    local start_ok=system:K2_ProjectPointToNavigation(controller,feet,start,mesh,nil,{X=50,Y=50,Z=200})
    local goal_ok=system:K2_ProjectPointToNavigation(controller,wanted,goal,mesh,nil,{X=50,Y=50,Z=200})
    emit(string.format("target_projection start=%s goal=%s goal_position=%.3f,%.3f,%.3f shift=%.3f",tostring(start_ok),tostring(goal_ok),goal.X,goal.Y,goal.Z,dist(wanted,goal)))
    if not start_ok or not goal_ok then return nil end
    local path=system:FindPathToLocationSynchronously(controller,start,goal,player,nil)
    if not valid(path) then return nil end
    local is_valid=StaticFindObject("/Script/NavigationSystem.NavigationPath:IsValid")(path)
    local partial=StaticFindObject("/Script/NavigationSystem.NavigationPath:IsPartial")(path)
    local points={};path.PathPoints:ForEach(function(_,v)points[#points+1]=point(v:get())end)
    local length=0;for i=2,#points do length=length+dist(points[i-1],points[i]) end
    local error=#points>0 and dist(points[#points],goal) or -1
    emit(string.format("target_path valid=%s partial=%s points=%d length=%.3f end_error=%.3f",tostring(is_valid),tostring(partial),#points,length,error))
    local state={actor=actor,component=component,controller=controller,player=player,goal=goal,stage=0}
    M.snapshot(state,"before",emit)
    if not is_valid or partial or #points<2 or error<0 or error>5 then return nil,state end
    return goal,state
end
function M.observe(s,result,face,emit)
    if s.stage==0 then
        M.snapshot(s,"after_"..result,emit);s.stage=1
        if face and result=="arrived_test_region" then
            local camera=s.controller.PlayerCameraManager
            local location=camera:GetCameraLocation()
            local rotation=StaticFindObject("/Script/Engine.Default__KismetMathLibrary"):FindLookAtRotation(location,s.actor:K2_GetActorLocation())
            local behaviour=camera.CamBhv_Current
            if not valid(behaviour) or not behaviour:IsA("/Script/LiS.CBA_3RD_Basic") then
                emit("target_face_refused=unsupported_active_camera");return
            end
            -- Probe the active game's one-shot camera request, not the engine
            -- controller rotation that this camera overwrites each frame.
            behaviour.NextWantedCameraRotationForced=rotation
            behaviour.WantNextCameraRotationRemainingTick=1
            behaviour.bWantNextCameraRotationForced=true
            emit(string.format("target_face_requested mechanism=active_camera_one_shot pitch=%.3f yaw=%.3f",rotation.Pitch,rotation.Yaw))
        end
    elseif s.stage==1 then M.snapshot(s,"settled",emit);s.stage=2 end
end
return M
