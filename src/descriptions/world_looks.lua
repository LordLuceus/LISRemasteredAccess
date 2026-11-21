-- Non-close-up Look actions. The game sets Triggered during Max's comment.
-- Discard the visual readout if the board or context changes while waiting.
local availability=require("scanner.availability")
local M={}
local corridor="E1_3C_Corridor_"
local draw=corridor.."KateSlate_Interact01_Triggered"
local kate={
    facts={corridor.."KateSlate_Look01_Triggered",corridor.."KateSlate_Look02_Triggered",draw},
    description=function(read)
        local drawn=read("E1_3C_MIN_KateSlate")
        if drawn==true then return "A peace sign is drawn on Kate's slate." end
        if drawn==false then return 'Someone has written "Will bang 4 Jesus" on Kate\'s slate.' end
    end,
}
local brooke={
    facts={corridor.."BrookeSlate_Look01_Triggered"},
    description=function()return "Brooke's slate shows 3.14, the pi symbol, the digits reversed to spell pie, and a drawing of a slice of pie." end,
}
local objects={E1_3C_Corridor_LD={LiSInteractionActor_KateSlate_3=kate,LiSInteractionActor_BrookeSlate_1=brooke}}
local worlds={E1_3C={kate,brooke}}

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
                if enabled and active==true and previous[fact]==false and not (pending and pending.reread and pending.entry==entry) then
                    pending={entry=entry,fact=fact,line=entry.description(read)}
                    if fact==draw then pending.action=require("lang.en").scene_e1_3c_corridor_kateslate_interact01_1 end
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
    return tick,request
end
return M
