-- One bounded native movement request in an explicitly authorized disposable profile.
local M={active=nil}
local function valid(o)return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end
local function point(p)return {X=p.X,Y=p.Y,Z=p.Z}end
local function horizontal(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)end
function M.cinematic_control(pawn)
    -- Mirror AActor::IsMatineeControlled: ownership alone is insufficient;
    -- the matching group must contain a movement track. Do not override it.
    local controlled=false
    pawn.ControllingMatineeActors:ForEach(function(_,a)
        local actor=a:get()
        if valid(actor) then
            actor.GroupInst:ForEach(function(_,g)
                local instance=g:get()
                if valid(instance) and valid(instance.GroupActor) and instance.GroupActor:GetAddress()==pawn:GetAddress() and valid(instance.Group) then
                    instance.Group.InterpTracks:ForEach(function(_,t)
                        local track=t:get()
                        if valid(track) and track:IsA("/Script/Engine.InterpTrackMove") then controlled=true end
                    end)
                end
            end)
        end
    end)
    return controlled
end
function M.ready(controller,pawn)
    if not valid(pawn) then return false,"no_pawn" end
    if M.cinematic_control(pawn) then return false,"cinematic_movement_track" end
    if controller:IsMoveInputIgnored() then return false,"input_ignored" end
    if StaticFindObject("/Script/Engine.Default__GameplayStatics"):IsGamePaused(controller) then return false,"paused" end
    return true
end
local function feet(pawn)
    local capsule=pawn.CapsuleComponent
    local p=point(capsule:K2_GetComponentLocation())
    p.Z=p.Z-capsule:GetScaledCapsuleHalfHeight()
    return p
end
local function owns(s)
    return valid(s.controller) and valid(s.pawn)
        and s.controller:GetFullName()==s.controller_name
        and s.pawn:GetFullName()==s.pawn_name
        and valid(s.controller.Pawn) and s.controller.Pawn:GetAddress()==s.pawn:GetAddress()
end
function M.stop(reason)
    local s=M.active
    if not s then return end
    M.active=nil
    local ok,err=pcall(function()if owns(s) then s.controller:StopMovement() end end)
    s.emit("follow_end="..reason.." stop_ok="..tostring(ok)..(ok and "" or " error="..tostring(err)))
end
function M.start(controller,pawn,goal,emit,diagnose)
    if M.active then error("Movement already owned") end
    if not valid(controller.Pawn) or controller.Pawn:GetAddress()~=pawn:GetAddress() then
        emit("follow_refused=controller_pawn_is_not_max actual="..(valid(controller.Pawn) and controller.Pawn:GetFullName() or "none"));return
    end
    local game=StaticFindObject("/Script/Engine.Default__GameplayStatics")
    local ready,reason=M.ready(controller,pawn)
    if not ready then emit("follow_refused="..reason);return end
    local library=StaticFindObject("/Script/AIModule.Default__AIBlueprintHelperLibrary")
    if not valid(library) then emit("follow_refused=no_native_movement_helper");return end
    local p=feet(pawn)
    local movement=pawn.CharacterMovement
    emit(string.format("follow_state speed=%.3f acceleration=%.3f active=%s tick=%s mode=%s",movement.MaxWalkSpeed,movement.MaxAcceleration,tostring(movement:IsActive()),tostring(movement:IsComponentTickEnabled()),tostring(movement.MovementMode)))
    local owner_ok,owner_error=pcall(function()
        local actual=pawn:GetMovementComponent()
        emit("follow_movement actual="..actual:GetFullName().." character="..movement:GetFullName().." class="..actual:GetClass():GetFullName().." updated="..tostring(actual.UpdatedComponent:IsValid()).." simulating="..tostring(pawn.CapsuleComponent:IsSimulatingPhysics(FName("None"))))
    end)
    if not owner_ok then emit("follow_movement_error="..tostring(owner_error)) end
    local matinee_ok,matinee_error=pcall(function()
        emit("follow_matinee_count="..pawn.ControllingMatineeActors:GetArrayNum())
        pawn.ControllingMatineeActors:ForEach(function(_,v)
            local actor=v:get()
            if valid(actor) then emit("follow_matinee="..actor:GetFullName().." playing="..tostring(actor.bIsPlaying).." position="..tostring(actor.InterpPosition)) end
        end)
    end)
    if not matinee_ok then emit("follow_matinee_error="..tostring(matinee_error)) end
    for _,name in ipairs({"IsPlayingRootMotion","IsPlayingNetworkedRootMotionMontage"}) do
        local ok,value=pcall(function()return pawn[name](pawn)end)
        emit("follow_gate="..name.." available="..tostring(ok).." value="..tostring(value))
    end
    for _,name in ipairs({"bInterpolating","bIsCrouched","bClientUpdating"}) do
        local ok,value=pcall(function()return pawn[name]end)
        emit("follow_field="..name.." available="..tostring(ok).." value="..tostring(value))
    end
    local info_ok,info_error=pcall(function()
        local props=movement.NavAgentProps
        emit(string.format("follow_agent radius=%.3f height=%.3f step=%.3f",props.AgentRadius,props.AgentHeight,props.AgentStepHeight))
    end)
    if not info_ok then emit("follow_agent_error="..tostring(info_error)) end
    local now=os.time()
    M.active={controller=controller,pawn=pawn,controller_name=controller:GetFullName(),pawn_name=pawn:GetFullName(),goal=point(goal),
              emit=emit,game=game,start=now,last_progress=now,last=p,last_report=0,diagnose=diagnose}
    emit(string.format("follow_start goal=%.3f,%.3f,%.3f distance=%.3f timeout_seconds=20",goal.X,goal.Y,goal.Z,horizontal(p,goal)))
    local ok,err=pcall(function()library:SimpleMoveToLocation(controller,goal)end)
    if not ok then emit("follow_request_error="..tostring(err));M.stop("request_error") end
    local path_ok,path_error=pcall(function()
        local path=library:GetCurrentPath(controller)
        if not valid(path) then emit("follow_current_path=none");return end
        local isvalid=StaticFindObject("/Script/NavigationSystem.NavigationPath:IsValid")(path)
        local partial=StaticFindObject("/Script/NavigationSystem.NavigationPath:IsPartial")(path)
        emit("follow_current_path valid="..tostring(isvalid).." partial="..tostring(partial).." points="..path.PathPoints:GetArrayNum())
        if M.active then
            M.active.path={}
            path.PathPoints:ForEach(function(i,v)
                local p=point(v:get());M.active.path[#M.active.path+1]=p
                if diagnose then emit(string.format("follow_path_point index=%d position=%.3f,%.3f,%.3f",i,p.X,p.Y,p.Z)) end
            end)
        end
    end)
    if not path_ok then emit("follow_current_path_error="..tostring(path_error)) end
end
function M.tick()
    local s=M.active
    if not s then return end
    local ok,err=pcall(function()
        if not owns(s) then M.stop("ownership_changed");return end
        local ready,reason=M.ready(s.controller,s.pawn)
        if not ready then M.stop(reason);return end
        local p=feet(s.pawn)
        local remaining=horizontal(p,s.goal)
        local now=os.time()
        if now~=s.last_report then
            s.last_report=now
            s.emit(string.format("follow_progress elapsed=%d remaining=%.3f vertical=%.3f position=%.3f,%.3f,%.3f",now-s.start,remaining,math.abs(p.Z-s.goal.Z),p.X,p.Y,p.Z))
        end
        if remaining<=30 and math.abs(p.Z-s.goal.Z)<=40 and (s.pawn.CharacterMovement.MovementMode==1 or s.pawn.CharacterMovement.MovementMode==2) then M.stop("arrived_test_region");return end
        if horizontal(p,s.last)>=5 then s.last=p;s.last_progress=now end
        if now-s.start>=20 then M.stop("timeout");return end
        if now-s.last_progress>=4 then M.stop("stalled");return end
    end)
    if not ok then s.emit("follow_error="..tostring(err));M.stop("observation_error") end
end
return M
