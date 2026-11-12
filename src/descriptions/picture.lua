-- Automatic descriptions for textless pictures; F5 for any open picture.
-- Engine objects are accessed ONLY in the picture view's own Tick. Requests and
-- expiry contain scalars, never retained widgets/brushes/textures. Asset identity
-- is read when fulfilling the request, not cached from opening the picture.
local M={clock=os.clock,say=function(_)end,log=function(_)end,
    text=function(key,_)return key end,language=function()return 'en' end,
    clean=function(s)return s end,on_close=function(_)end,on_described=function(_,_)end}
local catalog=require('descriptions.catalog')
local data=nil
M.lookup=function(asset,language)
    if not data then data=catalog.new(require('descriptions.data')) end
    return data.lookup(asset,language)
end
M.VIEW='/Game/Packages/Widgets/BP_LiSPictureWidget_View.BP_LiSPictureWidget_View_C'
M.MAX_AGE=0.5
local active,pending=nil,nil
local generation=0
local ticks,destructs,ready,errors={},{},{},{}
local function valid(o)return o~=nil and o:IsValid() end
local function unwrap(o)local ok,v=pcall(function()return o:get()end);return ok and v or o end
local function position(text,intent)
    if intent and intent.count and intent.count>1 then
        return text..' '..M.text('viewer_page',{index=intent.index,count=intent.count})
    end
    return text
end
local function fail(detail,intent)
    if detail and not errors[tostring(detail)] then
        errors[tostring(detail)]=true;M.log('picture_description error='..tostring(detail))
    end
    M.say(position(M.text(intent and intent.automatic and 'viewer_no_description'
        or 'picture_description_unavailable'),intent))
end
local function clear()
    local old_id=active and active.id
    active=nil;generation=generation+1
    if pending then
        local intent=pending;pending=nil
        if not intent.automatic then fail() end
    end
    if old_id then M.on_close(old_id) end
end
function M.active()
    return active~=nil and M.clock()-active.at<=M.MAX_AGE
end
local function queue(page,automatic)
    local id
    if page then id=page.id elseif M.active() then id=active.id end
    if not id then
        if not automatic then M.say(M.text('picture_description_not_ready')) end
        return false
    end
    if active and active.id~=id then clear() end
    if automatic and pending and not pending.automatic then return true end
    pending={id=id,generation=generation,expires=M.clock()+M.MAX_AGE,
        automatic=automatic,index=page and page.index,count=page and page.count}
    return true
end
function M.request(page)return queue(page,false) end
function M.automatic(page)return queue(page,true) end
function M.cancel_auto()if pending and pending.automatic then pending=nil end end
-- Called from the existing game-thread loop; no object reads here.
function M.poll()
    if pending and M.clock()>pending.expires then
        pending=nil;fail() -- no stale caption or assertion about native text
    end
    if active and not M.active() then clear() end
end
local function current_asset(v)
    local image=v.Image_ShowPicture
    assert(valid(image),'picture image unavailable')
    local library=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
    assert(valid(library),'widget library unavailable')
    local texture=library:GetBrushResourceAsTexture2D(image.Brush)
    assert(valid(texture),'picture texture unavailable')
    return catalog.canonical(texture:GetFullName())
end
local function capture(v)
    if not valid(v) or not v:IsInViewport() or not v:IsVisible() then return end
    local now=M.clock()
    local id=v:GetAddress()
    if active and active.id~=id then clear() end
    active={id=id,at=now}
    if not pending then return end
    local intent=pending;pending=nil -- consume before callbacks can reenter
    if intent.id~=id or intent.generation~=generation or now>intent.expires then
        if not intent.automatic then fail() end
        return
    end
    local index,count=(v.CurrentPicture or 0)+1,v.NumPages or 1
    if intent.automatic then
        if intent.index~=index then return end -- the next observed page queues its own request
        local tb=v.TextBlock_PictureText
        assert(valid(tb),'picture text status unavailable')
        local body=M.clean(tb:GetText():ToString())
        if body and body:find('%S') then return end -- native text arrived since observation
    end
    local asset=current_asset(v)
    local description=asset and M.lookup(asset,M.language())
    intent.index=index;intent.count=count
    if not description then fail(nil,intent);return end
    M.on_described(id,index)
    M.say(position(description,intent))
end
local function on_tick(self)
    local intent=pending
    local ok,err=pcall(capture,unwrap(self))
    if not ok then
        active=nil;generation=generation+1;pending=nil
        if intent then
            -- A failed native text read is not evidence that no text exists.
            fail(err)
        elseif not errors[tostring(err)] then errors[tostring(err)]=true;M.log('picture_description error='..tostring(err)) end
    end
end
function M.install()
    if not RegisterHook then return false end
    local ok,address=pcall(function()
        local f=StaticFindObject(M.VIEW..':Tick')
        if valid(f) then return f:GetAddress() end
    end)
    if not ok or not address then return false end
    local good,err=pcall(function()
        if not ticks[address] then
            RegisterHook(M.VIEW..':Tick',function(self)if ready[address] then on_tick(self) end end)
            ticks[address]=true
        end
        if not destructs[address] then
            RegisterHook(M.VIEW..':Destruct',function(self)
                -- Object identity only, while its own Destruct is running.
                local worked,id=pcall(function()return unwrap(self):GetAddress()end)
                if not worked or (active and active.id==id) or (pending and pending.id==id) then clear() end
                if worked then M.on_close(id) end
            end)
            destructs[address]=true
        end
        ready[address]=true
    end)
    if not good and not errors[tostring(err)] then errors[tostring(err)]=true;M.log('picture_description hooks='..tostring(err)) end
    return good
end
return M
