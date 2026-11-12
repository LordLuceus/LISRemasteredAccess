package.path='src/?.lua;'..package.path
local n=0
local function check(v,label)n=n+1;assert(v,label)end
local V=require('hud.viewer')
local old_text,old_clean=V.text,V.clean
V.text=function(key,p)
    if key=='viewer_page' then return 'Page '..p.index..' of '..p.count..'.' end
    return key
end
V.clean=function(s)return s:gsub('<[^>]+>','') end
local out,queued={},nil
local picture={}
picture.automatic=function(page)queued=page;return page.id~=nil end
picture.request=function(page)queued=page;return true end
picture.cancel_auto=function()queued=nil end
picture.cancel=picture.cancel_auto
local R=require('descriptions.reader').new(V,picture,function(s)out[#out+1]=s end,function()end)
local image={id=1,index=1,count=1,text='Native text.',reading=false,key='1:1:image'}
local read={id=1,index=1,count=1,text='Native text.',reading=true,key='1:1:read'}
R.step(image)
check(#out==0 and queued==image,'text-bearing picture describes instead of transcribing')
queued=nil;R.step(image);check(not queued,'unchanged picture does not repeat')
R.step(read)
check(out[1]=='Native text.' and not queued,'entering native Read reads text and cancels pending image')
R.step(read);check(#out==1,'unchanged Read mode stays quiet')
out[#out+1]='Help announcement.';R.reread(read)
check(out[#out]=='Native text.','Home in Read mode reads text rather than the last announcement')
R.step(image);check(queued==image,'returning to picture describes again')
queued=nil;R.reread(image);check(queued==image,'Home in picture mode requests its current description')
queued=nil;R.step(image);check(not queued,'Home before regular poll does not cause duplicate auto speech')
R.closed(1);R.step(image);check(queued==image,'same-address reopen describes again')
R.step(nil);check(not queued,'closing clears queued automatic description')
local photo={id=2,index=2,count=3,text='',reading=false,key='2:2:image'}
R.step(photo);check(queued==photo,'textless pictures keep automatic descriptions')
R.step(nil);out={};R.described(1,1,false,true);R.step(read)
check(out[1]=='Native text.','prior image description cannot suppress entering Read mode')
R.step(nil);out={};R.described(1,1,false,false);R.step(image)
check(out[1]=='picture_has_text' and not queued,'late-loaded text announces availability, not transcription')
R.step(nil);out={};local unknown={id=3,index=1,count=1,text='Accessible fallback.',key='3:1:unknown'}
R.step(unknown);check(out[1]=='Accessible fallback.','unknown mode retains working native text access')
R.step(nil);out={};local noid={index=1,count=1,text='Native text.',reading=false,key='noid'}
R.step(noid);check(out[1]=='picture_description_unavailable picture_has_text','missing image identity does not transcribe known picture mode')
local visible=false
local widget={CanvasPanel_Read={IsValid=function()return true end,IsVisible=function()return visible end}}
check(V.reading(widget)==false,'hidden native Read panel means picture mode')
visible=true;check(V.reading(widget)==true,'visible native Read panel means text mode')
check(V.reading({})==nil,'missing panel is unknown, not a fabricated mode')
local old_find=FindAllOf
widget.IsValid=function()return true end
widget.IsVisible=function()return true end
widget.IsInViewport=function()return true end
widget.GetAddress=function()return 123 end
widget.TextBlock_PictureText={IsValid=function()return true end,GetText=function()
    return {ToString=function()return 'Unchanged text.' end}
end}
widget.CurrentPicture=0;widget.NumPages=2
FindAllOf=function()return {widget} end
visible=false;local a=V.current();visible=true;local b=V.current()
check(a.text==b.text and a.key~=b.key and not a.reading and b.reading,'actual snapshot changes identity when only native Read visibility changes')
FindAllOf=old_find
R.step(nil);out={};R.reread(read);R.step(read)
check(#out==1 and out[1]=='Native text.','Home on entering Read suppresses a duplicate automatic read')
V.text,V.clean=old_text,old_clean
print('Description coordination: '..n..' checks passed')
return n
