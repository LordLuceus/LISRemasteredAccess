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
local function interactions(controller,out)
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
        local ok,entry=pcall(function()
            if a.bIsRegistered~=true or a.bNeedToHide==true then return nil end
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
            if not available(a,is_active) then return nil end
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
            return {id=id,label=label,pos=point(a:K2_GetActorLocation()),stand=stand,actor=a,kind="interaction",
                sublevel=rooms.sublevel(id),is_door=door~=nil or key=="$GT_Sensen_Int_Door01",
                door_like=door~=nil or rooms.door_like(id,key,label)~=false}
        end)
        if ok and entry then out[#out+1]=entry elseif not ok then report_once("read:"..tostring(#out),"scanner_source read_error="..tostring(entry)) end
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
-- Rooms around each door-like object, measured once per level visit: floors
-- 120 cm away in eight directions. Two or more rooms = a way between them.
local joins_cache,joins_world={},nil
-- Neighbouring rooms without a door, per room, measured once per level visit.
local ways_cache={}
M.WAY_STEP=50     -- cm between floor samples along a route
M.WAY_INTO=120    -- cm past the threshold for the entry's point
M.WAY_TRIES=12    -- candidate points tried per room
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
-- Ways from `room` into each neighbouring room no listed door already joins.
local function ways_from(controller,out,room,p)
    if ways_cache[room] then return ways_cache[room] end
    local found={}
    ways_cache[room]=found
    M.report("scanner_room_ways_check room="..tostring(room))
    local route=require("nav.route")
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
        local doored=false
        for _,e in ipairs(out) do if e.joins and e.joins[room] and e.joins[target] then doored=true end end
        if not doored then local okw,errw=pcall(function()
            -- Objects hang on walls and above the floor (3 Nov: the mirror, 1 m
            -- up a wall, never projected with a 50 cm search): try each
            -- candidate at floor height with a 150 cm search, nearest first.
            local okg,goal=false,nil
            local tried=0
            for _,c in ipairs(list) do
                if tried>=M.WAY_TRIES then break end
                tried=tried+1
                local o,g=route.project(controller,{X=c.pos.X,Y=c.pos.Y,Z=p.Z},{X=150,Y=150,Z=300})
                if o and g and rooms.room_of and floor_room(controller,{X=g.X,Y=g.Y,Z=g.Z+40},{})==target then okg,goal=true,g;break end
            end
            local oks,start=route.project(controller,p)
            if not (okg and oks) then M.report(string.format("scanner_room_way_none %s -> %s reason=unprojected target=%s start=%s tried=%d",room,target,tostring(okg),tostring(oks),tried));return end
            local _,_,pts=route.query(controller,controller.Pawn,"way",start,goal,function()end)
            if not pts or #pts<2 then M.report(string.format("scanner_room_way_none %s -> %s reason=no_route",room,target));return end
            -- Floor samples every WAY_STEP cm along the route.
            local samples,keys={},{}
            for i=2,#pts do
                local a,c=pts[i-1],pts[i]
                local len=math.sqrt((c.X-a.X)^2+(c.Y-a.Y)^2)
                local steps=math.max(1,math.floor(len/M.WAY_STEP))
                for s=0,steps-1 do
                    local f=s/steps
                    samples[#samples+1]={X=a.X+(c.X-a.X)*f,Y=a.Y+(c.Y-a.Y)*f,Z=a.Z+(c.Z-a.Z)*f}
                end
            end
            samples[#samples+1]=pts[#pts]
            for i,sp in ipairs(samples) do keys[i]=floor_room(controller,{X=sp.X,Y=sp.Y,Z=sp.Z+40},{}) end
            local i,k=rooms.entered(keys,#samples,room)
            if k~=target then M.report(string.format("scanner_room_way_none %s -> %s first=%s samples=%d",room,target,tostring(k),#samples)) end
            if k==target then
                local j=math.min(#samples,i+math.floor(M.WAY_INTO/M.WAY_STEP))
                found[#found+1]={room=target,pos=samples[j]}
                M.report(string.format("scanner_room_way %s -> %s at=%.0f,%.0f",room,target,samples[j].X,samples[j].Y))
            end
        end)
        if not okw then M.report("scanner_room_way_none "..room.." -> "..target.." reason=error "..tostring(errw)) end
        else M.report("scanner_room_way_skip "..room.." -> "..target.." reason=door") end
    end
    return found
end
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
    local world=nil;pcall(function()world=controller:GetWorld():GetFName():ToString()end)
    if world~=joins_world then joins_cache={};joins_world=world;ways_cache={};geometry=nil end
    local pawn=nil;pcall(function()pawn=controller.Pawn end)
    local room=floor_room(controller,p,{pawn})
    local how="floor"
    if not room then room=rooms.current(out,p);how="objects" end
    for _,e in ipairs(out) do if e.door_like and e.kind=="interaction" then e.joins=joins_of(controller,e) end end
    if room~=M.room then M.room=room;M.report("scanner_room="..tostring(room).." by="..how) end
    local kept=rooms.filter(out,room)
    -- Ways into neighbouring rooms reached through an open doorway.
    if room and how=="floor" then
        for _,w in ipairs(ways_from(controller,out,room,p)) do
            local name=rooms.room_name(w.room)
            kept[#kept+1]={id="way:"..w.room,label=M.text("room_way",{name=rooms.way_name(name)}),pos=w.pos,stand=w.pos,kind="goal"}
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
