-- Non-close-up Look actions. The game sets Triggered during Max's comment.
-- Delay the visual readout and discard it if the board or context changes.
local availability=require("scanner.availability")
local M={}
local corridor="E1_3C_Corridor_"
local kate={
    facts={corridor.."KateSlate_Look01_Triggered",corridor.."KateSlate_Look02_Triggered"},
    delay=3.5,
    description=function(read)
        local drawn=read("E1_3C_MIN_KateSlate")
        if drawn==true then return "A peace sign is drawn on Kate's slate." end
        if drawn==false then return 'Someone has written "Will bang 4 Jesus" on Kate\'s slate.' end
    end,
}
local brooke={
    facts={corridor.."BrookeSlate_Look01_Triggered"},
    delay=5,
    description=function()return "Brooke's slate shows 3.14, the pi symbol, the digits reversed to spell pie, and a drawing of a slice of pie." end,
}
local objects={E1_3C_Corridor_LD={LiSInteractionActor_KateSlate_3=kate,LiSInteractionActor_BrookeSlate_1=brooke}}
local worlds={E1_3C={kate,brooke}}

function M.describe(entry,controller)
    local room=objects[entry.sublevel]
    local object=room and room[entry.id:match("PersistentLevel%.([^%.]+)$")]
    if object then return object.description(availability.fact_reader(controller)) end
end

function M.new(clock)
    clock=clock or os.clock
    local previous,identity,pending={},nil,nil
    return function(controller,enabled,say)
        local world=controller and controller:GetWorld()
        local entries=world and worlds[world:GetFName():ToString()]
        if not entries then previous,identity,pending={},nil,nil;return end
        local current=tostring(world:GetAddress())..":"..tostring(controller:GetAddress())
        if identity~=current then previous,identity,pending={},current,nil end
        if not enabled then pending=nil end
        local read=availability.fact_reader(controller)
        for _,entry in ipairs(entries) do
            for _,fact in ipairs(entry.facts) do
                local active=read(fact)
                if enabled and active==true and previous[fact]==false then
                    pending={entry=entry,fact=fact,line=entry.description(read),due=clock()+entry.delay}
                end
                previous[fact]=active
            end
        end
        if pending then
            if not previous[pending.fact] or pending.line~=pending.entry.description(read) then
                pending=nil
            elseif clock()>=pending.due then
                if pending.line then say(pending.line,false) end
                pending=nil
            end
        end
    end
end
return M
