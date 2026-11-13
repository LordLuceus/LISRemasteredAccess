-- Execute the real entry point with engine/services replaced by inert fakes.
-- This checks actual Home/Read-mode wiring, not just strings in source.
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
    if name=='core.localization' or name=='core.text' or name=='core.help' or name=='descriptions.reader' or name=='scanner.pad' or name=='menus.tracker' then
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
fake_require('menus.keybindings').active=false
fake_require('hud.padlock').active=function()return false end
fake_require('core.controls').using_gamepad=function()return false end
local Key=setmetatable({F5=0x74},{__index=function(t,k)rawset(t,k,k);return k end})
local env=setmetatable({require=fake_require,Key=Key,ModifierKey={CONTROL=1,SHIFT=2},
    print=function()end,LoopInGameThreadWithDelay=function(ms,fn)if ms==50 then game_loop=fn end;return 1 end,
    CancelDelayedAction=function()end,RegisterHook=function()end,FindAllOf=function()return {} end},
    {__index=_G})
env._G=env
assert(loadfile('src/main.lua','t',env))()
check(bound['116:none']==nil,'extra F5 binding removed')
check(bound['ENTER:none']==nil and bound['RETURN:none']==nil,'native Enter is not intercepted or reimplemented')
local home,repeat_last=bound['HOME:none'],bound['HOME:ctrl']
local editor=fake_require('menus.keybindings')
editor.active=true
local directions={}
editor.move=function(d)
    directions[#directions+1]=d
    return {screen='keybinds@test',index=#directions,label='Quick Undo',value='U'},'screen=keybinds'
end
bound['PAGE_DOWN:none']();bound['PAGE_UP:none']()
check(directions[1]==1 and directions[2]==-1,'Page keys reach the editor traversal in both directions')
check(spoken[#spoken]=='Quick Undo, U','editor movement announces the selected native binding immediately')
editor.active=false
check(type(home)=='function' and type(repeat_last)=='function','contextual Home and literal repeat remain distinct')
current_page={id=1,index=1,count=1,text='Native page text.',reading=false,key='1:1:picture'}
home();check(requested[#requested]==current_page,'Home requests description in picture mode')
picture.say('Image description. Has text version.')
current_page={id=1,index=1,count=1,text='Native page text.',reading=true,key='1:1:read'}
home();check(spoken[#spoken]=='Native page text.','Home in Read mode reads text even when description was last')
bound['F1:none']();local help=spoken[#spoken]
repeat_last();check(spoken[#spoken]==help,'Control Home repeats help literally')
home();check(spoken[#spoken]=='Native page text.','Home still returns current native text after help')
current_menu={label='Pause'};local n=#requested;home()
check(#requested==n,'Home cannot request an image behind a menu')
current_menu=nil;current_page={id=2,index=1,count=1,text='Controller text.',reading=true,key='2:1:read'}
game_loop();buttons=1;game_loop()
check(spoken[#spoken]=='Controller text.','actual D-pad Up reads current text mode, not description')
n=#spoken;game_loop();check(#spoken==n,'controller hold does not repeat')
buttons=0;game_loop();buttons=0x41;n=#requested;game_loop()
check(#requested==n,'controller help chord does not also reread')
buttons=0;current_page.reading=false;current_page.key='2:1:picture';game_loop()
buttons=1;game_loop()
check(requested[#requested]==current_page,'D-pad Up back in picture mode requests description')
for _,name in ipairs({'hud.viewer','core.help','core.text','core.localization','descriptions.reader'}) do package.loaded[name]=nil end
print('Main description wiring: '..checks..' checks passed')
return checks
