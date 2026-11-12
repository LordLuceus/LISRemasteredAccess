-- Execute the real entry point with engine/services replaced by inert fakes.
-- This checks actual binding/wiring, not merely whether the source names F5.
package.path='src/?.lua;'..package.path
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local bound,modules,spoken,requested={},{},{},{}
local current_page,current_menu=nil,nil
local buttons,game_loop=0,nil
local real_require=require
local function stub()
    local s=setmetatable({},{__index=function()return function()end end})
    s.new=function()return s end;s.cursor=s.new
    return s
end
local function fake_require(name)
    if name=='LISNavRequest' then return {} end
    if modules[name] then return modules[name] end
    local s
    if name=='core.localization' or name=='core.text' or name=='core.help' or name=='descriptions.reader' or name=='scanner.pad' then
        s=real_require(name)
    elseif name=='hud.viewer' then
        s=real_require(name)
        s.current=function()return current_page end
    else s=stub() end
    modules[name]=s
    return s
end
local speech=fake_require('core.speech')
speech.status=function()return 'offline test' end
speech.say=function(t)spoken[#spoken+1]=t end
speech.pad=function()return buttons end
speech.keys=function()return 0 end
local keys=fake_require('core.keys')
keys.vks={};keys.update=function()return {} end
keys.bind=function(_,key,mods,fn)bound[key..':'..mods]=fn end
local picture=fake_require('descriptions.picture')
picture.request=function(page)requested[#requested+1]=page end
picture.automatic=function(page)requested[#requested+1]='auto:'..page.key;return true end
picture.active=function()return current_page~=nil end
fake_require('menus.main_menu').snapshot=function()return current_menu end
fake_require('hud.padlock').active=function()return false end
fake_require('core.controls').using_gamepad=function()return false end
local Key=setmetatable({F5=0x74},{__index=function(t,k)rawset(t,k,k);return k end})
local env=setmetatable({require=fake_require,Key=Key,ModifierKey={CONTROL=1,SHIFT=2},
    print=function()end,LoopInGameThreadWithDelay=function(ms,fn)if ms==50 then game_loop=fn end;return 1 end,
    CancelDelayedAction=function()end,RegisterHook=function()end,FindAllOf=function()return {} end},
    {__index=_G})
env._G=env
assert(loadfile('src/main.lua','t',env))()
local f5=bound['116:none']
check(type(f5)=='function','actual F5 key is bound without modifiers')
current_page={id=1,index=1,count=1,text='Native page text.',key='1:1:text'}
f5()
check(spoken[#spoken]=='Native page text.','F5 preserves initial native text before requesting description')
check(requested[#requested]==current_page,'F5 queues the currently observed picture')
local n=#spoken;f5();check(#spoken==n,'repeat F5 does not reannounce unchanged native text')
current_page={id=1,index=2,count=2,text='',key='1:2:'};f5()
check(requested[#requested-1]=='auto:1:2:' and requested[#requested]==current_page,'no-text fallback and F5 reach their distinct queues')
check(#spoken==n,'opening no-text line does not cut off its upcoming description')
current_menu={label='Pause'};n=#requested;f5()
check(#requested==n,'F5 does not act behind a menu')
current_menu=nil;current_page=nil;f5()
check(spoken[#spoken]=='No picture ready to describe.','F5 outside a picture gives explicit feedback')
current_page={id=2,index=1,count=1,text='Controller text.',key='2:1:text'}
game_loop();buttons=1;game_loop()
check(requested[#requested]==current_page,'real controller dispatch reaches current picture request')
n=#requested;game_loop();check(#requested==n,'controller hold does not repeat')
buttons=0;game_loop();buttons=0x41;game_loop()
check(#requested==n,'controller help chord never also requests description')
for _,name in ipairs({'hud.viewer','core.help','core.text','core.localization','descriptions.reader'}) do package.loaded[name]=nil end
print('Main description wiring: '..checks..' checks passed')
return checks
