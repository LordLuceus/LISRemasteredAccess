-- Keyboard shortcuts, polled from the mod's game-thread loop.
-- UE4SS key binds (RegisterKeyBind/Async) are NOT used: their callbacks run Lua
-- on the loader's event thread without the game-thread lock, so they can run at
-- the same moment as the game-thread loop and corrupt the shared Lua state
-- (traced with debug symbols: crashes inside Lua's own tables and object
-- lookups). Instead the native module reports which bound keys are down
-- (lisr_keys) and this module turns that into presses. Pure; offline tested.
-- Modifiers must match exactly, as with the loader's binds: Home alone, Ctrl+Home
-- and Shift+Home are three different shortcuts.
local M={}
M.__index=M
local SHIFT,CTRL=1<<30,1<<31
-- Held keys bound with {repeat=true} fire again after DELAY, then every RATE
-- seconds - the same timing as the controller's D-pad (scanner/pad.lua).
M.DELAY,M.RATE=0.45,0.18
function M.new()return setmetatable({list={},vks={},slot={},prev=nil,due={}},M)end
-- mods: nil/"none", "shift" or "ctrl". opts: {repeat=true} to repeat while held.
function M:bind(vk,mods,fn,opts)
    if not self.slot[vk] then self.vks[#self.vks+1]=vk;self.slot[vk]=#self.vks end
    self.list[#self.list+1]={vk=vk,mods=mods or "none",fn=fn,rep=opts and opts["repeat"]==true}
end
-- mask: bit i-1 for the i-th key in self.vks, bit 30 Shift, bit 31 Ctrl (or nil
-- when unavailable). Returns the functions of the shortcuts pressed since the
-- previous reading, in binding order, plus repeats of held repeating keys.
-- Keys already down at the first reading are ignored. now: seconds.
-- blocked consumes presses without dispatching them (native key capture).
-- Keep observing releases and discard repeat timers, so the newly assigned
-- key cannot also run a mod shortcut when the capture dialog closes.
function M:update(mask,now,blocked)
    local out={}
    now=now or 0
    if type(mask)~="number" then self.due={};return out end
    local prev=self.prev;self.prev=mask
    if blocked then self.due={};return out end
    if prev==nil then return out end
    local shift=(mask&SHIFT)~=0
    local ctrl=(mask&CTRL)~=0
    local mods=ctrl and (shift and "both" or "ctrl") or (shift and "shift" or "none")
    for _,b in ipairs(self.list) do
        local bit=1<<(self.slot[b.vk]-1)
        local down=(mask&bit)~=0
        if down and (prev&bit)==0 and b.mods==mods then
            out[#out+1]=b.fn
            if b.rep then self.due[b]=now+M.DELAY end
        elseif down and b.rep and self.due[b] and b.mods==mods and now>=self.due[b] then
            out[#out+1]=b.fn;self.due[b]=now+M.RATE
        end
        if not down or b.mods~=mods then self.due[b]=nil end
    end
    return out
end
return M
