-- Tutorial prompts (BWFTutorial_Widget). Every tutorial text sits in this one
-- widget and all of them count as visible while it is on screen, so the shown
-- prompt is found by following the widget's switchers: WidgetSwitcher_TutoStep's
-- active step, then each nested switcher's active child (keyboard or gamepad
-- variant), down to the text blocks that are actually displayed.
-- Mouse-drag prompts are replaced with the mod's own steps, matched by the text
-- block's NAME (stable in every language), as the original did by text ID.
local M={}
M.text=function(key,p)return key end
M.log=function(_)end
-- Text blocks whose prompts are rewritten (keyboard and gamepad variants).
M.REWRITE={
    ["Look_M+K"]="tutorial_look",["Look_GamepadRich"]="tutorial_look",
    ["Selfie_M+K"]="tutorial_selfie",["Selfie_GamepadRich"]="tutorial_selfie",["Selfie_Gamepad_1"]="tutorial_selfie",
}
-- Spoken names for the controller images the game puts in prompts. Pure.
M.IMAGES={LStick36="left stick",RStick36="right stick",LookXB1="Y",LTXB1_0="left trigger",
    RTXB1_0="right trigger",LBXB1_0="left bumper",RBXB1_0="right bumper",Mouse="the mouse"}
function M.speakable(s)
    s=s:gsub('<img id="([^"]+)"%s*/>',function(id)return M.IMAGES[id] or id end)
    s=s:gsub("<[^>]+>","")
    s=s:gsub("\226\128\156",'"'):gsub("\226\128\157",'"') -- curly quotes (UTF-8)
    s=s:gsub("%s*[\r\n]+%s*"," "):gsub("%s+"," ")
    return (s:gsub("^%s+",""):gsub("%s+$",""))
end
-- Split prompts: the game shows "Use " + a button picture + " to move" as two
-- text blocks around an image, so the picture's meaning is lost in text. From
-- the widget's own layout: each pad text box holds its two halves and one image
-- (MoveTutorialPad: Bouton_xbox_L3, CameraPad: Bouton_xbox_R, CameraMouse:
-- mouseicon). The name is inserted where the image sits, after the first half.
-- The rewind prompts use an animated face-button picture; its FaceButton value
-- (game enum: 12 LeftTrig, 11 RightTrig, 7 Leftbump) names the button:
-- Spiral/TapToRewind hold left trigger, FastRewind right trigger, QuickUndo and
-- NewFact the left bumper. Same buttons as the game's rich-text versions.
M.SPLIT_IMAGES={MoveTutorialPad1="tutorial_image_left_stick",CameraPad1="tutorial_image_right_stick",
    CameraMouse1="tutorial_image_mouse",TextBlock_SpiralPad1="tutorial_image_left_trigger",
    TapToRewindTutorialPad1="tutorial_image_left_trigger",FastRewindTutorialPad1="tutorial_image_right_trigger",
    QuickUndoTutorialPad1="tutorial_image_left_bumper",NewFactPad1="tutorial_image_left_bumper"}
-- Builds the spoken prompt from the displayed blocks {name=,text=}. Pure.
function M.compose(blocks,gamepad)
    for _,b in ipairs(blocks) do
        local key=M.REWRITE[b.name]
        if key then return M.text(key..(gamepad and "_pad" or "_keys")),key end
    end
    local parts={}
    for _,b in ipairs(blocks) do
        local t=M.speakable(b.text or "")
        if t~="" and not t:find("^%$") then parts[#parts+1]=t end
        local image=M.SPLIT_IMAGES[b.name]
        if image then parts[#parts+1]=M.text(image) end
    end
    -- Split prompts ("Hold " + image + " to rewind") are separate blocks in
    -- the widget; joining them with a space restores the sentence.
    local s=table.concat(parts," "):gsub("%s+"," ")
    if s=="" then return nil end
    return s,nil
end
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid()end)
    return ok and r==true
end
local function shown(w)
    local ok,v=pcall(function()return w:IsVisible()end)
    return ok and v==true
end
-- Collect the displayed text blocks under w, following switchers' active child.
local function collect(w,out,depth)
    if depth>8 or not valid(w) or not shown(w) then return end
    local name="";pcall(function()name=w:GetFName():ToString()end)
    local is_switcher=false;pcall(function()is_switcher=w:IsA("/Script/UMG.WidgetSwitcher")end)
    if is_switcher then
        local a=nil;pcall(function()a=w:GetActiveWidget()end)
        return collect(a,out,depth+1)
    end
    local is_text=false;pcall(function()is_text=w:IsA("/Script/UMG.TextBlock") or w:IsA("/Script/UMG.RichTextBlock")end)
    if is_text then
        local ok,s=pcall(function()return w:GetText():ToString()end)
        if ok and type(s)=="string" and s:find("%S") then out[#out+1]={name=name,text=s} end
        return
    end
    local n=0;pcall(function()n=w:GetChildrenCount()end)
    for i=0,(n or 0)-1 do
        local c=nil;pcall(function()c=w:GetChildAt(i)end)
        collect(c,out,depth+1)
    end
end
-- The prompt currently shown, or nil.
function M.current(gamepad)
    -- Several instances can exist (one per loaded world); use the one on screen.
    -- FindFirstOf returned a hidden instance while the photo prompt was showing.
    local w,count=nil,0
    pcall(function()
        for _,x in ipairs(FindAllOf("BWFTutorial_Widget_C") or {}) do
            count=count+1
            local ok,on=pcall(function()return x:IsValid() and x:IsInViewport() and x:IsVisible()end)
            if ok and on and not w then w=x end
        end
    end)
    if M.trace and count~=M.last_count then M.last_count=count;M.log("tutorial_instances count="..count) end
    local live=valid(w)
    if not live then
        if M.trace and M.last_sig~="hidden" then M.last_sig="hidden";M.log("tutorial_step widget_hidden") end
        return nil
    end
    local step=nil;pcall(function()step=w.WidgetSwitcher_TutoStep end)
    if not valid(step) then return nil end
    local blocks={}
    collect(step,blocks,0)
    -- Diagnostic (test sessions): the step index and why nothing was collected.
    if M.trace then
        local idx="?";pcall(function()idx=tostring(step:GetActiveWidgetIndex())end)
        local a=nil;pcall(function()a=step:GetActiveWidget()end)
        local an="none";pcall(function()an=a:GetFName():ToString()end)
        local vis="?";pcall(function()vis=tostring(a:IsVisible()).."/"..tostring(step:IsVisible()).."/"..tostring(w:IsVisible())end)
        local sig=idx..":"..an..":"..vis..":"..#blocks
        if sig~=M.last_sig then M.last_sig=sig;M.log("tutorial_step index="..idx.." active="..an.." visible(active/step/widget)="..vis.." blocks="..#blocks) end
    end
    if #blocks==0 then return nil end
    local names={};for _,b in ipairs(blocks) do names[#names+1]=b.name end
    local text,rewrite=M.compose(blocks,gamepad)
    return text,table.concat(names,","),rewrite
end
return M
