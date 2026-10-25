-- Makes the arrow keys do what W, A, S and D do in menus. The game binds its
-- menu directions to the input actions DPadUp/Down/Left/Right (W/S/A/D, the
-- D-pad and the left stick) but not to the arrows. This adds the arrows to
-- those same actions through the engine's input settings, the way the game's
-- own keybinding editor adds bindings. Runtime only: it never calls
-- SaveKeyMappings, so nothing is written to the player's Input.ini by the mod.
-- In gameplay the arrows already move Max like WASD, so they now match WASD
-- everywhere those direction actions are used.
local M={}
M.pairs={{"DPadUp","Up"},{"DPadDown","Down"},{"DPadLeft","Left"},{"DPadRight","Right"}}
local function mapping(action,key)
    return {ActionName=FName(action),bShift=false,bCtrl=false,bAlt=false,bCmd=false,Key={KeyName=FName(key)}}
end
local function key_name(k)
    local ok,s=pcall(function()return k.KeyName:ToString()end)
    return ok and s or nil
end
-- Keys currently bound to an action, read back from the engine (diagnostic).
function M.keys_for(settings,action)
    local out={}
    local ok=pcall(function()
        local list={}
        settings:GetActionMappingByName(FName(action),list)
        for _,m in ipairs(list) do
            local v=m
            pcall(function()v=m:get()end)
            local n=key_name(v.Key);if n then out[#out+1]=n end
        end
    end)
    return ok and out or nil
end
-- Returns true when all four mappings were added (or already present).
function M.apply(log)
    local settings=StaticFindObject("/Script/Engine.Default__InputSettings")
    if not (settings and settings:IsValid()) then log("arrow_keys result=no_input_settings");return false end
    local added=0
    for i,p in ipairs(M.pairs) do
        -- Rebuild the key maps once, with the last mapping.
        local ok,err=pcall(function()settings:AddActionMapping(mapping(p[1],p[2]),i==#M.pairs)end)
        if ok then added=added+1 else log("arrow_keys add_error action="..p[1].." error="..tostring(err)) end
    end
    -- Read back what the engine now holds, so a silent no-op is visible.
    for _,p in ipairs(M.pairs) do
        local keys=M.keys_for(settings,p[1])
        log("arrow_keys bound action="..p[1].." keys="..(keys and table.concat(keys,",") or "unreadable"))
    end
    -- Rebuild the live key maps the way the game's own keybinding editor does
    -- after changing bindings (Settings_Keybinds_Menu calls ForceRebuildKeymaps).
    local ok,err=pcall(function()settings:ForceRebuildKeymaps()end)
    log("arrow_keys result="..(added==#M.pairs and "applied" or "partial").." added="..added
        .." rebuild="..(ok and "ok" or ("error:"..tostring(err))))
    return added==#M.pairs
end
return M
