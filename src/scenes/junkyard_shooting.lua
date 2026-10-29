-- Episode 2 junkyard: helping Chloe shoot the bottles (level E2_3A).
--
-- Measured 29 Oct (user's play, read-only capture):
-- * Bottles 1 and 2 (not handled here yet): Chloe's first shot is the Matinee
--   E2_3A_Junkyard_LD_Bottle0N_FailChloe; the aiming choice (Left/Right/Up/
--   Down) appears as it ends. A wrong answer plays Bottle0N_Fail01..03, after
--   which FailChloe plays again; the right answer plays Bottle0N_Success.
--   Each bottle has a single miss animation (level data: PlayAnim_Gun01_Fail,
--   PlayAnim_Gun02_Fail), so where the shot lands is the same every time. It
--   is inferred from the answer that fixes it (bottle 1: Right; bottle 2: Up,
--   user-confirmed) - described, never named as the answer (user's decision:
--   "avoid just giving away the puzzle").
-- * Bottles 3 and 4: Max chooses a target by aiming the camera at it
--   (camera TP_Junkyard_Manual, a CBA_3RD_Basic like the walking camera, so
--   the mod's facing can turn it). The targets are enabled while
--   Enable_InteractionGun03/04 is on. No solution is given: trial and error
--   for sighted players too.
local M={}
M.LEVEL="E2_3A"
-- Story facts that mean "choose a target now".
M.AIMING={"Enable_InteractionGun03","Enable_InteractionGun04"}
-- Is Max choosing a target right now (bottles 3 and 4)?
function M.aiming(controller)
    local w=nil;pcall(function()w=controller:GetWorld():GetFName():ToString()end)
    if w~=M.LEVEL then return false end
    for _,f in ipairs(M.AIMING) do
        local ok,v=pcall(function()return controller:IsFactActive(FName(f))end)
        if ok and v==true then return true end
    end
    return false
end
return M
