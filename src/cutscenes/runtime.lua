-- Coordinates only movie descriptions; never controls playback, input or saves.
local Native=require('cutscenes.native')
local Tracks=require('cutscenes.tracks')
local Policy=require('cutscenes.policy')
local M={};M.__index=M
function M.new(o)
    return setmetatable({o=o,policy=Policy.new(),tracks=o.tracks or Tracks.new(o.root),
        owner={},errors={},active=false},M)
end
function M:cancel()
    self.o.stop(self.owner)
    self.policy:update(nil,{})
    self.active=false
end
function M:tick()
    local frame,why=(self.o.sample or Native.sample)()
    if not frame then
        self:cancel()
        if why and not self.errors[why] then
            self.errors[why]=true;self.o.log('cutscene_reader_error='..why)
            self.o.say(self.o.text('cutscene_unavailable'),true)
        end
        return
    end
    local language=self.o.language()
    frame.focused=self.o.focused()==true
    frame.allowed=self.o.allowed()==true
    local track,reason=self.tracks:load(frame.url,language)
    if not track then
        self:cancel()
        self.active=frame.active and frame.focused and frame.allowed
        self.has_track=false;self.policy.last=nil
        local key=language..':'..frame.url..':'..tostring(reason)
        if not self.errors[key] then
            self.errors[key]=true;self.o.log('cutscene_track_unavailable reason='..tostring(reason))
        end
        return
    end
    frame.key=frame.key..':'..track.key
    self.has_track=#track.cues>0
    self.active=frame.active and frame.focused and frame.allowed
    local key=frame.key
    local changed=self.key~=key
    if changed then self.key=key;self.first=true end
    local cue,stop=self.policy:update(frame,track.cues)
    if stop then self.o.stop(self.owner) end
    if cue then
        self.o.say(cue,self.first,self.owner);self.first=false
        self.o.log('cutscene_cue movie='..track.id..' time='..string.format('%.3f',frame.time))
    end
end
function M:reread()
    -- A menu or another movie may have appeared since the periodic sample.
    local frame=(self.o.sample or Native.sample)()
    if not frame or not frame.active or not self.o.focused() or not self.o.allowed() then return false end
    local track=self.tracks:load(frame.url,self.o.language())
    local same=track and self.key==frame.key..':'..track.key
    if same and self.policy.last then self.o.say(self.policy.last,true,self.owner)
    else self.o.say(self.o.text(track and #track.cues>0 and 'cutscene_not_yet' or 'cutscene_not_available'),true)end
    return true
end
return M
