-- Travel requires an explicit request and an exact verified disposable saved directory.
-- Movement requires request.follow and is bounded. No interactions, progress resets,
-- random-fact generation or navigation rebuilds.
local prefix = "[LISNavTick] "
local request_ok, request = pcall(require, "LISNavRequest")
if not request_ok then
    -- A malformed request must be visible, not indistinguishable from dormancy.
    print(prefix.."request_error="..tostring(request).."\n")
    request = {scene="inspect"}
end
if not request.expected_saved_directory then
    print(prefix.."dormant: no explicit isolated-profile request\n")
    return
end
local l10n=require("core.localization")
local controls=require("core.controls")
local speech=require("core.speech")
print(prefix.."speech_module "..speech.status().."\n")
local last_speech=""
local last_follow_result=nil
-- Key names are filled in at speech time, so they match the device in use now.
local function say(key)
    last_speech=l10n.text(key,{menu_key=controls.name("main_menu"),cancel_key=controls.name("cancel")})
    speech.say(last_speech,true)
end
-- Follow the game's language and input mode. Both getters are side-effect free.
local settings_reported=false
local function refresh_settings(controller)
    local ok,lang=pcall(function()return controller:GetCurrentLanguage()end)
    if ok then lang=type(lang)=="string" and lang or lang:ToString();l10n.set_language(lang) end
    if not settings_reported then
        -- One line proving both reads ran, since later lines appear only on change.
        settings_reported=true
        controls.refresh(controller)
        print(prefix.."settings language_read="..tostring(ok).." game_language="..tostring(lang)
            .." catalog="..l10n.language().." gamepad="..tostring(controls.using_gamepad()).."\n")
    end
    if controls.refresh(controller) then
        print(prefix.."input_mode gamepad="..tostring(controls.using_gamepad()).."\n")
    end
end
local function emit(line)
    print(prefix..line.."\n")
    local result=string.match(line,"^follow_end=([^ ]+)");if result then last_follow_result=result end
    if string.find(line,"follow_start ",1,true)==1 then say("starting")
    elseif string.find(line,"follow_end=arrived_test_region",1,true)==1 then say("arrived")
    elseif string.find(line,"follow_end=stalled",1,true)==1 then say("stalled")
    elseif string.find(line,"follow_end=",1,true)==1 then say("stopped")
    elseif string.find(line,"follow_refused=",1,true)==1 then say("unavailable") end
end
local scenes = {
    garage={title="$GT_Menus_Journal_Episode1Sub10",map="E1_5B",path="/Game/Maps/Episode01/Sequence05/E1_5B"},
    junkyard={title="$GT_Menus_Journal_Episode2Sub6",map="E2_3A",path="/Game/Maps/Episode02/Sequence03/E2_3A"}
}
local native_controls_passed = false
local travel_requested = false
local nav_checked = false
local return_requested = false
local scene_announced,menu_announced=false,false
local waiting_announced=false
local follow_cancelled=false
local actions_checked=false
local route_active=false
local target_test=nil
local nav_probe = require("dev.nav_sample")
local follow_probe = require("nav.follow")
local function normal_path(value)
    return string.lower((value:gsub("\\", "/"):gsub("/+$", "")))
end
local function native_string(value)
    return type(value) == "string" and value or value:ToString()
end
print(prefix .. "loaded engine_tick_available=" .. tostring(EngineTickAvailable) .. "\n")
if not EngineTickAvailable or EGameThreadMethod == nil then
    print(prefix .. "stopped: explicit EngineTick dispatch unavailable\n")
    return
end
local function text(object)
    if object == nil or not object:IsValid() then return "<none>" end
    return object:GetFullName()
end
ExecuteInGameThread(function()
    print(prefix .. "engine_tick_callback_entered\n")
    local calls_ok, calls_error = pcall(function()
        local mathlib = StaticFindObject("/Script/Engine.Default__KismetMathLibrary")
        local sum = mathlib:Add_IntInt(17, 25)
        print(prefix .. "native_add_result=" .. tostring(sum) .. " expected=42\n")
        if sum ~= 42 then error("Native call control failed; no further calls") end
        local yes,no=mathlib:Not_PreBool(false),mathlib:Not_PreBool(true)
        print(prefix .. "native_bool_result="..tostring(yes)..","..tostring(no).." expected=true,false\n")
        if yes ~= true or no ~= false then error("Native boolean control failed") end
        local vector = mathlib:Add_VectorVector({X=1,Y=3,Z=5}, {X=2,Y=4,Z=6})
        print(prefix .. string.format("native_vector_result=%s,%s,%s expected=3,7,11\n", tostring(vector.X), tostring(vector.Y), tostring(vector.Z)))
        if vector.X ~= 3 or vector.Y ~= 7 or vector.Z ~= 11 then error("Native vector control failed") end
        local system = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
        local saved = system:GetProjectSavedDirectory()
        local value = type(saved) == "string" and saved or saved:ToString()
        print(prefix .. "project_saved_directory=" .. value .. "\n")
        if value == "" then error("Empty native saved directory") end
        if request.expected_saved_directory and normal_path(value) ~= normal_path(request.expected_saved_directory) then
            error("Save directory differs from the explicit test profile; refusing travel")
        end
        native_controls_passed = true
    end)
    if not calls_ok then print(prefix .. "native_control_error=" .. tostring(calls_error) .. "\n");say("failed") end
    -- Metadata only until native invocation passes an independent control.
    for _, path in ipairs({
        "/Script/CoreUObject.Default__Object",
        "/Script/Engine.Default__KismetSystemLibrary",
        "/Script/Engine.KismetSystemLibrary:GetProjectSavedDirectory",
        "/Script/Engine.KismetMathLibrary:Add_IntInt",
        "/Script/LiS.LiSPlayerController:LoadSubEpisode",
        "/Script/LiS.LiSPlayerController:GetSubEpisodeLevel",
        "/Script/LiS.LiSPlayerController:GenerateMissingDebugFacts",
        "/Script/LiS.LiSPlayerController:GenerateRandomSubEpisodeFacts",
        "/Script/LiS.LiSPlayerController:SetActiveSaveSlot",
        "/Script/LiS.LiSPlayerController:LoadCheckpoint"
        ,"/Script/NavigationSystem.NavigationSystemV1:K2_ProjectPointToNavigation"
        ,"/Script/NavigationSystem.NavigationSystemV1:FindPathToLocationSynchronously"
    }) do
        local ok, err = pcall(function()
            local object = StaticFindObject(path)
            if not object:IsValid() then print(prefix .. "missing=" .. path .. "\n"); return end
            print(prefix .. "metadata=" .. path .. " address=" .. string.format("0x%X", object:GetAddress()) .. "\n")
            if string.find(path, ":", 1, true) then
                print(prefix .. "function=" .. path .. " flags=" .. object:GetFunctionFlags() .. "\n")
                object:ForEachProperty(function(property)
                    print(prefix .. "parameter=" .. property:GetFullName() .. "\n")
                end)
            end
        end)
        if not ok then print(prefix .. "metadata_error=" .. path .. " error=" .. tostring(err) .. "\n") end
    end
    for _, class in ipairs({"JourneyManager", "EpisodeDef"}) do
        local ok, err = pcall(function()
            for _, object in ipairs(FindAllOf(class) or {}) do
                print(prefix .. "definition_object=" .. text(object) .. "\n")
                local kind = object:GetClass()
                for depth=1,3 do
                    if not kind:IsValid() then break end
                    kind:ForEachProperty(function(property)
                        print(prefix .. "definition_property=" .. property:GetFullName() .. "\n")
                    end)
                    kind = kind:GetSuperStruct()
                end
            end
        end)
        if not ok then print(prefix .. "definition_error=" .. tostring(err) .. "\n") end
    end
    for _, class in ipairs({"World", "NavigationSystemV1", "RecastNavMesh", "LiSPlayerController", "Pawn"}) do
        local success, failure = pcall(function()
            local objects = FindAllOf(class) or {}
            print(prefix .. "class=" .. class .. " count=" .. #objects .. "\n")
            for index, object in ipairs(objects) do
                if index <= 12 then print(prefix .. "object=" .. text(object) .. "\n") end
            end
        end)
        if not success then print(prefix .. "class=" .. class .. " error=" .. tostring(failure) .. "\n") end
    end
    print(prefix .. "complete\n")
    local controller_class=StaticFindObject("/Script/LiS.LiSPlayerController")
    controller_class:ForEachFunction(function(fn)
        local name=fn:GetFName():ToString()
        if string.find(name,"Menu",1,true) or string.find(name,"Quit",1,true) or string.find(name,"Exit",1,true) then
            print(prefix.."exit_api="..fn:GetFullName().."\n")
            fn:ForEachProperty(function(prop)print(prefix.."exit_parameter="..prop:GetFullName().."\n")end)
        end
    end)
end, EGameThreadMethod.EngineTick)
print(prefix .. "explicit_engine_tick_callback_queued\n")
say("checking")

if request.live==true then
    -- Input callbacks are not game-thread calls. Dispatch Unreal access explicitly
    -- through EngineTick, regardless of the keyboard callback's delivery thread.
    RegisterKeyBindAsync(Key.HOME,function()print(prefix.."key=Home\n");speech.say(last_speech,true)end)
    RegisterKeyBindAsync(Key.F8,function()
        print(prefix.."key=F8\n")
        ExecuteInGameThread(function()
            if follow_probe.active then follow_cancelled=true;follow_probe.stop("user_cancel")
            elseif request.follow and not nav_checked and not follow_cancelled then follow_cancelled=true;say("stopped")
            else say("none") end
        end,EGameThreadMethod.EngineTick)
    end)
    RegisterKeyBindAsync(Key.F10,function()
        print(prefix.."key=F10\n")
        ExecuteInGameThread(function()
            if not native_controls_passed then say("failed");return end
            for _,controller in ipairs(FindAllOf("LiSPlayerController") or {}) do
                if controller:IsValid() and not controller:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed) then
                    local world=controller:GetWorld()
                    if world:GetFName():ToString()=="WhatIf_Menu" then say("menu");return end
                    if world:GetFName():ToString()==scenes[request.scene].map then
                        follow_cancelled=true
                        follow_probe.stop("return_to_menu")
                        return_requested=true;say("returning")
                        controller:ExitToMainMenu(FName("WhatIf_Menu"));return
                    end
                end
            end
            say("unavailable")
        end,EGameThreadMethod.EngineTick)
    end)
    print(prefix.."keys_registered="..tostring(IsKeyBindRegistered(Key.HOME))..","..tostring(IsKeyBindRegistered(Key.F8))..","..tostring(IsKeyBindRegistered(Key.F10)).."\n")
end

local polls = 0
LoopAsync(5000, function()
    polls = polls + 1
    if polls > (request.max_polls or 18) and not request.live then return true end
    local poll = polls
    ExecuteInGameThread(function()
        local ok, err = pcall(function()
            if not native_controls_passed then return end
            local controllers = FindAllOf("LiSPlayerController") or {}
            for _, controller in ipairs(controllers) do
                if controller:IsValid() and not controller:HasAnyFlags(EObjectFlags.RF_BeginDestroyed | EObjectFlags.RF_FinishDestroyed) then
                    local world = controller:GetWorld()
                    print(prefix .. "poll=" .. poll .. " controller=" .. text(controller) .. " world=" .. text(world) .. "\n")
                    refresh_settings(controller)
                    if scenes[request.scene] and world:GetFName():ToString()==scenes[request.scene].map
                        and not scene_announced and controller.Pawn:IsValid() then scene_announced=true;say(request.scene) end
                    if return_requested and not menu_announced and world:GetFName():ToString()=="WhatIf_Menu" then menu_announced=true;say("menu") end
                    if request.return_menu==true and poll>=(request.return_poll or 9) and travel_requested and not return_requested
                        and world:GetFName():ToString()==scenes[request.scene].map then
                        return_requested=true
                        follow_probe.stop("return_to_menu")
                        controller:ExitToMainMenu(FName("WhatIf_Menu"))
                        print(prefix.."return_menu_requested=true\n")
                        return
                    end
                    if request.inspect_widgets then
                        local phase=world:GetFName():ToString().."_poll"..poll
                        if poll==1 or poll==6 or poll==10 then
                            local wok,werr=pcall(function()require("dev.widgets").run(phase,emit)end)
                            if not wok then emit("widget_error="..tostring(werr)) end
                        end
                    end
                    if not travel_requested and poll == 1 then
                        for key, scene in pairs(scenes) do
                            local level = native_string(controller:GetSubEpisodeLevel(scene.title))
                            print(prefix .. "scene_lookup=" .. key .. " title=" .. scene.title .. " level=" .. level .. "\n")
                            if key == request.scene then
                                if not request.expected_saved_directory then error("No isolated directory authorization") end
                                if level ~= scene.map and level ~= scene.path and level ~= (scene.path .. "." .. scene.map) then error("Unexpected target level") end
                                travel_requested = true
                                controller:SetActiveSaveSlot(0)
                                -- Exact shipped collectible/debug-collector call: mode zero.
                                local accepted = controller:LoadSubEpisode(scene.title, 0)
                                print(prefix .. "scene_travel=" .. key .. " native_return=" .. tostring(accepted) .. " confirmation=await_world\n")
                                return -- Controller can be replaced during travel.
                            end
                        end
                    end
                    if travel_requested and not return_requested and not nav_checked and poll>=3
                        and world:GetFName():ToString()==scenes[request.scene].map then
                        local ready,reason=follow_probe.ready(controller,controller.Pawn)
                        if not ready then
                            emit("nav_wait="..reason)
                            if request.follow and not waiting_announced and not follow_cancelled then
                                waiting_announced=true;say(reason=="cinematic_movement_track" and "waiting" or "waiting_control")
                            end
                        else
                            if request.action_patterns and not actions_checked then
                                actions_checked=true
                                local aok,aerr=pcall(function()
                                    local probe=require("dev.actions")
                                    probe.schema(emit);probe.dump_targets(controller,request.action_patterns,emit)
                                end)
                                if not aok then emit("action_probe_error="..tostring(aerr)) end
                            end
                            local done,goal,player=nav_probe.run(controller,scenes[request.scene].map,emit)
                            nav_checked=done
                            if done and player and request.route_candidates then
                                local sok,serr=pcall(function()require("nav.route").survey(controller,player,request.route_candidates,emit)end)
                                if not sok then emit("route_survey_error="..tostring(serr)) end
                            end
                            if done and player and request.auto_goal and request.follow==true and not follow_cancelled then
                                local pok,perr=pcall(function()
                                    local r=require("nav.route")
                                    local c=player.CapsuleComponent;local f=c:K2_GetComponentLocation();f={X=f.X,Y=f.Y,Z=f.Z-c:GetScaledCapsuleHalfHeight()}
                                    local sok,start=r.project(controller,f)
                                    local g=request.auto_goal;local gok,goal=r.project(controller,{X=g[1],Y=g[2],Z=g[3]})
                                    if not sok or not gok then emit("door_plan=unprojected");return end
                                    local plan=require("nav.doors").plan(controller,player,start,goal,emit)
                                    if plan==false then return end
                                    route_active=true
                                    r.begin(controller,player,plan or {{goal.X,goal.Y,goal.Z}},emit)
                                    r.next(follow_probe,nil)
                                end)
                                if not pok then emit("door_plan_error="..tostring(perr)) end
                                goal=nil
                            end
                            if done and player and request.route_waypoints and request.follow==true and not follow_cancelled then
                                route_active=true
                                require("nav.route").begin(controller,player,request.route_waypoints,emit)
                                require("nav.route").next(follow_probe,nil)
                                goal=nil
                            end
                            if done and player and request.target_actor then
                                goal,target_test=require("nav.target").resolve(controller,player,request.target_actor,emit)
                            end
                            if done and goal and request.follow==true and not follow_cancelled then follow_probe.start(controller,player,goal,emit,request.target_actor~=nil) end
                        end
                    end
                    if route_active and last_follow_result and not follow_probe.active and not return_requested and not follow_cancelled then
                        local result=last_follow_result;last_follow_result=nil
                        local rok,rerr=pcall(function()require("nav.route").next(follow_probe,result)end)
                        if not rok then emit("route_error="..tostring(rerr));route_active=false end
                        if require("nav.route").done then route_active=false end
                    end
                    if target_test and last_follow_result and not follow_probe.active and not return_requested and target_test.stage<2 then
                        require("nav.target").observe(target_test,last_follow_result,request.face_target==true,emit)
                    end
                end
            end
            for _, mesh in ipairs(FindAllOf("RecastNavMesh") or {}) do
                if mesh:IsValid() then print(prefix .. "live_navmesh=" .. text(mesh) .. " world=" .. text(mesh:GetWorld()) .. "\n") end
            end
            for _, pawn in ipairs(FindAllOf("Pawn") or {}) do
                if pawn:IsValid() then
                    local p = pawn:K2_GetActorLocation()
                    print(prefix .. string.format("live_pawn=%s controller=%s position=%.3f,%.3f,%.3f\n",text(pawn),text(pawn.Controller),p.X,p.Y,p.Z))
                end
            end
        end)
        if not ok then print(prefix .. "poll_error=" .. tostring(err) .. "\n") end
    end, EGameThreadMethod.EngineTick)
    return false
end)
if request.follow==true then
    local count=0
    LoopAsync(250,function()
        count=count+1
        local expired=not request.live and count>=(request.follow_ticks or 240)
        ExecuteInGameThread(function()follow_probe.tick();if expired then follow_probe.stop("probe_expired") end end,EGameThreadMethod.EngineTick)
        return expired
    end)
end
