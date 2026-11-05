-- Rooms. The game builds most indoor scenes from one sub-level per room
-- (E3_1A_MaxRoom_LD, E3_1A_Corridor_LD, ...), and every actor's full name
-- carries its sub-level ("/Game/Maps/Episode03/Sequence01/E3_1A_MaxRoom_LD.
-- E3_1A_MaxRoom_LD:PersistentLevel.LiSInteractionActor_Bed_3"). The scanner
-- lists only the current room's objects, plus the connections to other rooms
-- (doors and exits), the user's design (31 Oct). Scenes built as one level
-- (the pool, the junkyard, the diner, the campus) have one room and are not
-- narrowed.
--
-- Which room Max is in: the room of the objects nearest her. Her own actor is
-- in the persistent level, so it says nothing; the nearest few non-door objects
-- vote. Doors are excluded from the vote because a door's sub-level is the
-- room on one of its sides.
--
-- Names: a hand table from the sub-level and door actor names (the game ships
-- no room or "door to" strings). Unlisted rooms fall back to the sub-level's
-- own word ("MaxRoom"); unlisted doors keep the game's "Door".
local M={}
M.VOTERS=3
-- Sub-level room word -> spoken name.
M.ROOMS={
    Corridor="corridor",MaxRoom="Max's room",DanaRoom="Dana's room",VicRoom="Victoria's room",
    Bathroom="bathroom",Toilets="toilets",ArtClass="art classroom",PrinOffice="principal's office",
    ChloeRoom="Chloe's room",ParentsRoom="parents' room",Garage="garage",Garden="garden",
    LivingRoom="living room",SwimPool="swimming pool",Junkyard="junkyard",Diner="diner",
    Railroad="railroad",CampusA="campus",CampusB="campus",CampusPark="campus park",
    CHouseFront="front of Chloe's house",ChloeCar="Chloe's car",CliffNow="cliff",CliffFuture="cliff",
}
-- Door interaction actor name (without the trailing _N) -> label. Each from
-- the level data; "door" is appended by the caller's text key.
M.DOORS={
    ArtClassDoor="Art classroom",ArtDoor="Art classroom",ScienceDoor="Science lab",SciDoor01="Science lab",
    SciDoor02="Science lab",PrincipalDoor="Principal's office",LockDoor="Principal's office",
    ToiletDoor="Toilet",LadiesRoomDoor="Ladies' room",SwimmingPoolDoor="Swimming pool",
    JanitorDoor="Janitor's",KateDoor="Kate's",VicRoomDoor="Victoria's",MaxRoomDoor="Max's",
    ChloeDoor="Chloe's",Door01="Garage",Door02="Garage",DinerDoor="Diner",DinerDoor2="Diner",
    BoysDoor="Boys' locker room",GirlsDoor="Girls' locker room", -- read as "...locker room door"ShedDoor="Shed",DoorLock="Shed",
}
-- Pure: the sub-level key of an actor's full name, e.g. "E3_1A_MaxRoom_LD",
-- or nil for actors in the persistent level (".../E3_1A.E3_1A:PersistentLevel").
function M.sublevel(fullname)
    if type(fullname)~="string" then return nil end
    local lvl=fullname:match("/Game/Maps/[%w_/]-/([%w_]+)%.%1:PersistentLevel")
    if not lvl then return nil end
    if not lvl:find("_LD$") then return nil end
    return lvl
end
-- Pure: the room key of ANY sub-level an actor lives in. Each room has its own
-- geometry levels (E3_5A_ChloeRoom_GRC / _GR2 hold its floor and walls) beside
-- its object level (_LD): all map to the same key, "E3_5A_ChloeRoom_LD".
-- nil for the persistent level.
function M.room_of(fullname)
    if type(fullname)~="string" then return nil end
    local lvl=fullname:match("/Game/Maps/[%w_/]-/([%w_]+)%.%1:PersistentLevel")
    if not lvl then return nil end
    local base=lvl:match("^(.-)_GR[%dC]$") or lvl:match("^(.-)_LD$") or lvl:match("^(.-)_SD$")
    if not base then return nil end
    return base.."_LD"
end
-- Pure: could this interaction be a way between rooms? Doors, and what the
-- game names a door in another word (3 Nov: the living room's "Sliding Door"
-- is BayWindow_87, key $GT_Sensen_Int_Window02). The floor test decides.
function M.door_like(fullname,key,label)
    local s=(tostring(fullname)..":"..tostring(key)..":"..tostring(label)):lower()
    return s:find("door",1,true) or s:find("window",1,true) or s:find("gate",1,true) or false
end
-- Pure: the rooms whose floors are found around a door (list of room keys,
-- nils allowed): a set, and whether it is a connection (two rooms or more).
function M.joins(keys,count)
    -- Not ipairs: a missed trace leaves a nil in the list, and ipairs stops
    -- there, losing the rooms after it.
    local set,n={},0
    for i=1,(count or 8) do local k=keys[i];if k and not set[k] then set[k]=true;n=n+1 end end
    return set,n>=2
end
-- Pure: the room from floor samples around Max (list of n keys, nils for
-- missed traces). A different room needs a majority of the samples; otherwise
-- the current room stays (3 Nov: one step onto the diner's doorstep, whose
-- floor is the diner's, switched the list to the diner's inside).
function M.vote(keys,n,current)
    local c,seen={},0
    for i=1,n do local k=keys[i];if k then c[k]=(c[k] or 0)+1;seen=seen+1 end end
    if seen==0 then return nil end
    local best,bn=nil,0
    for k,v in pairs(c) do if v>bn or (v==bn and k==current) then best,bn=k,v end end
    if best~=current and current and c[current] and bn*2<=n then return current end
    return best
end
-- Pure: the first room other than `current` met along a route, from the
-- rooms of floors sampled along it (list of n keys, nils allowed for missed
-- traces). Returns its index and key, or nil. A room reached this way, with
-- no other room in between, is a neighbour even when no door joins them (3
-- Nov: the upstairs bathroom has an open doorway, so nothing led there).
function M.entered(keys,n,current)
    for i=1,n do local k=keys[i];if k and k~=current then return i,k end end
    return nil
end
-- Pure: "Way to the bathroom", "Way to Chloe's room".
function M.way_name(name)
    if not name then return nil end
    if name:find("'",1,true) then return name end
    return "the "..name
end
-- Pure: the room word of a sub-level key ("E3_1A_MaxRoom_LD" -> "MaxRoom").
function M.room_word(sublevel)
    if not sublevel then return nil end
    return sublevel:match("^E%d_%d%u_(.-)_LD$") or sublevel:match("^(.-)_LD$")
end
function M.room_name(sublevel)
    local w=M.room_word(sublevel)
    if not w then return nil end
    return M.ROOMS[w] or w
end
-- Pure: the door label for an interaction actor name, or nil.
function M.door_label(fullname)
    if type(fullname)~="string" then return nil end
    local short=fullname:match("LiSInteractionActor_([%w]+)_%d+$") or fullname:match("LiSInteractionActor_([%w]+)$")
    if not short then return nil end
    return M.DOORS[short]
end
-- Pure: which room Max is in. entries: {pos={X,Y,Z},sublevel=,is_door=};
-- p: Max's position. The nearest VOTERS non-door entries with a sub-level
-- vote, each weighted by 1/distance, so a corridor's one nearby object
-- outweighs a furnished room's several behind the wall. nil when nothing has
-- a sub-level.
function M.current(entries,p)
    local c={}
    for _,e in ipairs(entries) do
        if e.sublevel and not e.is_door and e.pos then
            c[#c+1]={d=math.sqrt((e.pos.X-p.X)^2+(e.pos.Y-p.Y)^2),s=e.sublevel}
        end
    end
    if #c==0 then return nil end
    table.sort(c,function(a,b)return a.d<b.d end)
    local votes,order={},{}
    for i=1,math.min(M.VOTERS,#c) do
        local s=c[i].s
        if not votes[s] then votes[s]=0;order[#order+1]=s end
        votes[s]=votes[s]+1/math.max(c[i].d,30)
    end
    local best=order[1]
    for _,s in ipairs(order) do if votes[s]>votes[best] then best=s end end
    return best
end
-- Pure: keep the current room's objects and the ways out of it. Entries
-- without a sub-level (goals, exits, scene entries) are kept. When the scene
-- has only one sub-level among its objects, nothing is removed.
-- e.joins: the set of rooms a door's floors touch (from the floor test), when
-- known. A door that joins the current room is shown whichever room's level
-- holds it (Chloe's room door lives in her level but is the corridor's way
-- back); one that does not is hidden (the parents' door, from Chloe's room).
-- Without that knowledge, a door is shown as before.
function M.filter(entries,room)
    if not room then return entries end
    local levels={}
    for _,e in ipairs(entries) do if e.sublevel then levels[e.sublevel]=true end end
    local n=0;for _ in pairs(levels) do n=n+1 end
    if n<2 then return entries end
    local out={}
    for _,e in ipairs(entries) do
        local keep
        if e.joins then keep=e.joins[room]==true
        elseif e.is_door then keep=true
        else keep=not e.sublevel or e.kind~="interaction" or e.sublevel==room end
        if keep then out[#out+1]=e end
    end
    return out
end
return M
