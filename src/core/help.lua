-- Help: the mod's keys for the device in use, short enough to listen to.
-- Built from the same key names the rest of the mod speaks, so a translation
-- or a controller switch changes help too. Game-independent (offline tested).
local M={}
M.text=function(key,p)return key end
-- gamepad: whether the game reports a controller in use.
function M.lines(gamepad)
    local d=gamepad and "help_pad" or "help_keys"
    return {
        M.text(d.."_select"),
        M.text(d.."_describe"),
        M.text(d.."_walk"),
        M.text(d.."_face"),
        M.text(d.."_actions"),
        M.text(d.."_repeat"),
        M.text(d.."_preview"),
    }
end
function M.speech(gamepad)return table.concat(M.lines(gamepad)," ") end
return M
