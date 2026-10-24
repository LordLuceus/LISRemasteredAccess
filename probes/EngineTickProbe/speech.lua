-- In-process speech/braille through lisr_speech.dll (Prism). If the DLL cannot
-- load, announcements still reach the log, where the launcher's watcher speaks
-- them. The log line is kept in both cases so Home/reread and diagnostics work.
local M={native=false,load_error=nil}
local here=debug.getinfo(1,"S").source:gsub("^@",""):gsub("[^/\\]+$","")
local dll=here.."lisr_speech.dll"
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
end
-- Returns true when the native module queued it.
function M.say(text,interrupt)
    if type(text)~="string" or text=="" then return false end
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
return M
