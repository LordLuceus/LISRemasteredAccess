-- Dialogue choices (BP_LiSDialogWidget_View). The view holds four answer
-- buttons (DialogButtons_Array, BP_LiS_DialogButton_Widget). Each shown button
-- has its answer in DialogText, the game's choice index in ActionIndex and its
-- screen position in OptionPosition. The controller face buttons choose by
-- calling the pressed button's ClickButton, which asks the dialogue to choose
-- that button's ActionIndex; the mod's keys call the same ClickButton.
-- Plain values are copied out of the game inside each call.
local M={}
M.text=function(key,p)return key end
M.log=function(_)end
M.trace=false
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid()end)
    return ok and r==true
end
local function visible(o)
    local ok,r=pcall(function()return o:IsVisible()end)
    return ok and r==true
end
-- Face button for each direction icon (the pad's positions: top Y, left X,
-- right B, bottom A, as the interaction pop-up uses).
M.DIRECTION_BUTTONS={Up="Y",Left="X",Right="B",Down="A"}
-- Key names for options: numbers on the keyboard, face buttons on a controller
-- when the direction is known. Pure.
-- When the direction icons are hidden (they are in keyboard mode), the face
-- button comes from the button's slot, as the view's face handlers map it (each
-- branches on IsMajorChoice; 07 is jump-if-NOT):
--   minor: Top slot 1, Left slot 2, Right slot 3, Bottom slot 4
--   major: Left slot 1, Right slot 2, Top slot 3, Bottom slot 4
-- Minor confirmed in play (slot 2 X, slot 3 B); major is from the code only.
M.SLOT_BUTTONS={minor={"Y","X","B","A"},major={"X","B","Y","A"}}
function M.keys(options,gamepad,major)
    local map=M.SLOT_BUTTONS[major and "major" or "minor"]
    for i,o in ipairs(options) do
        local b=o.direction and M.DIRECTION_BUTTONS[o.direction] or map[o.slot or 0]
        o.key=(gamepad and b) or tostring(i)
    end
    return options
end
-- Spoken list. options: {text=,key=} in order. Pure.
function M.announce_text(options,major)
    local parts={}
    for _,o in ipairs(options) do parts[#parts+1]=M.text("choice_option",{key=o.key,text=o.text}) end
    local list=table.concat(parts,", ")
    local s=M.text(major and "choice_major" or "choice_list",{options=list})
    -- End with a full stop unless the last answer already ends a sentence.
    if not s:find("[%.!%?]$") and not s:find("\226\128\166$") then s=s.."." end
    return s
end
-- The dialogue view on screen, if any.
local function view()
    local found=nil
    pcall(function()
        for _,w in ipairs(FindAllOf("BP_LiSDialogWidget_View_C") or {}) do
            local ok,on=pcall(function()return w:IsValid() and w:IsInViewport() and w:IsVisible()end)
            if ok and on then found=w;break end
        end
    end)
    return found
end
-- Shown answers: {button=,text=,index=,position=} in button order.
function M.read()
    local v=view()
    if not v then return nil end
    local buttons={}
    pcall(function()
        v.DialogButtons_Array:ForEach(function(_,e)local ok,b=pcall(function()return e:get()end);if ok then buttons[#buttons+1]=b end end)
    end)
    local out={}
    for i,b in ipairs(buttons) do
        if valid(b) and visible(b) then
            local text=nil
            pcall(function()text=b.DialogText:GetText():ToString()end)
            if text and text:find("%S") then
                local idx,pos=nil,nil
                pcall(function()idx=b.ActionIndex end)
                pcall(function()pos=b.OptionPosition end)
                -- The button shows one direction icon (Image_Up/Left/Right/Down)
                -- for the face button that picks it on a controller.
                local dir=nil
                for _,d in ipairs({"Up","Left","Right","Down"}) do
                    if not dir then pcall(function()if visible(b["Image_"..d]) then dir=d end end) end
                end
                out[#out+1]={button=b,slot=i,text=text,index=idx,position=pos,direction=dir}
            end
        end
    end
    if #out==0 then return nil end
    local major=false;pcall(function()major=v:IsMajorChoice()==true end)
    return out,major
end
-- Chooses the n-th announced answer through the game's own button.
function M.choose(n)
    local options=M.read()
    if not options then M.say(M.text("choice_none"));return false end
    local o=options[n]
    if not o then M.say(M.text("choice_no_option",{index=n}));return false end
    local ok,err=pcall(function()o.button:ClickButton()end)
    M.log("choice_chosen n="..n.." slot="..o.slot.." index="..tostring(o.index).." ok="..tostring(ok)..(ok and "" or " err="..tostring(err)))
    return ok
end
M.say=function(_)end
return M
