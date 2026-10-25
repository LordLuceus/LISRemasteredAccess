-- Cleans game text for speech and joins spoken parts.
-- * Button icons (<img id="LStick36"/>) become spoken names. The table covers
--   every icon id used in the game's English text files (scanned Oct 2026:
--   LStick36/B/Bordered, RStick36/B/Bordered, Mouse, MouseB). An unknown id is
--   spoken as a marked placeholder and reported, never silently dropped.
-- * Other markup (<b>, </>) is removed.
-- * Line breaks become sentence breaks, without doubling existing punctuation.
-- * join() never puts a comma after text that already ends a sentence.
local M={}
M.icons={
    LStick36="left stick",LStick36B="left stick",LStick36Bordered="left stick",
    RStick36="right stick",RStick36B="right stick",RStick36Bordered="right stick",
    Mouse="the mouse",MouseB="the mouse",
}
local reported={}
M.report=function(_)end
local function ends_sentence(s)return s:find("[%.%!%?:;…]%s*$")~=nil or s:find("%.%.%.%s*$")~=nil end
M.ends_sentence=ends_sentence
local function icon(id)
    local name=M.icons[id]
    if name then return name end
    if not reported[id] then reported[id]=true;M.report("unknown_icon id="..id) end
    return "[icon "..id.."]"
end
function M.clean(s)
    if type(s)~="string" then return s end
    s=s:gsub('<img%s+id%s*=%s*\\?"([%w_]+)\\?"%s*/?>',icon)
    s=s:gsub("<[^>]*>","")
    -- Each line becomes a sentence; add a full stop only where one is missing.
    local lines={}
    for line in (s.."\n"):gmatch("([^\r\n]*)[\r\n]+") do
        line=line:gsub("^%s+",""):gsub("%s+$","")
        if line~="" then lines[#lines+1]=line end
    end
    for i=1,#lines-1 do
        if not ends_sentence(lines[i]) then lines[i]=lines[i].."." end
    end
    s=table.concat(lines," ")
    s=s:gsub("%s%s+"," ")
    return s
end
-- Joins a label and an extra part: "Volume, 80 percent", but
-- "…before changing the gamma. 42 percent" when the label ends a sentence.
function M.join(label,extra)
    if extra==nil or extra=="" then return label end
    if label==nil or label=="" then return extra end
    if ends_sentence(label) then return label.." "..extra end
    return label..", "..extra
end
return M
