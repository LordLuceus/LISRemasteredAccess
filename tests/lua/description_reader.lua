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
local out,queued,interrupts={},nil,{}
local picture={}
picture.automatic=function(page)queued=page;return page.id~=nil end
picture.cancel_auto=function()queued=nil end
local R=require('descriptions.reader').new(V,picture,function(s,interrupt)out[#out+1]=s;interrupts[#interrupts+1]=interrupt end,function()end)
local text={id=1,index=1,count=1,text='Original native text.',key='1:1:text'}
local photo={id=1,index=2,count=2,text='',key='1:2:'}
R.step(text)
check(out[1]=='Original native text.' and not queued,'native text preserved, no automatic caption')
R.step(text);check(#out==1,'native text not repeated unchanged')
R.step(photo);check(#out==1 and queued==photo,'no-text line suppressed while description is queued')
queued=nil;R.step(photo);check(not queued and #out==1,'automatic description requested once per page')
R.closed(1);R.step(photo);check(queued==photo,'same-address reopen automatically describes again')
R.step(text);check(not queued and out[#out]=='Original native text.','native text appearance cancels queued fallback')
R.step(nil);check(not queued,'closed viewer clears queue')
photo.text='<b> </b>';photo.key='1:2:markup';R.step(photo)
check(queued==photo,'markup-only text counts as no text after shared cleaning')
R.step(nil);photo.id=nil;photo.key='unknown';R.step(photo)
check(out[#out]=='viewer_no_text Page 2 of 2.','unavailable view identity retains existing native fallback')
-- The F5 wrapper first runs this same step, then queues its manual request.
-- A later normal poll must not overwrite the manual spoken description.
R.step(nil);out={};R.step(text);out[#out+1]='Requested description.';R.step(text)
check(#out==2 and out[2]=='Requested description.','F5 before normal poll is not interrupted by duplicate native text')
R.step(nil);out={};R.step(text);R.step(text);out[#out+1]='Requested description.';R.step(text)
check(#out==2 and out[2]=='Requested description.','normal poll before F5 preserves native read then requested description')
R.step(nil);out={};R.described(1,1);R.step(text)
check(out[1]=='Original native text.' and interrupts[#interrupts]==false,'late native text queues instead of interrupting F5')
R.step(nil);photo.id=1;photo.text='';photo.key='1:2:';R.described(1,2);R.step(photo)
check(not queued,'F5 on a freshly changed page prevents a duplicate automatic caption')
V.text,V.clean=old_text,old_clean
print('Description coordination: '..n..' checks passed')
return n
