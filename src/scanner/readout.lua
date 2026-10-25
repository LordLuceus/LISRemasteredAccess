-- Builds scanner announcements from a list entry. Game-independent.
-- "Mail, 1.5 metres, ahead, 3 of 38"; height is added when it matters:
-- "Lighthouse, 42 metres, ahead left, 8.5 metres up, 1 of 1".
-- Position (N of M) goes last, as in all the mod's readouts.
local M={}
local L=require("scanner.list")
-- text(key, params) is the mod's localisation lookup, supplied by the caller.
M.text=function(key,p)
    local en={scanner_distance="{value} metres",scanner_distance_one="1 metre",
        scanner_up="{value} metres up",scanner_down="{value} metres down",
        scanner_position="{index} of {count}",scanner_empty="Nothing to select here.",
        dir_ahead="ahead",["dir_ahead right"]="ahead right",dir_right="right",["dir_behind right"]="behind right",
        dir_behind="behind",["dir_behind left"]="behind left",dir_left="left",["dir_ahead left"]="ahead left"}
    local s=en[key] or key
    return (s:gsub("{(%w+)}",function(k)return tostring(p and p[k] or "{"..k.."}")end))
end
-- Metres, rounded sensibly: one decimal under 10 m, whole metres above.
function M.metres(cm)
    local m=cm/100
    if m<10 then
        local r=math.floor(m*10+0.5)/10
        if r==math.floor(r) then return string.format("%d",r) end
        return string.format("%.1f",r)
    end
    return string.format("%d",math.floor(m+0.5))
end
function M.describe(entry,index,count,player,yaw)
    local parts={entry.name}
    local d=M.metres(L.ground(entry.pos,player))
    parts[#parts+1]=d=="1" and M.text("scanner_distance_one") or M.text("scanner_distance",{value=d})
    parts[#parts+1]=M.text("dir_"..L.direction(player,yaw,entry.pos))
    local h,m=L.height(player,entry.pos)
    if h then parts[#parts+1]=M.text(h=="up" and "scanner_up" or "scanner_down",{value=M.metres(m*100)}) end
    parts[#parts+1]=M.text("scanner_position",{index=index,count=count})
    return table.concat(parts,", ")
end
return M
