-- RegisteredDNECues includes thoughts and other characters' voices, even
-- when a line has no visible subtitle. Registration can precede playback.
local M={}
function M.quiet()
    local ok,silent=pcall(function()
        local environments=FindAllOf("AudioEnvironment")
        if not environments or #environments==0 then return nil end
        for _,environment in ipairs(environments) do
            if not environment:IsValid() then return nil end
            local quiet=true
            environment.RegisteredDNECues:ForEach(function(_,item)
                local cue=item:get()
                if not cue or not cue:IsValid() or cue.bPlayFinished~=true then quiet=false end
            end)
            if not quiet then return false end
        end
        -- A subtitle can remain active beyond the audio cue's final callback.
        for _,widget in ipairs(FindAllOf("BP_LiSSubtitlesWidget_View_C") or {}) do
            if widget:IsValid() and widget.bIsShowSubtitle~=false then return false end
        end
        return true
    end)
    if ok then return silent end
end
return M
