-- Sound preview: each press plays the next of the mod's cues and says which it
-- is, so the player can learn them outside the moment they matter.
-- Game-independent apart from the play/say functions supplied by the caller.
local M={}
M.cues={
    {file="control_lost.wav",key="cue_control_lost"},
    {file="control_back.wav",key="cue_control_back"},
    {file="sneak_spotted.wav",key="cue_sneak_spotted"},
    {file="sneak_hidden.wav",key="cue_sneak_hidden"},
}
M.text=function(key)return key end
M.say=function(_)end
M.play=function(_)return false end
local index=0
-- Plays the next cue. Says its name first, then plays it once speech has had
-- a moment (the caller schedules `after`). Returns the cue played.
function M.next(after)
    index=index%#M.cues+1
    local cue=M.cues[index]
    M.say(M.text(cue.key))
    if after then after(function()M.play(cue.file)end) else M.play(cue.file) end
    return cue
end
function M.reset()index=0 end
return M
