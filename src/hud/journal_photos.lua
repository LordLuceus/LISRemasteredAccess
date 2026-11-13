-- Immediate game-thread scalar snapshot. Never retain engine objects between calls.
local catalog=require('descriptions.catalog')
local model=require('hud.journal_photo_state').new(require('hud.journal_photo_slots'))
local order=require('hud.journal_photo_order')
local defaults={journal_photo_locked='Not collected.',journal_photo_unlocked='Collected.',
    journal_photo_unknown='Photo state unavailable.',journal_photo_no_description='Description unavailable.',
    journal_photo_position='{index} of {count}.'}
local M={language=function()return 'en' end,log=function(_)end}
M.text=function(key,params)
    local text=defaults[key] or key
    return (text:gsub('{(%w+)}',function(k)return tostring(params and params[k] or '{'..k..'}')end))
end
local captions
M.lookup=function(asset,language)
    if not captions then captions=catalog.new(require('descriptions.journal_photos_data')) end
    return captions.lookup(asset,language)
end
local errors={}
local function report(stage,err)
    if not errors[stage] then
        errors[stage]=true
        pcall(M.log,'journal_photos '..stage..' error='..tostring(err))
    end
end
local function valid(o)return o~=nil and o:IsValid() end
local function visible(o)return valid(o) and o:IsVisible()==true end
local function address(o)
    assert(valid(o),'invalid object')
    local id=o:GetAddress()
    assert(type(id)=='number' or type(id)=='string','invalid address')
    return tostring(id)
end
local function class(o,name)
    return valid(o) and o:GetClass():GetFName():ToString()==name
end
local function same(a,b)return valid(a) and valid(b) and address(a)==address(b) end
local function heading(detail)
    local ok,value=pcall(function()return detail.EpisodeTitle:GetText():ToString()end)
    if ok and type(value)=='string' and value:find('%S') then return value end
    if not ok then report('heading',value) end
    local fallback=detail.LocalizedEpisodeTitle:ToString()
    assert(type(fallback)=='string','invalid episode heading')
    return fallback
end
local function spoken(state,caption,position)
    return M.text('journal_photo_'..state)..' '..(caption or M.text('journal_photo_no_description'))
        ..' '..M.text('journal_photo_position',{index=position,count=10})
end
local function snapshot(photos)
    if not visible(photos) or not class(photos,'DiaryPhotos_Widget_C') then return nil end
    local overlay=photos.Overlay_Conent
    if not visible(overlay) then return nil end
    assert(class(overlay,'Overlay'),'invalid photo overlay class')
    local count=overlay:GetChildrenCount()
    if count==0 then return nil end
    assert(count==1,'unexpected photo overlay layout')
    local detail=overlay:GetChildAt(0)
    if not visible(detail) or not class(detail,'DiaryPhotosDetails_Widget_C') then return nil end
    local episode=detail.EpisodeName:ToString()
    assert(type(episode)=='string' and episode:match('^Episode[1-5]$'),'unknown episode identity')
    local canvas=detail.CanvasPanel_Content
    assert(visible(canvas) and class(canvas,'CanvasPanel') and canvas:GetChildrenCount()==10,
        'invalid photo canvas layout')
    local title=heading(detail)
    local id=address(detail)
    local items,seen={},{}
    local library=StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
    for position=1,10 do
        -- Browse by episode progression, but read and validate the ORIGINAL
        -- native child identity. Reordering metadata would mix up photo states.
        local index=assert(order.native_index(episode,position),'missing photo order')
        local state,caption='unknown',nil
        local ok,err=pcall(function()
            local child=canvas:GetChildAt(index)
            assert(visible(child) and class(child,'DiaryCharacterPortrait_Widget_C'),'invalid photo child')
            local field=index==0 and 'DiaryCharacterPortrait_Widget' or 'DiaryCharacterPortrait_Widget_'..(index-1)
            assert(same(child,detail[field]),'photo child order mismatch')
            local child_id=address(child)
            assert(not seen[child_id],'duplicate photo child');seen[child_id]=true
            local image=child.Image_Photo
            assert(visible(image),'photo image unavailable')
            assert(valid(library),'widget library unavailable')
            local texture=library:GetBrushResourceAsTexture2D(image.Brush)
            local asset=valid(texture) and texture:GetFullName() or nil
            state=model.classify(episode,index,asset)
            -- Preserve known state if only caption lookup fails.
            local result=model.describe(episode,index,asset,M.language(),M.lookup)
            caption=result.caption
        end)
        if not ok then report('slot_'..index,err) end
        items[position]=spoken(state,caption,position)
    end
    -- Reject a page replaced during a reentrant callback rather than return stale data.
    if not visible(photos) or not same(photos.Overlay_Conent,overlay) or not visible(overlay)
        or overlay:GetChildrenCount()~=1 or not same(overlay:GetChildAt(0),detail)
        or not visible(detail) or detail.EpisodeName:ToString()~=episode then return nil end
    return {kind='photo_detail',title=title,ref=id..':'..episode,items=items}
end
function M.page(photos)
    local ok,result=pcall(snapshot,photos)
    if ok then return result end
    report('page',result)
    return nil
end
return M
