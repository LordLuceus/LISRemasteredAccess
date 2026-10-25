-- Reads the title screen and the main menu screens from the game's own state.
-- The title widget (BP_LiS_Main_Menu_Widget_C) shows "Click To Start"; the
-- screen it creates afterwards (LastCreatedWidget, derived from
-- BP_LiS_MainMenu_Parent_Widget_C) tracks the highlighted option itself in
-- CurrentInteractable / CurrentInteractableIndex, not through UMG focus.
-- Read-only: no input, no setters, no global widget scans.
local M={}
local cached=nil
local function valid(o)return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end
local function call_bool(o,fn)
    local ok,v=pcall(function()return o[fn](o)end)
    return ok and v==true
end
local clean=require("core.text").clean
local function plain_text(widget)
    local ok,s=pcall(function()return widget:GetText():ToString()end)
    if ok and type(s)=="string" then return clean(s) end
    return nil
end
-- Text shown by a widget. Settings rows use the game's LocalizedString_Widget,
-- a wrapper with no GetText of its own: its visible text is in TextBlock_0.
local function text_of(widget)
    if not valid(widget) then return nil end
    local s=plain_text(widget)
    if s then return s end
    local ok,inner=pcall(function()return widget.TextBlock_0 end)
    if ok and valid(inner) then return plain_text(inner) end
    return nil
end
local function field_text(option,field)
    local ok,w=pcall(function()return option[field] end)
    local s=ok and text_of(w) or nil
    if s and s~="" then return s end
    return nil
end
-- Current value of a selector's Settings_SelectButton_Widget: the text it
-- shows, else the Options entry its SelectedOption points at.
local function selector_value(option)
    local ok,sel=pcall(function()return option.Selector_Option end)
    if not (ok and valid(sel)) then return nil end
    local s=field_text(sel,"Text")
    if s then return s end
    local iok,i=pcall(function()return sel.SelectedOption end)
    if iok and type(i)=="number" then
        local str=nil
        pcall(function()
            local e=sel.Options[i+1]
            str=type(e)=="string" and e or e:get():ToString()
        end)
        if type(str)=="string" and str~="" then return str end
    end
    return nil
end
function M.percent(v,lo,hi)
    local p=(v-lo)/(hi-lo)*100
    if p<0 then p=0 elseif p>100 then p=100 end
    return math.floor(p+0.5)
end
-- Overridable so the percent wording can be localised by the caller.
function M.format_percent(p)return tostring(p).."%" end
-- Slider value as the player sees it: a whole percentage of its range.
local function slider_value(option)
    local ok,slider=pcall(function()return option.Slider_Slider end)
    if not (ok and valid(slider)) then return nil end
    local vok,v=pcall(function()return slider:GetValue()end)
    if not (vok and type(v)=="number") then return nil end
    local lo,hi=0,1
    pcall(function()lo=slider.MinValue;hi=slider.MaxValue end)
    if type(lo)~="number" or type(hi)~="number" or hi<=lo then lo,hi=0,1 end
    return M.format_percent(M.percent(v,lo,hi))
end
-- Label and current value of a menu option, from the fields each widget type
-- actually uses: ordinary buttons (Button_Text), selectors (Selector_Name and
-- the shown option) and sliders (Slider_Text and the slider value).
local function label_of(option)
    if not valid(option) then return nil end
    local s=field_text(option,"Button_Text")
    if s then return s end
    -- Episode selector (BP_EpisodeSelector_Button): number and title.
    local num,title=field_text(option,"EpNum"),field_text(option,"EpTitle")
    if num or title then return require("core.text").join(num,title) end
    local name=field_text(option,"Selector_Name")
    if name then return name,selector_value(option) end
    name=field_text(option,"Slider_Text")
    if name then return name,slider_value(option) end
    local ok,txt=pcall(function()return option.Text:ToString()end)
    if ok and type(txt)=="string" and txt~="" and not txt:find("^%$") then return txt end
    return nil
end
local function find_title()
    if valid(cached) and call_bool(cached,"IsInViewport") then return cached end
    cached=nil
    for _,w in ipairs(FindAllOf("BP_LiS_Main_Menu_Widget_C") or {}) do
        if valid(w) and call_bool(w,"IsInViewport") then cached=w;return w end
    end
    return nil
end
-- Shared two-button confirmation popup (MainMenu_2Option_PopUp_Widget, e.g.
-- "Quit the game?"). Its buttons don't report a highlight to the game's menu
-- parent, so only the question and its two choices are read.
local POPUPS={"MainMenu_2Option_PopUp_Widget_C","MainMenu_1Option_PopUp_Widget_C","MainMenu_PopUp_Widget_C"}
local function find_popup()
    for _,c in ipairs(POPUPS) do
        for _,p in ipairs(FindAllOf(c) or {}) do
            if valid(p) and call_bool(p,"IsInViewport") and call_bool(p,"IsVisible") then return p end
        end
    end
    return nil
end
-- How to answer a dialog, e.g. "Enter to confirm, Escape to cancel". The
-- caller overrides this with localised text and the active device's keys.
function M.format_choices(confirm,cancel)
    if confirm and cancel then return "Enter to confirm, Escape to cancel" end
    if confirm then return "Enter to confirm" end
    return nil
end
-- Identity of a message for change detection: digits removed, so a countdown
-- ticking inside the message does not count as a new message.
function M.message_key(s)return (s:gsub("%d+","#")) end
local function popup_snapshot(p)
    local message=field_text(p,"TextBlock_Message")
    if not message then return nil end
    local confirm=field_text(p,"TextBlock_Confirm")~=nil
    local cancel=field_text(p,"TextBlock_Cancel")~=nil
    local id="popup@"..string.format("%X",p:GetAddress())
    return {screen=id,index=0,label=message,key=M.message_key(message),value=M.format_choices(confirm,cancel)},
        "screen=popup"
end
-- Gamma calibration (GammaWidget_C), opened with Enter on the Gamma row: the
-- game's instruction for the device in use plus the slider value. Rich text
-- markup is removed. Only an instance still attached to the UI counts.
M.strip_markup=clean
M.using_gamepad=function()return false end
M.gamma_title="Gamma"
local function find_gamma()
    for _,g in ipairs(FindAllOf("GammaWidget_C") or {}) do
        if valid(g) and call_bool(g,"IsVisible") then
            local pok,parent=pcall(function()return g:GetParent()end)
            if call_bool(g,"IsInViewport") or (pok and valid(parent)) then return g end
        end
    end
    return nil
end
local function gamma_snapshot(g)
    local text=nil
    if M.using_gamepad() then text=field_text(g,"GamepadTooltipRich") end
    text=text or field_text(g,"PCTooltip") or field_text(g,"GamepadTooltipRich")
    local value=slider_value(g)
    return {screen="gamma@"..string.format("%X",g:GetAddress()),index=0,label=text or M.gamma_title,key="gamma",value=value},"screen=gamma"
end
-- Video Settings' built-in Apply confirmation ("Keep these changes?"): a
-- Confirmation panel inside the screen, visible only while it is asked.
local function embedded_confirmation(screen)
    local ok,panel=pcall(function()return screen.Confirmation end)
    if not (ok and valid(panel) and call_bool(panel,"IsVisible")) then return nil end
    return popup_snapshot(screen)
end
-- Save slots (BP_LiS_Main_Menu_SaveMenu_C): the highlighted slot is ActiveSlot
-- (0-based); each slot shows either its name, episode, chapter and date, or
-- "New game" for an empty slot. Hidden texts are skipped.
function M.save_slot_text(slot)
    local parts={}
    local name=field_text(slot,"Text_Button_Slot")
    local function shown(k)
        local ok,w=pcall(function()return slot[k] end)
        if not (ok and valid(w) and call_bool(w,"IsVisible")) then return nil end
        return field_text(slot,k)
    end
    local new_game=shown("TextBlock_NewGame")
    if new_game then
        local visible_name=shown("Text_Button_Slot")
        return (visible_name and (visible_name..", ") or "")..new_game
    end
    for _,k in ipairs({"Text_Button_Slot","TextBlock_Episode","TextBlock_Level","TextBlock_Date"}) do
        local s=shown(k);if s then parts[#parts+1]=s end
    end
    if #parts==0 and name then parts[1]=name end
    return #parts>0 and table.concat(parts,", ") or nil
end
local function save_menu_snapshot(screen)
    local ok,i=pcall(function()return screen.ActiveSlot end)
    if not (ok and type(i)=="number") then return nil end
    local sok,slot=pcall(function()return screen["BP_LiS_Main_Menu_SaveSlot_"..(i+1)] end)
    if not (sok and valid(slot)) then return nil end
    local id="saves@"..string.format("%X",screen:GetAddress())
    return {screen=id,index=i,label=M.save_slot_text(slot)},"screen=saves slot="..(i+1)
end
-- A screen of the game's menu parent type: the highlighted option is
-- CurrentInteractable (or InteractablesArray[CurrentInteractableIndex]).
local function interactable_snapshot(screen)
    local iok,index=pcall(function()return screen.CurrentInteractableIndex end)
    if not (iok and type(index)=="number") then return nil end
    local cok,current=pcall(function()return screen.CurrentInteractable end)
    local source="current"
    if not (cok and valid(current)) then
        -- Fall back to the option list, which the index points into.
        source="array"
        local aok,item=pcall(function()return screen.InteractablesArray[index+1]end)
        current=aok and item or nil
    end
    local class=screen:GetClass():GetFName():ToString()
    local id=class.."@"..string.format("%X",screen:GetAddress())
    -- Screen heading spoken when the screen (or its subject) changes, for
    -- example the episode shown on the Episodes screen.
    local context=nil
    local heading=M.headings[class]
    if heading then
        context=field_text(screen,heading.text)
        local hok,part=pcall(function()return screen[heading.id]end)
        if hok and part~=nil then id=id.."#"..tostring(part) end
    end
    local label,value=label_of(current)
    if label==nil and M.describe_unlabelled and valid(current) then M.describe_unlabelled(screen,current,index) end
    return {screen=id,index=index,label=label,value=value,context=context},
        "screen="..class.." index="..index.." source="..source
end
-- Screens shown on their own rather than as the title's LastCreatedWidget.
M.standalone={"BP_LiS_ChangeLevel_PopUp_Widget_C","BP_LiS_ChangeEpisode_PopUp_Widget_C","BP_LiS_ChangeEpisode_Widget_C"}
-- Heading text field and the field identifying its subject, per screen class.
M.headings={BP_LiS_ChangeEpisode_Widget_C={text="EpisodeTitle",id="EpisodeNumber"}}
local function find_live(class)
    for _,w in ipairs(FindAllOf(class) or {}) do
        if valid(w) and call_bool(w,"IsVisible") then
            local pok,parent=pcall(function()return w:GetParent()end)
            if call_bool(w,"IsInViewport") or (pok and valid(parent)) then return w end
        end
    end
    return nil
end
-- Returns a tracker snapshot plus a short diagnostic, or nil when no menu.
function M.snapshot()
    local title=find_title()
    if not title then return nil end
    local gamma=find_gamma()
    if gamma then return gamma_snapshot(gamma) end
    local popup=find_popup()
    if popup then
        local s,d=popup_snapshot(popup)
        if s then return s,d end
    end
    for _,class in ipairs(M.standalone) do
        local w=find_live(class)
        if w then
            local s,d=interactable_snapshot(w)
            if s then return s,d end
        end
    end    local ok,screen=pcall(function()return title.LastCreatedWidget end)
    if ok and valid(screen) and call_bool(screen,"IsVisible") then
        local c=embedded_confirmation(screen)
        if c then return c,"screen=confirmation" end
        if screen:GetClass():GetFName():ToString()=="BP_LiS_Main_Menu_SaveMenu_C" then
            local s,d=save_menu_snapshot(screen)
            if s then return s,d end
        end
    end
    if ok and valid(screen) and call_bool(screen,"IsVisible") then
        local s,d=interactable_snapshot(screen)
        if s then return s,d end
    end
    -- Title prompt, once the game accepts input (CanAdvance), and only before
    -- any menu screen exists: the title widget keeps reporting its prompt as
    -- visible underneath later screens, which once announced "Click To Start"
    -- on the Episodes screen. An unrecognised screen says nothing instead.
    if ok and valid(screen) then
        if M.report_unknown then M.report_unknown(screen) end
        return nil
    end
    local aok,can=pcall(function()return title.CanAdvance end)
    if aok and can==true then
        local tok,tap=pcall(function()return title.TapToStart end)
        if tok and valid(tap) and call_bool(tap,"IsVisible") then
            return {screen="title",index=0,label=text_of(tap)},"screen=title"
        end
    end
    return nil
end
return M
