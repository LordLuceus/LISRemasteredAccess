-- Game-independent coordinator. Suppression follows actual native rewind state,
-- independently of whether a visible gauge/focus currently permits marker cues.
local Policy=require('rewind.policy')
local M={};M.__index=M
function M.new(output)
    return setmetatable({policy=Policy.new(),output=output or {},session=false},M)
end
function M:update(frame,allowed,now)
    local key=frame and table.concat({tostring(frame.manager),tostring(frame.world),tostring(frame.controller)},':')
    if key~=self.key then self.session=false;self.policy:reset();self.key=key end
    if Policy.rewinding(frame) then self.session=true
    elseif not frame or frame.state~=3 then self.session=false end
    local mute=Policy.rewinding(frame) or (self.session and frame.state==3)
    if self.output.suppress then self.output.suppress(mute) end
    local sample
    if frame then sample={};for k,v in pairs(frame)do sample[k]=v end;sample.context=allowed==true end
    local cue=self.policy:update(sample,now)
    if not cue then return nil end
    local file='rewind_'..cue..'.wav'
    local ok,played=false,false
    if self.output.play then ok,played=pcall(self.output.play,file) end
    if (not ok or not played) and self.output.fallback then self.output.fallback('cue_rewind_'..cue) end
    return cue
end
return M
