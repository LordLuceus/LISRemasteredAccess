-- Guide through the episode 1 ending nightmare (E1_6B, the cliff in the storm).
-- The scene has no walking paths from the game and one object (the
-- newspaper at the end), so the scanner offers a single "Guide" entry whose
-- position is the next step along the doe's route. Steps are the scene's own
-- landmarks: the triggers that move the doe on, the logs shelter and the
-- newspaper, at positions measured in the remaster (27 Oct; identical to the
-- original game's; heights are the floor, the trigger's centre less its
-- half-height). Walking to the guide with autowalk carries on to the next
-- step by itself, except at the shelter, which waits for the logs to pass.
--
-- Progress is worked out from where Max is, every time - never remembered -
-- so a rewind that puts her back simply makes an earlier step current again.
-- Hazards are announced from the game's own danger facts. Pure; offline tested.
local M={}
-- through: aim this far past the point (cm) so Max crosses the trigger.
-- hold: the step is not left until hold(fact) says so.
M.STEPS={
    {id="rocks",  label="guide_follow",   X=3477, Y=1516, Z=-842, through=200},
    {id="tree",   label="guide_follow",   X=3303, Y=618,  Z=-737, through=200},
    {id="tree2",  label="guide_follow",   X=3383, Y=-25,  Z=-691},
    {id="bend",   label="guide_follow",   X=3063, Y=-284, Z=-695},
    {id="bend2",  label="guide_follow",   X=2887, Y=-330, Z=-695},
    {id="clear",  label="guide_follow",   X=2083, Y=-112, Z=-626},
    {id="logs",   label="guide_follow",   X=1711, Y=196,  Z=-537, through=200},
    {id="shelter",label="guide_shelter",  X=911,  Y=-124, Z=-163, hold="logs"},
    {id="corridor",label="guide_follow",  X=1048, Y=-485, Z=-204},
    {id="below",  label="guide_follow",   X=512,  Y=-633, Z=40},
    {id="rise",   label="guide_follow",   X=66,   Y=-339, Z=43},
    {id="rise2",  label="guide_follow",   X=-107, Y=-164, Z=101},
    {id="lighthouse",label="guide_follow",X=-439, Y=68,   Z=107, through=200},
    -- Past the falling lighthouse, straight to the newspaper. Measured 27 Oct:
    -- the trigger the doe uses here sits inside a fixed blocker, and the old
    -- step there let the guide stop ("Arrived") at the hole's edge, where the
    -- lighthouse then caught Max. The open ground runs from the hole's edge
    -- past that blocker to the newspaper once the tree is down (LighthouseTree,
    -- about 1 s into the fall) and until the floor drops (about 7.5 s), so the
    -- walk starts on that fact and goes all the way without stopping.
    -- reach 150: the newspaper lies on the ground below its actor's origin;
    -- with the guide's 60 cm the search reached ground 81-99 cm from it and
    -- still failed (27 Oct playtest). 150 is what the successful test used.
    {id="newspaper",label="guide_newspaper",X=-1453,Y=566,Z=188, persist=true, wait_fact="LighthouseTree", reach=150},
}
M.START={X=3537,Y=2403}
M.REACH=80     -- within this, a step counts as reached (well under the shortest leg)
local function d2(a,b)return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2)end
-- Where Max is along the route: the leg (start->step 1, step 1->step 2, ...)
-- nearest to her, and how far along it (0..1).
function M.locate(p)
    local best,bi,bt=math.huge,1,0
    local prev=M.START
    for i,s in ipairs(M.STEPS) do
        local dx,dy=s.X-prev.X,s.Y-prev.Y
        local len2=dx*dx+dy*dy
        local t=len2>0 and ((p.X-prev.X)*dx+(p.Y-prev.Y)*dy)/len2 or 0
        t=math.max(0,math.min(1,t))
        local q={X=prev.X+dx*t,Y=prev.Y+dy*t}
        local d=d2(p,q)
        if d<best then best,bi,bt=d,i,t end
        prev=s
    end
    return bi,bt,best
end
-- The current step for Max at p: the end of the leg she is on, or the next
-- one once she has reached it. held(id) -> true while a hold step must not be
-- left (the logs are still to come or still rolling).
function M.current(p,held)
    local i=M.locate(p)
    if d2(p,M.STEPS[i])<=M.REACH and i<#M.STEPS then
        if not (M.STEPS[i].hold and held and held(M.STEPS[i].hold)) then i=i+1 end
    end
    -- Past a hold step while it still holds (rewound into it, or ran ahead):
    -- the shelter stays the goal.
    for k=1,i-1 do
        local s=M.STEPS[k]
        if s.hold and held and held(s.hold) and i==k+1 then return k end
    end
    return i
end
-- The logs hold: wait in the shelter until they have started and stopped.
function M.logs_held(fact)
    if fact("RollingLogsDanger") then return true end
    return not fact("RollingLogsBegin")
end
-- Hazard announcements from fact changes. prev/cur: {fact=bool}.
-- Returns catalogue keys to speak, in order.
M.HAZARDS={
    {fact="RollingRock01Danger",on="guide_rocks",off=nil},
    {fact="TreeFalling01Danger",on="guide_tree",off=nil},
    {fact="RollingLogsDanger",on="guide_logs",off="guide_logs_passed"},
    {fact="SafePlace",on="guide_in_shelter",off=nil},
    {fact="LighthouseDebrisDanger",on="guide_lighthouse",off=nil},
    {fact="LighthouseFallingDanger",on="guide_lighthouse",off=nil},

}
M.FACTS={"LighthouseTree","RollingRock01Danger","TreeFalling01Danger","RollingLogsDanger","RollingLogsBegin","SafePlace","LighthouseDebrisDanger","LighthouseFallingDanger"}
function M.changes(prev,cur)
    local out={}
    if not prev then return out end
    local said={}
    for _,h in ipairs(M.HAZARDS) do
        local a,b=prev[h.fact]==true,cur[h.fact]==true
        local key=nil
        if b and not a then key=h.on elseif a and not b then key=h.off end
        -- "Get into the shelter" is pointless once Max is in it.
        if key=="guide_logs" and cur.SafePlace then key="guide_logs_stay" end
        if key and not said[key] then said[key]=true;out[#out+1]=key end
    end
    return out
end
-- Caught by a hazard: Max stops moving while one of the hazard danger facts
-- is on, and the game wants a rewind (Max says "I should rewind"). Pure:
-- facts {fact=bool} -> the hazard's catalogue key, or nil.
M.DANGERS={"RollingRock01Danger","TreeFalling01Danger","RollingLogsDanger","LighthouseDebrisDanger","LighthouseFallingDanger"}
function M.danger(facts)
    for _,f in ipairs(M.DANGERS) do if facts[f] then return f end end
    return nil
end
-- What to say when a guide walk stalls: caught (a danger is on) or blocked.
function M.stall_message(facts)
    if M.danger(facts) then return "guide_caught" end
    return nil
end
-- The lighthouse crossing has closed for this fall: the floor at the hole
-- drops at about 10.7 s of the sequence (measured), and Max is still on the
-- near side of the hole. Pure.
M.FLOOR_DROP=10.7
M.NEWSPAPER={X=-1453,Y=566}
-- Past the hole (on the newspaper's side): measured 28 Oct, Max caught there
-- at 11.0 2.25 m short of the newspaper; rewound far back she was then caught
-- by debris at 3.4 every time, standing still. Rewinding there is only to
-- buy walking time: let go after the debris (danger ends 5.2), and walk on at
-- once - never wait for the tree, which is no longer in the way.
M.HOLE_X=-1100
M.LET_GO_PAST_HOLE=6.0
function M.past_hole(max)return max~=nil and max.X<M.HOLE_X end
-- During a rewind: is it time to let go? tree = LighthouseTree fact now.
function M.let_go(pos,max,tree)
    if M.past_hole(max) then return pos~=nil and pos<=M.LET_GO_PAST_HOLE end
    return tree==false
end
function M.lighthouse_closed(pos,max)
    return pos~=nil and pos>=M.FLOOR_DROP and max~=nil and max.X>-1000
end
return M
