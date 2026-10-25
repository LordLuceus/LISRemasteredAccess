-- Controller buttons for the scanner, game-independent (offline tested).
-- Turns successive XInput button readings into commands:
--   D-pad left/right  previous/next (hold to repeat)
--   D-pad up          describe
--   D-pad down        autowalk
--   Left-stick click  face, on release, unless used as a modifier:
--   held + D-pad up   help;  held + D-pad right  repeat last announcement.
-- Active only in gameplay (the caller passes active=false in menus).
local M={}
M.__index=M
local UP,DOWN,LEFT,RIGHT,THUMB=0x1,0x2,0x4,0x8,0x40
local DELAY,RATE=0.45,0.18
function M.new()return setmetatable({previous=0,thumb_used=false,thumb_started=false,repeat_at={}},M)end
-- buttons: current bits (or -1 when no controller); now: seconds.
-- Returns a list of command names.
function M:update(buttons,active,now)
    local out={}
    if buttons<0 then buttons=0 end
    local edge=buttons & ~self.previous
    local released=self.previous & ~buttons
    local thumb=(buttons&THUMB)~=0
    if (edge&THUMB)~=0 then self.thumb_used=false;self.thumb_started=active end
    if not active then
        self.thumb_started=false;self.repeat_at={}
        self.previous=buttons;return out
    end
    if thumb and (buttons&(UP|DOWN|LEFT|RIGHT))~=0 then self.thumb_used=true end
    if (released&THUMB)~=0 and self.thumb_started and not self.thumb_used then out[#out+1]="face" end
    if thumb then
        if (edge&UP)~=0 then out[#out+1]="help" end
        if (edge&RIGHT)~=0 then out[#out+1]="repeat" end
        self.repeat_at={}
    else
        if (edge&UP)~=0 then out[#out+1]="describe" end
        if (edge&DOWN)~=0 then out[#out+1]="autowalk" end
        for _,b in ipairs({{LEFT,"previous"},{RIGHT,"next"}}) do
            local bit,cmd=b[1],b[2]
            if (edge&bit)~=0 then out[#out+1]=cmd;self.repeat_at[bit]=now+DELAY
            elseif (buttons&bit)~=0 and self.repeat_at[bit] and now>=self.repeat_at[bit] then out[#out+1]=cmd;self.repeat_at[bit]=now+RATE end
            if (buttons&bit)==0 then self.repeat_at[bit]=nil end
        end
    end
    self.previous=buttons
    return out
end
return M
