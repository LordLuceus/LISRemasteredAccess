-- Where scanner entries come from, in the live game. Read-only.
-- 1. The game's own interaction list: the player controller's interaction
--    component keeps RegisteredActors (LiSInteractionActor). An actor counts
--    when it is registered, not hidden, and has at least one enabled action.
--    Its name is objectName ("$GT_Sensen_Int_Bottle01"), translated by the game.
-- 2. Scene goals the game has no interaction for (the opening nightmare's
--    lighthouse), from a small table keyed by the scene's level and actor name.
local M={}
local rooms=require("scanner.rooms")
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end)
    return ok and r==true
end
local function point(p)return {X=p.X,Y=p.Y,Z=p.Z}end
-- Scene goals. label_key is a mod catalog key (a goal has no game name).
M.goals={
    {level="E1_1A_CliffFuture_LD",actor="FaceTrigger_0",class="FaceTrigger",label_key="goal_lighthouse",through=200},
}
M.report=function(_)end
M.trace_gates=false
M.gate_seen={}
local reported={}
local function report_once(id,line)if not reported[id] then reported[id]=true;M.report(line) end end
-- Object names: the game's own translator (LiSWidget:GetLocalizedString),
-- through a live widget or else the widget class's default object, cached per
-- language. If it fails, a readable name is made from the key itself
-- ("$GT_Sensen_Int_AnsweringMachine01" -> "Answering Machine") and reported.
M.language=function()return "" end
local cache,cache_lang,source_logged={},nil,false
local function as_string(v)
    if type(v)=="string" then return v end
    local ok,s=pcall(function()return v:ToString()end)
    if ok and type(s)=="string" then return s end
end
local function translators()
    local list={}
    for _,w in ipairs(FindAllOf("LiSWidget") or {}) do
        if valid(w) and not w:GetFullName():find("Default__",1,true) then list[#list+1]={w,"widget"};break end
    end
    local cdo=StaticFindObject("/Script/LiS.Default__LiSWidget")
    if valid(cdo) then list[#list+1]={cdo,"default_object"} end
    return list
end
function M.readable(key)
    local s=key:gsub("^%$GT_[%a]+_[%a]+_",""):gsub("%d+$","")
    s=s:gsub("(%l)(%u)","%1 %2"):gsub("_"," ")
    return s~="" and s or key
end
function M.translate(key)
    local lang=M.language()
    if lang~=cache_lang then cache,cache_lang={},lang end
    if cache[key] then return cache[key] end
    for _,t in ipairs(translators()) do
        local ok,v=pcall(function()return t[1]:GetLocalizedString(key)end)
        local s=ok and as_string(v) or nil
        if s and s~="" and not s:find("^%$") then
            if not source_logged then source_logged=true;M.report("scanner_translator source="..t[2]) end
            cache[key]=s;return s
        end
    end
    local s=M.readable(key)
    report_once("label:"..key,"scanner_source untranslated key="..key.." spoken="..s)
    cache[key]=s
    return s
end
M.text=function(key)return key end
local function component_of(controller)
    local found
    for _,c in ipairs(FindAllOf("LiSInteractionComponent") or {}) do
        local ok,own=pcall(function()return valid(c) and c:GetOwner():GetAddress()==controller:GetAddress()end)
        if ok and own then found=c;break end
    end
    return found
end
local availability=require("scanner.availability")
-- Enabled actions' conditions, copied out as plain values inside the walk.
-- Conditions are authored map data and do not change while the level is
-- loaded, so each object's are read once and kept (keyed by its full name,
-- which includes its level). Reading them walks arrays nested inside each
-- action - and another object's actions for actor conditions - the nested-walk
-- pattern that crashed the loader when repeated often (the cutscene check), so
-- it is not done on every scanner key press. Whether an action is enabled DOES
-- change in play, so that is read fresh each time with the same flat walk the
-- scanner has always used.
local condition_cache={}
local function all_conditions(actor)
    local key=nil;pcall(function()key=actor:GetFullName()end)
    if key and condition_cache[key] then return condition_cache[key] end
    local by_index={}
    local actions={}
    pcall(function()
        actor.Actions:ForEach(function(i,v)
            local ok,a=pcall(function()return v:get()end)
            if ok then actions[#actions+1]={i,a} end
        end)
    end)
    for _,p in ipairs(actions) do by_index[p[1]]=availability.read_conditions(p[2]) end
    if key then condition_cache[key]=by_index end
    return by_index
end
local function enabled_indices(actor)
    local list={}
    pcall(function()
        actor.Actions:ForEach(function(i,v)
            local ok,e=pcall(function()return v:get().bEnabled end)
            if ok and e==true then list[#list+1]=i end
        end)
    end)
    return list
end
local function enabled_conditions(actor)
    local on=enabled_indices(actor)
    if #on==0 then return {} end
    local all=all_conditions(actor)
    local list={}
    for _,i in ipairs(on) do list[#list+1]=all[i] or {} end
    return list
end
local function any_enabled(actor)return #enabled_conditions(actor)>0 end
-- Available now: some enabled action's story conditions hold (the game's rule).
local function available(actor,is_active)
    local list=enabled_conditions(actor)
    if #list==0 then return false end
    if not is_active then return true end
    for _,c in ipairs(list) do if availability.action_ok(c,is_active) then return true end end
    -- Diagnostic (test sessions): which story facts kept the object out.
    if M.trace_gates then pcall(function()
        local facts={}
        for _,c in ipairs(list) do for _,f in ipairs(c["and"]) do facts[#facts+1]=f.fact.."="..tostring(f.want).."/now="..tostring(is_active(f.fact)) end end
        M.report("scanner_story_gated id="..actor:GetFName():ToString().." conditions="..table.concat(facts,","))
    end) end
    return false
end
-- Story facts the game switches on only while the camera points at an object
-- (5 Nov). From all 158 object levels: facts that a level behaviour holding an
-- IA_CheckVisibility node both sets and clears, reviewed by hand to the ones
-- that are camera conditions (the rest are story state such as "Finished").
-- Each gates an object the player is meant to turn and look at.
M.LOOK_FACTS={
    E2_1A_Corridor_LD_Check_TP=true,
    E2_3A_Junkyard_LD_AllowLookFromBottomBottle=true,  -- bottle (look from below)
    E2_3A_Junkyard_LD_AllowPhotoBus=true,              -- school bus photo
    E2_4B_Corridor_LD_VortexBannerInScreen=true,       -- Vortex banner
    E3_1B_Corridor_LD_BrokenLampInScreen=true,         -- broken lamp, campus
    E3_6B_DinerPark_LD_Check_Truck=true,               -- truck photo, diner
}
-- Objects registered at any point during this level visit: id -> actor.
local remembered,remembered_world={},nil
local dropout_logged={}
local function interactions(controller,out)
    local w=nil;pcall(function()w=controller:GetWorld():GetFName():ToString()end)
    if w~=remembered_world then remembered={};remembered_world=w;dropout_logged={} end
    local is_active=availability.fact_reader(controller)
    local component=component_of(controller)
    if not component then report_once("component","scanner_source error=no_interaction_component");return end
    -- Copy the actor references out first, then read them. Reading names
    -- inside the array iteration (calling GetLocalizedString there) broke the
    -- iteration in play: "Property type 'LiSInteractionActor' not supported".
    local actors={}
    component.RegisteredActors:ForEach(function(_,v)
        local ok,a=pcall(function()return v:get()end)
        if ok and valid(a) then actors[#actors+1]=a end
    end)
    local seen={}
    local function read(a,registered)
            local ok,entry=pcall(function()
                if (registered and a.bIsRegistered~=true) or a.bNeedToHide==true then return nil end
                -- Hidden by the story (seen in the classroom: six students not yet in
                -- the scene are registered with their actor hidden).
                if a.bHidden==true then return nil end
                -- The object's visible model (ObjectActor) is hidden until the story
                -- shows it: the bathroom butterfly's model starts hidden and is
                -- revealed when it flies in, though its actions have no conditions.
                local model=nil;pcall(function()model=a.ObjectActor end)
                if valid(model) and model.bHidden==true then
                    if M.trace_gates then pcall(function()M.report("scanner_model_hidden id="..a:GetFName():ToString())end) end
                    return nil
                end
                if not available(a,is_active) then
                    -- "Look at it" conditions: a level script sets a *_Check_* fact
                    -- only while the camera points at the object (4 Nov: the diner
                    -- truck's Photo needs E3_6B_DinerPark_LD_Check_Truck, set by a
                    -- screen-centre check). Facing it is how the player meets
                    -- them, so the object stays listed for Face to turn to.
                    -- bObjectInDisplay is NOT permission to bypass story gates:
                    -- the classroom camera/pencilcase have it set before their
                    -- photo prerequisite. Relax only the reviewed camera facts.
                    local looking=function(f)if M.LOOK_FACTS[f] then return true end;return is_active(f) end
                    if not available(a,looking) then return nil end
                end
                local key=a.objectName:ToString()
                if key=="" or key=="None" then return nil end
                local label=M.translate(key)
                local id=a:GetFullName()
                -- Doors are named for the room they lead to ("Science lab door").
                local door=rooms.door_label(id)
                if door then label=M.text("door_label",{name=door}) end
                -- Where to stand: the game's authored approach point, else the actor.
                local stand=nil
                local dummy=a.TapToMoveActor
                if valid(dummy) then stand=point(dummy:K2_GetActorLocation()) end
            -- The object's own interaction radius, when the level sets one (the
            -- diner truck: 23.5 m; the Photo action appeared at about 23 m).
            local zone=nil;pcall(function()local z=a.OverrideInnerZoneRadius;if type(z)=="number" and z>0 then zone=z end end)
                return {id=id,label=label,pos=point(a:K2_GetActorLocation()),stand=stand,actor=a,kind="interaction",zone=zone,
                    sublevel=rooms.sublevel(id),is_door=door~=nil or key=="$GT_Sensen_Int_Door01",
                    door_like=door~=nil or rooms.door_like(id,key,label)~=false}
            end)
            if ok and entry then out[#out+1]=entry;seen[entry.id]=true;if registered then remembered[entry.id]=a end
            elseif not ok then report_once("read:"..tostring(#out),"scanner_source read_error="..tostring(entry)) end
    end
    for _,a in ipairs(actors) do
        -- Diagnostic (test sessions): the visibility state of every registered
        -- object, once per object, to find what marks story-gated ones.
        if M.trace_gates then pcall(function()
            local id=a:GetFName():ToString()
            local v={}
            for _,f in ipairs({"bHidden","bIsRegistered","bNeedToHide","bObjectInDisplay","bByPassVisiblityTest","bShowNameEvenIfNoActionAvailable","CurrentZoneStatus"}) do
                local ok,x=pcall(function()return a[f]end);v[#v+1]=f.."="..(ok and tostring(x) or "err")
            end
            local ok,h=pcall(function()return a:IsHidden()end);v[#v+1]="IsHidden="..(ok and tostring(h) or "err")
            local oa=nil;pcall(function()oa=a.ObjectActor end)
            if oa then local ok2,h2=pcall(function()return oa:IsHidden()end);v[#v+1]="object_hidden="..(ok2 and tostring(h2) or "err") end
            v[#v+1]="enabled="..tostring(any_enabled(a))
            local line=table.concat(v," ")
            if M.gate_seen[id]~=line then M.gate_seen[id]=line;M.report("scanner_gate id="..id.." "..line) end
        end) end
        read(a,true)
    end
    -- Objects the game registered earlier on this visit and has since dropped
    -- (3 Nov: the diner's truck and the dorms' broken lamp went on and off the
    -- list; the game deregisters some objects by distance). Kept, with the same
    -- story and visibility checks, so the list does not flicker.
    for id,a in pairs(remembered) do
        if not seen[id] then
            local before=#out
            local ok_valid=valid(a)
            if ok_valid then read(a,false) end
            -- Why a remembered object is or is not back on the list (3 Nov: the
            -- diner's truck still flickered; logged on each change).
            local why=not ok_valid and "invalid" or (#out>before and "kept") or "dropped"
            if why~="kept" and ok_valid then
                pcall(function()
                    local parts={}
                    for _,f in ipairs({"bIsRegistered","bNeedToHide","bHidden"}) do local ok2,x=pcall(function()return a[f]end);parts[#parts+1]=f.."="..(ok2 and tostring(x) or "err") end
                    local m=nil;pcall(function()m=a.ObjectActor end)
                    parts[#parts+1]="model_hidden="..tostring(valid(m) and m.bHidden==true)
                    parts[#parts+1]="enabled="..tostring(any_enabled(a))
                    -- Which story conditions say no (3 Nov: the truck is dropped
                    -- with every visible flag fine, so a condition must fail).
                    local is=availability.fact_reader(controller)
                    local bad={}
                    for _,c in ipairs(enabled_conditions(a)) do
                        for _,f in ipairs(c["and"] or {}) do local now=is(f.fact);if now~=nil and now~=f.want then bad[#bad+1]=f.fact.."="..tostring(now) end end
                        for _,f in ipairs(c["or"] or {}) do bad[#bad+1]="or:"..f.fact.."="..tostring(is(f.fact)) end
                    end
                    parts[#parts+1]="failing="..(#bad>0 and table.concat(bad,",") or "none")
                    why=why.." "..table.concat(parts," ")
                end)
            end
            local short=id:match("LiSInteractionActor_(.+)$") or id
            if dropout_logged[id]~=why then dropout_logged[id]=why;M.report("scanner_remembered "..short.." "..why) end
        end
    end
end
local function goals(out)
    for _,g in ipairs(M.goals) do
        for _,a in ipairs(FindAllOf(g.class) or {}) do
            local ok,match=pcall(function()return valid(a) and a:GetFName():ToString()==g.actor and a:GetFullName():find(g.level,1,true)~=nil end)
            if ok and match then
                local o,e={X=0,Y=0,Z=0},{X=0,Y=0,Z=0}
                local centre=point(a:K2_GetActorLocation())
                if pcall(function()a:GetActorBounds(true,o,e)end) then centre=point(o) end
                -- A doorway-style trigger (FaceTrigger: width, height, front and
                -- back actor lists) fires when Max passes through it, not when she
                -- stands inside it. The walk aims past its centre (see through=).
                local stand={X=centre.X,Y=centre.Y,Z=centre.Z-(e.Z or 0)}
                out[#out+1]={id=a:GetFullName(),label=M.text(g.label_key),pos=centre,stand=stand,kind="goal",through=g.through}
            end
        end
    end
end
-- Exits (loading zones). They are not interaction objects: a DNEVolume whose
-- behaviour components show the game's own exit prompt ("[action_interact] Go
-- To The Main Campus"), stored in the volume's string parameters
-- (ExposParam_STRING, $GT_HUD_Int_...). Found that way in every Episode 1 map
-- that has one. Listed only while one of its behaviour components is active
-- (the corridor has four, one per story stage), and named from the prompt with
-- the key placeholder removed. Max walks into the volume (its live bounds, not
-- the actor pivot, which can lie outside it); the game's own prompt then
-- appears and is used as usual.
local exit_keys_cache={}
local function exit_key(volume)
    local id=nil;pcall(function()id=volume:GetFullName()end)
    if id and exit_keys_cache[id]~=nil then return exit_keys_cache[id] or nil end
    local key=false
    for _,p in ipairs(FindAllOf("ExposParam_STRING") or {}) do
        local ok,hit=pcall(function()
            if p:GetOuter():GetAddress()~=volume:GetAddress() then return nil end
            local v=p.ParamValue:ToString()
            if v:find("^%$GT_HUD_Int_") then return v end
        end)
        if ok and hit then key=hit;break end
    end
    if id then exit_keys_cache[id]=key end
    return key or nil
end
local function exit_active(volume)
    local active=false
    pcall(function()
        for _,c in ipairs(FindAllOf("DNEBehaviorComponent") or {}) do
            local ok,on=pcall(function()return c:GetOuter():GetAddress()==volume:GetAddress() and c.bActive==true end)
            if ok and on then active=true;break end
        end
    end)
    return active
end
function M.exit_label(text)
    -- "[action_interact] Go To The Main Campus" -> "Go To The Main Campus"
    local s=text:gsub("%[[%w_]+%]",""):gsub("^%s+",""):gsub("%s+$","")
    return s
end
local function exits(out)
    for _,v in ipairs(FindAllOf("DNEVolume") or {}) do
        local ok,entry=pcall(function()
            if not valid(v) then return nil end
            local key=exit_key(v)
            if not key then return nil end
            if not exit_active(v) then return nil end
            local o,e={X=0,Y=0,Z=0},{X=0,Y=0,Z=0}
            -- This engine's GetActorBounds takes three arguments (no trailing
            -- bIncludeFromChildActors); the four-argument form raises an error.
            v:GetActorBounds(false,o,e)
            local centre=point(o)
            local prompt=M.translate(key)
            local label=M.exit_label(prompt)
            return {id=v:GetFullName(),label=M.text("exit_label",{name=label}),pos=centre,
                stand={X=centre.X,Y=centre.Y,Z=centre.Z-(e.Z or 0)},kind="exit",
                prompt=prompt,extent={X=e.X,Y=e.Y,Z=e.Z}}
        end)
        if ok and entry then
            out[#out+1]=entry
            report_once("exit_found:"..entry.id,string.format("scanner_exit label=%s at=%.0f,%.0f,%.0f",entry.label,entry.pos.X,entry.pos.Y,entry.pos.Z))
        elseif not ok then report_once("exit:"..tostring(#out),"scanner_source exit_error="..tostring(entry)) end
    end
end
-- Active exits only (for announcing the exit prompt when Max is inside one).
function M.exits()
    local out={}
    exits(out)
    return out
end
-- The ending nightmare's guide (nightmare/guide.lua): one entry, at the next
-- step along the doe's route, worked out afresh from Max's position.
M.guide=require("nightmare.guide")
local function in_ending(controller)
    local ok,name=pcall(function()return controller:GetWorld():GetFName():ToString()end)
    return ok and name=="E1_6B"
end
M.in_ending=in_ending
function M.guide_entry(controller)
    if not in_ending(controller) then return nil end
    local G=M.guide
    local p=nil;pcall(function()p=point(controller.Pawn:K2_GetActorLocation())end)
    if not p then return nil end
    local is_active=availability.fact_reader(controller)
    local held=function(h)if h=="logs" then return G.logs_held(function(f)return is_active(f)==true end) end end
    local i=G.current(p,held)
    local st=G.STEPS[i]
    local name=M.text(st.label)
    local label=M.text("guide_entry",{name=name})
    -- name as well as label: the scanner list adds name, but a chained guide
    -- walk takes this entry straight from here.
    return {id="nightmare_guide",label=label,name=label,pos={X=st.X,Y=st.Y,Z=st.Z},
        stand={X=st.X,Y=st.Y,Z=st.Z},kind="guide",through=st.through,persist=st.persist,reach=st.reach,wait_fact=st.wait_fact,step=i,steps=#G.STEPS,step_name=name,step_id=st.id}
end
-- While Max chooses a shooting target, only the targets: objects whose
-- enabled action is "Shoot" (the plank, monitors, barrel and rim; then the gas
-- tank, bumper, windshield and tire), in the scanner's usual order.
M.shoot_action=function(actor)
    local found=false
    pcall(function()
        actor.Actions:ForEach(function(_,v)
            local ok,x=pcall(function()return v:get()end)
            if ok and not found then
                local on=false;pcall(function()on=x.bEnabled==true end)
                -- The pop-up says "Shoot" from the action's display override
                -- ($GT_HUD_Action_Shoot); its ActionName may be a generic one.
                local n,o="",""
                pcall(function()n=x.ActionName:ToString()end)
                pcall(function()o=x.OverrideDisplayName:ToString()end)
                if on and (n:find("Shoot") or o:find("Shoot")) then found=true end
            end
        end)
    end)
    return found
end
-- The room Max is in (sub-level key) after the last collect, and its spoken name.
M.room=nil
M.ROOM_REACH=50  -- cm: floor samples around Max for the room vote
-- Room filtering on/off (F4 / hold left stick + click right stick). On by
-- default; off lists every object as before, with room names still spoken.
M.ROOM_FILTER=true
function M.toggle_room_filter()M.ROOM_FILTER=not M.ROOM_FILTER;M.report("scanner_room_filter="..tostring(M.ROOM_FILTER));return M.ROOM_FILTER end
-- Floors. Every room's floor is in that room's own geometry level, so the
-- floor under a point names its room exactly (3 Nov: the object vote said
-- "Chloe's room" well into the corridor, because her objects were still the
-- nearest).
local function floor_room(controller,p,ignore,depth)
    local room=nil
    pcall(function()
        local lib=StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
        local hit={}
        local ok=lib:LineTraceSingle(controller,{X=p.X,Y=p.Y,Z=p.Z+60},{X=p.X,Y=p.Y,Z=p.Z-(depth or 300)},0,false,ignore or {},0,hit,true,{R=1,G=0,B=0,A=1},{R=0,G=1,B=0,A=1},0)
        if ok then room=rooms.room_of(hit.Actor:Get():GetFullName()) end
    end)
    return room
end
M.floor_room=floor_room
-- Same standing-position vote for scanner classification and way arrival.
-- p is capsule/standing position, not a navigation point at the feet.
function M.standing_room(controller,p,current)
    local pawn=nil;pcall(function()pawn=controller.Pawn end)
    local keys={floor_room(controller,p,{pawn})}
    for i=0,3 do
        local a=i*math.pi/2
        keys[i+2]=floor_room(controller,{X=p.X+math.cos(a)*M.ROOM_REACH,Y=p.Y+math.sin(a)*M.ROOM_REACH,Z=p.Z},{pawn})
    end
    return rooms.vote(keys,5,current)
end
-- The room of the GROUND below a high point: every surface down the line, the
-- lowest one that names a room (3 Nov: the scared bird at 2513,-659, 1.5 m up
-- over the garden; the first surface below it was the living room's - the
-- house's eaves - so it stayed on the living-room list).
local function ground_room(controller,p)
    local found,n=nil,0
    local ok,err=pcall(function()
        local lib=StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
        local hits={}
        lib:LineTraceMulti(controller,{X=p.X,Y=p.Y,Z=p.Z+60},{X=p.X,Y=p.Y,Z=p.Z-5000},0,true,{},0,hits,true,{R=1,G=0,B=0,A=1},{R=0,G=1,B=0,A=1},0)
        local low=nil
        local function one(h)
            pcall(function()
                local hit=h
                if type(h)=="userdata" or (type(h)=="table" and h.get) then local ok2,g=pcall(function()return h:get()end);if ok2 and g then hit=g end end
                local r=rooms.room_of(hit.Actor:Get():GetFullName())
                local z=hit.ImpactPoint.Z
                n=n+1
                if r and (not low or z<low) then low=z;found=r end
            end)
        end
        -- UE4SS fills an out array as a plain Lua list (3 Nov: the earlier
        -- hits:ForEach failed silently, so every moved object fell back).
        if type(hits)=="table" and #hits>0 then for _,h in ipairs(hits) do one(h) end
        else pcall(function()hits:ForEach(function(_,h)one(h)end)end) end
    end)
    if not ok then report_once("ground_room","scanner_ground_error="..tostring(err)) end
    return found,n
end
M.ground_room=ground_room
-- Rooms around each door-like object, measured once per level visit: floors
-- 120 cm away in eight directions. Two or more rooms = a way between them.
local joins_cache,joins_world={},nil
-- Objects that move (3 Nov: the scared bird flies from the living room out to
-- the garden, but its level is still the living room's). An object more than
-- MOVED_CM from where it was first seen takes its room from the floor under
-- it now; re-measured only when it has moved again.
M.MOVED_CM=150
-- Short-lived route evidence: doors can change without a level/room change.
local ways_cache={}
M.way_clock=os.time
M.WAY_REFRESH=3 -- seconds; includes previously empty results
M.WAY_MOVE=150  -- cm; re-evaluate from a meaningfully different position
M.WAY_STEP=50     -- cm between floor samples along a route
M.WAY_INTO=120    -- cm past the threshold for the entry's point
M.WAY_TRIES=12    -- candidate points tried per room
M.WAY_DOOR_NEAR=250 -- cm: a door this close to a route's threshold is the way
-- Rooms' geometry, measured once per level visit: for every room, the
-- positions of its geometry actors (floors, walls). Lets a way be found into a
-- room none of whose objects the game has registered (3 Nov: no bathroom
-- object was ever in the list, so the first version had nothing to aim at).
-- Also logs, once, how many interaction objects each room has in the world
-- against how many the player's component registered.
local geometry=nil
local world_objects={}
local function room_geometry(controller)
    if geometry then return geometry end
    geometry={}
    pcall(function()
        for _,a in ipairs(FindAllOf("StaticMeshActor") or {}) do
            pcall(function()
                local r=rooms.room_of(a:GetFullName())
                if not r then return end
                local g=geometry[r];if not g then g={};geometry[r]=g end
                if #g<400 then local v=a:K2_GetActorLocation();g[#g+1]={X=v.X,Y=v.Y,Z=v.Z} end
            end)
        end
    end)
    world_objects={}
    pcall(function()
        local world={}
        for _,a in ipairs(FindAllOf("LiSInteractionActor") or {}) do
            pcall(function()
                local r=rooms.sublevel(a:GetFullName());if not r then return end
                world[r]=(world[r] or 0)+1
                local v=a:K2_GetActorLocation()
                -- Placeholders sit at the level origin (the bathroom bird at 0,-2).
                if math.abs(v.X)+math.abs(v.Y)>50 then
                    local l=world_objects[r];if not l then l={};world_objects[r]=l end
                    l[#l+1]={X=v.X,Y=v.Y,Z=v.Z}
                end
            end)
        end
        local parts={}
        for r,n in pairs(world) do parts[#parts+1]=r.."="..n end
        table.sort(parts)
        local g={};for r,list in pairs(geometry) do g[#g+1]=r.."="..#list end;table.sort(g)
        M.report("scanner_rooms_world objects "..table.concat(parts,",").." | geometry "..table.concat(g,","))
    end)
    return geometry
end
-- Pure: the room whose geometry point is nearest to p on the ground plan.
function M.nearest_room(geo,p)
    local best,bd=nil,math.huge
    for r,list in pairs(geo or {}) do
        for _,v in ipairs(list) do
            local d=(v.X-p.X)^2+(v.Y-p.Y)^2
            if d<bd then bd=d;best=r end
        end
    end
    return best
end
-- Ways follow complete, doorway-aware native paths, not room-pair proxies.
local function ways_from(controller,out,room,p)
    local now=M.way_clock()
    local signature={}
    for _,e in ipairs(out) do
        if e.pos then signature[#signature+1]=tostring(e.id)..":"..tostring(e.sublevel)..":"..math.floor(e.pos.X/100)..","..math.floor(e.pos.Y/100)..","..math.floor(e.pos.Z/100) end
    end
    table.sort(signature);signature=table.concat(signature,";")
    local cached=ways_cache[room]
    if cached and now-cached.time<M.WAY_REFRESH and cached.signature==signature
        and (p.X-cached.pos.X)^2+(p.Y-cached.pos.Y)^2+(p.Z-cached.pos.Z)^2<M.WAY_MOVE^2 then return cached.found end
    local found={}
    ways_cache[room]={time=now,pos={X=p.X,Y=p.Y,Z=p.Z},signature=signature,found=found}
    M.report("scanner_room_ways_check room="..tostring(room))
    local route=require("nav.route")
    local doors=require("nav.doors")
    local survey -- shared lazily across all candidate rooms in this refresh
    -- Candidate points per other room: its registered objects, else its
    -- objects in the world, else its geometry; nearest to Max first.
    local cands={}
    local function add(r,v)
        if r==room then return end
        local l=cands[r];if not l then l={};cands[r]=l end
        l[#l+1]={d=(v.X-p.X)^2+(v.Y-p.Y)^2,pos=v}
    end
    for _,e in ipairs(out) do
        if e.kind=="interaction" and e.sublevel and e.pos then add(e.sublevel,e.pos) end
    end
    local best={}
    -- Rooms with no registered object: aim at their objects in the world (the
    -- game had not registered any of the bathroom's six), else their geometry.
    local geo=room_geometry(controller)
    for r,list in pairs(world_objects) do for _,v in ipairs(list) do add(r,v) end end
    for r,list in pairs(geo) do for _,v in ipairs(list) do add(r,v) end end
    for r,l in pairs(cands) do table.sort(l,function(a,c)return a.d<c.d end);best[r]=l end
    for target,list in pairs(best) do
        local okw,errw=pcall(function()
            -- Objects hang on walls and above the floor (3 Nov: the mirror, 1 m
            -- up a wall, never projected with a 50 cm search): try each
            -- candidate at floor height with a 150 cm search, nearest first.
            local oks,start=route.project(controller,p)
            if not oks then M.report("scanner_room_way_none "..room.." -> "..target.." reason=unprojected_start");return end
            local tried,planned,complete=0,0,0
            local represented={}
            local function prepare()
                if not survey then survey=doors.survey(controller,controller.Pawn,function()end) end
                for _,e in ipairs(out) do
                    if e.door_like and e.pos then
                        local nearest,dist=nil,M.WAY_DOOR_NEAR^2
                        for _,d in ipairs(survey) do
                            local dd=(e.pos.X-d.centre.X)^2+(e.pos.Y-d.centre.Y)^2
                            if math.abs(e.pos.Z-d.centre.Z)<200 and dd<dist then nearest=d;dist=dd end
                        end
                        if nearest then represented[nearest]=true end
                    end
                end
            end
            local function evaluate(pts)
                complete=complete+1
                -- Sample actual native legs, retaining their bends for activation.
                local samples,keys,segments={},{},{}
                for i=2,#pts do
                    local a,c=pts[i-1],pts[i]
                    local len=math.sqrt((c.X-a.X)^2+(c.Y-a.Y)^2)
                    local steps=math.max(1,math.ceil(len/M.WAY_STEP))
                    for s=0,steps-1 do
                        local f=s/steps
                        samples[#samples+1]={X=a.X+(c.X-a.X)*f,Y=a.Y+(c.Y-a.Y)*f,Z=a.Z+(c.Z-a.Z)*f}
                        segments[#samples]=i
                    end
                end
                samples[#samples+1]=pts[#pts];segments[#samples]=#pts
                for i,sp in ipairs(samples) do keys[i]=floor_room(controller,{X=sp.X,Y=sp.Y,Z=sp.Z+40},{}) end
                local i,k=rooms.entered(keys,#samples,room)
                if k~=target then
                    M.report(string.format("scanner_room_way_none %s -> %s first=%s samples=%d",room,target,tostring(k),#samples))
                    return false
                end
                local j=i
                for n=i+1,math.min(#samples,i+math.floor(M.WAY_INTO/M.WAY_STEP)) do
                    if keys[n]~=target then break end
                    j=n
                end
                local via,avoid,prefix={},{},{pts[1]}
                for n=2,segments[j]-1 do via[#via+1]=pts[n];prefix[#prefix+1]=pts[n] end
                via[#via+1]=samples[j];prefix[#prefix+1]=samples[j]
                for d in pairs(represented) do
                    -- A listed portal represents only itself, regardless of
                    -- whether the collision survey reports it open or closed.
                    if doors.represents(prefix,d) then
                        M.report(string.format("scanner_room_way_skip %s -> %s reason=represented_portal doorway=%s",room,target,tostring(d.index)))
                        return false
                    end
                    avoid[#avoid+1]={centre=d.centre,nx=d.nx,ny=d.ny}
                end
                -- The current standing vote is NOT target. A goal already in
                -- follower acceptance range could announce arrival without a
                -- room transition; keep looking for a meaningful approach.
                local arrival=require("nav.arrival")
                if (samples[j].X-p.X)^2+(samples[j].Y-p.Y)^2<=arrival.RADIUS^2
                    and math.abs(samples[j].Z-start.Z)<=arrival.HEIGHT then return false end
                found[#found+1]={room=target,pos=samples[j],via=via,avoid=avoid}
                M.report(string.format("scanner_room_way %s -> %s at=%.0f,%.0f via=%d",room,target,samples[j].X,samples[j].Y,#via))
                return true
            end
            -- First keep the usual geometry/object route, including openings
            -- the mesh-name survey does not discover. Duplicates reject THIS
            -- route, never the whole target room.
            for _,c in ipairs(list) do
                if tried>=M.WAY_TRIES then break end
                tried=tried+1
                local o,goal=route.project(controller,{X=c.pos.X,Y=c.pos.Y,Z=p.Z},{X=150,Y=150,Z=300})
                if o and goal and floor_room(controller,{X=goal.X,Y=goal.Y,Z=goal.Z+40},{})==target then
                    prepare()
                    planned=planned+1
                    local plan,pts=doors.plan(controller,controller.Pawn,start,goal,function()end,nil,survey)
                    if plan~=false and pts and #pts>=2 and evaluate(pts) then return end
                end -- projected candidate in target room
            end -- try other candidates, including after a missing/blocked route
            -- A shorter represented entrance must not hide a distinct portal.
            -- Query its near side and crossing explicitly, not another final
            -- destination whose shortest route could use the same bad door.
            prepare()
            local avoid={};for d in pairs(represented) do avoid[#avoid+1]=d end
            for _,d in ipairs(survey) do
                if d.state=="open" and not represented[d] and d.sides then
                    for order=1,2 do
                        local near,far=d.sides[order],d.sides[3-order]
                        if near and far and floor_room(controller,{X=far.X,Y=far.Y,Z=far.Z+40},{})==target then
                            local pts=doors.approach(controller,controller.Pawn,start,{near,far},function()end,survey,avoid)
                            if pts and evaluate(pts) then return end
                        end
                    end
                end
            end
            M.report(string.format("scanner_room_way_none %s -> %s reason=no_usable_route tried=%d planned=%d complete=%d",room,target,tried,planned,complete))
        end)
        if not okw then M.report("scanner_room_way_none "..room.." -> "..target.." reason=error "..tostring(errw)) end
    end
    return found
end
local first_seen,moved_room={},{}
local function joins_of(controller,e)
    if joins_cache[e.id]~=nil then return joins_cache[e.id] or nil end
    local keys={}
    for i=0,7 do
        local a=i*math.pi/4
        keys[i+1]=floor_room(controller,{X=e.pos.X+math.cos(a)*120,Y=e.pos.Y+math.sin(a)*120,Z=e.pos.Z})
    end
    local set,isjoin=rooms.joins(keys,8)
    joins_cache[e.id]=isjoin and set or false
    if isjoin then
        local names={};for k in pairs(set) do names[#names+1]=k end;table.sort(names)
        M.report("scanner_door_joins "..tostring(e.label).." rooms="..table.concat(names,","))
    end
    return isjoin and set or nil
end
-- The room step of collect, on its own so it can be tested with a fake world:
-- room from the floor under Max (the object vote where no room floor is
-- found: open areas built as one level, or a missed trace), doors judged by
-- the floors around them, then the filter.
function M.by_room(controller,out,p)
    local world=nil;pcall(function()
        local w=controller:GetWorld()
        world=w:GetFName():ToString()
        pcall(function()world=world..":"..tostring(w:GetAddress())end)
    end)
    if world~=joins_world then joins_cache={};joins_world=world;first_seen={};moved_room={};ways_cache={};geometry=nil end
    for _,e in ipairs(out) do
        if e.kind=="interaction" and e.pos and e.sublevel then
            local f=first_seen[e.id]
            if not f then first_seen[e.id]={X=e.pos.X,Y=e.pos.Y}
            elseif (e.pos.X-f.X)^2+(e.pos.Y-f.Y)^2>M.MOVED_CM^2 then
                local m=moved_room[e.id]
                if not m or (e.pos.X-m.X)^2+(e.pos.Y-m.Y)^2>100^2 then
                    -- A flying or perched object can be metres up: trace far
                    -- down; if that finds no room, the room whose geometry is
                    -- nearest on the ground plan (3 Nov: the bird, 14 m out,
                    -- never got a room from a 3 m trace).
                    local r,hits=ground_room(controller,e.pos)
                    local how="ground"..(hits and ("/"..hits) or "")
                    if not r then r=floor_room(controller,e.pos,{},5000);how="floor" end
                    if not r then r=M.nearest_room(room_geometry(controller),e.pos);how="geometry" end
                    moved_room[e.id]={X=e.pos.X,Y=e.pos.Y,room=r}
                    M.report(string.format("scanner_moved %s at=%.0f,%.0f,%.0f room=%s by=%s",tostring(e.label),e.pos.X,e.pos.Y,e.pos.Z,tostring(r),how))
                    m=moved_room[e.id]
                end
                if m.room then e.sublevel=m.room end
            end
        end
    end
    -- Floor under Max and 50 cm out in four directions; a new room needs a
    -- majority of them.
    local room=M.standing_room(controller,p,M.room)
    local how="floor"
    if not room then room=rooms.current(out,p);how="objects" end
    for _,e in ipairs(out) do if e.door_like and e.kind=="interaction" then e.joins=joins_of(controller,e) end end
    if room~=M.room then M.room=room;M.report("scanner_room="..tostring(room).." by="..how) end
    -- Totals for the "N in all" hint: everything here, before the filter.
    M.total=#out
    -- Room filter switched off by the player (F4): everything, as before rooms.
    if not M.ROOM_FILTER then M.filtered=false;return out end
    M.filtered=true
    local kept=rooms.filter(out,room)
    -- Ways into neighbouring rooms reached through an open doorway.
    if room and how=="floor" then
        for _,w in ipairs(ways_from(controller,out,room,p)) do
            local name=rooms.room_name(w.room)
            kept[#kept+1]={id="way:"..w.room,label=M.text("room_way",{name=rooms.way_name(name)}),pos=w.pos,stand=w.pos,kind="goal",way_via=w.via,way_avoid=w.avoid,way_room=w.room,way_from=room}
        end
    end
    -- When the room changes, which objects of that room were dropped and why
    -- (3 Nov: the bathroom mirror was missing and no log said why).
    if M.room_logged~=room then
        M.room_logged=room
        local shown={};for _,e in ipairs(kept) do shown[e]=true end
        local hidden=0
        for _,e in ipairs(out) do if not shown[e] and e.sublevel==room then hidden=hidden+1;M.report("scanner_room_hidden "..tostring(e.label).." joins="..tostring(e.joins~=nil)) end end
        M.report(string.format("scanner_room_list room=%s shown=%d of=%d own_hidden=%d",tostring(room),#kept,#out,hidden))
    end
    return kept
end
function M.collect(controller)
    local out={}
    interactions(controller,out)
    -- Only the current room's objects, plus doors and everything else.
    local p=nil;pcall(function()p=point(controller.Pawn:K2_GetActorLocation())end)
    if p then out=M.by_room(controller,out,p) end
    -- Episode 3 principal's office: walk through the door to its other side.
    do local ok,e=pcall(require("scenes.principal_office").entry,controller);if ok and e then out[#out+1]=e elseif not ok then report_once("office","scanner_source office_error="..tostring(e)) end end
    -- Episode 3 pool: the way to the hall and the hiding spot behind the lockers.
    do local ok,list=pcall(require("scenes.pool_guard").entries,controller);if ok then for _,e in ipairs(list) do out[#out+1]=e end else report_once("pool_guard","scanner_source pool_guard_error="..tostring(list)) end end
    local aok,aiming=pcall(require("scenes.junkyard_shooting").aiming,controller)
    if aok and aiming then
        local before=#out
        local names={}
        for i=#out,1,-1 do
            local e=out[i]
            local keep=false;pcall(function()keep=M.shoot_action(e.actor)end)
            if not keep then names[#names+1]=tostring(e.label);table.remove(out,i) end
        end
        -- Never fail silently: once per aiming phase, what was kept and dropped.
        local line="scanner_aiming before="..before.." kept="..#out.." dropped="..table.concat(names,"|")
        if M.last_aiming~=line then M.last_aiming=line;M.report(line) end
        return out
    end
    goals(out)
    exits(out)
    local ok,g=pcall(M.guide_entry,controller)
    if ok and g then
        -- The newspaper is the guide's last step: listed on its own only once
        -- the guide has reached it, so the guide is the one entry until then.
        if g.step_id~="newspaper" then
            for i=#out,1,-1 do if out[i].kind=="interaction" then table.remove(out,i) end end
        end
        out[#out+1]=g
    elseif not ok then report_once("guide","scanner_source guide_error="..tostring(g)) end
    return out
end
return M
