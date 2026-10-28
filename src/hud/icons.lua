-- The two story icons the game shows without any spoken or readable cue:
-- * the butterfly (ButterflyIcon): "This action will have consequences...";
--   the widget's ConsequencesText is set from the game's own localized line
--   ($GT_HUD_Tuto_Tuto26), which is what is spoken;
-- * the new-fact bubble (NewFactIcon): pictures only.
-- Each is announced once when it appears (hidden or absent -> visible).
local M={}
M.text=function(key)return key end
M.clean=function(s)return s end
local function shown(o)local ok,v=pcall(function()return o~=nil and o:IsValid() and o:IsVisible()end);return ok and v==true end
local function on_screen(w)
    local ok,on=pcall(function()return w:IsValid() and w:IsVisible() and (w:IsInViewport() or w:GetParent()~=nil)end)
    return ok and on==true
end
-- Both widgets stay on the HUD all the time (one was "visible" the moment the
-- game loaded, 28 Oct). Their scripts show the animation by setting their
-- Switcher to HitTestInvisible (3) and hide it again with Hidden (2), so that
-- state - not the widget's own visibility - says the icon is showing.
local SHOWING=3
M.state=function(_)end
local function visible(class)
    for _,w in ipairs(FindAllOf(class) or {}) do
        if on_screen(w) then
            local v=nil;pcall(function()v=w.Switcher:GetVisibility()end)
            M.state(class,v)
            if v==SHOWING then return w end
        end
    end
end
-- game: the game's own line for the icon, read through its translator.
M.translate=function(key)return nil end
M.ICONS={
    {class="ButterflyIcon_C",key="icon_consequences",game="$GT_HUD_Tuto_Tuto26"},
    {class="NewFactIcon_C",key="icon_new_fact"},
}
-- Pure: which icons just appeared. now/prev: {class=bool}.
function M.appeared(prev,now)
    local out={}
    for _,i in ipairs(M.ICONS) do
        if now[i.class] and not prev[i.class] then out[#out+1]=i end
    end
    return out
end
local prev={}
-- Returns the lines to speak for icons that appeared since the last call.
function M.tick()
    local now={}
    for _,i in ipairs(M.ICONS) do now[i.class]=visible(i.class)~=nil end
    local lines={}
    for _,i in ipairs(M.appeared(prev,now)) do
        local s=nil
        if i.game then local ok,v=pcall(M.translate,i.game);if ok and type(v)=="string" and v:find("%a") and not v:find("^%$") then s=M.clean(v) end end
        lines[#lines+1]=s or M.text(i.key)
    end
    prev=now
    return lines
end
function M.reset()prev={} end
return M
