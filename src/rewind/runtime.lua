-- Called by the existing game-thread loop, never an async/native-input thread.
local Native=require('rewind.native')
local View=require('rewind.view')
local Feedback=require('rewind.feedback')
local Policy=require('rewind.policy')
local M={};M.__index=M
function M.new(o)
    local self=setmetatable({o=o,last_status=nil},M)
    self.native=o.native or Native
    self.view=o.view or View
    self.view.log=o.log
    if not o.native then Native.configure()end
    if not o.view then View.configure()end
    self.feedback=Feedback.new({suppress=function(on)o.control:suppress_cues(on)end,
        play=o.play,fallback=function(key)o.say(o.text(key))end})
    return self
end
function M:tick(now)
    local world,controller=self.o.identity()
    if not world or not controller then self.feedback:update(nil,false,now);return end
    local frame,reason=self.native.sample()
    local allowed=false
    if frame then
        frame.world,frame.controller=world,controller
        -- Native manager state still mutes competing control cues without focus
        -- or a readable gauge. Audio needs both focus and an unobscured HUD.
        allowed=self.o.focused()==true
        if Policy.rewinding(frame) or self.feedback.session or self.feedback.policy.running then
            allowed=allowed and not self.o.in_menu()
            frame.visible=allowed and self.view.visible(frame) or false
        else frame.visible=false end
    end
    local cue=self.feedback:update(frame,allowed,now)
    local status=tostring(reason)..':'..tostring(frame and frame.state)..':'..tostring(frame and frame.visible)
    if status~=self.last_status then
        self.last_status=status;self.o.log('rewind_state '..status)
    end
    if cue then self.o.log('rewind_cue='..cue)end
end
function M:cancel()self.feedback:update(nil,false,0)end
return M
