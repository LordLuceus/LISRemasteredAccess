-- Object viewer (BP_LiSPictureWidget_View): the close-up shown by Look on
-- letters, posters and photos. Captured in Chloe's house (the mail):
-- TextBlock_PictureText holds the page's text version even while the game's
-- Read panel is closed, Button_Read is shown only when a text version exists,
-- and CurrentPicture/NumPages give the page. Objects without a text version
-- (the classroom photo) leave the text empty: that is said plainly, since an
-- authored description does not exist yet.
-- The text is read as soon as a page is shown, so the Read button is not needed.
local M={}
M.text=function(key,p)return key end
M.clean=function(s)return s end
-- Spoken form of one page. Pure. Page position goes last, and only when there
-- is more than one page.
function M.describe(text,index,count)
    local body=text and M.clean(text) or nil
    if body and not body:find("%S") then body=nil end
    local s=body or M.text("viewer_no_text")
    if count and count>1 then s=s.." "..M.text("viewer_page",{index=index,count=count}) end
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
    local text,index,count,id=nil,1,1,""
    pcall(function()
        local tb=found.TextBlock_PictureText
        if tb and tb:IsValid() then text=tb:GetText():ToString() end
    end)
    pcall(function()index=(found.CurrentPicture or 0)+1 end)
    pcall(function()count=found.NumPages or 1 end)
    pcall(function()id=string.format("%x",found:GetAddress())end)
    return {text=text,index=index,count=count,key=id..":"..index..":"..tostring(text)}
end
return M
