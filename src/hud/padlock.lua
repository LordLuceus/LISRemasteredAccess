-- Garage combination entry. Never submit, change digits, or infer the answer.
-- Blueprint fields are read ONLY in the live view's own callbacks. Between
-- callbacks we retain Lua strings/numbers, never engine objects.
local M={}
local VIEW='/Game/Packages/Widgets/TimeTravel/BP_LiSPickLockWidget_View.BP_LiSPickLockWidget_View_C'
local CLASS='BP_LiSPickLockWidget_View_C'
M.text=function(key,p)return key end
M.log=function(_)end
M.clock=os.clock
local state,pending,changed_at=nil,nil,nil
local help_up=false
local installed,reported={},{}
local notified=false
local function unwrap(p)local ok,v=pcall(function()return p:get()end);return ok and v or p end

function M.clear(reason)
    if state then M.log('padlock_closed reason='..tostring(reason)) end
    state,pending,changed_at=nil,nil,nil
    help_up=false
end
function M.active()return state~=nil end
local function selected_text()
    if not state then return nil end
    local n=state.selected
    if n<0 or n>=#state.digits then return M.text('padlock_no_selection') end
    return M.text('padlock_digit',{value=state.digits[n+1],position=n+1,count=#state.digits})
end
function M.current()
    if not state then return nil end
    return M.text('padlock_code',{digits=table.concat(state.digits,', ')})..' '..selected_text()
end
-- Track the actual help gesture, not a speech-duration timer. The game also
-- receives Up: keep its changed value, but don't let that Up press/repeats
-- interrupt help. If L3 is released first, protect until Up is released too.
-- The existing controller command decoder identifies the chord. Raw Up alone
-- (or Up followed by L3) must not arm this protection.
function M.observe_buttons(buttons)
    if type(buttons)~='number' or buttons<0 then buttons=0 end
    if (buttons&0x1)==0 then
        if help_up then M.log('padlock_help_chord released') end
        help_up=false
    end
end
function M.controller_help()
    if not state then return end
    help_up=true
    pending=nil
    M.log('padlock_help_chord start')
end
-- Pure state reducer. Digit is zero-based; -1 means no wheel selected, as
-- observed on first open and reopen. Do not substitute a guessed first wheel.
function M.update(id,digits,selected,event)
    if type(selected)~='number' or selected%1~=0 or selected< -1 or selected>=#digits or #digits==0 then
        M.clear('invalid_snapshot');return false
    end
    local copy={}
    for i,d in ipairs(digits) do
        if type(d)~='string' or not d:match('^%d$') then M.clear('invalid_snapshot');return false end
        copy[i]=d
    end
    local fresh=not state or state.id~=id
    local different=fresh or state.selected~=selected or table.concat(state.digits)~=table.concat(copy)
    state={id=id,digits=copy,selected=selected}
    if different then
        if help_up and event=='Up Pressed' then
            pending=nil
        else
            pending=(fresh or pending=='open') and 'open' or 'change'
        end
        changed_at=M.clock()
        M.log('padlock_capture event='..event..' selected='..selected..' digits='..table.concat(copy,',')..' speech_suppressed='..tostring(help_up and event=='Up Pressed'))
    end
    return different
end
function M.help(gamepad)
    if not state then return nil end
    -- A deliberate help request supersedes speech already queued by its key.
    pending=nil
    return M.text(gamepad and 'padlock_controller' or 'padlock_keyboard')
end
function M.due()
    if not pending or M.clock()-changed_at<0.10 then return nil end
    local opening=pending=='open';pending=nil
    if not opening then return selected_text() end
    return M.text('padlock_open',{count=#state.digits})..' '..M.current()
end
local function capture(self,event)
    local ok,err=pcall(function()
        local v=unwrap(self)
        local digits={}
        v.DigitWidgets_Array:ForEach(function(i,p)
            if i>16 then return end
            local d=unwrap(p)
            digits[i]=d.TextBlock_Digit:GetText():ToString()
        end)
        M.update(v:GetAddress(),digits,v.Digit,event)
    end)
    if not ok then M.clear('read_error');M.log('padlock_read_error='..tostring(err)) end
end
local function hook_failure(path,address,err)
    -- Construction notifications also occur while class defaults are loading,
    -- before UFunction::Func is bound. Keep retrying, but don't dump a stack on
    -- every notification/poll. The real instance notification succeeds before
    -- SpawnDigits (native first-open test, 9 Nov).
    if reported[path]==address then return end
    reported[path]=address
    local message=tostring(err)
    if message:find('UFunction::Func: 0x0',1,true) then
        M.log('padlock_hook_pending='..path)
    else M.log('padlock_hook_error='..path..' '..(message:match('^[^\r\n]+') or message)) end
end
function M.install()
    if not RegisterHook then return end
    for _,event in ipairs({'OpenMenuImplementable','SpawnDigits','DialFocused','Up Pressed','Down Pressed','Left Pressed','Right Pressed','Code_Touched'}) do
        local path=VIEW..':'..event
        local f=StaticFindObject(path)
        if f and f:IsValid() and installed[path]~=f:GetAddress() then
            local address=f:GetAddress()
            local ok,err=pcall(RegisterHook,path,function(self)capture(self,event)end)
            if ok then installed[path]=address;reported[path]=nil;M.log('padlock_hook='..event)
            else hook_failure(path,address,err) end
        end
    end
    for _,event in ipairs({'Exit','Cancel Pressed'}) do
        local path=VIEW..':'..event
        local f=StaticFindObject(path)
        if f and f:IsValid() and installed[path]~=f:GetAddress() then
            local address=f:GetAddress()
            local ok,err=pcall(RegisterHook,path,function()M.clear(event)end)
            if ok then installed[path]=address;reported[path]=nil else hook_failure(path,address,err) end
        end
    end
end
-- The native base exists at startup. Its construction notification installs
-- Blueprint hooks before the first OpenMenuImplementable, even when the asset
-- was just loaded. No widget fields are touched in this notification.
function M.start()
    if notified or not NotifyOnNewObject then return end
    local ok,err=pcall(NotifyOnNewObject,'/Script/LiS.LiSPickLockWidget',function()
        local good,why=pcall(M.install)
        if not good then M.log('padlock_install_error='..tostring(why)) end
    end)
    if ok then notified=true else M.log('padlock_notify_error='..tostring(err)) end
end
-- Presence only, using fresh objects and native methods, like the choices
-- reader. No cached object and no Blueprint property dereferences here.
-- This also clears on successful native submission, map changes and removal
-- by routes other than Escape; Apply itself says nothing about the result.
function M.check_presence()
    if not state then return end
    local found=false
    local ok=pcall(function()
        for _,v in ipairs(FindAllOf(CLASS) or {}) do
            if v:IsValid() and v:GetAddress()==state.id and v:IsInViewport() and v:IsVisible() then found=true;break end
        end
    end)
    if not ok or not found then M.clear(ok and 'hidden' or 'presence_error') end
end
return M
