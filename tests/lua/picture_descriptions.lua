package.path='src/?.lua;src/?/init.lua;'..package.path
local n=0
local function check(v,label)n=n+1;assert(v,label)end
local old_find,old_hook=StaticFindObject,RegisterHook
local inside=false
local now=0
local state={id=11,visible=true,asset='/Game/Pictures/One.One',index=0,count=2,text='',reading=false}
local asset_reads=0
local function obj(fields)
    return setmetatable({},{__index=function(_,key)
        assert(inside,'object access outside owned callback: '..key)
        return fields[key]
    end})
end
local texture=obj({IsValid=function()return true end,GetFullName=function()return 'Texture2D '..state.asset end})
local brush={}
local image=obj({IsValid=function()return true end,Brush=brush})
local textblock=obj({IsValid=function()return true end,GetText=function()
    return {ToString=function()return state.text end}
end})
local view=setmetatable({},{__index=function(_,key)
    assert(inside,'view access outside callback: '..key)
    local methods={IsValid=function()return true end,IsVisible=function()return state.visible end,
        IsInViewport=function()return true end,GetAddress=function()return state.id end}
    if methods[key] then return methods[key] end
    if key=='Image_ShowPicture' then asset_reads=asset_reads+1;return image end
    if key=='TextBlock_PictureText' then return textblock end
    if key=='CurrentPicture' then return state.index end
    if key=='NumPages' then return state.count end
    error('unexpected view field: '..key)
end})
local library=obj({IsValid=function()return true end,GetBrushResourceAsTexture2D=function(_,b)
    check(b==brush,'native getter gets the current brush')
    if state.broken then error('injected native getter failure') end
    return texture
end})
local hooks,counts={},{}
local fail_destruct=true
local function_address=100
RegisterHook=function(path,fn)
    if path:find(':Destruct',1,true) and fail_destruct then error('injected hook failure') end
    hooks[path]=fn;counts[path]=(counts[path] or 0)+1
end
StaticFindObject=function(path)
    if path=='/Script/UMG.Default__WidgetBlueprintLibrary' then
        assert(inside,'library requested outside callback');return library
    end
    return {IsValid=function()return true end,GetAddress=function()return function_address end}
end
local P=require('descriptions.picture')
local default_lookup=P.lookup
local said,logs={},{}
P.clock=function()return now end
P.say=function(text)said[#said+1]=text end
P.log=function(text)logs[#logs+1]=text end
P.text=function(key,params)
    if key=='viewer_page' then return string.format('Page %s of %s.',params.index,params.count) end
    return key
end
P.language=function()return 'fr' end
P.read_mode=function()assert(inside,'mode read outside owned callback');return state.reading end
P.native_text=function(text,index,count)return text..(count>1 and (' Page '..index..' of '..count..'.') or '')end
P.lookup=function(asset,language)
    check(language=='fr','current locale used')
    return ({['/game/pictures/one.one']='Picture one.',
             ['/game/pictures/two.two']='Picture two.'})[asset]
end
local function event(name)
    inside=true
    local ok,err=pcall(hooks[P.VIEW..':'..name],view)
    inside=false
    assert(ok,err)
end
check(not P.install(),'partial registration reports failure')
event('Tick');check(not P.active(),'partial hooks cannot admit requests without lifecycle invalidation')
fail_destruct=false;check(P.install(),'partial registration can recover')
check(counts[P.VIEW..':Tick']==1,'partial recovery does not duplicate Tick')
check(P.install() and counts[P.VIEW..':Destruct']==1,'installation idempotent')
check(not P.request() and said[#said]=='picture_description_not_ready','no ready picture is explicit')
event('Tick')
check(P.active() and asset_reads==0,'heartbeat does not inspect textures')
local before=#said;event('Tick');check(#said==before,'no unsolicited description')
check(P.request(),'request accepted without object reads')
check(asset_reads==0,'request itself does not inspect a widget')
state.asset='/Game/Pictures/Two.Two';state.index=1
event('Tick')
check(said[#said]=='Picture two. Page 2 of 2.','uses actual image at speech time, position last')
local reads=asset_reads;event('Tick');check(asset_reads==reads,'not read repeatedly without request')
P.request();state.asset='/Game/Pictures/One.One';state.index=0;event('Tick')
check(said[#said]=='Picture one. Page 1 of 2.','return to first page reads fresh')
P.request();event('Destruct')
check(not P.active() and said[#said]=='picture_description_unavailable','close cancels pending intent')
before=#said;event('Tick');check(#said==before,'reopened same address does not inherit request')
state.count=1;P.request();event('Tick');check(said[#said]=='Picture one.','single page has no count')
P.request();state.id=22;event('Tick')
check(said[#said]=='picture_description_unavailable','new viewer cannot inherit old intent')
P.request();state.asset='/Game/Pictures/Missing.Missing';event('Tick')
check(said[#said]=='viewer_no_description','unknown asset is explicit')
state.asset='/Game/Pictures/One.One';state.visible=false;before=#said;P.request();event('Tick')
check(#said==before,'hidden viewer never speaks its picture')
now=1;P.poll();check(said[#said]=='picture_description_unavailable' and not P.active(),'hidden/stopped tick request expires')
state.visible=true;event('Tick');P.request();state.broken=true;event('Tick')
check(said[#said]=='picture_description_unavailable','native failure is not silent')
local errors=#logs;event('Tick');P.request();event('Tick')
check(#logs==errors,'identical native error logged once')
state.broken=false;event('Tick');P.request();event('Tick')
check(said[#said]=='Picture one.','later explicit request recovers')
P.lookup=default_lookup
state.asset='/Game/Packages/ShowPicture/Episode01/TX_E1_5B/TX_E1_5B_LivingRoom_Mail_SP01.TX_E1_5B_LivingRoom_Mail_SP01'
P.request();event('Tick')
check(said[#said]:find('Two white envelopes',1,true)==1,'live-observed ID resolves generated reviewed data with English fallback')
state.id=999;event('Destruct');check(P.active(),'unrelated view destruction leaves active viewer alone')
state.id=22;event('Destruct');check(not P.active(),'active view destruction clears state')
function_address=101;check(P.install() and counts[P.VIEW..':Tick']==2,'reloaded function gets one fresh hook')
-- Auto fallback is requested by the existing native-text observer, not by a
-- second reader that competes with it. Real texture reads stay inside Tick.
P.lookup=function(asset)if asset:find('/missing.',1,true) then return nil end;return 'Visual description.' end
state.id=44;state.index=0;state.count=2;state.text='';state.asset='/Game/Pictures/One.One'
local page={id=44,index=1,count=2,text='',reading=false,key='44:1:'}
check(P.automatic(page),'automatic intent can precede first owned Tick')
before=#said;event('Tick')
check(#said==before+1 and said[#said]=='Visual description. Page 1 of 2.','textless page described automatically')
check(not P.automatic({index=1,count=2}),'missing observed identity cannot borrow a previous view')
P.automatic(page);state.text='Native text arrived.';before=#said;event('Tick')
check(said[#said]=='Visual description. picture_has_text Page 1 of 2.','text-bearing picture describes and advertises native Read')
P.request(page);event('Tick')
check(said[#said]=='Visual description. picture_has_text Page 1 of 2.','contextual image reread preserves text availability')
state.text='';P.automatic(page);P.request(page);P.automatic(page);before=#said;event('Tick')
check(#said==before+1,'automatic intent cannot overwrite or duplicate contextual reread')
P.automatic(page);state.index=1;before=#said;event('Tick')
check(#said==before,'old automatic page request does not describe a different page')
state.index=0;P.automatic(page);event('Destruct');before=#said;now=now+1;P.poll()
check(#said==before,'closing silently cancels an automatic intent')
state.id=55;page.id=55;P.automatic(page);now=now+1;P.poll()
check(said[#said]=='picture_description_unavailable','missing hooks/ticks do not silently swallow automatic fallback')
event('Tick');P.automatic(page);state.asset='/Game/Pictures/Missing.Missing';event('Tick')
check(said[#said]=='viewer_no_description Page 1 of 2.','missing caption and text reported once with page last')
state.text='Native text.';P.request(page);event('Tick')
check(said[#said]=='picture_description_unavailable picture_has_text Page 1 of 2.','uncovered picture still advertises its text')
P.automatic(page);state.reading=true;before=#said;event('Tick')
check(#said==before,'entering Read discards stale automatic image request')
P.request(page);local reads_before=asset_reads;event('Tick')
check(said[#said]=='Native text. Page 1 of 2.' and asset_reads==reads_before,'manual request follows actual Read mode without touching texture')
state.reading=nil;P.request(page);event('Tick')
check(said[#said]=='Native text. Page 1 of 2.','unknown mode preserves accessible native text fallback')
print('Picture descriptions: '..n..' checks passed')
StaticFindObject=old_find;RegisterHook=old_hook
package.loaded['descriptions.picture']=nil
return n
