-- DIAGNOSTIC (test sessions only, never normal play): what the lighthouse
-- stage of the episode 1 ending nightmare does over time. Places Max on the
-- path just before the lighthouse trigger (test copy only - a test cannot get
-- past the earlier hazards), walks her through the trigger, then for 18 s
-- after the lighthouse starts to fall logs, every 0.5 s: the stage facts, the
-- collision of every blocking volume near the hole, the moving floor's
-- position, Max's position, and - every second - whether our planner finds a
-- way from Max to the crossing (with a map every 2 s).
local M={}
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local FACTS={"LighthouseTree","LighthouseDebrisDanger","LighthouseFallingDanger","RollingLogsBegin"}
local CROSSING={X=-1453,Y=566,Z=188}
local HOLE={X=-900,Y=50}
local function facts(c)
    local s={}
    for _,f in ipairs(FACTS) do
        local ok,v=pcall(function()return c:IsFactActive(FName(f))end)
        s[#s+1]=f.."="..(ok and (v and "1" or "0") or "?")
    end
    return table.concat(s," ")
end
local function in_level(a)local ok,n=pcall(function()return a:GetFullName()end);return ok and n:find("E1_6B",1,true)~=nil end
local blockers={}
local floor=nil
local function collect(emit)
    for _,cls in ipairs({"BlockingVolume","DynamicBlockingVolume"}) do
        for _,v in ipairs(FindAllOf(cls) or {}) do
            pcall(function()
                if not (valid(v) and in_level(v)) then return end
                local o,e={X=0,Y=0,Z=0},{X=0,Y=0,Z=0};v:GetActorBounds(false,o,e)
                if math.sqrt((o.X-HOLE.X)^2+(o.Y-HOLE.Y)^2)>1300 then return end
                blockers[#blockers+1]=v
                emit(string.format("lighthouse blocker i=%d name=%s at=%.0f,%.0f,%.0f extent=%.0f,%.0f,%.0f",#blockers,v:GetFName():ToString(),o.X,o.Y,o.Z,e.X,e.Y,e.Z))
            end)
        end
    end
    for _,cls in ipairs({"LiSInterpActor","InterpActor","StaticMeshActor"}) do
        for _,v in ipairs(FindAllOf(cls) or {}) do
            pcall(function()if not floor and valid(v) and in_level(v) and v:GetFName():ToString()=="InterpActor_24" then floor=v end end)
        end
    end
    emit("lighthouse blockers="..#blockers.." floor_actor="..tostring(floor~=nil))
end
local function blocker_state()
    local s={}
    for _,v in ipairs(blockers) do
        local a,c="?","?"
        pcall(function()a=v:GetActorEnableCollision() and "1" or "0" end)
        pcall(function()c=tostring(v.BrushComponent:GetCollisionEnabled())end)
        s[#s+1]=a..c
    end
    return table.concat(s," ")
end
local function pos(a)local p=a:K2_GetActorLocation();return string.format("%.0f,%.0f,%.0f",p.X,p.Y,p.Z) end
-- The lighthouse sequence's playback position (Matinee seconds) and state.
local matinee=nil
local function lh_matinee()
    if valid(matinee) then return matinee end
    for _,m in ipairs(FindAllOf("MatineeActor") or {}) do
        local ok,n=pcall(function()return m:GetFName():ToString()..m:GetFullName()end)
        if ok and n:find("E1_6B",1,true) and n:find("LighthouseFalling",1,true) and not n:find("REV",1,true) then matinee=m;break end
    end
    if not matinee then
        for _,m in ipairs(FindAllOf("MatineeActor") or {}) do
            pcall(function()local d=m.MatineeData;if d and d:GetFullName():find("LighthouseFalling",1,true) and not d:GetFullName():find("REV",1,true) then matinee=m end end)
            if matinee then break end
        end
    end
    return matinee
end
local function mat_state()
    local m=lh_matinee()
    if not m then return "mat=none" end
    local pos_,play,rate="?","?","?"
    pcall(function()pos_=string.format("%.2f",m.InterpPosition)end)
    pcall(function()play=tostring(m.bIsPlaying)end)
    pcall(function()rate=string.format("%.2f",m.PlayRate)end)
    local rv="?";pcall(function()rv=tostring(m.bReversePlayback)end)
    return "mat="..pos_.." playing="..play.." rate="..rate.." reverse="..rv
end
local function plan(c,emit,with_map)
    local pawn=c.Pawn
    local cap=pawn.CapsuleComponent;local l=cap:K2_GetComponentLocation()
    local from={X=l.X,Y=l.Y,Z=l.Z-cap:GetScaledCapsuleHalfHeight()}
    local offmesh=require("nav.offmesh")
    local tgt={X=CROSSING.X,Y=CROSSING.Y,Z=from.Z}
    local gz=188;tgt.Z=gz
    local p=offmesh.planner(c,pawn,from,tgt,150,700)
    local t0=os.clock();local st
    repeat st=p:step(4000) until st~="running" or os.clock()-t0>1.5
    emit(string.format("lighthouse plan result=%s reason=%s target_z=%s closest=%.0f samples=%d waypoints=%d secs=%.2f",
        st,tostring(p.reason),tostring(gz and math.floor(gz) or "none"),p.g.best_d or -1,p.g.samples,p.waypoints and #p.waypoints or 0,os.clock()-t0))
    -- Found during the window: walk it, once, and report where Max ends up.
    if st=="found" and not M.walked then
        M.walked=true
        offmesh.log=function(l)emit("lighthouse "..l)end
        offmesh.walk(c,pawn,p.waypoints,function(r,rem)
            emit(string.format("lighthouse walk_end result=%s remaining=%.0f max=%s %s",r,rem or -1,pos(pawn),mat_state()))
            if r~="arrived_test_region" then M.rounds=(M.rounds or 0)+1;emit("lighthouse REWIND_NOW round="..M.rounds);M.wait_rewind=true;M.saw_rewind=false end
        end)
    end
    if with_map then for _,line in ipairs(p.g:report(60)) do emit("lighthouse "..line) end end
end
-- Walk Max along waypoints with movement input, then call done().
local function steer(c,wps,secs,done,emit)
    local pawn=c.Pawn;local i=1;local t0=os.clock();local h
    h=LoopInGameThreadWithDelay(1,function()
        local ok=pcall(function()
            local p=pawn:K2_GetActorLocation();local w=wps[i]
            local d=math.sqrt((w.X-p.X)^2+(w.Y-p.Y)^2)
            if d<40 then i=i+1 end
            if i>#wps or os.clock()-t0>secs then
                CancelDelayedAction(h);emit(string.format("lighthouse steer_end reached=%s max=%s",tostring(i>#wps),pos(pawn)));done();return
            end
            w=wps[i];d=math.max(1,math.sqrt((w.X-p.X)^2+(w.Y-p.Y)^2))
            pawn:AddMovementInput({X=(w.X-p.X)/d,Y=(w.Y-p.Y)/d,Z=0},1.0,false)
        end)
        if not ok then CancelDelayedAction(h);done() end
    end)
end
function M.run(c,emit)
    local pawn=c.Pawn
    emit("lighthouse start max="..pos(pawn).." "..facts(c))
    collect(emit)
    -- Wait for the opening cutscene to hand control over (it repositions Max),
    -- then place her on the path just before the lighthouse trigger and check
    -- the move held.
    local follow=require("nav.follow")
    local ready_n,tries=0,0
    local gate
    gate=LoopInGameThreadWithDelay(500,function()
        local ready=false;pcall(function()ready=follow.ready(c,pawn)end)
        ready_n=ready and ready_n+1 or 0
        if ready_n<4 then return end
        local p=pawn:K2_GetActorLocation()
        if math.abs(p.X+107)<150 and math.abs(p.Y+164)<150 then
            CancelDelayedAction(gate);emit("lighthouse placed max="..pos(pawn));M.measure(c,emit);return
        end
        tries=tries+1
        if tries>4 then CancelDelayedAction(gate);emit("lighthouse place_failed max="..pos(pawn));return end
        local ok,err=pcall(function()pawn:K2_TeleportTo({X=-107,Y=-164,Z=240},{Pitch=0,Yaw=150,Roll=0})end)
        emit("lighthouse teleport try="..tries.." ok="..tostring(ok).." "..tostring(err or "").." max="..pos(pawn))
        ready_n=0
    end)
end
function M.measure(c,emit)
    local pawn=c.Pawn
    local waited=0;local h
    h=LoopInGameThreadWithDelay(500,function()
        waited=waited+1
        if waited<4 then return end
        CancelDelayedAction(h)
        emit("lighthouse before_walk max="..pos(pawn).." "..facts(c).." blockers="..blocker_state())
        if M.guide_mode then
            M.walked=true -- the probe never walks; the guide does
            local g=require("scanner.sources").guide_entry(c)
            emit("lighthouse guide_start step="..tostring(g and g.step_id))
            if g then require("autowalk.autowalk").start(c,g) end
        end
        local route=M.guide_mode and {{X=-110,Y=-160}} or {{X=-300,Y=-20},{X=-439,Y=68},{X=-540,Y=110}}
        steer(c,route,M.guide_mode and 1 or 10,function()
            local t=0;local fall0=nil;local h2
            h2=LoopInGameThreadWithDelay(500,function()
                t=t+1
                pcall(function()
                    local f=facts(c)
                    if not fall0 and (f:find("LighthouseDebrisDanger=1",1,true) or f:find("LighthouseFallingDanger=1",1,true) or f:find("LighthouseTree=1",1,true)) then fall0=t end
                    local since=fall0 and string.format("%.1f",(t-fall0)*0.5) or "-"
                    local rew=false;pcall(function()rew=pawn:IsRewinding()==true end)
                    local spd=0;pcall(function()local v=pawn:GetVelocity();spd=math.sqrt(v.X*v.X+v.Y*v.Y)end)
                    f=f..string.format(" speed=%.0f",spd)
                    emit(string.format("lighthouse tick t=%.1f since_fall=%s max=%s rewinding=%s %s floor=%s %s blockers=%s",t*0.5,since,pos(pawn),tostring(rew),mat_state(),floor and pos(floor) or "-",f,blocker_state()))
                    if f:find("LighthouseTree=1",1,true) and not M.walked then plan(c,emit,true) end
                    -- After the test's rewind ends: walk on once.
                    if M.wait_rewind then
                        local m=lh_matinee();local back=false
                        pcall(function()back=m.bReversePlayback==true end)
                        if back then M.saw_rewind=true
                        elseif M.saw_rewind then
                            M.wait_rewind=false;M.rewound=true;M.walked=false
                            if (M.rounds or 0)>=4 then emit("lighthouse giving_up rounds="..M.rounds);return end
                            emit("lighthouse REWIND_DONE max="..pos(pawn).." "..mat_state().." "..f.." blockers="..blocker_state())
                            if f:find("LighthouseTree=1",1,true) then plan(c,emit,true) else emit("lighthouse tree_lost_by_rewind") end
                        end
                    end
                end)
                if t>=110 or (fall0 and t-fall0>=100) then CancelDelayedAction(h2);emit("lighthouse done fall_started="..tostring(fall0~=nil)) end
            end)
        end,emit)
    end)
end
return M
