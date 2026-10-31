-- Episode 3, night at the school (level E3_2A): getting into the principal's
-- office. Chloe blows the door, Max walks in, then rewinds time; the door is
-- whole again and Max must unlock it from the inside, in a short window.
--
-- From the level data (E3_2A_Corridor_LD.umap): the inside of the door is
-- LiSInteractionActor_LockDoor ("Door"; actions Open/Use/Unlock), usable from
-- one side only and only while the story fact E3_2A_Corridor_LD_Unlock is on.
-- A sighted player sees its prompt appear; "You can unlock the door now." says
-- so (confirmed in play 31 Oct: spoken when the window opened).
--
-- The scanner also gets an entry "Other side of the principal's door": a point
-- 130 cm past the door on whichever side Max is not on (the user's design, 31
-- Oct), so autowalk takes her through the blown doorway in time. The door's
-- wall runs along X; the principal's office is on its +Y side (from logged
-- positions). Inside/outside announcements were tried and removed: unreliable.
local M={}
M.LEVEL="E3_2A"
M.FACT="E3_2A_Corridor_LD_Unlock"
M.DOOR="LockDoor"
M.MARGIN=40
M.INSIDE_SIGN=1 -- the office is on the +Y side of the door
M.STEP=130   -- cm past the door line to stand
M.log=function(_)end
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local function xy(v)return {X=v.X,Y=v.Y} end
-- Pure: which side of the door p is on. door: {X,Y}. Returns "inside",
-- "outside", or nil within MARGIN of the door line.
function M.side(p,door,margin)
    if not (p and door) then return nil end
    margin=margin or M.MARGIN
    local along=(p.Y-door.Y)*M.INSIDE_SIGN
    if along>margin then return "inside" end
    if along< -margin then return "outside" end
    return nil
end
-- Pure: the standing point on the other side of the door from p (nil in the
-- doorway). door: {X,Y,Z} (the door actor, about 1 m above the floor).
function M.other_side(p,door)
    local s=M.side(p,door)
    if not s then return nil end
    local sign=(s=="inside" and -1 or 1)*M.INSIDE_SIGN
    return {X=door.X,Y=door.Y+sign*M.STEP,Z=door.Z-100},(s=="inside" and "outside" or "inside")
end
-- Pure: what to say for a change. prev/now: {open=}. Only the unlock window
-- is announced; inside/outside announcements were removed (31 Oct, user:
-- "still wonky, take them out").
function M.changes(prev,now)
    local out={}
    if now.open and prev.open==false then out[#out+1]="office_door_unlockable" end
    return out
end
local door,found_at=nil,-10
local state={}
local function find_door()
    for _,a in ipairs(FindAllOf("LiSInteractionActor") or {}) do
        local ok,d=pcall(function()
            if valid(a) and a:GetFullName():find(M.DOOR,1,true) then local v=a:K2_GetActorLocation();return {X=v.X,Y=v.Y,Z=v.Z} end
        end)
        if ok and d then return d end
    end
end
local function in_level(controller)
    local w=nil;pcall(function()w=controller:GetWorld():GetFName():ToString()end)
    return w==M.LEVEL
end
local function refresh(now)
    if not door or now-found_at>=1 then
        found_at=now
        local d=find_door()
        if d and not door then M.log(string.format("office door=%.0f,%.0f,%.0f",d.X,d.Y,d.Z)) end
        door=d or door
    end
end
-- Scanner entry for the other side of the door, or nil.
function M.entry(controller)
    if not in_level(controller) then return nil end
    refresh(os.clock())
    if not door then return nil end
    local p=nil;pcall(function()local v=controller.Pawn:K2_GetActorLocation();p={X=v.X,Y=v.Y} end)
    local target=M.other_side(p,door)
    if not target then return nil end
    return {id="principal_door_other_side",label=M.text("office_other_side"),pos=target,stand=target,kind="goal"}
end
M.text=function(key)return key end
-- Called every main step. Returns text keys to speak.
function M.tick(controller,now)
    if not in_level(controller) then door=nil;state={};return {} end
    local open=false;pcall(function()open=controller:IsFactActive(FName(M.FACT))==true end)
    local cur={open=open}
    local out=M.changes(state,cur)
    if open~=state.open then M.log("office unlock_fact="..tostring(open)) end
    state=cur
    return out
end
return M
