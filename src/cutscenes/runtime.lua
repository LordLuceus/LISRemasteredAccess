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
    self.repeat_key=nil
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
        local key=tostring(language)..':'..frame.url..':'..tostring(reason)
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
    if not self.active or not frame.playing or changed or
       (self.policy.time and frame.time<self.policy.time-.05) then self.repeat_key=nil end
    local dialogue=Tracks.in_dialogue(track,frame.time)
    frame.allowed=frame.allowed and not dialogue
    local cue,stop=self.policy:update(frame,track.cues)
    if stop then self.o.stop(self.owner) end
    if cue then
        self.repeat_key=nil
        local queued=self.o.say(cue,self.first,self.owner);self.first=false
        self.o.log('cutscene_cue movie='..track.id..' time='..string.format('%.3f',frame.time)..' queued='..tostring(queued))
    elseif self.repeat_key==key and frame.allowed and frame.playing and self.policy.last then
        self.repeat_key=nil;self.o.say(self.policy.last,true,self.owner)
    end
end
function M:reread(repeat_only)
    -- A menu or another movie may have appeared since the periodic sample.
    local frame=(self.o.sample or Native.sample)()
    if not frame or not frame.active or not self.o.focused() or not self.o.allowed() then return false end
    local track=self.tracks:load(frame.url,self.o.language())
    local same=track and self.key==frame.key..':'..track.key
    if repeat_only and not (same and self.policy.last) then return false end
    if track and Tracks.in_dialogue(track,frame.time) then
        if same and self.policy.last then self.repeat_key=self.key end
        return true
    end
    if same and self.policy.last then self.o.say(self.policy.last,true,self.owner)
    else self.o.say(self.o.text(track and #track.cues>0 and 'cutscene_not_yet' or 'cutscene_not_available'),true)end
    return true
end
return M
