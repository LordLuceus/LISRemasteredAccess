-- In-process speech/braille through lisr_speech.dll (Prism). If the DLL cannot
-- load, announcements still reach the log, where the launcher's watcher speaks
-- them. The log line is kept in both cases so Home/reread and diagnostics work.
local M={native=false,load_error=nil}
-- This file is Scripts/core/speech.lua; the DLL is installed in Scripts/.
local here=debug.getinfo(1,"S").source:gsub("^@",""):gsub("[^/\\]+$","")
local dll=here:gsub("core[/\\]$","").."lisr_speech.dll"
local speak_fn,stop_fn,status_fn
do
    local ok,err=pcall(function()
        local f1,e1=package.loadlib(dll,"lisr_speak");if not f1 then error(e1) end
        local f2,e2=package.loadlib(dll,"lisr_stop");if not f2 then error(e2) end
        local f3,e3=package.loadlib(dll,"lisr_status");if not f3 then error(e3) end
        speak_fn,stop_fn,status_fn=f1,f2,f3
    end)
    M.native=ok
    if not ok then M.load_error=tostring(err) end
    -- Controller buttons (same DLL). Optional: an older DLL without it just
    -- means no controller scanner input.
    if ok then
        local f4=package.loadlib(dll,"lisr_pad")
        if f4 then M.pad=function()local pok,v=pcall(f4);return pok and v or -1 end end
        local f5=package.loadlib(dll,"lisr_move")
        if f5 then M.moving=function()local mok,v=pcall(f5);return mok and v==true end end
        local f7=package.loadlib(dll,"lisr_keys")
        if f7 then M.keys=function(...)local kok,v=pcall(f7,...);if kok then return v end end end
        local f8=package.loadlib(dll,"lisr_tick")
        if f8 then M.tick=function(ch,on,pan,ms,vol)local tok,v=pcall(f8,math.floor(ch),on==true,math.floor(pan or 0),math.floor(ms or 500),math.floor(vol or 50));return tok and v==true end end
        local f9=package.loadlib(dll,"lisr_tick_load")
        if f9 then M.tick_load=function(ch,path)local tok,v=pcall(f9,math.floor(ch),path);return tok and v==true end end
        local f6=package.loadlib(dll,"lisr_play")
        if f6 then M.play=function(path)local pok,v=pcall(f6,path);return pok and v==true end end
    end
end
-- Returns true when the native module queued it.
local tidy=require("core.text").tidy
function M.say(text,interrupt)
    if type(text)~="string" or text=="" then return false end
    text=tidy(text)
    print("[LISNavSay] "..text.."\n")
    if not M.native then return false end
    local ok,queued=pcall(speak_fn,text,interrupt~=false)
    return ok and queued==true
end
function M.stop()
    if M.native then pcall(stop_fn) end
end
function M.status()
    if not M.native then return "native=false error="..tostring(M.load_error) end
    local ok,s=pcall(status_fn)
    return ok and ("native=true "..tostring(s)) or ("native=true status_error="..tostring(s))
end
-- Folder holding the cue WAVs (Scripts/audio/).
M.audio_dir=here:gsub("core[/\\]$","").."audio/"
return M
