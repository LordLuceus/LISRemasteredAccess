package.path='src/?.lua;src/?/init.lua;'..package.path
local C=require('descriptions.catalog')
local count=0
local function check(value,label)count=count+1;assert(value,label)end
local path='/Game/Packages/ShowPicture/Episode01/TX_Test.TX_Test'
check(C.canonical('Texture2D '..path)==path:lower(),'full UE object name')
check(C.canonical(path:upper())==path:lower(),'FName case normalization')
for _,bad in ipairs({'TX_Test','Slate, A','/Game/Texture','/Engine/White.White',
    '/Game/../Texture.Texture','/Game//Texture.Texture','/Game/X.X:Child','C:/private/photo.png','/Game/X.X.extra'}) do
    check(C.canonical(bad)==nil,'reject ambiguous identity '..bad)
end
check(C.canonical(nil)==nil,'nil identity')
local hash=string.rep('a',64)
local a={asset=path,language='en',text='A reviewed picture.',status='reviewed',image_sha256=hash}
local b={asset=path,language='fr',text='Draft translation.',status='draft',image_sha256=hash}
local c=C.new({a,b});a.text='Changed after construction.'
check(c.lookup(path,'en')=='A reviewed picture.','catalog owns its text')
check(c.lookup(path,'fr')=='A reviewed picture.','unreviewed translation falls back')
check(c.lookup(path,'de')=='A reviewed picture.','missing locale falls back')
check(c.lookup('/Game/Elsewhere/TX_Test.TX_Test','en')==nil,'same basename is not same image')
local draft=C.new({b});check(draft.lookup(path,'fr')==nil,'drafts never speak')
check(not pcall(C.new,{b,b}),'duplicate key rejected')
check(not pcall(C.new,{{asset=path,language='en',text='',status='reviewed',image_sha256=hash}}),'empty text rejected')
check(not pcall(C.new,{{asset=path,language='en',text='Unproven.',status='reviewed'}}),'image provenance required')
local other='/Game/Shared/Collection.DifferentExport'
check(C.canonical(other)==other:lower(),'object export need not equal package basename')
local portuguese={asset=path,language='pt_BR',text='Portuguese caption.',status='reviewed',image_sha256=hash}
local translated=C.new({portuguese})
check(translated.lookup(path,'pt-br')=='Portuguese caption.','locale separators and case normalized')
local alias={asset=path,language='pt-br',text='Duplicate.',status='reviewed',image_sha256=hash}
check(not pcall(C.new,{portuguese,alias}),'locale aliases cannot duplicate a record')
check(translated.lookup(path,'pt-')==nil,'invalid incomplete locale does not match translation')
print('Description catalogue: '..count..' checks passed')
return count
