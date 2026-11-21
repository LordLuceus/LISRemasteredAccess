-- Matinee names from the Episode 1 LD maps. Only announce a newly
-- observed forward start, never a static pose or a late sample after a seek.
local scenes = {
    E1_1A_CliffFuture_LD_IntroStorm = "Max lies on the ground in the driving rain.",
    E1_1A_CliffFuture_LD_LighthouseBreak = {{21.05, "The lighthouse light goes out. The tower breaks apart above Max."}},
    E1_2A_ArtClass_LD_Polaroid_Broken = "Max's camera falls from the desk.",
    E1_2A_ArtClass_LD_Polaroid_Picture01 = "Max turns the instant camera on herself.",
    E1_2A_ArtClass_LD_PencilCase_Look = "Max looks down at the pencil case on her desk.",
    E1_2A_Corridor_LD_PrincipalIntro = "Principal Wells stops Max in the hall.",
    E1_2A_Corridor_LD_MaxLocker_Interact01 = "Max opens her locker.",
    E1_2A_Toilets_LD_Mirror_Interact01 = "Max faces her reflection above the sinks.",
    E1_2A_Toilets_LD_Trolley_Interact01 = "Max pushes the cart away from the wall.",
    E1_2A_ArtClass_LD_BellRing = "The students get up from their desks.",
    E1_2A_Corridor_LD_Insertion_ArtClassToCorridor_Mat = "Max steps out into a hallway full of students.",
    E1_2A_Corridor_LD_PrincipalAndDavid = "The principal approaches Max and the security guard.",
    E1_2A_Toilets_LD_NathanAndChloeArgue = "The blue-haired girl confronts Nathan. Max watches from behind a stall.",
    -- Gun mix at 81.05, rewind blood effect at 92.02.
    E1_2A_Toilets_LD_NathanAndChloe = {
        {81.05, "The blue-haired girl crumples in front of Nathan."},
        {92.02, "The blood draws back."},
    },
    E1_2A_Toilets_LD_FireAlarm_Interact01 = "Max reaches for the fire alarm.",
    E1_2A_Toilets_LD_Butterfly_Photo = "Max raises her instant camera toward the blue butterfly.",
    E1_2A_Corridor_LD_EvanLockerClose = "Evan shuts his locker.",
    E1_2A_Toilets_LD_Hammer_Take = "Max picks up the hammer.",
    E1_3A_CampusA_LD_DanielDraws = "Daniel sketches Max.",
    E1_3A_CampusA_LD_Insertion_CampusAReveal = "The view opens onto the wide lawn in front of Blackwell.",
    E1_3A_CampusA_LD_EvanPhotoBook_Interact01 = "Max looks through Evan's photographs.",
    E1_3A_CampusA_LD_Fountain_ZenStart = "Max sits at the edge of the fountain.",
    E1_3A_CampusA_LD_Satue_Collectible = "Max frames the statue in her camera.",
    E1_3A_CampusA_LD_CHTrevor_OnGround = "Trevor lies on the ground beside his skateboard.",
    E1_3B_CampusB_LD_VictoriaDeniesAccess = "Victoria and her friends block the dormitory steps.",
    E1_3B_CampusB_LD_AlyssaHurt = "A football hits Alyssa.",
    E1_3B_CampusB_LD_PipeActivated = "The sprinklers spray water across the lawn.",
    E1_3B_CampusB_LD_Window_Collectible = "Max photographs the broken dormitory window.",
    E1_3B_CampusB_LD_Squirrel_Collectible = "Max aims her camera at the squirrel.",
    E1_3B_CampusB_LD_KateDavid = "David corners Kate outside the dormitory.",
    E1_3B_CampusB_LD_VIctoria_Comfort = "Max stops beside Victoria on the steps.",
    E1_3A_CampusA_LD_CHGrant_Sign = "Max signs Ms. Grant's petition.",
    E1_3B_CampusB_LD_BucketFall = "The paint bucket tips and falls.",
    E1_3B_CampusB_LD_VIctoria_Stained = "Paint streaks Victoria's clothes.",
    E1_3B_CampusB_LD_VIctoria_TakePhoto = "Max takes a picture of Victoria covered in paint.",
    E1_3B_CampusB_LD_KateDavid_TakePhoto = "From a distance, Max photographs David confronting Kate.",
    E1_3B_CampusB_LD_KateDavid_Intervene = "Max steps in between David and Kate.",
    E1_3C_Corridor_LD_JulietLocksDoor = "Juliet locks Dana's door.",
    E1_3C_Corridor_LD_JulietUnlocksDana = "Juliet unlocks Dana's door.",
    E1_3C_MaxRoom_LD_Guitar_ZenStart = "Max picks up her guitar.",
    E1_3C_MaxRoom_LD_Mirror_Photo = "Max photographs her reflection.",
    E1_3C_MaxRoom_LD_Plant_Interact01 = "Max waters the potted plant by the window.",
    E1_3C_MaxRoom_LD_MaxChloePhoto_Interact01 = "Max holds up an old photograph of herself with Chloe.",
    E1_3C_VicRoom_LD_Mail_Take = "Max takes the printed email from Victoria's room.",
    E1_3C_VicRoom_LD_Photos_Interact01 = "Max rearranges the pictures on Victoria's wall.",
    E1_3C_DanaRoom_LD_USBKey_Take = "Max picks up Warren's flash drive.",
    E1_3C_DanaRoom_LD_PregnancyTest_Take = "Max picks up a pregnancy test.",
    E1_3C_VicRoom_LD_Photos_Photo = "Max photographs the arrangement of pictures on Victoria's wall.",
    E1_3D_CampusPark_LD_DirtyWindow_Photo = "Max aims her camera at the drawing on the dirty window.",
    E1_3D_CampusPark_LD_IntroDialWarren_RTC = "Warren waits beside his car. Max has his flash drive.",
    E1_3D_CampusPark_LD_NathanArrives_Part01 = "Max draws close to Warren in the parking lot.",
    -- Warren's two hit reactions bracket Nathan's at 12.84.
    E1_3D_CampusPark_LD_NathanArrives_Part02 = {
        {4, "Nathan hits Warren."},
        {26.14, "Warren takes another blow as Max gets away."},
    },
    E1_4A_ChloeCar_LD_FirstReunion = "Max and Chloe ride side by side in the pickup.",
    E1_4A_ChloeCar_LD_BrokenCamera = "Max examines her broken instant camera.",
    E1_4A_CHouseFront_LD_HouseReveal01 = "Chloe's house comes into view.",
    E1_5A_ChloeRoom_LD_Chloe_TakePhoto = "Max frames Chloe in her camera.",
    E1_5A_ChloeRoom_LD_DavidFurious_Hidden = "David comes into the bedroom. Max is hidden in the closet.",
    E1_5A_ChloeRoom_LD_DavidFurious_NotHidden = "David enters and finds Max in Chloe's room.",
    E1_5A_ChloeRoom_LD_DavidFurious_DavidDesk = "David stands by Chloe's desk. There's a joint in plain sight.",
    E1_5A_ChloeRoom_LD_DavidFurious_ChoiceNotHidden = "David turns his attention to Max.",
    E1_5A_ChloeRoom_LD_DavidFurious_TakeBlame = "Max faces David beside Chloe.",
    E1_5A_ChloeRoom_LD_DavidFurious_GetOut = "Max comes out of hiding.",
    E1_5A_ChloeRoom_LD_DavidFurious_StayHidden = {
        {0, "From inside the closet, Max watches David confront Chloe."},
        {35.24, "The bedroom door slams behind David."},
    },
    E1_5A_ChloeRoom_LD_DavidFurious_BlameChloe = {
        {0, "David turns on Chloe."},
        {52.17, "David leaves, slamming the door."},
    },
    E1_5A_ChloeRoom_LD_DavidFurious_ShowGun = "Chloe shows Max the gun.",
    E1_5A_ParentsRoom_LD_Bird_Crash = "A bird strikes the bedroom window.",
    E1_5B_Garden_LD_Swing_ZenStart = "Max settles onto the backyard swing.",
    E1_5B_LivingRoom_LD_Couch_ZenStart = "Max sits down on the couch.",
    E1_3C_MaxRoom_LD_Bed_ZenStart = "Max lies back on her bed.",
    E1_6B_CliffFuture_LD_Doe_JumpOverHole = "The doe leaps across the gap in the path.",
    E1_6A_CliffNow_LD_CHChloe_Photo = "Max photographs Chloe looking out over the bay.",
    E1_6A_CliffNow_LD_Bird_Photo = "Max raises her camera toward the bird.",
    E1_6A_CliffNow_LD_IntroDialChloe = "Chloe sits on the cliff overlooking Arcadia Bay. Max joins her.",
    E1_6B_CliffFuture_LD_Doe_FirstView = "A pale doe stands on the storm-swept path.",
    E1_6B_CliffFuture_LD_RollingLogs = "Logs roll across the path.",
    E1_6B_CliffFuture_LD_Tree01Falling = "A tree topples across the trail.",
    E1_6B_CliffFuture_LD_RocksFalling = "Rocks tumble down the slope.",
    E1_6B_CliffFuture_LD_LighthouseFalling = "The lighthouse gives way above Max.",
    E1_6B_CliffFuture_LD_Doe_RunToTheLightHouse = "The doe bounds toward the lighthouse.",
}

local previous = {}
for id, entry in pairs(scenes) do
    if type(entry) == "string" then scenes[id] = {{0, entry}} end
end
local M = {}
function M.tick(controller, enabled, say)
    if not enabled then previous = {}; return end
    local active_world = controller:GetWorld()
    local world = active_world:GetFName():ToString()
    if not world:match("^E1_%d%u$") then previous = {}; return end
    local language = controller:GetCurrentLanguage()
    if type(language) ~= "string" then language = language:ToString() end
    if language ~= "en" then previous = {}; return end
    local current = {}
    for _, actor in ipairs(FindAllOf("MatineeActor") or {}) do
        if actor:IsValid() and actor.bIsPlaying and not actor.bReversePlayback then
            local id = actor:GetFName():ToString()
            if scenes[id] and id:sub(1, #world + 1) == world .. "_"
                and actor:GetWorld():GetAddress() == active_world:GetAddress() then
                local position = actor.InterpPosition
                current[id] = position
                for _, cue in ipairs(scenes[id]) do
                    local last = previous[id]
                    local crossed = last and last < cue[1] and position - last < 1.5
                    local starting = last == nil and cue[1] == 0
                    if (crossed or starting) and position >= cue[1] and position - cue[1] < 0.75 then
                        say(cue[2], false)
                    end
                end
            end
        end
    end
    previous = current
end
return M
