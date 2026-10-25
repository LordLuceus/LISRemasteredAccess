-- Decides what to speak from successive menu snapshots. Game-independent, so it
-- is covered by the offline tests. A snapshot is {screen=id, index=n, label=s,
-- value=s or nil}, or nil when no readable menu is on screen.
-- * Moving to another screen or option speaks "label, value" (or just label).
-- * The same option's value changing (for example A/D on a setting) speaks
--   only the new value, so changing a setting doesn't repeat its name.
-- * The same option's label changing speaks the full readout.
-- Never speaks the same readout twice in a row.
local M={}
M.__index=M
function M.new()
    return setmetatable({screen=nil,index=nil,label=nil,value=nil},M)
end
local function join(label,value)
    if value==nil or value=="" then return label end
    return label..", "..value
end
-- Returns text,is_fallback when something should be spoken, otherwise nil.
-- is_fallback means the option had no readable label.
function M:update(s)
    if not s or not s.screen then
        self.screen,self.index,self.label,self.value=nil,nil,nil,nil
        return nil
    end
    local same_option=s.screen==self.screen and s.index==self.index
    if same_option and s.label==self.label and s.value==self.value then return nil end
    local only_value=same_option and s.label==self.label
    self.screen,self.index,self.label,self.value=s.screen,s.index,s.label,s.value
    if s.label==nil or s.label=="" then return nil,true end
    if only_value then
        if s.value==nil or s.value=="" then return s.label,false end
        return s.value,false
    end
    return join(s.label,s.value),false
end
return M
