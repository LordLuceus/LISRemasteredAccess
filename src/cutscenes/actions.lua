-- Short environmental actions outside the timed scene catalogue. The scene
-- reader takes precedence while a timed scene is playing.
local scene_reader=require("cutscenes.scene")
local registry=require("cutscenes.registry").default
local scenes=registry.actions

local previous = {}
local M = {}
function M.tick(controller, enabled, say)
    if not enabled then previous = {}; return end
    local active_world = controller:GetWorld()
    local world = active_world:GetFName():ToString()
    if not registry.levels[world] then previous = {}; return end
    local language = controller:GetCurrentLanguage()
    if type(language) ~= "string" then language = language:ToString() end
    if language ~= "en" then previous = {}; return end
    local current = {}
    for _, actor in ipairs(FindAllOf("MatineeActor") or {}) do
        if actor:IsValid() and actor.bIsPlaying and not actor.bReversePlayback then
            local id = actor:GetFName():ToString()
            if scenes[id] and id:sub(1, #world + 1) == world .. "_"
                and scene_reader.belongs(actor,active_world,id) then
                local position = actor.InterpPosition
                current[id] = true
                if not previous[id] and position >= 0 and position < 0.75 then
                    say(scenes[id], false)
                end
            end
        end
    end
    previous = current
end
return M
