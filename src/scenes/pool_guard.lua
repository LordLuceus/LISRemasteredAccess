-- Episode 3, the swimming pool at night (level E3_3A): hiding from the guard.
--
-- From the level's script (E3_3A_SwimPool_LD.umap, IA_Behavior_29) and two
-- recorded runs (31 Oct): after the "Hide!" cutscene Max is free; walking into
-- the hall trigger (FaceTrigger_4 at 4,-2231) starts GuardBlockExit, and when
-- it ends the patrol Matinee GuardPatrolInLocker plays: the guard walks his
-- fixed route with the torch, switching the game's detection on and off at
-- fixed moments; Chloe hides; StealthOn is set. When the patrol ends, Chloe
-- can be spoken to (CanLeaveWithChloe) and the exit opens. A passage on the
-- pool side (FaceTrigger_1 at -386,-2317) plays "wrong way" at any time.
-- Three volumes along the lockers in the middle of the room
-- (x -521/-361/-217, y -1690) are the hiding row the guide means.
--
-- What this gives the player (user's design, 31 Oct: audio cues, not speech):
-- * scanner entries "Way to the hall" (walk into the trigger that starts the
--   scene) and "Hiding spot" (the far side of the locker furthest from the
--   guard, recomputed as he moves);
-- * while the patrol plays, a cue when the guard gets a clear view of Max
--   (sneak_spotted.wav) and a calmer one when she is out of his view again
--   (sneak_hidden.wav). "In view" = a line from his head to her chest is
--   clear AND she is within SIGHT_HALF_ANGLE of his facing. Two readings in a
--   row must agree. Nothing plays outside the patrol.
local M={}
M.LEVEL="E3_3A"
M.PATROL="E3_3A_SwimPool_LD_GuardPatrolInLocker"
M.GUARD_MESH="DavidGuard"
-- 31 Oct, 68 readings during a patrol: the guard actor stood still at the
-- locker-room door (80,-1360) facing west (yaw 180) the whole time, while the
-- player was caught twice, once 10 m away behind geometry. What sweeps is the
-- TORCH (SkeletalMeshActorMAT with SK_Light_TorchLight01, moved during the
-- patrol): its facing is the cone the game tests, so the sight test runs
-- from the torch, with the guard's facing as the fallback.
M.TORCH_MESH="TorchLight"
-- Run 9 (1 Nov): the TorchLight actor sat at the origin, rotation 0, the whole
-- patrol - it is not what sweeps either. The beam is the guard's ANIMATION:
-- his hand sweeps the torch while his actor stands still. So the eye is the
-- guard's hand bone/socket, read live from his skeletal mesh. Sockets are
-- listed once (DIAGNOSTIC) to find the right name; candidates tried in order.
M.HAND_SOCKETS={"Torch","TorchSocket","Lamp","Flashlight","hand_r","RightHand","R_Hand","hand_R","Bip01_R_Hand","b_RightHand"}
-- Where the guard comes from. The GuardBlockExit cutscene's camera keys sit
-- at the pool's main entrance (220,-707 / 124,-856 / 174,-548), the entrance
-- volume DNEVolume_3 is at 123,-763, and the patrol then comes down past the
-- lockers to the locker-room doors (y=-1344). So "the hall" the guide means
-- is the main entrance, north of the pool, not the south passage (two runs
-- aimed there, 31 Oct, both refused by the "wrong way" trigger at -386,-2317:
-- that passage is the way OUT, opened only after the patrol).
-- Confirmed from a playthrough video (31 Oct): after "Hide!" the player walks
-- out through a locker room into the hall with the vending machine, and
-- "Leave The Swimming Pool" comes up at the double doors; taking it is what
-- brings the guard. The prompt is the entrance volume's own (DNEVolume_3,
-- 123,-763, half-size 76x57): Max must be INSIDE it. The previous target, 90
-- cm short of its centre, stopped her 35 cm outside and nothing happened.
M.ENTRANCE={X=123,Y=-763,Z=0}
M.ENTRANCE_THROUGH=100       -- aim past the centre so she crosses into the volume
M.WAY_OUT={X=-386,Y=-2317,Z=4}
M.WAY_OUT_THROUGH=120
M.STEALTH_FACT="E3_3A_SwimPool_LD_StealthOn"
M.ESCAPE_FACT="E3_3A_SwimPool_LD_EscapingOn"
M.LOCKER_Y=-1690       -- the hiding row (live volumes are found; this is the fallback)
M.LOCKER_X={-521,-361,-217}
-- 31 Oct, run 8: the hiding point was the far side of the end locker, 110 cm
-- out; Max stood there (-882,-1626), outside every hiding volume, 10 m from
-- the guard with geometry between, and was caught. The three volumes
-- (65x75 cm) are the game's own hiding places: the point is now a volume's
-- CENTRE, the one furthest from the guard. In-volume is also logged.
M.HIDE_HALF={X=65,Y=75}
-- Run 10 (1 Nov, 115 readings with the hand socket "RightHand"): the hand's
-- yaw swept -164..-6 while the guard stood at the locker-room door. Both
-- catches came with the hand at yaw -8/-6, Max at bearing 172 / -152 from
-- the hand: the beam is the hand's facing REVERSED (172 / 174 at the catches,
-- 0 and 34 degrees off Max). A line trace from the hand to Max was always
-- blocked by the door's own blocking volume (BlockingVolume_5), yet she was
-- caught, so geometry does not shield her: the test is the cone alone.
-- Run 11 (1 Nov, 184 readings): the reversed-hand cone did NOT predict the
-- catches: caught at t=56/31/18 s into the pass with the beam 80-100 degrees
-- off Max, once inside the east hiding volume with the beam pointing the
-- other way. The hand position also walks (x -107..328) while the actor
-- stays at 80,-1360: the MESH moves, the actor is stale. Cues are OFF until
-- the game's own rule is measured; this pass records the mesh, head and hand,
-- the torch actor, and the patrol sequence's own position per reading.
-- THE GAME'S OWN RULE (IA_Behavior_32 "VisualDetection", decoded 1 Nov):
-- every tick while detection is on: Max within 800 cm of FSMDummy_1, AND
-- within 65 degrees of FSMDummy_1's facing (2D), AND a trace from FSMDummy_1
-- to Max hits nothing, held 0.4 s -> caught. Separately: Max within 160 cm
-- of FSMDummy_2 -> caught at once. FSMDummy_1 is a dummy actor the patrol
-- sequence moves (the "eye"); nothing I read from the guard's bones was it.
M.EYE="FSMDummy_1"
M.CLOSE="FSMDummy_2"
M.SIGHT_RANGE=800
M.SIGHT_HALF_ANGLE=65
M.CLOSE_RANGE=160
-- Confirmed in play 2 Nov: both catches came 0.6-1.3 s after this test
-- turned true. To WARN rather than report, the cue uses a looser version
-- (wider cone, longer range, first reading); the game's exact test is logged
-- alongside. Hiding spot: candidate points on the navigation mesh; the
-- nearest one the eye cannot see under the loose test, kept while it stays
-- safe (so it does not flicker as he turns).
M.WARN_HALF_ANGLE=85
M.WARN_RANGE=1000
M.SPOT_GRID=150
M.SPOT_BOUNDS={minX=-1000,maxX=300,minY=-2400,maxY=-1350}
M.SPOT_SEARCH=900   -- only candidates within this of Max are traced
-- Every candidate within reach is tested, nearest first (14 was too few: in
-- the open, the nearest 14 can all be in view while a safe point lies 4 m off).
-- ~30 traces per reading at most; readings are 4 a second, during the patrol only.
M.SPOT_MAX_TRACES=40
M.CUES_ENABLED=true
-- BYPASS (user's decision, 3 Nov, principle 80): finding a hiding place is
-- trivial for a sighted player and this is the game's only stealth sequence,
-- so by default the guard cannot see Max. A toggle (F3 / left stick + D-pad
-- down, during the patrol) turns it off for players who want to try.
-- How: the game's own test reads the eye marker (FSMDummy_1, 800 cm) and the
-- close sensor (FSMDummy_2, 160 cm). Both are detached and parked far below
-- the floor on every reading while the patrol plays, so every distance test
-- fails. The guard, his patrol, his torch and his speech are untouched.
M.BYPASS=true
-- Per-reading guard log (eye, route, warning, spot). Off by default; the
-- bypass's "parked" line and state changes are always logged.
M.DEBUG=false
M.PARK_Z=-5000
-- 2 Nov run 15: the loose test still fired in the same reading as the game's
-- catch: no lead. His patrol is a fixed sequence and his eye was within 60 cm
-- at the same sequence time on every pass, so his path predicts him.
-- pool_guard_path.lua covers the whole 78 s: decoded from the game's own walk
-- animation (artifacts/anim-extract, CUE4Parse) and checked against the 21 s
-- recorded in play (mean 18 cm, max 42 cm). The warning fires when a pose in the next
-- WARN_AHEAD seconds would see Max (game's own test, traced from that pose);
-- the hiding spot must stay unseen for SPOT_AHEAD seconds.
-- 2 Nov run 19 (user): 3 s was not enough to walk to the spot. Warn 6 s
-- ahead; a spot must stay out of view 10 s, so it is still safe on arrival
-- and for a while after.
M.WARN_AHEAD={0,1,2,3,4,5,6}
M.SPOT_AHEAD={0,1,2,3,4,5,6,7,8,9,10}
-- One aim height for Max and for spots: chest height above the floor. Run 19:
-- spots were traced at knee height (navmesh Z+40) and Max at actor Z+40, so
-- low obstacles hid "safe" spots that the guard could in fact see; he caught
-- the player 50 cm from one.
M.AIM_HEIGHT=128
-- Nearest candidates tested; ~15 lie within 3 m of any point, so 12 could all
-- be in view. Recomputed only when the current spot stops being safe.
M.SPOT_CANDIDATES=24
M.SPOT_STALE=300  -- cm: a spot further from Max than this is replaced by a nearer one
M.PATH=require("scenes.pool_guard_path")
M.text=function(key)return key end
M.log=function(_)end
M.play=function(_)end
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local function in_level(controller)
    local w=nil;pcall(function()w=controller:GetWorld():GetFName():ToString()end)
    return w==M.LEVEL
end
-- Pure: the hiding point among hiding volumes (list of {X,Y}): the centre of
-- the one furthest, in angle, from the beam (eye position + beam yaw); with
-- no beam yet, the one furthest from the guard g.
function M.hide_point(lockers,g,beam)
    if #lockers==0 then return nil end
    local best,bd=nil,-1
    for _,l in ipairs(lockers) do
        local d
        if beam then
            local a=math.deg(math.atan(l.Y-beam.Y,l.X-beam.X))-beam.yaw
            d=math.abs((a+180)%360-180)
        elseif g then d=(l.X-g.X)^2+(l.Y-g.Y)^2
        else return nil end
        if d>bd then bd=d;best=l end
    end
    return {X=best.X,Y=best.Y}
end
-- Pure: is p inside one of the hiding volumes?
function M.in_hide(lockers,p)
    for _,l in ipairs(lockers) do
        if math.abs(p.X-l.X)<=M.HIDE_HALF.X and math.abs(p.Y-l.Y)<=M.HIDE_HALF.Y then return true end
    end
    return false
end
-- Pure: is Max (p) within the guard's (g, facing yaw) sight cone?
function M.in_cone(g,yaw,p,half)
    local a=math.deg(math.atan(p.Y-g.Y,p.X-g.X))-yaw
    a=(a+180)%360-180
    return math.abs(a)<=(half or M.SIGHT_HALF_ANGLE)
end
-- Pure: can the eye (pos {X,Y}, yaw) see point p under the loose test?
-- blocked: whether a trace eye->p hit something.
function M.exposed(eye,yaw,p,blocked)
    local d=math.sqrt((p.X-eye.X)^2+(p.Y-eye.Y)^2)
    if d>M.WARN_RANGE then return false end
    if not M.in_cone(eye,yaw,p,M.WARN_HALF_ANGLE) then return false end
    return not blocked
end
-- Pure: the eye's pose at sequence time s, interpolated along path (list of
-- {seq,x,y,z,yaw}); nil outside the recorded range.
function M.pose_at(path,s)
    if not path or #path==0 or s<path[1][1] or s>path[#path][1] then return nil end
    for i=1,#path-1 do
        local a,b=path[i],path[i+1]
        if s>=a[1] and s<=b[1] then
            local f=(b[1]>a[1]) and (s-a[1])/(b[1]-a[1]) or 0
            local dy=((b[5]-a[5]+180)%360)-180
            return {X=a[2]+(b[2]-a[2])*f,Y=a[3]+(b[3]-a[3])*f,Z=a[4]+(b[4]-a[4])*f,yaw=a[5]+dy*f}
        end
    end
    return {X=path[#path][2],Y=path[#path][3],Z=path[#path][4],yaw=path[#path][5]}
end
-- Pure: would any pose at seq s+k (k in ahead) see point p? sees(pose,p) is
-- the game's test for one pose (distance, cone, trace). The current live pose
-- is passed too, so the unrecorded part of the patrol still gets the live test.
function M.danger(path,s,ahead,p,sees,live)
    if live and sees(live,p) then return true end
    if not s then return false end
    for _,k in ipairs(ahead) do
        local pose=M.pose_at(path,s+k)
        if pose and sees(pose,p) then return true end
    end
    return false
end
-- Pure: grid of candidate points inside bounds, spaced step apart.
function M.grid(b,step)
    local out={}
    for x=b.minX,b.maxX,step do for y=b.minY,b.maxY,step do out[#out+1]={X=x,Y=y} end end
    return out
end
-- Pure: what to say for the bypass state.
function M.bypass_text_key(on)return on and "pool_bypass_on" or "pool_bypass_off" end
-- Pure: cue transitions. prev/now: "seen"/"hidden"/nil. Returns the cue key or nil.
function M.cue(prev,now)
    if now==prev then return nil end
    if now=="seen" then return "sneak_spotted" end
    if now=="hidden" and prev=="seen" then return "sneak_hidden" end
    return nil
end
-- Live readings -------------------------------------------------------------
-- Shared state, declared before every function that uses it (2 Nov: entries()
-- was defined above these lines, so its patrol_start/safe_spot were GLOBALS,
-- always nil: the live spot never reached the scanner).
local state,pending,count,last_tick=nil,nil,0,0
local patrol_start,beam_yaw=nil,nil
local spots=nil          -- candidate points projected onto the navmesh (once per level visit)
local safe_spot=nil      -- current recommended point
local last_seq=nil       -- patrol position at the previous reading (rewind detection)
local guard_cache,guard_at=nil,-10
function M.toggle_bypass()
    M.BYPASS=not M.BYPASS
    M.log("pool_guard bypass="..tostring(M.BYPASS))
    return M.bypass_text_key(M.BYPASS)
end
function M.in_patrol()return patrol_start~=nil end
local torch_cache,torch_at=nil,-10
local sockets_logged,hand_socket=false,nil
-- The guard's hand: where the torch is and where it points.
local function hand(g)
    local comp=nil;pcall(function()comp=g.SkeletalMeshComponent end)
    if not valid(comp) then return nil end
    if not sockets_logged then
        sockets_logged=true
        pcall(function()
            local names={}
            comp:GetAllSocketNames():ForEach(function(_,v)local ok,s=pcall(function()return v:get():ToString()end);if ok then names[#names+1]=s end end)
            if M.DEBUG then M.log("pool_guard sockets="..table.concat(names,",")) end
        end)
    end
    if not hand_socket then
        for _,n in ipairs(M.HAND_SOCKETS) do
            local ok,has=pcall(function()return comp:DoesSocketExist(FName(n))end)
            if ok and has then hand_socket=n;M.log("pool_guard hand_socket="..n);break end
        end
        if not hand_socket then hand_socket=false end
    end
    if not hand_socket then return nil end
    local out=nil
    pcall(function()
        local loc=comp:GetSocketLocation(FName(hand_socket));local rot=comp:GetSocketRotation(FName(hand_socket))
        out={X=loc.X,Y=loc.Y,Z=loc.Z,Yaw=rot.Yaw,Pitch=rot.Pitch}
    end)
    return out
end
local patrol_done=false
local function torch(now)
    if torch_cache and valid(torch_cache) and now-torch_at<1 then return torch_cache end
    torch_at=now
    local found=nil
    for _,a in ipairs(FindAllOf("SkeletalMeshActorMAT") or {}) do
        pcall(function()
            if found or not valid(a) then return end
            local sm=a.SkeletalMeshComponent.SkeletalMesh
            if valid(sm) and sm:GetFName():ToString():find(M.TORCH_MESH,1,true) then found=a end
        end)
    end
    torch_cache=found
    return found
end
local function guard(controller,now)
    if guard_cache and valid(guard_cache) and now-guard_at<1 then return guard_cache end
    guard_at=now
    local best,bd=nil,math.huge
    local mp=nil;pcall(function()local v=controller.Pawn:K2_GetActorLocation();mp={X=v.X,Y=v.Y}end)
    for _,a in ipairs(FindAllOf("SkeletalMeshActorMAT") or {}) do
        pcall(function()
            if not valid(a) then return end
            local sm=a.SkeletalMeshComponent.SkeletalMesh
            if not (valid(sm) and sm:GetFName():ToString():find(M.GUARD_MESH,1,true)) then return end
            local v=a:K2_GetActorLocation()
            local d=mp and ((v.X-mp.X)^2+(v.Y-mp.Y)^2) or 0
            if d<bd then bd=d;best=a end
        end)
    end
    guard_cache=best
    return best
end
local seen_playing={}
-- Park the game's two detection markers far below the floor (bypass).
local park_logged=false
local function park(controller)
    for _,a in ipairs(FindAllOf("FSMDummy") or {}) do
        pcall(function()
            if not valid(a) then return end
            local n=a:GetFName():ToString()
            if n~=M.EYE and n~=M.CLOSE then return end
            local l=a:K2_GetActorLocation()
            if l.Z<M.PARK_Z/2 then return end
            pcall(function()a:K2_DetachFromActor(1,1,1)end)
            a:K2_TeleportTo({X=l.X,Y=l.Y,Z=M.PARK_Z},{Pitch=0,Yaw=0,Roll=0})
            if not park_logged then
                local l2=a:K2_GetActorLocation()
                M.log(string.format("pool_guard parked %s z=%.0f -> %.0f",n,l.Z,l2.Z))
                if n==M.EYE then park_logged=true end
            end
        end)
    end
end
local function patrol_playing()
    local found=false
    for _,m in ipairs(FindAllOf("MatineeActor") or {}) do
        pcall(function()
            if not valid(m) or m.bIsPlaying~=true then return end
            local id=m:GetFName():ToString()
            if id==M.PATROL then found=true end
            -- DIAGNOSTIC: which sequences play during the scene.
            if M.DEBUG and not seen_playing[id] then seen_playing[id]=true;M.log("pool_guard playing="..id) end
        end)
    end
    return found
end
-- DIAGNOSTIC: every skeletal-mesh actor that moved since the last reading
-- (the patrol may drive a different actor than the one with the guard mesh).
local last_pos={}
local function movers()
    for _,a in ipairs(FindAllOf("SkeletalMeshActorMAT") or {}) do
        pcall(function()
            if not valid(a) then return end
            local id=a:GetFName():ToString();local v=a:K2_GetActorLocation()
            local p=last_pos[id]
            if p and (math.abs(p.X-v.X)>5 or math.abs(p.Y-v.Y)>5) then
                local mesh="?";pcall(function()mesh=a.SkeletalMeshComponent.SkeletalMesh:GetFName():ToString()end)
                M.log(string.format("pool_guard mover=%s mesh=%s at=%.0f,%.0f,%.0f",id,mesh,v.X,v.Y,v.Z))
            end
            last_pos[id]={X=v.X,Y=v.Y}
        end)
    end
end
local function lockers()
    local out={}
    for _,v in ipairs(FindAllOf("DNEVolume") or {}) do
        pcall(function()
            if not valid(v) then return end
            local p=v:K2_GetActorLocation()
            if math.abs(p.Y-M.LOCKER_Y)<60 then out[#out+1]={X=p.X,Y=p.Y} end
        end)
    end
    if #out==0 then for _,x in ipairs(M.LOCKER_X) do out[#out+1]={X=x,Y=M.LOCKER_Y} end end
    return out
end
-- Scanner entries ---------------------------------------------------------------
function M.entries(controller)
    if not in_level(controller) then return {} end
    local out={}
    local stealth=false;pcall(function()stealth=controller:IsFactActive(FName(M.STEALTH_FACT))==true end)
    if not stealth then
        local h={X=M.ENTRANCE.X,Y=M.ENTRANCE.Y,Z=M.ENTRANCE.Z}
        out[#out+1]={id="pool_hall_way",label=M.text("pool_hall_way"),pos=h,stand=h,kind="goal",through=M.ENTRANCE_THROUGH}
        -- After the patrol (stealth off again) the south passage is the way out;
        -- before it, the same passage only plays "wrong way".
        if patrol_done then
            local w={X=M.WAY_OUT.X,Y=M.WAY_OUT.Y,Z=M.WAY_OUT.Z}
            out[#out+1]={id="pool_way_out",label=M.text("pool_way_out"),pos=w,stand=w,kind="goal",through=M.WAY_OUT_THROUGH}
        end
    end
    local g=guard(controller,os.clock())
    local gp=nil
    if g then pcall(function()local v=g:K2_GetActorLocation();gp={X=v.X,Y=v.Y}end) end
    local lk=lockers()
    local beam=nil
    if beam_yaw and g then pcall(function()local hd=hand(g);if hd then beam={X=hd.X,Y=hd.Y,yaw=beam_yaw} end end) end
    local hp=M.hide_point(lk,gp or {X=M.ENTRANCE.X,Y=M.ENTRANCE.Y},beam)
    -- During the patrol: the live safe spot (out of the guard's view).
    if patrol_start then hp=safe_spot end
    -- Not listed while Max already stands in a hiding volume (run 9: the walk
    -- "arrived" ten times in a row from inside it).
    local mp=nil;pcall(function()local v=controller.Pawn:K2_GetActorLocation();mp={X=v.X,Y=v.Y}end)
    if hp and (patrol_start or not (mp and M.in_hide(lk,mp))) then
        local p={X=hp.X,Y=hp.Y,Z=M.WAY_OUT.Z}
        out[#out+1]={id="pool_hiding_spot",label=M.text("pool_hiding_spot"),pos=p,stand=p,kind="goal"}
    end
    return out
end
-- Cues ----------------------------------------------------------------------------
-- The beam's current direction (degrees), while the patrol plays.
function M.beam()return beam_yaw end
function M.tick(controller,now)
    if not in_level(controller) then state=nil;patrol_done=false;spots=nil;safe_spot=nil;return end
    if now-last_tick<0.25 then return end
    last_tick=now
    if not patrol_playing() then
        if state then M.log("pool_guard patrol_over");state=nil;patrol_done=true end
        patrol_start=nil;beam_yaw=nil
        return
    end
    if not patrol_start then
        patrol_start=now
        if M.announce then M.announce(M.bypass_text_key(M.BYPASS)) end
    end
    if M.DEBUG then movers() end
    if M.BYPASS then
        park(controller)
        -- Bypass on: he cannot see Max, so no cues and no hiding spot (3 Nov:
        -- the cues still played - they ran on his predicted route).
        if state then state=nil;pending=nil;count=0 end
        safe_spot=nil
        return
    end
    local g=guard(controller,now)
    if not g then M.log("pool_guard no_guard_actor");return end
    local seen,why=false,"?"
    local game_seen,warn=false,false
    local ok,err=pcall(function()
        local gv=g:K2_GetActorLocation();local gyaw=g:K2_GetActorRotation().Yaw
        local eye,eyaw,src={X=gv.X,Y=gv.Y,Z=gv.Z+70},gyaw,"guard"
        local tr=nil
        local h=hand(g)
        if h then eye={X=h.X,Y=h.Y,Z=h.Z};eyaw=h.Yaw;src=string.format("hand(%.0f,%.0f,%.0f pitch=%.0f)",h.X,h.Y,h.Z,h.Pitch) end
        local pawn=controller.Pawn;local mv=pawn:K2_GetActorLocation()
        local dist=math.sqrt((eye.X-mv.X)^2+(eye.Y-mv.Y)^2)
        beam_yaw=eyaw
        -- DIAGNOSTIC (31 Oct: he spotted the player every time and the cue never
        -- fired): every reading while the patrol plays.
        local inside=M.in_hide(lockers(),{X=mv.X,Y=mv.Y})
        local bearing=math.deg(math.atan(mv.Y-eye.Y,mv.X-eye.X))
        -- DIAGNOSTIC: the mesh (what actually moves), head socket, torch actor, sequence position.
        local mesh="?";pcall(function()local c=g.SkeletalMeshComponent;local l=c:K2_GetComponentLocation();local r=c:K2_GetComponentRotation();mesh=string.format("%.0f,%.0f,%.0f/yaw%.0f",l.X,l.Y,l.Z,r.Yaw)end)
        local head="?";pcall(function()local c=g.SkeletalMeshComponent;for _,n in ipairs({"head","Head","Bip01_Head","b_Head"}) do if c:DoesSocketExist(FName(n)) then local l=c:GetSocketLocation(FName(n));local r=c:GetSocketRotation(FName(n));head=string.format("%s:%.0f,%.0f,%.0f/yaw%.0f/pitch%.0f",n,l.X,l.Y,l.Z,r.Yaw,r.Pitch);break end end end)
        local tl="?";pcall(function()local tr=torch(now);if tr then local l=tr:K2_GetActorLocation();local r=tr:K2_GetActorRotation();tl=string.format("%.0f,%.0f,%.0f/yaw%.0f/pitch%.0f",l.X,l.Y,l.Z,r.Yaw,r.Pitch) end end)
        local seqpos="?";pcall(function()for _,m in ipairs(FindAllOf("MatineeActor") or {}) do if valid(m) and m:GetFName():ToString()==M.PATROL then seqpos=string.format("%.1f",m.InterpPosition);break end end end)
        -- The game's eye and close-range dummies, with the game's own three tests.
        local eyes="?"
        pcall(function()
            local e1,e2=nil,nil
            for _,a in ipairs(FindAllOf("FSMDummy") or {}) do
                if valid(a) then local n=a:GetFName():ToString();if n==M.EYE then e1=a elseif n==M.CLOSE then e2=a end end
            end
            if e1 then
                local l=e1:K2_GetActorLocation();local r=e1:K2_GetActorRotation()
                local dd=math.sqrt((l.X-mv.X)^2+(l.Y-mv.Y)^2)
                local inc=M.in_cone({X=l.X,Y=l.Y},r.Yaw,{X=mv.X,Y=mv.Y},M.SIGHT_HALF_ANGLE)
                local lib=StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
                local hit={};local blocked=lib:LineTraceSingle(controller,{X=l.X,Y=l.Y,Z=l.Z},{X=mv.X,Y=mv.Y,Z=mv.Z+40},0,false,{e1,pawn},0,hit,true,{R=1,G=0,B=0,A=1},{R=0,G=1,B=0,A=1},0)
                local by="-";if blocked then pcall(function()by=hit.Actor:Get():GetFName():ToString()end) end
                eyes=string.format("eye=%.0f,%.0f,%.0f/yaw%.0f dist=%.0f cone=%s blocked=%s by=%s",l.X,l.Y,l.Z,r.Yaw,dd,tostring(inc),tostring(blocked),by)
                game_seen=(dd<=M.SIGHT_RANGE and inc and not blocked)
                -- The game's test for one pose (800 cm, 65 deg, clear trace).
                local floor_z=mv.Z-88
                local function sees(pose,pt)
                    local dx,dy=pt.X-pose.X,pt.Y-pose.Y
                    if dx*dx+dy*dy>M.SIGHT_RANGE*M.SIGHT_RANGE then return false end
                    if not M.in_cone({X=pose.X,Y=pose.Y},pose.yaw,pt,M.SIGHT_HALF_ANGLE) then return false end
                    local h2={}
                    local b2=lib:LineTraceSingle(controller,{X=pose.X,Y=pose.Y,Z=pose.Z},{X=pt.X,Y=pt.Y,Z=(pt.Z or floor_z)+M.AIM_HEIGHT},0,false,{e1,pawn},0,h2,true,{R=1,G=0,B=0,A=1},{R=0,G=1,B=0,A=1},0)
                    return not b2
                end
                local live={X=l.X,Y=l.Y,Z=l.Z,yaw=r.Yaw}
                local sq=tonumber(seqpos)
                warn=M.danger(M.PATH,sq,M.WARN_AHEAD,{X=mv.X,Y=mv.Y,Z=floor_z},sees,live)
                if not spots then
                    spots={}
                    local unreachable=0
                    local doors=require("nav.doors")
                    local dok,doorlist=pcall(doors.survey,controller,pawn,function()end)
                    if not dok then doorlist=nil end
                    local route=require("nav.route")
                    for _,c in ipairs(M.grid(M.SPOT_BOUNDS,M.SPOT_GRID)) do
                        local ok,okp,pt=pcall(route.project,controller,{X=c.X,Y=c.Y,Z=10},{X=40,Y=40,Z=150})
                        if ok and okp and pt and math.abs(pt.X-c.X)<40 and math.abs(pt.Y-c.Y)<40 then
                            -- Reachable from Max (2 Nov: a candidate on the locker-room
                            -- door wall projected to the far side: "No route to Hiding
                            -- spot"). One path query per candidate, once per patrol.
                            -- Same rule as autowalk: a complete path that does not
                            -- cross a doorway the survey found closed (2 Nov run 18:
                            -- -100,-1350 was "reachable" only through the shut
                            -- locker-room door, and autowalk refused it).
                            local qok,complete,_,pts=pcall(route.query,controller,pawn,"spot",{X=mv.X,Y=mv.Y,Z=mv.Z},{X=pt.X,Y=pt.Y,Z=pt.Z},function()end)
                            local through=false
                            if qok and complete and doorlist and pts then local cok,c=pcall(doors.crosses_closed,pts,doorlist);through=cok and c end
                            if qok and complete and not through then spots[#spots+1]={X=pt.X,Y=pt.Y,Z=pt.Z} else unreachable=unreachable+1 end
                        end
                    end
                    M.log("pool_guard spots="..#spots.." unreachable="..unreachable)
                end
                local function unsafe(s) return M.danger(M.PATH,sq,M.SPOT_AHEAD,s,sees,live) end
                -- Re-search when the spot stops being safe, or when it is no longer
                -- near Max (2 Nov: it was chosen once at the patrol's start and
                -- stayed 6 m behind her as she moved). Kept otherwise, so it
                -- does not shift under her while she walks to it.
                local far=safe_spot and math.sqrt((safe_spot.X-mv.X)^2+(safe_spot.Y-mv.Y)^2)>M.SPOT_STALE
                -- Rewound (sequence went back): choose again for the earlier moment.
                local rewound=sq and last_seq and sq<last_seq-0.5
                if rewound then far=true;M.log(string.format("pool_guard spot_search reason=rewind seq=%.1f",sq)) end
                last_seq=sq
                if far or not (safe_spot and not unsafe(safe_spot)) then
                    local near={}
                    for _,s in ipairs(spots) do local ds=math.sqrt((s.X-mv.X)^2+(s.Y-mv.Y)^2);if ds<=M.SPOT_SEARCH then near[#near+1]={s=s,d=ds} end end
                    table.sort(near,function(x,y)return x.d<y.d end)
                    safe_spot=nil
                    for i=1,math.min(#near,M.SPOT_CANDIDATES) do if not unsafe(near[i].s) then safe_spot=near[i].s;break end end
            end
            end
            if e2 then local l=e2:K2_GetActorLocation();local dd=math.sqrt((l.X-mv.X)^2+(l.Y-mv.Y)^2);eyes=eyes..string.format(" close=%.0f,%.0f dist=%.0f",l.X,l.Y,dd);if dd<=M.CLOSE_RANGE then game_seen=true end end
        end)
        why=string.format("t=%.1f seq=%s %s max=%.0f,%.0f warn=%s game_seen=%s spot=%s",now-(patrol_start or now),seqpos,eyes,mv.X,mv.Y,tostring(warn),tostring(game_seen),safe_spot and string.format("%.0f,%.0f",safe_spot.X,safe_spot.Y) or "none")
    end)
    if not ok then M.log("pool_guard read_error="..tostring(err));return end
    if M.DEBUG then M.log("pool_guard "..why) end
    local now_state=warn and "seen" or "hidden"
    if now_state~=pending then pending=now_state;count=1 else count=count+1 end
    if now_state==state then return end
    if now_state=="hidden" and count<2 then return end
    local key=M.cue(state,now_state)
    M.log("pool_guard state="..now_state.." cue="..tostring(key))
    state=now_state
    if key and M.CUES_ENABLED then M.play(key..".wav") end
end
return M
