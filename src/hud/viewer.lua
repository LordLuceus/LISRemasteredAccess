-- Object viewer (BP_LiSPictureWidget_View): the close-up shown by Look on
-- letters, posters and photos. Captured in Chloe's house (the mail):
-- TextBlock_PictureText holds the page's text version even while the game's
-- Read panel is closed, Button_Read is shown only when a text version exists,
-- and CurrentPicture/NumPages give the page. Objects without a text version
-- (the classroom photo) leave the text empty. The description coordinator adds
-- authored image descriptions for those pages; native text stays unchanged.
-- Native Read mode is CanvasPanel_Read visibility: ShowPicture hides it (2),
-- Read shows it (4), and Back hides it again. Text presence is NOT the mode.
local M={}
M.text=function(key,p)return key end
M.clean=function(s)return s end
M.log=function(_)end
local reported_mode_error=false
function M.reading(view)
    local ok,on=pcall(function()
        local panel=view.CanvasPanel_Read
        if panel and panel:IsValid() then return panel:IsVisible() end
    end)
    if ok and type(on)=='boolean' then return on end
    if not reported_mode_error then
        reported_mode_error=true;M.log('viewer_mode_unavailable: preserving native text fallback')
    end
    return nil
end
-- Spoken form of one page. Pure. Page position goes last, and only when there
-- is more than one page.
function M.body(text)
    local body=text and M.clean(text) or nil
    if body and not body:find("%S") then body=nil end
    return body
end
function M.describe(text,index,count)
    local s=M.body(text) or M.text("viewer_no_text")
    if count and count>1 then s=s.." "..M.text("viewer_page",{index=index,count=count}) end
    return s
end
function M.picture_fallback(text,index,count)
    local has_text=M.body(text)~=nil
    local s=M.text(has_text and 'picture_description_unavailable' or 'viewer_no_description')
    if has_text then s=s..' '..M.text('picture_has_text') end
    if count and count>1 then s=s..' '..M.text('viewer_page',{index=index,count=count}) end
    return s
end
local function on_screen(w)
    local ok,on=pcall(function()return w:IsValid() and w:IsInViewport() and w:IsVisible()end)
    return ok and on==true
end
-- Current page: text, 1-based index, count, and an identity for change checks.
function M.current()
    local found=nil
    pcall(function()
        for _,w in ipairs(FindAllOf("BP_LiSPictureWidget_View_C") or {}) do
            if on_screen(w) then found=w;break end
        end
    end)
    if not found then return nil end
    local text,index,count,id=nil,1,1,nil
    pcall(function()
        local tb=found.TextBlock_PictureText
        if tb and tb:IsValid() then text=tb:GetText():ToString() end
    end)
    pcall(function()index=(found.CurrentPicture or 0)+1 end)
    pcall(function()count=found.NumPages or 1 end)
    pcall(function()id=found:GetAddress()end)
    local reading=M.reading(found)
    return {text=text,index=index,count=count,id=id,reading=reading,
        key=(id and string.format("%x",id) or "")..":"..index..":"..tostring(reading)..":"..tostring(text)}
end
return M
