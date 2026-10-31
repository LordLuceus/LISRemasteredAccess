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
                sublevel=rooms.sublevel(id),is_door=door~=nil or key=="$GT_Sensen_Int_Door01"}
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
function M.collect(controller)
    local out={}
    interactions(controller,out)
    -- Only the current room's objects, plus doors and everything else.
    local p=nil;pcall(function()p=point(controller.Pawn:K2_GetActorLocation())end)
    if p then
        local room=rooms.current(out,p)
        if room~=M.room then M.room=room;M.report("scanner_room="..tostring(room)) end
        out=rooms.filter(out,room)
    end
    -- Episode 3 principal's office: walk through the door to its other side.
    do local ok,e=pcall(require("scenes.principal_office").entry,controller);if ok and e then out[#out+1]=e end end
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
