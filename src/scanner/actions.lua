-- Interactions with the object the GAME has focused (not the scanner
-- selection: the probe showed focus stays on the last object in reach).
-- * When the focused object changes, it is announced with its available
--   actions and their keys: "Door. 1, Open."
-- * Keys 1-4 trigger the action through the object's own TriggerActionBP,
--   after re-checking that the same object is still focused with its
--   interaction open and the action still enabled.
-- Reads single values every tick and the action list only when focus changes.
local M={}
M.say=function(_)end
M.log=function(_)end
M.text=function(key,p)return key end
M.translate=function(key)return key end
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid()end)
    return ok and r==true
end
-- Label key for an action: its display override, else its name without the
-- trailing number ("Look01" -> Look). Pure, offline tested.
function M.label_key(action_name,override)
    if override and override~="" and override~="None" then
        -- Overrides may already be a complete text key ("$GT_Sensen_Action_Read").
        if override:sub(1,1)=="$" then return override end
        return "$GT_Sensen_Action_"..override
    end
    return "$GT_Sensen_Action_"..(action_name or ""):gsub("%d+$","")
end
-- Spoken announcement for a focused object. Pure, offline tested.
-- The key spoken before each action: its number on the keyboard, or its face
-- button on a controller when the pop-up slot is known. Supplied by the caller.
M.key_name=function(position,_slot)return tostring(position) end
-- labels: strings, or {label=,slot=} entries.
function M.announce_text(name,labels)
    if #labels==0 then return M.text("focus_no_actions",{name=name}) end
    local parts={}
    for i,l in ipairs(labels) do
        local label,slot=l,nil
        if type(l)=="table" then label,slot=l.label,l.slot end
        parts[#parts+1]=M.text("focus_action",{index=M.key_name(i,slot),label=label})
    end
    return M.text("focus_actions",{name=name,actions=table.concat(parts,", ")})
end
local function component(controller)
    local all=FindAllOf("LiSInteractionComponent") or {}
    for _,c in ipairs(all) do
        local ok,own=pcall(function()return valid(c) and c:GetOwner():GetAddress()==controller:GetAddress()end)
        if ok and own then return c end
    end
end
-- The game's focused object and whether its interaction is open.
function M.focused(controller)
    local c=component(controller)
    if not c then return nil end
    local f=nil;pcall(function()f=c.ActorInteractionFocused end)
    if not valid(f) then return nil end
    local open=false;pcall(function()open=f.bIsInteractionUIOpened==true end)
    return f,open
end
-- Enabled actions of an object: {index=0-based Actions index, label=spoken}.
function M.available(actor)
    -- Copy plain values out INSIDE the iteration. Element references from a game
    -- array must not outlive it, and no game function (such as the translator)
    -- may run while any are held: the loader crashed when they did.
    local raw={}
    pcall(function()
        actor.Actions:ForEach(function(i,v)
            local ok,x=pcall(function()return v:get()end)
            if not ok then return end
            local on=false;pcall(function()on=x.bEnabled==true end)
            if on then
                local name,override,kind,sub=nil,nil,nil,nil
                pcall(function()name=x.ActionName:ToString()end)
                pcall(function()override=x.OverrideDisplayName:ToString()end)
                pcall(function()kind=tostring(x.ActionType)end)
                pcall(function()sub=tostring(x.ActionSubType)end)
                raw[#raw+1]={index=i-1,name=name,override=override,kind=kind,sub=sub}
            end
        end)
    end)
    local out={}
    local desc={}
    for _,r in ipairs(raw) do desc[#desc+1]=string.format("%d:%s/%s/%s/%s",r.index,tostring(r.name),tostring(r.override),tostring(r.kind),tostring(r.sub)) end
    if M.trace_popup then M.log("focus_actions_raw "..table.concat(desc," ")) end
    for _,r in ipairs(raw) do
        local key=M.label_key(r.name,r.override)
        out[#out+1]={index=r.index,name=r.name,key=key,label=M.translate(key)}
    end
    return out
end
local function object_name(actor)
    local key=nil;pcall(function()key=actor.objectName:ToString()end)
    return key and M.translate(key) or "?"
end
-- The actions the game's own pop-up offers. Its TextValues hold one label key
-- per button slot (1-4, then the object name) and buttonN_visible says which
-- buttons are shown. The raw action list can hold several enabled actions with
-- the same label (Look01 and Look02) that the pop-up shows as one button, so
-- the spoken list comes from the pop-up; each button is matched to the first
-- enabled action with the same label for triggering. Pure part: M.from_popup.
function M.from_popup(texts,visible,actions)
    local out,used={},{}
    for k=1,4 do
        local key=texts[k]
        if visible[k] and key and key:find("^%$") then
            for _,a in ipairs(actions) do
                if not used[a.index] and a.key==key then
                    used[a.index]=true
                    out[#out+1]={index=a.index,name=a.name,label=a.label,slot=k}
                    break
                end
            end
        end
    end
    return out
end
local function popup(actor)
    local texts,visible={},{}
    local ok=pcall(function()
        local w=actor:GetInteractionWidget()
        if not valid(w) then error("no widget") end
        local list={}
        w.TextValues:ForEach(function(_,v)local tok,s=pcall(function()return v:get():ToString()end);list[#list+1]=tok and s or "" end)
        texts=list
        for k=1,4 do local vok,v=pcall(function()return w["button"..k.."_visible"]end);visible[k]=vok and v==true end
    end)
    return ok,texts,visible
end
-- What the player can do now: the pop-up's buttons, else the raw list.
function M.offered(actor)
    local actions=M.available(actor)
    local ok,texts,visible=popup(actor)
    if ok then
        local list=M.from_popup(texts,visible,actions)
        if #list>0 then return list end
    end
    return actions
end
local last_address,last_open=nil,nil
-- The same object is not re-announced within REPEAT_GAP seconds of its last
-- automatic announcement: focus flickers while Max settles after walking.
M.REPEAT_GAP=3
local last_spoken_address,last_spoken_at=nil,-math.huge
M.clock=os.clock
-- Announces the focused object (called by facing as well as on change).
function M.announce(controller)
    local f=M.focused(controller)
    if not f then return false end
    local actions=M.offered(f)
    -- Diagnostic (test sessions): the pop-up's own button texts, in slot order.
    if M.trace_popup then
        local texts={}
        pcall(function()
            local w=f:GetInteractionWidget()
            local list={}
            w.TextValues:ForEach(function(_,v)local ok,s=pcall(function()return v:get():ToString()end);if ok then list[#list+1]=s end end)
            texts=list
        end)
        M.log("focus_popup_texts "..table.concat(texts,"|"))
    end
    local labels={};for _,a in ipairs(actions) do labels[#labels+1]={label=a.label,slot=a.slot} end
    local text=M.announce_text(object_name(f),labels)
    -- Any announcement (automatic or from facing) starts the repeat gap, so the
    -- automatic check does not say the same object again right after facing.
    pcall(function()last_spoken_address,last_spoken_at=f:GetAddress(),M.clock()end)
    M.say(text)
    M.log("focus_announce spoken="..text)
    return true
end
-- Called regularly while the player has control.
function M.tick(controller)
    local f,open=M.focused(controller)
    local address=nil;if f then pcall(function()address=f:GetAddress()end) end
    if address==last_address and open==last_open then return end
    last_address,last_open=address,open
    if f and open then
        local now=M.clock()
        if address==last_spoken_address and now-last_spoken_at<M.REPEAT_GAP then return end
        last_spoken_address,last_spoken_at=address,now
        M.announce(controller)
    end
end
-- Triggers action slot n (1-based) on the focused object.
function M.trigger(controller,n)
    local f,open=M.focused(controller)
    if not f or not open then M.say(M.text("focus_none"));return false end
    local actions=M.offered(f)
    local a=actions[n]
    if not a then M.say(M.text("focus_no_slot",{index=n}));return false end
    local ok,result=pcall(function()return f:TriggerActionBP(a.index)end)
    M.log("action_trigger object="..object_name(f).." slot="..n.." index="..a.index.." name="..tostring(a.name).." ok="..tostring(ok).." result="..tostring(result))
    if not ok then M.say(M.text("focus_failed"));return false end
    return true
end
function M.reset()last_address,last_open=nil,nil;last_spoken_address,last_spoken_at=nil,-math.huge end
return M
