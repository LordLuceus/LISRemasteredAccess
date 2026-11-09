package.path='src/?.lua;'..package.path
local p=require('hud.padlock')
local l=require('core.localization')
p.text=l.text
local now=0;p.clock=function()return now end
local n=0
local function eq(a,b)assert(a==b,tostring(a)..' ~= '..tostring(b));n=n+1 end
local function due(gamepad)now=now+0.11;return p.due(gamepad)end
-- Recorded native states, 9 Nov: initial -1, then 0..3; D and A wrap.
eq(p.update(1,{'0','0','0','0'},-1,'OpenMenuImplementable'),true)
eq(p.due(false),nil)
local initial=due(false)
eq(initial:find('No digit selected.',1,true)~=nil,true)
eq(initial,'Combination lock, 4 digits. Code: 0, 0, 0, 0. No digit selected.')
eq(p.help(false),l.text('padlock_keyboard'))
eq(p.help(false):find('Home',1,true)~=nil,true)
eq(p.help(true),l.text('padlock_controller'))
eq(p.help(true):find('D-pad or left stick',1,true)~=nil,true)
eq(p.help(true):find('A applies; B goes back.',1,true)~=nil,true)
eq(p.help(true):find('Home',1,true),nil)
eq(p.help(true):find('W and S',1,true),nil)
eq(p.current(),'Code: 0, 0, 0, 0. No digit selected.')
eq(p.update(1,{'0','0','0','0'},-1,'SpawnDigits'),false)
eq(due(false),nil)
local records={
 {0,{'0','0','0','0'},'0, digit 1 of 4.'},
 {0,{'9','0','0','0'},'9, digit 1 of 4.'},
 {1,{'9','0','0','0'},'0, digit 2 of 4.'},
 {1,{'9','1','0','0'},'1, digit 2 of 4.'},
 {2,{'9','1','0','0'},'0, digit 3 of 4.'},
 {2,{'9','1','1','0'},'1, digit 3 of 4.'},
 {3,{'9','1','1','0'},'0, digit 4 of 4.'},
 {3,{'9','1','1','1'},'1, digit 4 of 4.'},
 {0,{'9','1','1','1'},'9, digit 1 of 4.'},
 {3,{'9','1','1','1'},'1, digit 4 of 4.'},
}
for _,r in ipairs(records) do eq(p.update(1,r[2],r[1],'recorded'),true);eq(due(false),r[3]) end
eq(p.current(),'Code: 9, 1, 1, 1. 1, digit 4 of 4.')
p.clear('cancel');eq(p.active(),false);eq(p.current(),nil);eq(due(false),nil)
eq(p.help(false),nil);eq(p.help(true),nil)
p.update(2,{'0','0','0','0'},-1,'reopen')
local controller=due(true)
eq(controller,initial)
eq(controller:find('A and D',1,true),nil)
eq(controller:find('Home',1,true),nil)
eq(p.current(),'Code: 0, 0, 0, 0. No digit selected.')
eq(p.update(2,{'0','0','0','0'},4,'invalid'),false)
eq(p.current(),nil)
eq(p.update(2,{'0','bad','0','0'},0,'invalid'),false)
eq(due(false),nil)
p.update(2,{'1','0','0','0'},0,'pending');p.clear('closed');eq(due(false),nil)
-- Native adapter: hooks use the owning callback, and metadata creation only
-- installs hooks. A fake object explodes on any access after callback return.
local hooks,notify={},nil
function NotifyOnNewObject(path,cb)eq(path,'/Script/LiS.LiSPickLockWidget');notify=cb end
function StaticFindObject()return {IsValid=function()return true end,GetAddress=function()return 5 end}end
function RegisterHook(path,cb)hooks[path]=cb end
p.start();notify();p.install()
local live=true
local fields={Digit=0,GetAddress=function()assert(live);return 10 end,DigitWidgets_Array={}}
function fields.DigitWidgets_Array:ForEach(fn)
    assert(live)
    for i=1,4 do fn(i,{get=function()return {TextBlock_Digit={GetText=function()assert(live);return {ToString=function()return '0'end}end}}end}) end
end
local view=setmetatable({},{__index=function(_,k)assert(live,'cached object accessed');return fields[k]end})
local prefix='/Game/Packages/Widgets/TimeTravel/BP_LiSPickLockWidget_View.BP_LiSPickLockWidget_View_C:'
hooks[prefix..'OpenMenuImplementable']({get=function()return view end})
live=false;eq(p.current(),'Code: 0, 0, 0, 0. 0, digit 1 of 4.');due(false)
hooks[prefix..'Exit']();eq(p.current(),nil)
p.update(10,{'0','0','0','0'},0,'open')
function FindAllOf()return {}end
p.check_presence();eq(p.active(),false);eq(due(false),nil)
eq(p.help(true),nil)
p.update(10,{'0','0','0','0'},0,'open')
function FindAllOf()error('unavailable native view')end
p.check_presence();eq(p.active(),false)
eq(p.help(false),nil)
-- Existing controller help chord remains available with gameplay disabled.
local pad=require('scanner.pad').new()
pad:update(0,false,0)
pad:update(0x40,false,1)
eq(table.concat(pad:update(0x41,false,2),','),'help')
-- Early class-default construction has metadata but no bound function yet.
-- Failed registrations must be retried, not permanently marked installed.
package.loaded['hud.padlock']=nil
local retry=require('hud.padlock')
local attempts,messages=0,{}
retry.log=function(s)messages[#messages+1]=s end
function RegisterHook()attempts=attempts+1;error('UFunction::Func: 0x0')end
retry.install();eq(attempts,10);eq(#messages,10)
retry.install();eq(attempts,20);eq(#messages,10)
function RegisterHook()attempts=attempts+1 end
retry.install();eq(attempts,30)
retry.install();eq(attempts,30)
-- Exercise the actual shared F1/controller-help dispatcher without booting
-- main.lua or touching game objects. Closing must restore ordinary help.
local f=assert(io.open('src/main.lua','r'));local source=f:read('*a');f:close()
local body=assert(source:match('local function show_help%(%)%s*\n(.-)\nend'))
local gamepad,closed,heard,checks=false,false,nil,0
local show=assert(load('return function() '..body..' end','@show_help_test','t',{
    padlock={check_presence=function()checks=checks+1;if closed then p.clear('hidden') end end,help=p.help},
    controls={using_gamepad=function()return gamepad end},
    help={speech=function(g)return g and 'general controller help' or 'general keyboard help' end},
    say=function(t,interrupt)eq(interrupt,true);heard=t end,
}))()
p.update(10,{'0','0','0','0'},-1,'help-test')
show();eq(heard,l.text('padlock_keyboard'))
gamepad=true;show();eq(heard,l.text('padlock_controller'))
closed=true;show();eq(heard,'general controller help')
gamepad=false;show();eq(heard,'general keyboard help')
eq(checks,4)
-- Help and native Up can arrive in either order. Exercise the real controller
-- decoder as well as the reader; snapshots stay current even when speech loses
-- priority to the help gesture. No speech-length timer masks later edits.
local function start_lock()
    p.clear('test');p.observe_buttons(0)
    p.update(20,{'0','0','0','0'},0,'OpenMenuImplementable');due(false)
end
local function edit(value,event)
    p.update(20,{tostring(value),'0','0','0'},0,event or 'Up Pressed')
end
for _,order in ipairs({'before','after'}) do
    start_lock()
    local decoder=require('scanner.pad').new()
    decoder:update(0,false,now);decoder:update(0x40,false,now)
    if order=='before' then edit(1);now=now+0.2 end
    p.observe_buttons(0x41)
    local commands=decoder:update(0x41,false,now)
    eq(table.concat(commands,','),'help')
    for _,cmd in ipairs(commands) do
        if cmd=='help' then p.controller_help();eq(p.help(true),l.text('padlock_controller')) end
    end
    if order=='after' then edit(1) end
    eq(due(true),nil)
    eq(p.current(),'Code: 1, 0, 0, 0. 1, digit 1 of 4.')
    edit(2);eq(due(true),nil) -- held-Up repeats
    p.observe_buttons(0x1) -- release L3 first; Up still belongs to help
    edit(3);eq(due(true),nil)
    edit(2,'Down Pressed');eq(due(true),'2, digit 1 of 4.')
    p.observe_buttons(0) -- release Up; next deliberate edit speaks immediately
    edit(4);eq(due(true),'4, digit 1 of 4.')
end
start_lock();p.controller_help();p.observe_buttons(0x40) -- Up released first
edit(1);eq(due(true),'1, digit 1 of 4.')
p.controller_help();p.observe_buttons(-1) -- disconnect cannot leave it muted
edit(2);eq(due(true),'2, digit 1 of 4.')
p.controller_help();p.clear('Exit')
p.update(21,{'0','0','0','0'},-1,'OpenMenuImplementable')
eq(due(true),initial)
-- Up alone, and Up THEN L3, must remain ordinary native edits.
start_lock()
local reverse=require('scanner.pad').new()
reverse:update(0,false,now);reverse:update(0x1,false,now)
p.observe_buttons(0x41)
eq(#reverse:update(0x41,false,now),0)
edit(1);eq(due(true),'1, digit 1 of 4.')
local loop=assert(source:match('LoopInGameThreadWithDelay%(50,function%(%)\n(.*)'))
eq(assert(loop:find('pad_step()',1,true))<assert(loop:find('padlock.due()',1,true)),true)
eq(source:find('elseif cmd=="help" then padlock.controller_help();show_help()',1,true)~=nil,true)
print('padlock reader: '..n..' checks passed')
