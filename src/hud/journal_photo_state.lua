-- Pure identity gate. Never query game facts or infer missing photo artwork.
local canonical=require('descriptions.catalog').canonical
local M={}
local function valid_index(index)
    return type(index)=='number' and index>=0 and index<10 and index%1==0
end
local function valid_episode(episode)
    return type(episode)=='string' and episode:match('^Episode[1-5]$')~=nil
end
function M.new(definitions)
    assert(type(definitions)=='table','photo definitions must be a table')
    local size=0
    for key in pairs(definitions) do
        assert(type(key)=='number' and key>=1 and key%1==0,'invalid definition array key')
        size=size+1
    end
    local by_episode,resources={},{}
    for i=1,size do
        local row=definitions[i]
        assert(type(row)=='table','invalid or sparse photo definition')
        assert(valid_episode(row.episode),'invalid photo episode')
        assert(valid_index(row.index),'invalid zero-based photo index')
        local entries=by_episode[row.episode] or {};by_episode[row.episode]=entries
        assert(not entries[row.index],'duplicate photo slot')
        local pair={}
        for _,state in ipairs({'locked','unlocked'}) do
            local asset=canonical(row[state])
            assert(asset,'invalid photo resource path')
            assert(not resources[asset],'duplicate or colliding photo resource')
            resources[asset]=true
            pair[state]=asset
        end
        entries[row.index]=pair -- Copy canonical strings; retain no caller tables.
    end
    local model={}
    function model.classify(episode,index,asset)
        if not valid_episode(episode) or not valid_index(index) then return 'unknown',nil end
        local entries=by_episode[episode]
        local pair=entries and entries[index]
        local id=canonical(asset)
        if pair and id then
            if id==pair.locked then return 'locked',id end
            if id==pair.unlocked then return 'unlocked',id end
        end
        return 'unknown',nil
    end
    function model.describe(episode,index,asset,language,lookup)
        local state,id=model.classify(episode,index,asset)
        local caption
        if id and type(lookup)=='function' then
            local value=lookup(id,language)
            if type(value)=='string' and value:find('%S') then caption=value end
        end
        return {state=state,asset=id,caption=caption}
    end
    return model
end
return M
