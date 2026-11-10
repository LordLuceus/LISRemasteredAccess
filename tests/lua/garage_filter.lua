-- Engine-free producer + real shared planner regression. Synthetic floors and
-- native query responses, NOT evidence about the game's physical garage.
package.path="src/?.lua;src/?/init.lua;"..package.path
local count,fail=0,0
local function check(label,ok)
    count=count+1;if not ok then fail=fail+1;print("FAIL "..label) end
end
local saved={}
for _,m in ipairs({"scanner.sources","scanner.rooms","nav.route","nav.doors"}) do saved[m]=package.loaded[m];package.loaded[m]=nil end
local oldF,oldS=FindAllOf,StaticFindObject
local A,B,C="Test_A_LD","Test_B_LD","Test_C_LD"
local function p(x,y)return {X=x,Y=y,Z=0} end
local now,queries,projects,surveys,floorReads=0,0,0,0,0
local closed,alternative,partial,intervening,missing,unreachable=true,true,false,false,false,false
local badLeg,farRoom=false,false
local alternateY=600
local function room(q)
    if farRoom and q.X>500 then return C end
    if intervening and q.X < -300 and q.Y>200 and q.Y<450 then return C end
    return q.X>0 and B or A
end
FindAllOf=function()return {} end
StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b,_,_,_,_,hit)
    floorReads=floorReads+1
    local r=room(b):gsub("_LD$","_GRC")
    hit.Actor={Get=function()return {GetFullName=function()return "StaticMeshActor /Game/Maps/Test/"..r.."."..r..":PersistentLevel.Floor" end} end}
    return true
end} end
package.loaded["nav.route"]={project=function(_,q)
    projects=projects+1
    if missing and q.X==300 then return false,p(0,0) end
    return true,p(q.X,q.Y)
end,query=function(_,_,_,a,b)
    queries=queries+1
    local pts={a,b}
    if a.X< -300 and b.Y==alternateY then pts={a,p(a.X,alternateY),b}
    elseif a.Y==alternateY and b.X>200 then pts={a,p(b.X,alternateY),b} end
    local len=0;for i=2,#pts do len=len+math.sqrt((pts[i].X-pts[i-1].X)^2+(pts[i].Y-pts[i-1].Y)^2) end
    return not partial and not (unreachable and b.X==300) and not (badLeg and b.Y==600),len,pts
end}
local D=require("nav.doors")
D.survey=function()
    surveys=surveys+1
    local list={{index=1,state=closed and "blocked" or "open",centre=p(0,0),nx=1,ny=0,sides={p(-80,0),p(80,0)}}}
    if alternative then list[2]={index=2,state="open",centre=p(0,alternateY),nx=1,ny=0,sides={p(-80,alternateY),p(80,alternateY)}} end
    return list
end
local S=require("scanner.sources");S.report=function()end;S.text=function(k)return k end;S.way_clock=function()return now end
local world="one"
local controller={Pawn={},GetWorld=function()return {GetFName=function()return {ToString=function()return world end} end} end}
local function entries(extra)
    local out={{id="own",kind="interaction",sublevel=A,pos=p(-400,0)},
        {id="look",label="Look door",kind="interaction",sublevel=A,pos=p(0,0),door_like=true},
        {id="test",label="Test door",kind="interaction",sublevel=B,pos=p(0,0),door_like=true},
        {id="target",kind="interaction",sublevel=B,pos=p(400,0)}}
    if extra then out[#out+1]={id="near",kind="interaction",sublevel=B,pos=p(300,0)} end
    if farRoom then out[#out+1]={id="far",kind="interaction",sublevel=C,pos=p(700,0)} end
    return out
end
local function scan(pos,extra)
    local result=S.by_room(controller,entries(extra),pos or p(-400,0));local ids={};local way
    for _,e in ipairs(result) do ids[e.id]=true;if e.id=="way:"..B then way=e end end
    return ids,way
end
local ids,way=scan()
check("locked listed proxies plus usable alternative produces way",way and way.pos.Y==600)
check("final result keeps both Look/Test proxies and current object",ids.look and ids.test and ids.own)
check("room filter still hides target object",not ids.target)
local total=0;for _ in pairs(ids) do total=total+1 end
check("exact final set is own, Look, Test and alternative way",total==4)
check("one survey shared across candidate rooms",surveys==1)
local initial=queries
check("two-door detour uses seven route queries",initial==7)
local cachedFloors=floorReads
scan();check("unchanged scan reuses route evidence",queries==initial and surveys==1)
check("cache scan retains exactly the existing five floor reads",floorReads-cachedFloors==5)
for t=0.5,2.5,0.5 do now=t;scan() end
check("five half-second repeated scans do not resurvey",queries==initial and surveys==1)
now=3;alternative=false;ids,way=scan()
check("closed-only path disappears on timed refresh",not way)
check("closed-only query budget is one",queries==initial+1 and surveys==2)
closed=false;now=6;ids,way=scan()
check("open listed doorway prevents duplicate on actual threshold",not way and ids.look and ids.test)
closed=true;alternative=true;now=9;ids,way=scan()
check("door state reopening alternative refreshes empty verdict",way~=nil)
local before=surveys;scan(p(-600,0));check("meaningful movement refreshes evidence",surveys==before+1)
partial=true;now=12;ids,way=scan();check("partial or invalid direct path cannot produce way",not way)
partial=false;intervening=true;now=15;ids,way=scan()
check("actual bent leg polyline preserves intervening room rejection",not way)
intervening=false;missing=true;now=18;ids,way=scan(nil,true)
check("missing nearest projection does not reject farther candidate",way~=nil)
missing=false;unreachable=true;now=21;ids,way=scan(nil,true)
check("incomplete nearest route does not reject farther candidate",way~=nil)
unreachable=false;alternative=false;now=24;scan();alternative=true;world="two";ids,way=scan()
check("scene change refreshes closed verdict immediately",way~=nil)
badLeg=true;now=27;ids,way=scan()
check("invalid or partial detour legs cannot supply route evidence",not way)
badLeg=false;now=30;ids,way=scan()
check("failed detour verdict recovers on refresh",way~=nil)
-- A nearby open surveyed doorway must actually be crossed before it deduplicates.
closed=false;alternative=false
local originalQuery=package.loaded["nav.route"].query
package.loaded["nav.route"].query=function(_,_,_,a,b)
    queries=queries+1;return true,900,{a,p(-80,100),p(80,100),b}
end
now=33;ids,way=scan()
check("nearby but uncrossed open proxy does not suppress another opening",way~=nil)
package.loaded["nav.route"].query=originalQuery
closed=true;alternative=true;farRoom=true;now=36
local multiBefore=surveys;local multiQuery=queries
ids,way=scan()
check("multiple target rooms share one live survey",surveys==multiBefore+1)
check("far target reached through first room is absent from final set",way and not ids["way:"..C] and not ids.far)
check("two target rooms require fourteen route queries, not two surveys",queries-multiQuery==14)
farRoom=false;alternateY=180;now=39;ids,way=scan()
check("locked proxy cannot claim nearby distinct open doorway",way and way.pos.Y==180)
alternateY=600
-- Planner's first-result contract remains unchanged; evidence follows native bends.
local survey=D.survey();local plan,pts=D.plan(controller,{},p(-400,0),p(400,0),function()end,nil,survey)
check("detour keeps three-waypoint caller contract",type(plan)=="table" and #plan==3)
local bend=false;for _,v in ipairs(pts or {}) do if v.X==-400 and v.Y==600 then bend=true end end
check("planner evidence includes native bend omitted by waypoint chords",bend)
closed=false;local direct,evidence=D.plan(controller,{},p(-400,0),p(400,0),function()end,nil,D.survey())
check("direct nil contract includes complete evidence",direct==nil and #evidence==2)
partial=true;local rejected=D.plan(controller,{},p(-400,0),p(400,0),function()end,nil,D.survey())
check("incomplete route retains false contract",rejected==false)
-- Native regression: the blocked hall was actually surveyed OPEN. A represented
-- short route must not veto the distinct, unlisted eastern portal.
partial=false;closed=false;alternative=true;now=42
local falseOpenQueries, falseOpenSurveys=queries,surveys
ids,way=scan()
check("false-open represented hall still offers distinct unlisted portal",way and way.pos.Y==600 and ids.look and ids.test and not ids.target)
check("false-open portal search costs three queries and one survey",queries-falseOpenQueries==3 and surveys-falseOpenSurveys==1)
check("generated way retains native approach bend and portal crossing",way and #way.way_via==3 and way.way_via[1].X==-400 and way.way_via[1].Y==600 and way.way_via[2].X==-80)
check("generated way remembers represented hall as excluded approach",way and #way.way_avoid==1 and way.way_avoid[1].centre.Y==0)
local positiveWay=way
alternative=false;now=45;ids,way=scan()
check("false-open represented hall alone creates no duplicate",not way and ids.look and ids.test)
alternative=true;intervening=true;now=48;ids,way=scan()
check("explicit portal approach cannot jump intervening room",not way)
intervening=false;badLeg=true;now=51;ids,way=scan()
check("explicit portal rejects incomplete approach despite complete hall route",not way)
badLeg=false
-- The geometry/object fallback still tries later destinations when their
-- entrance is NOT in the doorway survey: a duplicate is not a room-wide veto.
alternative=false
local fallbackQuery=package.loaded["nav.route"].query
package.loaded["nav.route"].query=function(c,pawn,label,a,b)
    if b.X==400 then queries=queries+1;return true,1500,{a,p(-400,600),p(400,600),b} end
    return fallbackQuery(c,pawn,label,a,b)
end
now=54;local fallbackBefore=queries;ids,way=scan(nil,true)
check("later candidate can use unsurveyed opening after represented duplicate",way and way.pos.Y==600)
check("unsurveyed fallback checks both candidate routes",queries-fallbackBefore==2)
package.loaded["nav.route"].query=fallbackQuery;alternative=true
-- Exercise actual autowalk with the generated entry, not a separately authored
-- waypoint list. Shortest path to the final goal alone still goes through hall.
local oldAW,oldFollow=package.loaded["autowalk.autowalk"],package.loaded["nav.follow"]
package.loaded["autowalk.autowalk"]=nil
local here=p(-400,0)
local started={}
local follower={ready=function()return true end,tick=function()end}
follower.start=function(_,_,goal,emit)started[#started+1]=goal;follower.active={emit=emit} end
follower.stop=function(reason)local s=follower.active;follower.active=nil;if s then s.emit("follow_end="..reason) end end
package.loaded["nav.follow"]=follower
local AW=require("autowalk.autowalk")
local actorReads=0
local walkingController={Pawn={K2_GetActorLocation=function()actorReads=actorReads+1;return here end,CapsuleComponent={K2_GetComponentLocation=function()return here end,GetScaledCapsuleHalfHeight=function()return 0 end}}}
local activationQueries,activationSurveys,activationFloors=queries,surveys,floorReads
check("generated false-open alternative starts autowalk",AW.start(walkingController,positiveWay)==true)
check("autowalk first aims at approach bend not final goal",started[1] and started[1].X==-400 and started[1].Y==600)
local arrivalActorReads=actorReads
local oldStanding,arrivalCurrent=S.standing_room,nil
S.standing_room=function(c,q,current)arrivalCurrent=current;return oldStanding(c,q,current) end
for i=1,3 do if follower.active then
    here=started[#started]
    if i==3 then S.room=B end -- scanner may already have observed the crossing
    follower.stop("arrived_test_region");AW.tick()
end end
S.standing_room=oldStanding
check("autowalk follows all retained approach legs to arrival",#started==3 and not AW.walking() and started[2].X==-80 and started[3].X==80)
check("activation and three legs use six queries and three surveys",queries-activationQueries==6 and surveys-activationSurveys==3)
check("only final room arrival adds five floor reads",floorReads-activationFloors==5)
check("arrival uses scanner actor-position getter exactly once",actorReads-arrivalActorReads==1)
check("arrival shares scanner current-room vote context, not stale departure room",arrivalCurrent==B)
-- If native routing changes to the represented hall, refuse rather than fall
-- back to ordinary/offmesh walking to the far-side goal.
here=p(-400,0)
local oldQuery=package.loaded["nav.route"].query
package.loaded["nav.route"].query=function(_,_,_,a,b)return true,1000,{a,p(100,0),b} end
local startedBefore=#started
check("activation refuses a changed route through false-open listed hall",AW.start(walkingController,positiveWay)==false and #started==startedBefore)
package.loaded["nav.route"].query=oldQuery
-- Revalidation also happens between legs, not just on selection.
check("alternative can start again after routing recovers",AW.start(walkingController,positiveWay)==true)
here=started[#started];follower.stop("arrived_test_region")
partial=true;AW.tick()
check("invalid next leg stops before issuing movement",not AW.walking() and #started==startedBefore+1)
partial=false
here=p(-400,0);AW.start(walkingController,positiveWay)
here=started[#started];follower.stop("arrived_test_region");AW.tick()
here=p(-200,600);follower.stop("stalled");AW.tick()
check("stall retry retains only the unfinished approach",AW.active and #AW.active.walk.legs==2 and started[#started].X==-80)
AW.cancel();AW.tick()
local originalSurvey=D.survey
D.survey=function()local ds=originalSurvey();ds[2].state="blocked";return ds end
here=p(-400,0);local beforeClosure=#started
check("newly closed alternative is rejected before movement",AW.start(walkingController,positiveWay)==false and #started==beforeClosure)
D.survey=originalSurvey
-- Final tolerance is not room arrival: one centre floor hit is insufficient.
local lastSpeech
AW.say=function(t)lastSpeech=t end
here=p(-400,0);AW.start(walkingController,positiveWay)
for i=1,2 do here=started[#started];follower.stop("arrived_test_region");AW.tick() end
local ordinaryFloors=StaticFindObject
StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b,_,_,_,_,hit)
    local r=(math.abs(b.X-60)<1 and math.abs(b.Y-600)<1) and "Test_B_GRC" or "Test_A_GRC"
    hit.Actor={Get=function()return {GetFullName=function()return "StaticMeshActor /Game/Maps/Test/"..r.."."..r..":PersistentLevel.Floor" end} end};return true
end} end
here=p(60,600);follower.stop("arrived_test_region");AW.tick()
check("within-30cm final stop with non-target standing vote cannot announce arrival",not AW.walking() and lastSpeech=="walk_no_route")
here=p(-400,0);AW.start(walkingController,positiveWay)
for i=1,2 do here=started[#started];follower.stop("arrived_test_region");AW.tick() end
here=p(60,600);follower.active.emit("follow_progress elapsed=1 remaining=20")
follower.stop("cinematic_movement_track");AW.tick()
check("native takeover before target-room vote remains interruption, not false arrival or route failure",lastSpeech=="walk_interrupted")
AW.start(walkingController,{name="ordinary",pos=p(80,600),kind="goal"})
follower.stop("arrived_test_region");AW.tick()
check("ordinary entry arrival retains existing distance semantics",lastSpeech=="walk_arrived")
StaticFindObject=ordinaryFloors
package.loaded["autowalk.autowalk"],package.loaded["nav.follow"]=oldAW,oldFollow
-- Recorded native coordinates, SYNTHETIC floor/collision responses. Raw logs
-- round these numbers; offsets explicitly avoid assuming exact plane equality.
-- Source: native-scans.json / UE4SS.log 19:46:49 and 19:48:11-12, Nov 9.
do
    local LR,GA="E4_3B_LivingRoom_LD","E4_3B_Garage_LD"
    local start={X=59.886,Y=-15.020,Z=85.036}
    StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b,_,_,_,_,hit)
        local garage=(b.X>500 and b.Y>=230) or (b.X<=500 and b.Y>=4)
        local r=garage and "E4_3B_Garage_GRC" or "E4_3B_LivingRoom_GRC"
        hit.Actor={Get=function()return {GetFullName=function()return "StaticMeshActor /Game/Maps/Test/"..r.."."..r..":PersistentLevel.Floor" end} end};return true
    end} end
    local hall={index=1,state="open",centre=p(48,5),nx=0,ny=1,sides={p(48,-75),p(48,85)}}
    local east={index=2,state="open",centre=p(880,230),nx=0,ny=1,sides={p(880,150),p(880,310)}}
    D.survey=function()return {hall,east} end
    local boundaryQueries=0
    package.loaded["nav.route"].query=function(_,_,_,a,b)
        boundaryQueries=boundaryQueries+1
        if b.X==880 and b.Y==150 then return true,1000,{a,p(730,-160),p(745,-150),b} end
        return true,math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2),{a,b}
    end
    check("recorded start standing vote remains living room",S.standing_room(controller,start,LR)==LR)
    for _,offset in ipairs({-0.5,0,0.5}) do
        local qBefore=boundaryQueries
        world="boundary"..offset;S.room=nil
        local goal={X=40,Y=5+offset,Z=4}
        local line={p(60,-15),goal}
        check("represented terminal before/on/after plane "..offset,D.represents(line,hall))
        local out={{id="look",label="Garage door",kind="interaction",door_like=true,sublevel=LR,pos={X=70,Y=19,Z=111}},
            {id="test",label="Garage door",kind="interaction",door_like=true,sublevel=LR,pos={X=69,Y=9,Z=112}},
            {id="target",label="Target",kind="interaction",sublevel=GA,pos=goal}}
        local found=S.by_room(controller,out,start);local chosen
        for _,e in ipairs(found) do if e.id=="way:"..GA then chosen=e end end
        check("boundary candidate preserves four-leg eastern way "..offset,chosen and #chosen.way_via==4 and chosen.way_via[1].X==730 and chosen.way_via[2].X==745 and chosen.way_via[3].Y==150 and chosen.way_via[4].Y==310)
        check("boundary way carries intended room vote identity "..offset,chosen and chosen.way_room==GA and chosen.way_from==LR)
        check("boundary recovery uses three route queries "..offset,boundaryQueries-qBefore==3)
    end
    check("endpoint outside finite portal reach is not represented",not D.represents({p(200,-15),p(200,5)},hall))
    check("endpoint on another floor is not represented",not D.represents({{X=60,Y=-15,Z=200},{X=40,Y=5,Z=200}},hall))
    D.survey=function()return {} end;world="boundary-no-survey";S.room=nil
    local result=S.by_room(controller,{{id="own",label="Own",kind="interaction",sublevel=LR,pos=start},
        {id="tiny",label="Tiny",kind="interaction",sublevel=GA,pos={X=40,Y=5,Z=4}}},start)
    local short=false;for _,e in ipairs(result) do if e.id=="way:"..GA then short=true end end
    check("already-within-arrival-radius goal cannot create a no-movement room way",not short)
    -- The no-op check uses BOTH existing follower tolerances, not just XY.
    StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b,_,_,_,_,hit)
        local r=b.Z>-150 and "E4_3B_Garage_GRC" or "E4_3B_LivingRoom_GRC"
        hit.Actor={Get=function()return {GetFullName=function()return "StaticMeshActor /Game/Maps/Test/"..r.."."..r..":PersistentLevel.Floor" end} end};return true
    end} end
    package.loaded["nav.route"].project=function(_,q,extent)return true,{X=q.X,Y=q.Y,Z=extent and 200 or 0} end
    world="different-height";S.room=nil
    result=S.by_room(controller,{{id="own",label="Own",kind="interaction",sublevel=LR,pos=p(0,0)},
        {id="upper",label="Upper",kind="interaction",sublevel=GA,pos={X=0,Y=0,Z=200}}},p(0,0))
    local upper=false;for _,e in ipairs(result) do if e.id=="way:"..GA then upper=true end end
    check("same XY on a different floor is not rejected as already arrived",upper)
end
print(string.format("garage filter: %d checks, %d failures; first detour=%d queries, one survey; cached scan=0 queries/0 surveys",count,fail,initial))
FindAllOf,StaticFindObject=oldF,oldS
for _,m in ipairs({"scanner.sources","scanner.rooms","nav.route","nav.doors"}) do package.loaded[m]=saved[m] end
assert(fail==0,"garage filter regressions")
return count
