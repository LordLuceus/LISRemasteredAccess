-- DIAGNOSTIC (test sessions only): can the loader's RegisterHook see the
-- game's Blueprint functions at all? Finds the widgets on screen whose
-- Blueprint overrides Tick (runs every frame while shown), hooks each Tick
-- once, counts the calls for 20 s and logs the counts. Any count above zero
-- means script hooks work; all zero means they do not, with these settings.
local M={}
function M.run(emit)
    local counts,paths={},{}
    local seen={}
    for _,w in ipairs(FindAllOf("UserWidget") or {}) do
        pcall(function()
            if not (w:IsValid() and w:IsVisible()) then return end
            local cls=w:GetClass():GetFullName():match("^%S+%s+(.+)$")
            if not cls or seen[cls] or not cls:find("^/Game/") then return end
            seen[cls]=true
            local path=cls..":Tick"
            local f=StaticFindObject(path)
            if not (f and f:IsValid()) then return end
            if #paths>=8 then return end
            local ok,err=pcall(function()RegisterHook(path,function()counts[path]=(counts[path] or 0)+1 end)end)
            paths[#paths+1]=path
            emit(string.format("hook_probe hooked=%s ok=%s %s",path,tostring(ok),ok and "" or tostring(err)))
        end)
    end
    emit("hook_probe candidates="..#paths)
    local n=0;local h
    h=LoopInGameThreadWithDelay(1000,function()
        n=n+1
        if n<20 then return end
        CancelDelayedAction(h)
        local total=0
        for _,p in ipairs(paths) do total=total+(counts[p] or 0);emit(string.format("hook_probe count=%d %s",counts[p] or 0,p)) end
        emit("hook_probe RESULT total_calls="..total.." hooked="..#paths)
    end)
end
return M
