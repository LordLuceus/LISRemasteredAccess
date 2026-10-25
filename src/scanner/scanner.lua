-- Scanner: select an object, hear where it is. Commands run on the game thread.
-- The list is rebuilt on every command, so readouts are always current.
-- Gameplay only: in menus the scanner says nothing and the keys are free.
local M={}
local L=require("scanner.list")
local R=require("scanner.readout")
local sources=require("scanner.sources")
local list=L.new()
M.say=function(_)end
M.log=function(_)end
M.text=function(key,p)return key end
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid()end)
    return ok and r==true
end
local function controller()
    for _,c in ipairs(FindAllOf("LiSPlayerController") or {}) do
        if valid(c) and valid(c.Pawn) then return c end
    end
end
-- Where Max is and which way the camera faces.
local function viewpoint(c)
    local p=c.Pawn:K2_GetActorLocation()
    local yaw=c:GetControlRotation().Yaw
    return {X=p.X,Y=p.Y,Z=p.Z},yaw
end
local function refresh(c)
    local player=viewpoint(c)
    return list:update(sources.collect(c),player)
end
local function announce(entry,index)
    local c=controller();if not c then return end
    local player,yaw=viewpoint(c)
    local text=R.describe(entry,index,#list.entries,player,yaw)
    M.say(text)
    M.log("scanner_readout spoken="..text)
end
function M.command(cmd)
    local c=controller()
    if not c then return false end
    -- Position and camera, so a game-side reaction to the same key would show.
    if M.trace then pcall(function()
        local p=c.Pawn:K2_GetActorLocation();local r=c:GetControlRotation()
        M.log(string.format("scanner_key cmd=%s max=%.1f,%.1f,%.1f yaw=%.2f pitch=%.2f",cmd,p.X,p.Y,p.Z,r.Yaw,r.Pitch))
    end) end
    refresh(c)
    if cmd=="next" or cmd=="previous" then
        local e,i=list:move(cmd=="next" and 1 or -1)
        if not e then M.say(M.text("scanner_empty"));return true end
        announce(e,i)
    elseif cmd=="describe" then
        local e,i=list:current()
        if not e then e,i=list:move(1) end
        if not e then M.say(M.text("scanner_empty"));return true end
        announce(e,i)
    end
    return true
end
-- The selected entry (for autowalk and facing), refreshed from the game.
function M.selected()
    local c=controller();if not c then return nil end
    refresh(c)
    return list:current()
end
M.controller=controller
return M
