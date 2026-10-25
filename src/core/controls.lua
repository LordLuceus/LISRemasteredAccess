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
    -- The game's own confirm/cancel bindings (DefaultInput.ini UI_Confirm/UI_Cancel).
    confirm={keyboard="Enter",controller="A"},
    back={keyboard="Escape",controller="B"},
}
-- Controller buttons for the interaction pop-up's four slots. From the pop-up's
-- own code: slot 1 is its Left action, 2 Top, 3 Right, 4 Bottom; the game maps
-- those to the face buttons X, Y, B and A. (Inferred from the widget code and
-- the captured layouts, e.g. Look in slot 2 and Open/Read in slot 4.)
M.slot_buttons={"X","Y","B","A"}
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
