-- Native identities: Episode02/Sequence01/E2_1A_Bathroom_LD,
-- LiSInteractionActor_Bathroom_2 / $GT_Sensen_Int_Room14 (Showers), whose
-- Interact01/02 use Door02/01 (Leave/Enter). Shower_9 / Shower01 is the
-- separate shower stall. Extracted all-actions.json and English Sensen.ini;
-- user's 2026-11-23 log confirms both entrance actions and the filter toggle.
-- Positions, control props and floor traces are synthetic: this tests the
-- actual collector/filter wiring, not native doorway geometry or navigation.
package.path='src/?.lua;'..package.path
local n,failed=0,0
local function check(ok,label)
    n=n+1;if not ok then failed=failed+1;print('FAIL showers: '..label) end
end
local old_find,old_static,old_name,old_flags=FindAllOf,StaticFindObject,FName,EObjectFlags
local old_source,old_route=package.loaded['scanner.sources'],package.loaded['nav.route']
local R=require('scanner.rooms')
local function name(s)return {ToString=function()return s end}end
local function array(values)
    return {ForEach=function(_,fn)for i,v in ipairs(values) do fn(i,{get=function()return v end}) end end}
end
local CO,BA,MA='E2_1A_Corridor_LD','E2_1A_Bathroom_LD','E2_1A_MaxRoom_LD'
local function full(room,id)
    return 'LiSInteractionActor /Game/Maps/Episode02/Sequence01/'..room..'.'..room..':PersistentLevel.'..id
end
local function action(id,label)
    return {ActionName=name(id),OverrideDisplayName=name(label),bEnabled=true,
        FactCondAND=array({}),FactCondOR=array({}),ActorCondAND=array({}),ActorCondOR=array({})}
end
local function actor(room,id,key,x)
    return {IsValid=function()return true end,HasAnyFlags=function()return false end,
        bIsRegistered=true,bHidden=false,bNeedToHide=false,objectName=name(key),
        GetFullName=function()return full(room,id) end,GetFName=function()return name(id) end,
        K2_GetActorLocation=function()return {X=x,Y=0,Z=100} end,
        Actions=array({action('Look01','None')})}
end
local entrance=actor(BA,'LiSInteractionActor_Bathroom_2','$GT_Sensen_Int_Room14',0)
entrance.Actions=array({action('Interact01','$GT_Sensen_Action_Door02'),action('Interact02','$GT_Sensen_Action_Door01')})
local shower=actor(BA,'LiSInteractionActor_Shower_9','$GT_Sensen_Int_Shower01',500)
shower.Actions=array({action('Interact01','$GT_Sensen_Action_Use')})
local registered={entrance,shower,actor(CO,'FixtureCorridorProp','fixture_corridor',-500),
    actor(MA,'FixtureBedroomProp','fixture_bedroom',1000)}
local x,world,floors=-500,'E2_1A',true
local controller={GetAddress=function()return 777 end,IsFactActive=function()return false end,
    GetWorld=function()return {GetFName=function()return name(world)end}end,
    Pawn={K2_GetActorLocation=function()return {X=x,Y=0,Z=100}end}}
local component={IsValid=function()return true end,HasAnyFlags=function()return false end,
    GetOwner=function()return controller end,RegisteredActors=array(registered)}
FindAllOf=function(class)if class=='LiSInteractionComponent' then return {component} end;return {} end
FName=function(s)return s end
EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
StaticFindObject=function()return {LineTraceSingle=function(_,_,_,b,_,_,_,_,hit)
    if not floors then return false end
    local room=b.X<0 and CO or (b.X<800 and BA or MA)
    hit.Actor={Get=function()return {GetFullName=function()return full(room:gsub('_LD$','_GRC'),'FixtureFloor') end}end}
    return true
end}end
package.loaded['nav.route']={project=function()return false end}
package.loaded['scanner.sources']=nil
local S=require('scanner.sources')
local label='Showers'
S.translate=function(key)return key=='$GT_Sensen_Int_Room14' and label or key end
local errors={}
S.report=function(line)if line:find('error',1,true) then errors[#errors+1]=line end end
local function collect()
    local out={};for _,e in ipairs(S.collect(controller)) do out[e.id]=e end;return out
end
local id=entrance:GetFullName()
local outside=collect()
check(outside[id]~=nil,'entrance listed from corridor with filter on')
check(outside[shower:GetFullName()]==nil,'actual shower stall stays hidden outside')
S.ROOM_FILTER=false
local entry=collect()[id]
check(entry~=nil and entry.is_door==true,'producer marks native entrance as a door')
check(entry~=nil and entry.door_like==true,'producer requests its floor-connection test')
check(entry and entry.joins and entry.joins[CO] and entry.joins[BA],'both neighbouring rooms recorded')
check(entry and entry.label=='Showers','native label preserved, not Bathroom door')
check(R.door_label(id)==nil,'recognition does not invent a replacement label')
S.ROOM_FILTER=true;x=500
local inside=collect()
check(inside[id]~=nil,'entrance remains listed inside bathroom')
check(inside[shower:GetFullName()]~=nil,'actual shower stall remains listed inside')
x=1000
check(collect()[id]==nil,'known connection stays hidden from unrelated bedroom')
x=-500;label='Douches'
check((collect()[id] or {}).label=='Douches','classification is independent of translated label')
entrance.bHidden=true
check(collect()[id]==nil,'hidden story entrance is still excluded')
entrance.bHidden=false
check(R.door_like(shower:GetFullName(),'$GT_Sensen_Int_Shower01','Shower')==false,'singular shower is not an entrance')
check(R.door_like(shower:GetFullName(),'$GT_Sensen_Int_Shower02','Showers')==false,'matching English plural alone does not identify a door')
-- New world invalidates the cached floor join; keep the established fallback
-- for confirmed doors when the floor test cannot establish their connections.
floors=false;world='E2_1A_no_floor'
check(collect()[id]~=nil,'missing floor evidence does not hide a confirmed entrance')
check(#errors==0,'collector has no swallowed errors: '..table.concat(errors,'; '))
FindAllOf,StaticFindObject,FName,EObjectFlags=old_find,old_static,old_name,old_flags
package.loaded['scanner.sources'],package.loaded['nav.route']=old_source,old_route
print('Showers room filter: '..n..' checks, '..failed..' failures')
assert(failed==0,'Showers room-filter regressions')
return n
