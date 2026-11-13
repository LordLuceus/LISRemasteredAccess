package.path='src/?.lua;src/?/init.lua;'..package.path
package.loaded['hud.journal_photos']=nil
local M=require('hud.journal_photos')
local definitions=require('hud.journal_photo_slots')
local count,sequence,lookups,forbidden=0,0,0,0
local function check(value,label)count=count+1;assert(value,label)end
local function banned()forbidden=forbidden+1;error('forbidden engine operation')end
local function text(s)return {ToString=function()return s end}end
local function object(kind)
    sequence=sequence+1
    local o={id=sequence,visible=true,valid=true}
    function o:IsValid()return self.valid end
    function o:IsVisible()return self.visible end
    function o:GetAddress()return self.id end
    function o:GetClass()return {GetFName=function()return text(kind)end}end
    o.Construct=banned;o.PostConstructSetup=banned;o.GetCollectibleElementTexture=banned
    o.GetCollectiblesData=banned;o.IsFactActive=banned
    return o
end
local function panel(kind)
    local o=object(kind);o.children={}
    function o:GetChildAt(i)return self.children[i+1]end
    function o:GetChildrenCount()return #self.children end
    return o
end
local function texture(path)
    if not path then return nil end
    local o=object('Texture2D');function o:GetFullName()return 'Texture2D '..path end;return o
end
local function detail(ep)
    local d=object('DiaryPhotosDetails_Widget_C');d.EpisodeName=text('Episode'..ep)
    d.LocalizedEpisodeTitle=text('Fallback '..ep)
    d.EpisodeTitle=object('TextBlock');function d.EpisodeTitle:GetText()return text('Episode title '..ep)end
    d.CanvasPanel_Content=panel('CanvasPanel')
    for i=0,9 do
        local child=object('DiaryCharacterPortrait_Widget_C')
        setmetatable(child,{__index=function(_,k)
            if k=='CharacterID' or k=='isBlocked' or k=='CharacterName' then return banned() end
        end})
        child.Image_Photo=object('Image')
        local row=definitions[(ep-1)*10+i+1]
        child.Image_Photo.Brush={resource=texture(row[i%2==0 and 'locked' or 'unlocked'])}
        d.CanvasPanel_Content.children[i+1]=child
        d[i==0 and 'DiaryCharacterPortrait_Widget' or 'DiaryCharacterPortrait_Widget_'..(i-1)]=child
    end
    return d
end
local owner=object('DiaryPhotos_Widget_C');owner.Overlay_Conent=panel('Overlay')
local d=detail(1);owner.Overlay_Conent.children={d}
local library=object('WidgetBlueprintLibrary')
function library:GetBrushResourceAsTexture2D(brush)return brush.resource end
local old_static,old_find,old_hook=StaticFindObject,FindAllOf,RegisterHook
StaticFindObject=function(path)
    check(path=='/Script/UMG.Default__WidgetBlueprintLibrary','only brush library resolved')
    return library
end
FindAllOf=banned;RegisterHook=banned
local logs=0;M.log=function()logs=logs+1 end
M.language=function()return 'en' end
M.lookup=function(asset,language)
    lookups=lookups+1;check(language=='en','language forwarded')
    return 'Caption '..asset
end
local p=M.page(owner)
check(p and p.kind=='photo_detail' and #p.items==10,'first open works without hook')
check(p.title=='Episode title 1' and p.ref==tostring(d.id)..':Episode1','heading and scalar owner identity')
for i=1,10 do
    check(p.items[i]:find(i%2==1 and '^Not collected%.' or '^Collected%.'),'mixed native states')
    check(p.items[i]:sub(-#(i..' of 10.'))==i..' of 10.','position last')
end
local function scalars(value)
    if type(value)=='table' then for k,v in pairs(value)do check(type(k)=='number' or type(k)=='string','scalar key');scalars(v)end
    else check(type(value)=='string' or type(value)=='number' or type(value)=='boolean','no retained engine values')end
end
scalars(p)
local first=d.CanvasPanel_Content.children[1]
first.Image_Photo.Brush.resource=texture(definitions[1].unlocked)
check(M.page(owner).items[1]:find('^Collected%.'),'fresh resource every snapshot')
local before=lookups
first.Image_Photo.Brush.resource=texture(definitions[2].unlocked)
p=M.page(owner)
check(p.items[1]=='Photo state unavailable. Description unavailable. 1 of 10.','wrong-slot known resource rejected')
check(lookups-before==9,'wrong slot never looked up')
first.Image_Photo.Brush.resource=nil;before=lookups
check(M.page(owner).items[1]:find('^Photo state unavailable%.'),'nil resource unknown')
check(lookups-before==9,'nil resource never looked up')
first.Image_Photo.Brush.resource=texture(definitions[11].locked)
before=lookups;M.page(owner);check(lookups-before==9,'wrong-episode known resource never looked up')
first.Image_Photo.Brush.resource=texture(definitions[1].locked)
M.lookup=function()return nil end
check(M.page(owner).items[1]=='Not collected. Description unavailable. 1 of 10.','known state missing caption')
M.lookup=function()error('caption failure')end
p=M.page(owner);check(p.items[1]=='Not collected. Description unavailable. 1 of 10.','caption exception preserves observed state')
local logged=logs;M.page(owner);check(logs==logged,'repeated slot errors logged once')
M.lookup=function()return 'Caption.'end
first.Image_Photo=nil
p=M.page(owner);check(p and p.items[1]:find('^Photo state unavailable%.') and p.items[2]:find('^Collected%.'),'individual slot failure leaves other slots readable')
first.visible=false;check(M.page(owner).items[1]:find('^Photo state unavailable%.'),'invisible child fails closed')
first.visible=true
local other=detail(2);owner.Overlay_Conent.children={other}
p=M.page(owner);check(p.title=='Episode title 2' and p.ref==tostring(other.id)..':Episode2','replacement uses current child')
owner.Overlay_Conent.children={};check(M.page(owner)==nil,'closed page absent')
owner.Overlay_Conent.children={other};check(M.page(owner).ref==p.ref,'reopen requires no cache or hook')
other.EpisodeTitle=nil;check(M.page(owner).title=='Fallback 2','localized heading fallback')
other.visible=false;check(M.page(owner)==nil,'invisible detail absent');other.visible=true
owner.visible=false;check(M.page(owner)==nil,'invisible owner absent');owner.visible=true
owner.Overlay_Conent.visible=false;check(M.page(owner)==nil,'invisible overlay absent');owner.Overlay_Conent.visible=true
owner.Overlay_Conent.children={object('WrongClass')};check(M.page(owner)==nil,'wrong detail class absent')
owner.Overlay_Conent.children={other,other};check(M.page(owner)==nil,'malformed overlay rejected')
owner.Overlay_Conent.children={other}
local canvas=other.CanvasPanel_Content;local last=table.remove(canvas.children)
check(M.page(owner)==nil,'wrong canvas count rejected');canvas.children[10]=last
canvas.children[1],canvas.children[2]=canvas.children[2],canvas.children[1]
p=M.page(owner);check(p.items[1]:find('^Photo state unavailable%.') and p.items[2]:find('^Photo state unavailable%.'),'native child ordering verified')
canvas.children[1],canvas.children[2]=canvas.children[2],canvas.children[1]
canvas.children[1]=object('WrongClass')
check(M.page(owner).items[1]:find('^Photo state unavailable%.'),'wrong child class safely unavailable')
owner.Overlay_Conent=nil;check(M.page(owner)==nil,'missing overlay absent')
check(M.page(nil)==nil,'nil owner absent')
check(M.page(object('WrongOwner'))==nil,'wrong owner class absent')
owner.Overlay_Conent=panel('WrongOverlay');check(M.page(owner)==nil,'wrong overlay class rejected')
owner.Overlay_Conent=panel('Overlay');owner.Overlay_Conent.children={detail(1)}
M.lookup=function()owner.Overlay_Conent.children={other};return 'Caption.'end
check(M.page(owner)==nil,'replacement during lookup discards stale snapshot')
check(forbidden==0,'no mutating getter, setup, facts, portrait identity or global search used')
StaticFindObject,FindAllOf,RegisterHook=old_static,old_find,old_hook
print('Journal photos adapter: '..count..' checks passed')
return count
