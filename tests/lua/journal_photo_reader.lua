package.path='src/?.lua;'..package.path
package.loaded['hud.journal']=nil
local J=require('hud.journal')
local en=require('lang.en')
local count=0
local function check(ok,label)count=count+1;assert(ok,label)end
J.text=function(k,p)return (en[k]:gsub('{(%w+)}',function(n)return tostring(p[n])end))end
local c=J.cursor()
local first={kind='photo_detail',title='Chrysalis',ref='1:Episode1',items={'Preview one. 1 of 10.','Preview two. 2 of 10.'}}
local current=first
J.page=function()return current end
check(c:update(first):find('Chrysalis',1,true),'episode heading on entry')
local text,handled=J.photo_read(c,1)
check(handled and text==first.items[2],'Down advances the fresh photo page')
check(J.photo_read(c)==first.items[2],'Home rereads current photo')
current={kind='photo_detail',title='Chrysalis',ref=first.ref,items={first.items[1],'Collected photo. 2 of 10.'}}
check(J.photo_read(c)=='Collected photo. 2 of 10.','Home reflects a changed current brush, not old text')
current={kind='photo_detail',title='Out of Time',ref='2:Episode2',items={'New preview. 1 of 10.'}}
text=J.photo_read(c,1)
check(text:find('Out of Time',1,true) and text:find('New preview',1,true),'owner replacement announces new episode before advancing')
check(c.index==1,'episode change resets to first photo')
current=nil
text,handled=J.photo_read(c)
check(text==nil and handled,'closed page cannot replay stale photo')
c:update({kind='characters',title='Characters',items={'Name'},list=true})
text,handled=J.photo_read(c,1)
check(text==nil and not handled,'other journal readers retain native navigation')

local Pad=require('scanner.pad')
for _,reader_first in ipairs({true,false}) do
    local p=Pad.new();p:reader(0,0);p:update(0,false,0)
    local moved,commands
    if reader_first then moved=p:reader(0x41,.1);commands=p:update(0x41,false,.1)
    else commands=p:update(0x41,false,.1);moved=p:reader(0x41,.1) end
    check(moved==nil and commands[1]=='help','help does not also browse, in either callback order')
    check(p:reader(0x1,1)==nil,'releasing thumb while holding Up does not leak a movement')
    p:reader(0,2)
    check(p:reader(0x1,3)==-1,'new deliberate Up press works')
end
package.loaded['hud.journal']=nil
print('Journal photo reader: '..count..' checks passed')
return count
