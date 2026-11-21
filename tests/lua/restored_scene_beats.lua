package.path = "./src/?.lua;" .. package.path
local scenes = require("cutscenes.episode1")
local english = require("lang.en")
local checks = 0
local function check(value)
    assert(value)
    checks = checks + 1
end

-- Native ep1-scenes.json + ep1-duration.json (English media), retained under
-- artifacts/scene-access-research. These are source-identity fixtures, not
-- inferred gaps from the former action-caption timestamps.
local blood = scenes.E1_2A_Toilets_LD_NathanAndChloe
local cue = blood.windows[#blood.windows]
local key = "scene_e1_2a_toilets_nathanandchloe_4"
check(cue[3] == key and english[key] == "Blood rewinds.")
check(cue[1] == 92.03 and cue[2] == 93.2)
check(cue[1] >= 92.022) -- RewindBlood
check(cue[1] > 81.05 + 0.796 + 0.38) -- Act_E1_2A_Toilets_VoiceOver01_Max_040_C
check(cue[2] < blood.length and blood.length == 93.289)

-- DoorSlam is 52.165, but Max_200 starts at 52.704 (duration 2.417).
-- David_130 ends at 49.766 + 1.574 = 51.340. With 0.38s speech guards,
-- the post-slam slot is just 0.159s. Do not restore the old queued caption.
local blame = scenes.E1_5A_ChloeRoom_LD_DavidFurious_BlameChloe
for _, window in ipairs(blame.windows) do
    check(window[2] <= 51.34 or window[1] >= 55.121)
end
local departure=blame.windows[2]
check(departure[3]=='scene_e1_5a_chloeroom_davidfurious_blamechloe_3')
check(english[departure[3]]=='David has left.')
check(departure[1]>=55.832+5.541+.38) -- Chloe_210 ends before delayed caption
check(departure[2]<=63.608-.38) -- stop before Chloe_220, including slow TTS
check(departure[1]>52.165) -- retrospective, never anticipates the departure

-- Exercise the actual adapter, not a separately reconstructed policy window.
local Scene = require("cutscenes.scene")
local function name(value) return {ToString=function() return value end} end
local world = {IsValid=function() return true end, GetAddress=function() return 900 end,
    GetFName=function() return name("E1_2A") end}
local actor = {IsValid=function() return true end, GetAddress=function() return 901 end,
    GetWorld=function() return world end, GetFName=function()
        return name("E1_2A_Toilets_LD_NathanAndChloe") end,
    bIsPlaying=true, PlayRate=1, InterpPosition=92.03}
local controller = {IsValid=function() return true end, GetWorld=function() return world end,
    GetCurrentLanguage=function() return "en" end}
local api = {all=function() return {actor} end, find=function() return {
    IsValid=function() return true end, IsGamePaused=function() return false end} end}
local said, stops = {}, 0
local reader = Scene.new({sample=function() return Scene.sample(controller, api) end,
    focused=function() return true end, allowed=function() return true end,
    text=function(k) return english[k] end,
    say=function(text) said[#said+1]=text; return true end,
    stop=function() stops=stops+1 end})
reader:tick()
check(#said == 1 and said[1] == "Blood rewinds.")
local before = stops
actor.InterpPosition = 93.2
reader:tick()
check(stops > before and #said == 1)
reader:reread()
check(#said == 1) -- no repeat across the native transition protection
world.GetFName=function()return name('E1_5A')end
actor.GetFName=function()return name('E1_5A_ChloeRoom_LD_DavidFurious_BlameChloe')end
actor.InterpPosition=52.17
reader:tick();reader:reread();check(#said==1) -- old slot stays silent
actor.InterpPosition=61.78
reader:tick();check(#said==2 and said[2]=='David has left.')
before=stops;actor.InterpPosition=63.2
reader:tick();reader:reread()
check(stops>before and #said==2) -- hard cutoff before Chloe resumes
print('Restored scene beats: '..checks..' checks passed')
return checks
