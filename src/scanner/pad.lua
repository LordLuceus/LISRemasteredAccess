-- Controller buttons for the scanner, game-independent (offline tested).
-- Turns successive XInput button readings into commands:
--   D-pad left/right  previous/next (hold to repeat)
--   D-pad up          describe
--   D-pad down        autowalk
--   Left-stick click  face, on release, unless used as a modifier:
--   held + D-pad up   help;  held + D-pad right  repeat last announcement;
--   held + D-pad left sound preview.
-- Scanner commands only in gameplay (the caller passes active=false otherwise);
-- the left-stick chords work everywhere.
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
        -- Without control (object viewer, cutscenes, menus) the left-stick
        -- chords still work - repeat, help and sound preview, like Ctrl+Home,
        -- F1 and F2 on the keyboard - but nothing that acts on the world.
        if thumb then
            if (buttons&(UP|DOWN|LEFT|RIGHT))~=0 then self.thumb_used=true end
            if (edge&UP)~=0 then out[#out+1]="help" end
            if (edge&RIGHT)~=0 then out[#out+1]="repeat" end
            if (edge&LEFT)~=0 then out[#out+1]="preview" end
        end
        self.thumb_started=false;self.repeat_at={}
        self.previous=buttons;return out
    end
    if thumb and (buttons&(UP|DOWN|LEFT|RIGHT))~=0 then self.thumb_used=true end
    if (released&THUMB)~=0 and self.thumb_started and not self.thumb_used then out[#out+1]="face" end
    if thumb then
        if (edge&UP)~=0 then out[#out+1]="help" end
        if (edge&RIGHT)~=0 then out[#out+1]="repeat" end
        if (edge&LEFT)~=0 then out[#out+1]="preview" end
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
-- D-pad up/down for reading lists (the journal), with hold-to-repeat. Separate
-- from the scanner state; used only while a reader is open. Returns -1, 1 or nil.
function M:reader(buttons,now)
    if buttons<0 then buttons=0 end
    local prev=self.reader_prev or buttons -- ignore keys already held on entry
    local edge=buttons & ~prev
    self.reader_prev=buttons
    for _,b in ipairs({{UP,-1},{DOWN,1}}) do
        local bit,dir=b[1],b[2]
        if (edge&bit)~=0 then self.reader_at=now+DELAY;self.reader_bit=bit;return dir end
        if (buttons&bit)~=0 and self.reader_bit==bit and self.reader_at and now>=self.reader_at then self.reader_at=now+RATE;return dir end
    end
    if (buttons&(UP|DOWN|LEFT|RIGHT))==0 then self.reader_bit=nil;self.reader_at=nil end
    return nil
end
function M:reader_reset()self.reader_prev=nil;self.reader_bit=nil;self.reader_at=nil end
return M
