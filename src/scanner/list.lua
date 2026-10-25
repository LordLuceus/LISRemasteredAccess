-- Scanner list logic, independent of the game (covered by offline tests).
-- Entries: {id=stable identity, label=spoken name, pos={X,Y,Z}}.
-- * Ordered nearest first by ground distance; height is reported separately.
-- * Duplicate names get letters by identity, not distance ("Bottle, A"), so
--   walking past two bottles doesn't swap their names.
-- * The selection stays on the same object when the order changes.
local M={}
M.__index=M
function M.new()return setmetatable({entries={},selected=nil},M)end
local function ground(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)end
M.ground=ground
local LETTERS="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
-- Replaces the list. Returns the entries in spoken order.
function M:update(entries,player)
    local groups={}
    for _,e in ipairs(entries) do groups[e.label]=groups[e.label] or {};table.insert(groups[e.label],e) end
    for _,g in pairs(groups) do
        if #g>1 then
            table.sort(g,function(a,b)return a.id<b.id end)
            for i,e in ipairs(g) do e.name=e.label..", "..(i<=#LETTERS and LETTERS:sub(i,i) or tostring(i)) end
        else g[1].name=g[1].label end
    end
    for _,e in ipairs(entries) do e.distance=ground(e.pos,player) end
    table.sort(entries,function(a,b)
        if a.distance~=b.distance then return a.distance<b.distance end
        return a.id<b.id
    end)
    self.entries=entries
    if self.selected then
        local still=false
        for _,e in ipairs(entries) do if e.id==self.selected then still=true end end
        if not still then self.selected=nil end
    end
    return entries
end
function M:index_of(id)
    for i,e in ipairs(self.entries) do if e.id==id then return i end end
end
function M:current()
    local i=self.selected and self:index_of(self.selected)
    if i then return self.entries[i],i end
end
-- Moves the selection by step (+1 next, -1 previous), wrapping. The first
-- press with nothing selected picks the nearest (next) or farthest (previous).
function M:move(step)
    local n=#self.entries
    if n==0 then self.selected=nil;return nil end
    local i=self.selected and self:index_of(self.selected)
    if not i then i=step>0 and 1 or n
    else i=((i-1+step)%n)+1 end
    self.selected=self.entries[i].id
    return self.entries[i],i
end
-- Direction of a point relative to Max's facing (yaw in degrees), as one of
-- eight words. 0 = straight ahead.
local WORDS={"ahead","ahead right","right","behind right","behind","behind left","left","ahead left"}
function M.direction(player,yaw,target)
    local angle=math.deg(math.atan(target.Y-player.Y,target.X-player.X))-yaw
    angle=(angle+180)%360-180
    local i=math.floor(((angle+22.5)%360)/45)+1
    return WORDS[i]
end
-- Height difference in metres, only when it matters (more than 1.5 m).
function M.height(player,target)
    local dz=(target.Z-player.Z)/100
    if dz>1.5 then return "up",dz elseif dz< -1.5 then return "down",-dz end
end
return M
