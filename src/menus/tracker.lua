-- Decides what to speak from successive menu snapshots. Game-independent, so it
-- is covered by the offline tests. A snapshot is {screen=id, index=n, label=s,
-- value=s or nil, key=s or nil}, or nil when no readable menu is on screen.
-- * Moving to another screen or option speaks "label, value" (or just label).
-- * The same option's value changing (for example A/D on a setting) speaks
--   only the new value, so changing a setting doesn't repeat its name.
-- * key, when given, identifies the label for change detection instead of the
--   label text itself: a countdown inside a message ("restored in 22 seconds")
--   then doesn't re-read the message every second.
-- Never speaks the same readout twice in a row.
local M={}
M.__index=M
function M.new()
    return setmetatable({screen=nil,index=nil,label=nil,value=nil,key=nil},M)
end
local join=require("core.text").join
local function ident(s)return s.key or s.label end
-- Returns text,is_fallback when something should be spoken, otherwise nil.
-- is_fallback means the option had no readable label.
-- Full readout of the current state, for rereading on request.
function M:current()
    if not self.screen or self.label==nil or self.label=="" then return nil end
    return join(self.label,self.value)
end
function M:update(s)
    if not s or not s.screen then
        self.screen,self.index,self.label,self.value,self.key=nil,nil,nil,nil,nil
        return nil
    end
    local same_option=s.screen==self.screen and s.index==self.index
    local same_label=same_option and ident(s)==(self.key or self.label)
    if same_label and s.value==self.value then
        self.label=s.label -- keep the latest wording without speaking it
        return nil
    end
    self.screen,self.index,self.label,self.value,self.key=s.screen,s.index,s.label,s.value,s.key
    if s.label==nil or s.label=="" then return nil,true end
    if same_label then
        if s.value==nil or s.value=="" then return s.label,false end
        return s.value,false
    end
    return join(s.label,s.value),false
end
return M
