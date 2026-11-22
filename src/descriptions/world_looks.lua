-- Non-close-up Look actions. The game sets Triggered during Max's comment.
-- Discard the visual readout if the object or context changes while waiting.
local availability=require("scanner.availability")
local M={}
local corridor="E1_3C_Corridor_"
local function state_caption(fact,before,after)
    return function(read)
        local active=read(fact)
        if active==false then return before end
        if active==true then return after end
    end
end
-- This choice changes as the wiping animation begins. Interact01_Triggered
-- changes at the end, alongside the consequences notification.
local draw="E1_3C_MIN_KateSlate"
local kate={
    facts={corridor.."KateSlate_Look01_Triggered",corridor.."KateSlate_Look02_Triggered",draw},
    description=state_caption(draw,
        [[Someone has written "Will bang 4 Jesus" on Kate's slate.]],
        "A peace sign is drawn on Kate's slate."),
}
local objects,worlds={},{}
local function register(room,actor,entry)
    local world=room:match("^(E%d+_%d+%u)_")
    objects[room]=objects[room] or {}
    worlds[world]=worlds[world] or {}
    objects[room][actor]=entry
    table.insert(worlds[world],entry)
end

local dorm="E1_3C_Corridor_LD"
register(dorm,"LiSInteractionActor_KateSlate_3",kate)

-- The two Look branches on Max's board are gated by completion of Draw.
local max_draw=corridor.."MaxSlate_Interact01_Triggered"
register(dorm,"LiSInteractionActor_MaxSlate_13",{
    facts={corridor.."MaxSlate_Look01_Triggered",corridor.."MaxSlate_Look02_Triggered"},
    description=state_caption(max_draw,
        "The green-framed board beside room 219 is blank.",
        "Max has underlined her name above a round face with a straight mouth and two little legs."),
})

local courtyard="E1_3B_CampusB_"
local victoria_facts={}
for i=1,7 do
    victoria_facts[i]=courtyard.."CHVictoria_Look0"..i.."_Triggered"
end
register("E1_3B_CampusB_LD","LiSInteractionActor_CHVictoria_7",{
    facts=victoria_facts,
    description=state_caption(courtyard.."LD_VictoriaStained",
        "Victoria and her friends cluster by the dormitory steps. Her blonde hair is cropped short.",
        "Wet paint streaks Victoria's short blonde hair and her sweater."),
})

local rv="E1_3D_CampusPark_DirtyWindow_"
register("E1_3D_CampusPark_LD","LiSInteractionActor_DirtyWindow_0",{
    facts={rv.."Look01_Triggered",rv.."Look02_Triggered"},
    description=state_caption(rv.."Interact01_Triggered",
        "A thick brown film of dust covers the RV's side window.",
        [[The words "I'm so dirty" and a round face with a straight mouth are traced in the dust.]]),
})

local function fixed(room,actor,facts,line,aliases)
    local entry={facts=facts,description=function()return line end}
    register(room,actor,entry)
    -- Copies share their Look facts, but Home can select any instance.
    for _,alias in ipairs(aliases or {}) do
        objects[room][alias]=entry
    end
end

-- These actors already have scanner wording. Only their in-world branches
-- need a fact listener; the first classroom Look uses a camera sequence.
local room_objects=require("descriptions.episode1_rooms").objects
local classroom="E1_2A_ArtClass_LD"
for _,item in ipairs({{"MaxBag","3"},{"PencilCase","8"}}) do
    local actor="LiSInteractionActor_"..item[1].."_"..item[2]
    fixed(classroom,actor,{"E1_2A_ArtClass_"..item[1].."_Look02_Triggered"},room_objects[classroom][actor])
end
local toilets="E1_2A_Toilets_LD"
local graffiti="LiSInteractionActor_Graffiti_3"
fixed(toilets,graffiti,{"E1_2A_Toilets_Graffiti_Look01_Triggered"},room_objects[toilets][graffiti])

local photos="LiSInteractionActor_Photos_21"
local vic_room="E1_3C_VicRoom_LD"
register(vic_room,photos,{
    facts={"E1_3C_VicRoom_Photos_Look01_Triggered","E1_3C_VicRoom_Photos_Look02_Triggered"},
    description=state_caption("E1_3C_MIN_VicPhoto",room_objects[vic_room][photos].Look01,
        room_objects[vic_room][photos].Look02),
})
register("E1_5B_Garage_LD","LiSInteractionActor_ToolBox_6",{
    facts={"E1_5B_Garage_ToolBox_Look02_Triggered"},
    description=function(read)
        local fallen=read("E1_5B_Garage_Puzzle_Tools_Fallen")
        if fallen==false then return "A small green box balances high above the washing machine." end
        if fallen==true and read("E1_5B_Garage_Puzzle_PizzaBoxPullWithTools")==false then
            return "The green tool case has fallen into the gap beneath the cabinet."
        end
    end,
})
register("E1_5A_ParentsRoom_LD","LiSInteractionActor_Bird_13",{
    facts={"E1_5A_ParentsRoom_Bird_Look03_Triggered"},
    description=function(read)
        local alive=read("E1_5A_ParentsRoom_BirdLoopAlive")
        if alive==true then return "A blue jay perches on top of the wardrobe." end
        if alive==false and read("E1_5A_ParentsRoom_BirdCrashed")==true then
            return "A blue jay lies motionless at the window, its wings spread."
        end
    end,
})
register("E1_5A_Bathroom_LD","LiSInteractionActor_MakeUpStuff_33",{
    facts={"E1_5A_Bathroom_MakeUpStuff_Look02_Triggered"},
    description=state_caption("E1_5A_Bathroom_LightsON",
        "The bathroom is dark. Only the outlines of the containers by the sink are visible.",
        "Makeup and small bottles are clustered together beside the sink."),
})

for room,entries in pairs(require("descriptions.episode1_world_objects")) do
    for _,entry in ipairs(entries) do
        fixed(room,entry[1],entry[2],entry[3],entry[4])
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
                if enabled and active==true and previous[fact]==false and (fact==draw or not requested) then
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
    local function draw_pending()return pending~=nil and pending.action~=nil end
    return tick,request,draw_pending
end
return M
