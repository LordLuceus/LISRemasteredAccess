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
M.language=function()return "" end
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
local described_room
local function refresh(c)
    local player=viewpoint(c)
    local entries=sources.collect(c)
    if described_room~=sources.room then described_room=nil end
    return list:update(entries,player)
end
-- Once per room, on the first readout there: how many objects the room filter
-- left out, and the key that shows them (3 Nov: the player had no way to know
-- the filter was hiding anything).
local hint_room=nil
M.filter_key=function()return "F4" end
function M.filter_hint(room,shown,total,filtered)
    if not room or room==hint_room or not filtered or not total or total<=shown then return nil end
    hint_room=room
    return M.text("scanner_filter_hint",{total=total,key=M.filter_key()})
end
local function announce(entry,index,setting,repeat_request)
    local c=controller();if not c then return end
    local player,yaw=viewpoint(c)
    local text=R.describe(entry,index,#list.entries,player,yaw)
    local hint=M.filter_hint(sources.room,#list.entries,sources.total,sources.filtered)
    if hint then text=text..". "..hint end
    if setting then text=text:gsub("%.$","")..". "..setting end
    M.say(text,repeat_request)
    M.log("scanner_readout spoken="..text)
end
local function reread_world_object(id,repeat_request)M.command("describe",id,repeat_request)end
function M.command(cmd,expected_id,repeat_request)
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
        if expected_id and (not e or e.id~=expected_id) then return false end
        if not e then e,i=list:move(1) end
        local setting
        if M.language()=="en" then
            if e and not expected_id and M.request_world_look and M.request_world_look(e,c,reread_world_object) then return true end
            local descriptions=require("descriptions.episode1_rooms")
            if sources.room and sources.room~=described_room then
                setting=descriptions[sources.room]
                if setting then described_room=sources.room end
            end
            local objects=e and descriptions.objects[e.sublevel]
            local detail=objects and objects[e.id:match("PersistentLevel%.([^%.]+)$")]
            if not detail and e then detail=require("descriptions.world_looks").describe(e,c) end
            if type(detail)=="table" then
                local variants=detail
                detail=nil
                for _,action in ipairs(require("scanner.actions").available(e.actor)) do
                    if variants[action.name] then detail=variants[action.name];break end
                end
            end
            if detail then setting=setting and (detail.." "..setting) or detail end
        end
        if e then announce(e,i,setting,repeat_request)
        else M.say(setting or M.text("scanner_empty")) end
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
