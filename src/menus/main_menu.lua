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
local function plain_text(widget)
    local ok,s=pcall(function()return widget:GetText():ToString()end)
    if ok and type(s)=="string" then return s end
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
-- Returns a tracker snapshot plus a short diagnostic, or nil when no menu.
function M.snapshot()
    local title=find_title()
    if not title then return nil end
    local ok,screen=pcall(function()return title.LastCreatedWidget end)
    if ok and valid(screen) and call_bool(screen,"IsVisible") then
        local iok,index=pcall(function()return screen.CurrentInteractableIndex end)
        if iok and type(index)=="number" then
            local cok,current=pcall(function()return screen.CurrentInteractable end)
            local source="current"
            if not (cok and valid(current)) then
                -- Fall back to the option list, which the index points into.
                source="array"
                local aok,item=pcall(function()return screen.InteractablesArray[index+1]end)
                current=aok and item or nil
            end
            local id=screen:GetClass():GetFName():ToString().."@"..string.format("%X",screen:GetAddress())
            local label,value=label_of(current)
            if label==nil and M.describe_unlabelled and valid(current) then M.describe_unlabelled(screen,current,index) end
            return {screen=id,index=index,label=label,value=value},
                "screen="..screen:GetClass():GetFName():ToString().." index="..index.." source="..source
        end
    end
    -- Title prompt, once the game accepts input (CanAdvance).
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
