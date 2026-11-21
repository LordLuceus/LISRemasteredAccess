-- Execute the actual integration function, not a parallel model of its queue.
local f=assert(io.open('src/main.lua'));local source=f:read('*a');f:close()
local first=assert(source:find('local pending_icons,icons_world=',1,true))
local last=assert(source:find('local function sms_step()',first,true))
local count=0
local function check(ok,message)count=count+1;assert(ok,message)end
local function fixture()
    local state={menu=false,owned=true,name='E1_2A',id=42,lines={},spoken={}}
    local world={IsValid=function()return true end,GetAddress=function()return state.id end,
        GetFName=function()return{ToString=function()return state.name end}end}
    local env=setmetatable({
        scanner={controller=function()
            if state.missing then return nil end
            if state.error then error('transient controller failure')end
            return{GetWorld=function()return world end}
        end},
        icons={reset=function()state.resets=(state.resets or 0)+1 end,
            tick=function()local lines=state.lines;state.lines={};return lines end},
        in_menu=function()return state.menu end,
        speech={has_owner=function()return state.owned end},
        world_draw_pending=function()return state.draw_pending end,
        say=function(text,interrupt)check(interrupt==false,'HUD delivery stays queued');state.spoken[#state.spoken+1]=text end,
        log=function()end,
    },{__index=_G})
    return state,assert(load(source:sub(first,last-1)..'\nreturn icons_step','HUD integration','t',env))()
end
local s,step=fixture()
s.owned=false;s.draw_pending=true;s.lines={'Consequences.'};step()
check(#s.spoken==0,'consequence waits while Draw is pending behind dialogue')
s.draw_pending=false;step();step()
check(#s.spoken==1 and s.spoken[1]=='Consequences.','consequence queues once after Draw')
s,step=fixture()
s.lines={'This action will have consequences.','New fact.','Saving.'};step()
check(#s.spoken==0,'all notices wait during narration')
s.menu=true;s.owned=false;step();step();check(#s.spoken==0,'pause never drains pending notices')
s.menu=false;step();step()
check(table.concat(s.spoken,'|')=='This action will have consequences.|New fact.|Saving.','pause retains all notices in order, exactly once')
for _,kind in ipairs({'missing','error'})do
    s,step=fixture();s.lines={'Saving.'};step();s[kind]=true;step();s[kind]=false;s.owned=false;step()
    check(#s.spoken==1,kind..' world observation does not discard a queued event')
end
for _,transition in ipairs({'main menu','other map','same-map reload'})do
    s,step=fixture();s.lines={'Old notice'};step()
    if transition=='main menu'then s.name='WhatIf_Menu';s.menu=true
    elseif transition=='other map'then s.name='E1_3A';s.id=43
    else s.id=43 end
    step();s.menu=false;s.name='E1_2A';s.owned=false;step()
    check(#s.spoken==0,transition..' drops old-session notices')
    s.lines={'New notice'};step();check(s.spoken[1]=='New notice',transition..' does not disable future notices')
end
print('HUD notification queue: '..count..' checks passed')
return count
