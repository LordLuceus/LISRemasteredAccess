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
local function text_of(widget)
    if not valid(widget) then return nil end
    local ok,s=pcall(function()return widget:GetText():ToString()end)
    if ok and type(s)=="string" then return s end
    return nil
end
-- Label of a menu option: the button's own text widget, else its Text field.
local function label_of(option)
    if not valid(option) then return nil end
    local ok,w=pcall(function()return option.Button_Text end)
    local s=ok and text_of(w) or nil
    if s and s~="" then return s end
    ok,s=pcall(function()return option.Text:ToString()end)
    if ok and type(s)=="string" and s~="" and not s:find("^%$") then return s end
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
            local label=label_of(current)
            if label==nil and M.describe_unlabelled and valid(current) then M.describe_unlabelled(screen,current,index) end
            return {screen=id,index=index,label=label},
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
