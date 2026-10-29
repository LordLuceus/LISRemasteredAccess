-- Episode 2 junkyard: helping Chloe shoot the bottles (level E2_3A).
--
-- Measured 29 Oct (user's play, read-only capture):
-- * Bottles 1 and 2: Chloe's first shot is the Matinee
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
M.text=function(key)return key end
M.LEVEL="E2_3A"
-- Chloe's first shot (the Matinee that plays before the rewind) and the
-- moment she fires in it, in sequence seconds. From the level data
-- (E2_3A_Junkyard_LD.umap): the gun group's two sound events and the
-- muzzle/impact toggles sit at 7.73-7.88 s (bottle 1) and 7.65-7.82 s
-- (bottle 2). The description is spoken just after that, once each time the
-- sequence plays forward through it. (29 Oct: speaking at the sequence start
-- was ~8 s early; speaking with the choice was useless - the choice only
-- appears after the rewind.)
M.SHOTS={
    E2_3A_Junkyard_LD_Bottle01_FailChloe={key="shoot_miss_left",fire=8.0},
    E2_3A_Junkyard_LD_Bottle02_FailChloe={key="shoot_miss_low",fire=8.0},
}
-- Story facts that mean "choose a target now".
M.AIMING={"Enable_InteractionGun03","Enable_InteractionGun04"}
-- Pure: one reading of a shot sequence -> its text key if Chloe has just
-- fired. last = the previous position seen (nil before), pos = now, reverse
-- = playing backwards (a rewind). Fires on crossing the shot moment forwards.
function M.fired(shot,last,pos,reverse)
    if reverse or type(pos)~="number" then return nil end
    if last and last<shot.fire and pos>=shot.fire then return shot.key end
    return nil
end
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local last={}
-- Called twice a second. Returns the text keys to speak (Chloe just fired).
function M.tick(controller)
    local w=nil;pcall(function()w=controller:GetWorld():GetFName():ToString()end)
    if w~=M.LEVEL then last={};return {} end
    local out,seen={},{}
    for _,m in ipairs(FindAllOf("MatineeActor") or {}) do
        pcall(function()
            if not valid(m) then return end
            local id=m:GetFName():ToString()
            local shot=M.SHOTS[id]
            if not shot then return end
            seen[id]=true
            local playing=m.bIsPlaying==true
            local pos,rev=nil,false
            pcall(function()pos=m.InterpPosition;rev=m.bReversePlayback==true end)
            if not playing then last[id]=nil;return end
            local k=M.fired(shot,last[id],pos,rev)
            if k then out[#out+1]=k end
            last[id]=pos
        end)
    end
    for id in pairs(last) do if not seen[id] then last[id]=nil end end
    return out
end
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
