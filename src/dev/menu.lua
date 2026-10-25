-- Read-only main menu discovery, deliberately narrow: it touches only the main
-- menu widget, its gamepad button array and those buttons' own properties.
-- No global widget scans or recursive tree walks (a broad 500 ms version of
-- this probe preceded a loader crash). Sends no input and calls no setters.
local M={}
local schema_done={}
local last_state=nil
local function valid(o)return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end
local function cls(o)return o:GetClass():GetFName():ToString()end
-- Text of a text-bearing widget, or of an FText/FString value.
local function as_text(v)
    if v==nil then return nil end
    if type(v)=="string" then return v end
    if type(v)~="userdata" then return nil end
    local ok,s=pcall(function()return v:GetText():ToString()end)
    if ok and type(s)=="string" then return s end
    ok,s=pcall(function()return v:ToString()end)
    if ok and type(s)=="string" and not s:find("^%a+ /") then return s end
    return nil
end
-- One-time schema of a widget class (this class only, not UMG base classes).
local function schema(emit,w)
    local c=cls(w)
    if schema_done[c] then return end
    schema_done[c]=true
    local kind=w:GetClass()
    for _=1,2 do
        if not valid(kind) or kind:GetFullName():find("/Script/UMG.",1,true) then break end
        kind:ForEachProperty(function(p)emit("menu_schema widget="..c.." property="..p:GetFullName())end)
        kind:ForEachFunction(function(f)emit("menu_schema widget="..c.." function="..f:GetFullName())end)
        kind=kind:GetSuperStruct()
    end
end
-- Scalars and any text found in a button's own properties (one level only).
local function describe_button(emit,b)
    schema(emit,b)
    local parts={}
    local kind=b:GetClass()
    if not valid(kind) or kind:GetFullName():find("/Script/UMG.",1,true) then return "" end
    kind:ForEachProperty(function(p)
        local key=p:GetFName():ToString()
        local pc=p:GetClass():GetFName():ToString()
        local ok,v=pcall(function()return b[key]end)
        if not ok then return end
        if pc=="BoolProperty" or pc=="IntProperty" or pc=="FloatProperty" or pc=="ByteProperty" or pc=="EnumProperty" then
            parts[#parts+1]=key.."="..tostring(v)
        elseif pc=="TextProperty" or pc=="StrProperty" or pc=="NameProperty" then
            local s=as_text(v);if s and s~="" then parts[#parts+1]=key.."=\""..s.."\"" end
        elseif pc=="ObjectProperty" and valid(v) then
            local s=as_text(v);if s and s~="" then parts[#parts+1]=key.."=\""..s.."\"" end
        end
    end)
    return table.concat(parts," ")
end
function M.tick(world_name,emit)
    local menu
    for _,w in ipairs(FindAllOf("BP_LiS_Main_Menu_Widget_C") or {}) do
        local ok,inview=pcall(function()return valid(w) and w:IsInViewport()end)
        if ok and inview then menu=w;break end
    end
    if not menu then
        if last_state~="none" then last_state="none";emit("menu_state none world="..world_name) end
        return
    end
    schema(emit,menu)
    local parts={}
    for _,field in ipairs({"HighlightThisOption","CanAdvance","ChoicesOn","CanGoBack"}) do
        local ok,v=pcall(function()return menu[field]end)
        parts[#parts+1]=field.."="..(ok and tostring(v) or "?")
    end
    local ok,n=pcall(function()return menu.Buttons_array_Gamepad:GetArrayNum()end)
    parts[#parts+1]="buttons="..(ok and tostring(n) or "?")
    if ok and n>0 then
        menu.Buttons_array_Gamepad:ForEach(function(i,e)
            local b=e:get()
            if valid(b) then
                local vok,vis=pcall(function()return b:IsVisible()end)
                parts[#parts+1]="["..i.." visible="..tostring(vok and vis).." "..describe_button(emit,b).."]"
            end
        end)
    end
    -- The menu's own options are created after "Click To Start" as further
    -- instances of the button class; list the visible ones (one class only).
    local lok,last=pcall(function()return menu.LastCreatedWidget end)
    parts[#parts+1]="last_created="..((lok and valid(last)) and cls(last) or "none")
    local shown={}
    for _,b in ipairs(FindAllOf("BP_LiS_Main_Menu_Button_Widget_C") or {}) do
        local vok,vis=pcall(function()return valid(b) and b:IsVisible()end)
        if vok and vis then
            local tok,label=pcall(function()return b.Button_Text:GetText():ToString()end)
            local mok,option=pcall(function()return b.MenuOption end)
            local aok,anim=pcall(function()return b.Animate end)
            shown[#shown+1]=(tok and label or "?").."{option="..tostring(mok and option).." animate="..tostring(aok and anim).."}"
        end
    end
    parts[#parts+1]="visible_buttons="..#shown..": "..table.concat(shown,"; ")
    -- The main menu screen created after Click To Start: dump its schema once
    -- and log every scalar of it and its option buttons, so the field that
    -- tracks the highlight shows up as the one that changes on each W/S press.
    if lok and valid(last) then
        schema(emit,last)
        local scal={}
        local kind=last:GetClass()
        for _=1,2 do
            if not valid(kind) or kind:GetFullName():find("/Script/UMG.",1,true) then break end
            kind:ForEachProperty(function(p)
                local pc=p:GetClass():GetFName():ToString()
                if pc=="BoolProperty" or pc=="IntProperty" or pc=="FloatProperty" or pc=="ByteProperty" or pc=="EnumProperty" then
                    local key=p:GetFName():ToString();local ok,v=pcall(function()return last[key]end)
                    if ok and pc~="FloatProperty" then scal[#scal+1]=key.."="..tostring(v) end
                elseif pc=="ObjectProperty" then
                    local key=p:GetFName():ToString();local ok,v=pcall(function()return last[key]end)
                    if ok and valid(v) and v:IsA("/Script/UMG.Widget") then
                        local fok,f=pcall(function()return v:HasKeyboardFocus() or v:HasAnyUserFocus()end)
                        if fok and f then scal[#scal+1]=key..":focused" end
                    end
                end
            end)
            kind=kind:GetSuperStruct()
        end
        parts[#parts+1]="start_widget{"..table.concat(scal," ").."}"
        for _,b in ipairs(FindAllOf("BP_LiS_Main_Menu_Button_Widget_C") or {}) do
            local vok,vis=pcall(function()return valid(b) and b:IsVisible() and b.MenuOption end)
            if vok and vis then
                local tok,label=pcall(function()return b.Button_Text:GetText():ToString()end)
                local sok,sel=pcall(function()return b["Is Selected"](b)end)
                local hok,hov=pcall(function()return b.Button_Ref:IsHovered()end)
                local kok,kf=pcall(function()return b.Button_Ref:HasKeyboardFocus()end)
                local cok,col=pcall(function()local c=b.Button_Text.ColorAndOpacity.SpecifiedColor;return string.format("%.2f,%.2f,%.2f,%.2f",c.R,c.G,c.B,c.A)end)
                local rok,op=pcall(function()return string.format("%.2f",b:GetRenderOpacity())end)
                parts[#parts+1]=(tok and label or "?").."{selected="..(sok and tostring(sel) or "err").." hovered="..(hok and tostring(hov) or "err")
                    .." kfocus="..(kok and tostring(kf) or "err").." color="..(cok and col or "err").." opacity="..(rok and op or "err").."}"
            end
        end
    end
    local line=table.concat(parts," ")
    if line~=last_state then last_state=line;emit("menu_state "..line) end
end
return M
