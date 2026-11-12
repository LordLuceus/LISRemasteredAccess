-- Authored visual descriptions. No engine access; persistent keys are full
-- texture object paths, never widget addresses, display labels or basenames.
local M={}
function M.canonical(value)
    if type(value)~="string" then return nil end
    local s=value:match("^%s*(.-)%s*$"):gsub("^Texture2D%s+", "")
    if #s>2048 or s:find("//",1,true) then return nil end
    local package,object=s:match("^(/[%w_/-]+)%.([%w_-]+)$")
    if not package or package:sub(1,6):lower()~="/game/" or package:sub(-1)=="/" then return nil end
    return (package.."."..object):lower()
end
local function locale(s)
    if type(s)~="string" then return nil end
    s=s:lower():gsub('_','-')
    if s:match('^[a-z][a-z][a-z]?$') or s:match('^[a-z][a-z][a-z]?%-[a-z]+$') then return s end
end
function M.new(records)
    assert(type(records)=="table","description records must be a table")
    local by_asset={}
    for i,r in ipairs(records) do
        assert(type(r)=="table","invalid description record "..i)
        local id=M.canonical(r.asset)
        assert(id,"invalid full description asset path at "..i)
        local language=locale(r.language)
        assert(language,"invalid description language at "..i)
        assert(r.status=="draft" or r.status=="reviewed","invalid description review status at "..i)
        assert(type(r.text)=="string" and r.text:find("%S"),"empty description at "..i)
        assert(type(r.image_sha256)=="string" and #r.image_sha256==64 and r.image_sha256:match("^[0-9a-f]+$"),
            "missing source image hash at "..i)
        local languages=by_asset[id] or {};by_asset[id]=languages
        assert(not languages[language],"duplicate description: "..id.." ("..language..")")
        -- Copy values: callers cannot alter published text by mutating input tables.
        languages[language]={text=r.text,status=r.status,image_sha256=r.image_sha256}
    end
    local catalog={}
    function catalog.lookup(asset,language)
        local id=M.canonical(asset);local languages=id and by_asset[id]
        if not languages then return nil,"missing" end
        language=locale(language) or "en"
        local entry=languages[language]
        if not entry or entry.status~="reviewed" then entry=languages.en end
        if not entry or entry.status~="reviewed" then return nil,"unreviewed" end
        return entry.text
    end
    return catalog
end
return M
