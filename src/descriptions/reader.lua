-- Coordinates the existing native-text reader with additional descriptions.
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
    function reader.described(id,index)described={id=id,index=index} end
    function reader.step(page)
        if not page then last_key=nil;last_id=nil;described=nil;picture.cancel_auto();return end
        if page.key==last_key then return end
        last_key=page.key;last_id=page.id
        local already_described=described and described.id==page.id and described.index==page.index
        described=nil
        if viewer.body(page.text) then
            picture.cancel_auto()
            local text=viewer.describe(page.text,page.index,page.count)
            -- If native text arrives after F5, keep it but don't cut off the
            -- user's requested description with that late automatic readout.
            say(text,not already_described)
            log('viewer page='..page.index..'/'..page.count..' spoken='..text)
        elseif not already_described and not picture.automatic(page) then
            -- Preserve a useful readout if the view's identity is unavailable.
            say(viewer.describe(page.text,page.index,page.count),true)
        end
    end
    return reader
end
return M
