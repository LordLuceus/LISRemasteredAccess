-- Picture mode describes the image; the game's Read mode reads its native text.
-- All input is a scalar snapshot. No engine objects or new native Read path.
local M={}
function M.new(viewer,picture,say,log)
    local last_key,last_id=nil,nil
    local described=nil
    local reader={}
    function reader.closed(id)
        if id==last_id then last_key=nil;last_id=nil end
        if described and described.id==id then described=nil end
    end
    function reader.described(id,index,reading,has_text)
        described={id=id,index=index,reading=reading,has_text=has_text}
    end
    local function native_text(page)
        picture.cancel()
        local text=viewer.describe(page.text,page.index,page.count)
        say(text,true)
        log('viewer page='..page.index..'/'..page.count..' spoken='..text)
    end
    local function is_text_view(page)
        -- Preserve the previously working text path if native mode cannot be
        -- established. Don't strand readable text behind an uncertain new gate.
        return page.reading==true or (page.reading==nil and viewer.body(page.text)~=nil)
    end
    function reader.step(page)
        if not page then last_key=nil;last_id=nil;described=nil;picture.cancel_auto();return end
        if page.key==last_key then return end
        last_key=page.key;last_id=page.id
        local already_described=described and described.id==page.id and described.index==page.index
            and described.reading==page.reading
        local previous=described
        described=nil
        if is_text_view(page) then
            if not already_described then native_text(page) end
        elseif already_described then
            -- Native text can finish loading after the picture. Announce its
            -- availability, not the transcription while still in picture mode.
            if viewer.body(page.text) and not previous.has_text then
                say(viewer.text('picture_has_text'),false)
            end
        elseif not already_described and not picture.automatic(page) then
            -- An unidentified picture still advertises its native Read text,
            -- without reading that text prematurely in known picture mode.
            say(viewer.picture_fallback(page.text,page.index,page.count),true)
        end
    end
    function reader.reread(page)
        if not page then return false end
        last_key=page.key;last_id=page.id
        if is_text_view(page) then native_text(page) else picture.request(page) end
        return true
    end
    return reader
end
return M
