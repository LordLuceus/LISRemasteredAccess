-- Decides what to speak from successive menu snapshots. Game-independent, so it
-- is covered by the offline tests. A snapshot is {screen=id, index=n, label=s},
-- or nil when no readable menu is on screen. Speaks when the screen or the
-- highlighted option changes, or when the same option's label changes (for
-- example when text finishes loading). Never speaks the same readout twice.
local M={}
M.__index=M
function M.new()
    return setmetatable({screen=nil,index=nil,label=nil},M)
end
-- Returns text,is_fallback when something should be spoken, otherwise nil.
-- is_fallback means the option had no readable label.
function M:update(s)
    if not s or not s.screen then
        self.screen,self.index,self.label=nil,nil,nil
        return nil
    end
    if s.screen==self.screen and s.index==self.index and s.label==self.label then return nil end
    self.screen,self.index,self.label=s.screen,s.index,s.label
    if s.label==nil or s.label=="" then return nil,true end
    return s.label,false
end
return M
