-- Spoken names for the mod's own commands, chosen for the input device the game
-- says is in use. The game's flag (LiSCharacter.IsGamepadOn) follows actual use,
-- not what is plugged in, so a connected but idle controller still gives
-- keyboard names. When the flag cannot be read, keyboard names are used.
local M={}
-- Each command: keyboard key name, controller button name (nil = keyboard only).
M.commands={
    repeat_announcement={keyboard="Home",controller=nil},
    cancel={keyboard="F8",controller=nil},
    main_menu={keyboard="F10",controller=nil},
}
local gamepad=false
function M.set_gamepad(on)gamepad=on==true end
function M.using_gamepad()return gamepad end
-- Name of the binding for the active device, falling back to the keyboard name
-- when a command has no controller binding yet.
function M.name(command)
    local c=M.commands[command]
    if not c then return "[unknown command: "..tostring(command).."]" end
    if gamepad and c.controller then return c.controller end
    return c.keyboard
end
-- Reads the game's own input-mode flag; leaves the mode unchanged if unreadable.
function M.refresh(controller)
    local ok,on=pcall(function()
        local pawn=controller.Pawn
        if not pawn:IsValid() then return nil end
        return pawn.IsGamepadOn
    end)
    if ok and type(on)=="boolean" then
        local changed=on~=gamepad
        gamepad=on
        return changed
    end
    return false
end
return M
