-- Explicit episode registration only: actor identities determine allowed worlds.
local M={}
function M.new(episodes,startup)
    local result={ids={},levels={},actors={},actions={},startup=startup}
    local function register(actor)
        assert(not result.actors[actor],'duplicate authored actor '..actor)
        local level=assert(actor:match('^(E%d+_%d+%u)_'),'invalid authored actor '..actor)
        result.actors[actor]=level
        result.levels[level]=true
    end
    for _,episode in ipairs(episodes)do
        for _,group in pairs(episode.groups or {})do
            for id,stage in pairs(group.stages)do
                register(stage.actor)
                result.ids[stage.actor]={id=id,data=group}
            end
        end
        for actor,definition in pairs(episode.timelines or {})do
            register(actor)
            local stage={length=definition.length,protect={},cues={},loop=definition.loop,
                after_first_loop=definition.after_first_loop}
            local last=0
            for _,window in ipairs(definition.windows)do
                local start,finish,key=table.unpack(window)
                assert(last<=start and start<finish and finish<=stage.length,actor)
                if last<start then table.insert(stage.protect,{last,start})end
                table.insert(stage.cues,{start=start,finish=math.min(start+.8,finish),key=key})
                last=finish
            end
            table.insert(stage.protect,{last,stage.length+.25})
            result.ids[actor]={id='intro',data={order={'intro'},stages={intro=stage}}}
        end
        for actor,text in pairs(episode.actions or {})do
            register(actor)
            result.actions[actor]=text
        end
    end
    return result
end
local episode1=require('cutscenes.episode1')
local episode2=require('cutscenes.episode2')
M.default=M.new({episode1,episode2},episode1.groups.classroom)
return M
