-- Development aid: logs, on change only, which menu screen is current, which
-- interactable it says is highlighted, and the state of the confirmation
-- popups and save slots, so their highlight tracking can be measured. Reads
-- only the title widget, its current screen and three popup classes by name.
local M={}
local last=nil
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end)
    return ok and r==true
end
local function cls(o)return valid(o) and o:GetClass():GetFName():ToString() or "none" end
local function nm(o)return valid(o) and o:GetFName():ToString() or "none" end
local function txt(w)
    if not valid(w) then return nil end
    local ok,s=pcall(function()return w:GetText():ToString()end)
    if ok and type(s)=="string" then return s end
    ok,s=pcall(function()return w.TextBlock_0:GetText():ToString()end)
    if ok and type(s)=="string" then return s end
    return nil
end
local function vis(w)local ok,v=pcall(function()return w:IsVisible()end);return ok and v==true end
local function field(o,k)local ok,v=pcall(function()return o[k]end);if ok then return v end end
local function focus(w)
    if not valid(w) then return "-" end
    local parts={}
    for _,f in ipairs({"HasKeyboardFocus","IsHovered","HasAnyUserFocus"}) do
        local ok,v=pcall(function()return w[f](w)end)
        if ok and v then parts[#parts+1]=f end
    end
    return #parts>0 and table.concat(parts,"+") or "-"
end
local function describe_screen(s)
    local parts={"screen="..cls(s)}
    for _,k in ipairs({"CurrentInteractableIndex","ButtonInFocusIndex","ActiveSlot","Slot_Num","IsExitConfirm"}) do
        local v=field(s,k);if type(v)=="number" or type(v)=="boolean" then parts[#parts+1]=k.."="..tostring(v) end
    end
    local cur=field(s,"CurrentInteractable");parts[#parts+1]="current="..cls(cur).."/"..nm(cur)
    local n=0;pcall(function()n=s.InteractablesArray:GetArrayNum()end);parts[#parts+1]="interactables="..n
    pcall(function()
        s.InteractablesArray:ForEach(function(i,e)
            local o=e:get();if i<=12 then parts[#parts+1]="  ["..(i-1).."]"..cls(o).."/"..nm(o).." vis="..tostring(vis(o)).." focus="..focus(o) end
        end)
    end)
    -- Video screen's built-in confirmation.
    local conf=field(s,"Confirmation")
    if valid(conf) then
        parts[#parts+1]="confirmation_visible="..tostring(vis(conf)).." message=\""..tostring(txt(field(s,"TextBlock_Message"))).."\""
            .." confirm=\""..tostring(txt(field(s,"TextBlock_Confirm"))).."\" cancel=\""..tostring(txt(field(s,"TextBlock_Cancel"))).."\""
        for _,b in ipairs({"ConfirmBtn","CancelBtn","Button_Confirm","Button_Cancel"}) do
            local o=field(s,b);if valid(o) then parts[#parts+1]=b.."="..cls(o).." vis="..tostring(vis(o)).." focus="..focus(o).." text=\""..tostring(txt(field(o,"Button_Text"))).."\"" end
        end
    end
    -- Save slots.
    for i=1,3 do
        local slot=field(s,"BP_LiS_Main_Menu_SaveSlot_"..i)
        if valid(slot) then
            local t={}
            for _,k in ipairs({"Text_Button_Slot","TextBlock_Episode","TextBlock_Level","TextBlock_Date","TextBlock_NewGame"}) do
                local w=field(slot,k);t[#t+1]=k.."=\""..tostring(txt(w)).."\""..(valid(w) and (vis(w) and "" or "(hidden)") or "")
            end
            parts[#parts+1]="slot"..i.." vis="..tostring(vis(slot)).." focus="..focus(slot).." btn_focus="..focus(field(slot,"Button_Slot")).." "..table.concat(t," ")
        end
    end
    return table.concat(parts," ")
end
function M.tick(log)
    local parts={}
    local title=nil
    for _,w in ipairs(FindAllOf("BP_LiS_Main_Menu_Widget_C") or {}) do
        local ok,v=pcall(function()return w:IsInViewport()end);if ok and v then title=w;break end
    end
    if title then
        local s=field(title,"LastCreatedWidget")
        if valid(s) then parts[#parts+1]=describe_screen(s) end
    end
    -- Episode and chapter screens, found by class (narrow; no global widget scan).
    for _,c in ipairs({"BP_LiS_ChangeEpisode_Widget_C","BP_LiS_ChangeLevelMenu_Widget_C","BP_LiS_ChangeLevel_PopUp_Widget_C","BP_LiS_ChangeEpisode_PopUp_Widget_C"}) do
        for _,w in ipairs(FindAllOf(c) or {}) do
            local ok,live=pcall(function()return valid(w) and (w:IsInViewport() or valid(w:GetParent())) and w:IsVisible()end)
            if ok and live then
                local p={"EPISODES "..c}
                for _,k in ipairs({"EpisodeNumber","IsOnPage1","CanPlay","IsCollectorMode","SlotIndex","SelectedButtonIndex","SelectedEpisode","LevelIndex","Level"}) do
                    local v=field(w,k);if type(v)=="number" or type(v)=="boolean" then p[#p+1]=k.."="..tostring(v) end
                end
                for _,k in ipairs({"EpisodeTitle","FinishPrevEp","TimeUntilNextEpText","LevelText","StatusText","TextBlock_Collected","EpisodeName_TextBlock","EnvStatusText","TextBlock_Continue","TextBlock_WarningMessage","TextBlock_CollectibleMode_info","TextBlock_Reset_info","TextBlock_5","TextBlock_0","TextBlock_23","TextBlock_83"}) do
                    local o=field(w,k);if valid(o) then p[#p+1]=k.."=\""..tostring(txt(o)).."\""..(vis(o) and "" or "(hidden)") end
                end
                p[#p+1]=describe_screen(w)
                for i=1,5 do
                    local s=field(w,"E"..i.."_Selector")
                    if valid(s) then p[#p+1]="E"..i.."=["..tostring(txt(field(s,"EpNum"))).." | "..tostring(txt(field(s,"EpTitle"))).."] vis="..tostring(vis(s)).." focus="..focus(s).." btn="..focus(field(s,"Button")) end
                end
                for i=1,3 do
                    local b=field(w,"LevelButton"..i)
                    if valid(b) then
                        local tx=nil;pcall(function()tx=b.Texts:ToString()end)
                        local ln=nil;pcall(function()ln=b.LevelName:ToString()end)
                        p[#p+1]="Level"..i.."=[texts="..tostring(tx).." name="..tostring(ln).." sub="..tostring(field(b,"SubEpisodeIndex")).."] focus="..focus(b).." btn="..focus(field(b,"LevelSelectButton"))
                    end
                end
                for _,k in ipairs({"PlayButton","RestartButton","CollectorModeButton","Slot1Button","Slot2Button","Slot3Button","StartEpEOEButton","EpisodesEOEButton","Button_Continue","Button_Reset","Button_CollectibleMode"}) do
                    local o=field(w,k);if valid(o) then p[#p+1]=k.."=\""..tostring(txt(field(o,"Button_Text")) or txt(o)).."\" vis="..tostring(vis(o)).." focus="..focus(o) end
                end
                parts[#parts+1]=table.concat(p," ")
            end
        end
    end    for _,c in ipairs({"MainMenu_2Option_PopUp_Widget_C","MainMenu_1Option_PopUp_Widget_C","MainMenu_PopUp_Widget_C"}) do
        for _,p in ipairs(FindAllOf(c) or {}) do
            local ok,inview=pcall(function()return valid(p) and p:IsInViewport()end)
            if ok and inview then
                parts[#parts+1]="POPUP "..c.." vis="..tostring(vis(p)).." message=\""..tostring(txt(field(p,"TextBlock_Message"))).."\""
                    .." confirm=\""..tostring(txt(field(p,"TextBlock_Confirm"))).."\" cancel=\""..tostring(txt(field(p,"TextBlock_Cancel"))).."\""
                parts[#parts+1]=describe_screen(p)
                for _,b in ipairs({"Button_Confirm","Button_Cancel"}) do
                    local o=field(p,b);if valid(o) then parts[#parts+1]=b.." focus="..focus(o) end
                end
            end
        end
    end
    local line=table.concat(parts," | ")
    if line~=last then last=line;log("dialog_trace "..line) end
end
return M
