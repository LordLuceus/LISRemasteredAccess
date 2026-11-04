-- The photo-focus minigame ("PolaRewind": Episode 3 Max's room, Episode 4
-- garage, Episode 5 darkroom, art gallery, diner).
-- Two pictures, two dials: A/D (left stick) turn one, the mouse buttons
-- (right stick) the other. Measured in play (4 Nov, 100 ms trace): each
-- picture's blur is the .B channel of the picture material's
-- ImageA_PositionAndBlur / ImageB_PositionAndBlur, 0.6 (sharp) .. 3.0; held,
-- a dial sweeps it there and back in about half a second each way.
-- Guidance (user's design, 4 Nov): one tick per dial, clearly distinct, panned
-- slightly left (A/D) and right (mouse), ticking faster as its picture
-- sharpens. The tutorial line on the widget is read when it appears or changes.
-- Every read finds the widget fresh and stops once it is solved or gone.
local M={}
M.say=function(_)end
M.log=function(_)end
-- tick(channel, on, pan_thousandths, interval_ms, volume_percent); load(channel, wav)
M.tick_fn=function()end
M.load_fn=function()return false end
M.audio_dir=""
M.WIDGET="BP_LiSPolaRewindWidget_New_C"
M.SHARP,M.BLURRED=0.6,3.0
M.SLOW,M.FAST=700,90          -- ms between ticks, far and sharp
M.CHANNELS={
    {param="ImageA_PositionAndBlur",pan=-400,file="focus_tick_a.wav",volume=90},
    {param="ImageB_PositionAndBlur",pan=400,file="focus_tick_b.wav",volume=60},
}
local active,loaded,last_tuto,last_log=false,false,nil,0
-- Pure: ms between ticks for a blur value: slow when blurred, fast when sharp,
-- quickening most near the sweet spot.
function M.interval_for(v)
    local c=(M.BLURRED-math.max(M.SHARP,math.min(M.BLURRED,v)))/(M.BLURRED-M.SHARP)
    return math.floor(M.FAST+(M.SLOW-M.FAST)*(1-c)^2+0.5)
end
-- Pure: the game has locked the photo (both pictures below the sweet spot).
function M.locked(a,b)
    return type(a)=="number" and type(b)=="number" and a<M.SHARP-0.01 and b<M.SHARP-0.01
end
-- Pure: tidy the tutorial text for speech (markup tags and line breaks out).
function M.tidy(s)
    if type(s)~="string" then return nil end
    s=s:gsub("<[^>]*>",""):gsub("\\n"," "):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
    if s=="" then return nil end
    return s
end
local function widget()
    for _,w in ipairs(FindAllOf(M.WIDGET) or {}) do
        local ok,on=pcall(function()return w:IsValid() and w:IsInViewport() and w:IsVisible()end)
        if ok and on then return w end
    end
end
local function stop(why)
    if active then
        active=false
        for i=1,#M.CHANNELS do pcall(M.tick_fn,i-1,false,0,500,0) end
        M.log("polarewind ticks_off why="..why)
    end
end
function M.tick(now)
    local w=nil;pcall(function()w=widget()end)
    if not w then last_tuto=nil;stop("gone");return end
    local solved=false;pcall(function()solved=w.PuzzleSolved==true end)
    if solved then stop("solved");return end
    pcall(function()
        for _,f in ipairs({"KBTutorial","GamepadTutorial"}) do
            local tb=w[f]
            if tb and tb:IsValid() and tb:IsVisible() then
                local text=M.tidy(tb:GetText():ToString())
                if text and text~=last_tuto then last_tuto=text;M.say(text);M.log("polarewind tutorial="..text) end
                break
            end
        end
    end)
    local mid=nil;pcall(function()mid=w.mEmissiveInstance end)
    local okm=false;pcall(function()okm=mid~=nil and mid:IsValid()end)
    if not okm then stop("no_material");return end
    if not loaded then
        loaded=true
        for i,c in ipairs(M.CHANNELS) do
            local ok=M.load_fn(i-1,M.audio_dir..c.file)
            if not ok then M.log("polarewind tick_load_failed "..c.file) end
        end
    end
    local vals={}
    for i,c in ipairs(M.CHANNELS) do
        pcall(function()vals[i]=mid:K2_GetVectorParameterValue(FName(c.param)).B end)
    end
    -- Locked: the game drives both pictures together below their normal
    -- sharpest value for its closing animation (4 Nov: 0.6 -> 0.08 while the
    -- ticks kept going for several seconds). Silent while that lasts; if the
    -- values part again the game let go, and the ticks come back.
    if M.locked(vals[1],vals[2]) then
        if active then active=false;for i=1,#M.CHANNELS do pcall(M.tick_fn,i-1,false,0,500,0) end;M.log("polarewind ticks_off why=locked") end
        return
    end
    for i,c in ipairs(M.CHANNELS) do
        local v=vals[i]
        if type(v)=="number" and v>0 then
            vals[i]=v
            M.tick_fn(i-1,true,c.pan,M.interval_for(v),c.volume)
        else
            M.tick_fn(i-1,false,c.pan,500,0)
        end
    end
    if not active then active=true;M.log("polarewind ticks_on") end
    if now-last_log>=1 then
        last_log=now
        M.log(string.format("polarewind a=%.3f b=%.3f",vals[1] or -1,vals[2] or -1))
    end
end
function M.stop()stop("stop") end
return M
