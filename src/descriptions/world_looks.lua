-- Non-close-up Look actions. The game sets Triggered during Max's comment.
-- Discard the visual readout if the object or context changes while waiting.
local availability=require("scanner.availability")
local M={}
local objects,worlds={},{}
local function register(room,actor,entry)
    local world=room:match("^(E%d+_%d+%u)_")
    objects[room]=objects[room] or {}
    worlds[world]=worlds[world] or {}
    objects[room][actor]=entry
    table.insert(worlds[world],entry)
end

local function fixed(room,actor,facts,line,aliases)
    local entry={facts=facts,description=function()return line end}
    register(room,actor,entry)
    -- Copies share their Look facts, but Home can select any instance.
    for _,alias in ipairs(aliases or {}) do
        objects[room][alias]=entry
    end
end

-- Catalogue order and each catalogue's registration order are significant.
for _,catalogue in ipairs(require("descriptions.world_catalogues")) do
    catalogue.register(register,fixed)
    for room,entries in pairs(catalogue.fixed) do
        for _,entry in ipairs(entries) do
            fixed(room,entry[1],entry[2],entry[3],entry[4])
        end
    end
end

local function object_for(entry)
    local room=objects[entry.sublevel]
    return room and room[entry.id:match("PersistentLevel%.([^%.]+)$")]
end

function M.describe(entry,controller)
    local object=object_for(entry)
    if object then return object.description(availability.fact_reader(controller)) end
end

local function identity_of(world,controller)
    return tostring(world:GetAddress())..":"..tostring(controller:GetAddress())
end

function M.new(is_quiet)
    is_quiet=is_quiet or require("dialogue.playback").quiet
    local previous,identity,pending={},nil,nil
    local function request(entry,controller,reread)
        local object=object_for(entry)
        if not object then return false end
        local current=identity_of(controller:GetWorld(),controller)
        if current~=identity then previous,identity={},current end
        pending={entry=object,line=object.description(availability.fact_reader(controller)),
            id=entry.id,reread=reread}
        return true
    end
    local function tick(controller,enabled,say,other_narration)
        local world=controller and controller:GetWorld()
        local entries=world and worlds[world:GetFName():ToString()]
        if not entries then previous,identity,pending={},nil,nil;return end
        local current=identity_of(world,controller)
        if identity~=current then previous,identity,pending={},current,nil end
        if not enabled then pending=nil end
        local read=availability.fact_reader(controller)
        for _,entry in ipairs(entries) do
            for _,fact in ipairs(entry.facts) do
                local active=read(fact)
                local requested=pending and pending.reread and pending.entry==entry
                local action=entry.actions and entry.actions[fact]
                if enabled and active==true and previous[fact]==false and ((action and action.supersedes_reread) or not requested) then
                    pending={entry=entry,fact=fact,line=entry.description(read)}
                    if action then pending.action=require("lang.en")[action.key] end
                end
                previous[fact]=active
            end
        end
        if pending then
            if (pending.fact and not previous[pending.fact]) or pending.line~=pending.entry.description(read) then
                pending=nil
            elseif not other_narration and is_quiet(controller)==true then
                local ready=pending
                pending=nil
                local function repeat_when_quiet()
                    if identity==current then pending=ready end
                end
                if ready.reread then ready.reread(ready.id,repeat_when_quiet)
                elseif ready.line then say(ready.action or ready.line,false,repeat_when_quiet) end
            end
        end
    end
    local function action_pending()return pending~=nil and pending.action~=nil end
    return tick,request,action_pending
end
return M
