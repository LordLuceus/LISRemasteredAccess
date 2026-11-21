package.path = "./src/?.lua;" .. package.path
local actions = require("cutscenes.episode1_actions")
local function fname(name)
    return {ToString=function() return name end}
end
local world = {IsValid=function()return true end, GetFName=function() return fname("E1_6B") end, GetAddress=function() return 123 end}
local controller = {GetWorld=function() return world end, GetCurrentLanguage=function() return "en" end}
local actor = {
    GetFName=function() return fname("E1_6B_CliffFuture_LD_Doe_RunToTheLightHouse") end,
    IsValid=function() return true end, bIsPlaying=true,
    GetWorld=function() return world end,
}
local original_find = FindAllOf
FindAllOf = function() return {actor} end
local heard = {}
local function sample(time)
    actor.InterpPosition = time
    actions.tick(controller, true, function(text, interrupt)
        assert(interrupt == false)
        heard[#heard + 1] = text
    end)
end
sample(0.1)
sample(0.2)
assert(#heard == 1 and heard[1]:find("doe bounds", 1, true))
actor.bReversePlayback = true
sample(0.1)
assert(#heard == 1)
actor.bReversePlayback = false
sample(0.15)
assert(#heard == 2)
actor.bIsPlaying = false
sample(0)
actor.bIsPlaying = true
sample(3.2)
assert(#heard == 2)
FindAllOf = original_find
return 4
