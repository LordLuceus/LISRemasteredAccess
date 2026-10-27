-- On-screen prompts:
-- * the HUD's tooltip line (BP_Widget_HUD_View.TextBlock_Tolltip): Max's
--   thoughts and objectives, read when they change;
-- * activity prompts (BP_LiSPromptWidget_View): "Stop Playing" with its key;
-- * exit prompts, which no widget reports (checked in play): spoken from the
--   exit itself by main.lua using exit_at() and speakable().
-- Read only from copies on screen. Text blocks also hold designer placeholders
-- ("dsfasdfasfd") while hidden, so visibility is required and obvious
-- placeholder text is ignored.
local M={}
M.key_name=function(_)return nil end
local function on_screen(w)
    local ok,on=pcall(function()return w:IsValid() and w:IsInViewport() and w:IsVisible()end)
    return ok and on==true
end
-- Spoken form: action placeholders become the key for the device in use
-- ("[action_interact] Go To The Main Campus" -> "Go To The Main Campus, E"), or
-- are dropped when no key name is known. Pure.
function M.speakable(text,key_name)
    if type(text)~="string" then return nil end
    local key=nil
    local s=text:gsub("%[([%w_]+)%]",function(action)key=key or key_name(action);return "" end)
    s=s:gsub("<[^>]+>",""):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
    if s=="" or not s:find("%a") then return nil end
    if s:find("^%$") then return nil end
    -- Developer placeholder seen in the shipped widget.
    if s:lower()=="dsfasdfasfd" then return nil end
    if key then s=s..", "..key end
    return s
end
-- Candidate on-screen widgets for action prompts (the exit prompt was NOT on
-- BP_LiSTooltipsHigh_View in play): the HUD's own tooltip line, the standalone
-- tooltip, the notification line and the prompt widget. Each field is read only
-- when its widget and the field are visible; the first speakable text wins and
-- its source is reported so the right one can be kept.
M.SOURCES={
    {"BP_Widget_HUD_View_C","TextBlock_Tolltip"},
    {"BP_LiSTooltipsHigh_View_C","TextBlock_Tolltip"},
    {"BP_LiSNotificationWidget_View_C","TextBlock_Notification"},
}
-- Activity prompts ("Stop Playing", "Stop Flying", getting up): the game's
-- prompt widget (BP_LiSPromptWidget_View) shows the words in SkipWordText and
-- the key in KeyText - the key the game reads for SkipPrimary (Space) - or a
-- face-button picture on a controller (B). Reading KeyText alone gave a bare
-- "Space". Pure: the spoken form from the words and the key name.
function M.prompt_text(words,key)
    if type(words)~="string" then return nil end
    local s=words:gsub("<[^>]+>",""):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
    if s=="" or not s:find("%a") or s:find("^%$") or s:lower()=="dsfasdfasfd" then return nil end
    if key and key~="" then s=s..", "..key end
    return s
end
-- key_for(shown_key_text) -> the key to name for the device in use.
M.prompt_key=function(shown)return shown end
local function visible_text(o)
    local ok,s=pcall(function()
        if not (o and o:IsValid() and o:IsVisible()) then return nil end
        return o:GetText():ToString()
    end)
    return ok and s or nil
end
function M.prompt()
    local found=nil
    pcall(function()
        for _,w in ipairs(FindAllOf("BP_LiSPromptWidget_View_C") or {}) do
            if on_screen(w) then
                local words=visible_text(w.SkipWordText)
                if words then
                    local shown=visible_text(w.KeyText)
                    found=M.prompt_text(words,M.prompt_key(shown))
                    if found then return end
                end
            end
        end
    end)
    return found
end
M.source=nil
local function shown(o)local ok,v=pcall(function()return o~=nil and o:IsValid() and o:IsVisible()end);return ok and v==true end
function M.current()
    for _,src in ipairs(M.SOURCES) do
        local text=nil
        pcall(function()
            for _,w in ipairs(FindAllOf(src[1]) or {}) do
                if on_screen(w) then
                    local tb=nil;pcall(function()tb=w[src[2]]end)
                    if shown(tb) then
                        local ok,s=pcall(function()return tb:GetText():ToString()end)
                        if ok then text=s end
                    end
                    if text then break end
                end
            end
        end)
        local spoken=M.speakable(text,M.key_name)
        if spoken then M.source=src[1];return spoken end
    end
    M.source=nil
    return nil
end
-- Pure: the exit Max is standing in, from {pos,extent,prompt} entries (the
-- exit volume's live bounds) and her feet. A margin keeps the announcement
-- from flickering at the edge. Returns the entry or nil.
function M.exit_at(list,feet,margin)
    margin=margin or 0
    for _,e in ipairs(list or {}) do
        if e.extent and e.prompt then
            if math.abs(feet.X-e.pos.X)<=e.extent.X+margin and math.abs(feet.Y-e.pos.Y)<=e.extent.Y+margin
                and math.abs(feet.Z-e.pos.Z)<=e.extent.Z+100 then return e end
        end
    end
    return nil
end
return M
