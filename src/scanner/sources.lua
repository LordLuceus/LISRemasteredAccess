-- Where scanner entries come from, in the live game. Read-only.
-- 1. The game's own interaction list: the player controller's interaction
--    component keeps RegisteredActors (LiSInteractionActor). An actor counts
--    when it is registered, not hidden, and has at least one enabled action.
--    Its name is objectName ("$GT_Sensen_Int_Bottle01"), translated by the game.
-- 2. Scene goals the game has no interaction for (the opening nightmare's
--    lighthouse), from a small table keyed by the scene's level and actor name.
local M={}
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
local function any_enabled(actor)
    local any=false
    pcall(function()
        actor.Actions:ForEach(function(_,v)
            local ok,e=pcall(function()return v:get().bEnabled end)
            if ok and e==true then any=true end
        end)
    end)
    return any
end
local function interactions(controller,out)
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
        local ok,entry=pcall(function()
            if a.bIsRegistered~=true or a.bNeedToHide==true then return nil end
            if not any_enabled(a) then return nil end
            local key=a.objectName:ToString()
            if key=="" or key=="None" then return nil end
            local label=M.translate(key)
            -- Where to stand: the game's authored approach point, else the actor.
            local stand=nil
            local dummy=a.TapToMoveActor
            if valid(dummy) then stand=point(dummy:K2_GetActorLocation()) end
            return {id=a:GetFullName(),label=label,pos=point(a:K2_GetActorLocation()),stand=stand,actor=a,kind="interaction"}
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
                if pcall(function()a:GetActorBounds(true,o,e,false)end) then centre=point(o) end
                -- A doorway-style trigger (FaceTrigger: width, height, front and
                -- back actor lists) fires when Max passes through it, not when she
                -- stands inside it. The walk aims past its centre (see through=).
                local stand={X=centre.X,Y=centre.Y,Z=centre.Z-(e.Z or 0)}
                out[#out+1]={id=a:GetFullName(),label=M.text(g.label_key),pos=centre,stand=stand,kind="goal",through=g.through}
            end
        end
    end
end
function M.collect(controller)
    local out={}
    interactions(controller,out)
    goals(out)
    return out
end
return M
