local looks=require("descriptions.world_looks")
local catalogue_checks=0
local old_fname=FName
FName=function(name)return name end
local ok,err=pcall(function()
    local states={}
    local world={GetFName=function()return {ToString=function()return "E1_3C" end} end,
        GetAddress=function()return 1 end}
    local controller={GetWorld=function()return world end,GetAddress=function()return 2 end,
        IsFactActive=function(_,key)return states[key] end}
    local entry={sublevel="E1_3C_Corridor_LD",id="PersistentLevel.LiSInteractionActor_KateSlate_3"}
    local prefix="E1_3C_Corridor_KateSlate_"
    local look,draw=prefix.."Look01_Triggered","E1_3C_MIN_KateSlate"
    assert(looks.describe(entry,controller)==nil)
    states[draw]=false
    assert(looks.describe(entry,controller):find("Will bang 4 Jesus",1,true))
    local quiet=false
    local poll,request,draw_pending=looks.new(function()return quiet end)
    local heard={}
    local function tick(enabled)
        poll(controller,enabled,function(line,interrupt)
            assert(interrupt==false)
            heard[#heard+1]=line
        end)
    end
    states[look]=true;tick(true)
    assert(#heard==0,"loading a completed Look must stay quiet")
    states[look]=false;tick(true)
    states[look]=true;tick(true)
    assert(#heard==0,"leave time for Max's line")
    for _=1,100 do tick(true) end
    assert(#heard==0,"dialogue can outlast the original timer")
    quiet=nil;tick(true)
    assert(#heard==0,"an unavailable voice read must not count as silence")
    quiet=true;tick(true);tick(true)
    assert(#heard==1 and heard[1]==looks.describe(entry,controller))
    states[draw]=true
    assert(looks.describe(entry,controller):find("peace sign",1,true))
    states[look]=false;tick(true)
    local action_line=require("lang.en").scene_e1_3c_corridor_kateslate_interact01_1
    assert(heard[2]==action_line,"in silence Draw speaks at the start of the animation")
    states[look]=true;tick(false);tick(true)
    tick(true)
    assert(#heard==2,"a suppressed completion must not replay")
    local second=prefix.."Look02_Triggered"
    states[second]=false;tick(true)
    quiet=false;states[second]=true;tick(true)
    states[draw]=false
    quiet=true;tick(true)
    assert(#heard==2,"discard the pending description when the board changes")
    assert(looks.describe(entry,controller)==heard[1],"rewind restores the original wording")
    local rereads=0
    local repeat_request
    local function reread(id,again)assert(id==entry.id);rereads=rereads+1;repeat_request=again end
    quiet=false
    assert(request(entry,controller,reread))
    tick(true);tick(true)
    assert(rereads==0,"manual description waits through dialogue too")
    quiet=true;tick(true);tick(true)
    assert(rereads==1,"manual description released once")
    quiet=false;repeat_request();tick(true)
    assert(rereads==1,"repeat waits for a new speaker")
    quiet=true;tick(true)
    assert(rereads==2,"repeat resumes after dialogue")
    quiet=false;request(entry,controller,reread);tick(false)
    quiet=true;tick(true)
    assert(rereads==2,"leaving the context discards a deferred manual request")
    local draw_action=prefix.."Interact01_Triggered"
    states[draw_action]=false;quiet=false
    request(entry,controller,reread)
    states[draw]=true;tick(true)
    assert(#heard==2 and draw_pending(),"Draw supersedes the stale board read and waits for dialogue")
    quiet=true;tick(true)
    assert(heard[3]==action_line and not draw_pending())
    states[draw_action]=true;tick(true)
    assert(#heard==3,"the completion flag does not narrate Draw again")
    entry.sublevel="E2_3C_Corridor_LD"
    assert(looks.describe(entry,controller)==nil)
    entry.sublevel="E1_3C_Corridor_LD"
    for _,board in ipairs({
        {"DanaSlate_23","Stomp 'em Bigfoots!"},{"JulietSlate_22","Blackwell Totem"},
        {"StellaSlate_20","REDRUM"},{"TaylorSlate_19","Taylor is a slave"},
        {"VictoriaSlate_1","Gandhi"},
    }) do
        entry.id="PersistentLevel.LiSInteractionActor_"..board[1]
        local manual=assert(looks.describe(entry,controller))
        assert(manual:find(board[2],1,true))
        local fact="E1_3C_Corridor_"..board[1]:match("^(%a+)_").."_Look01_Triggered"
        states[fact]=false;tick(true)
        states[fact]=true;tick(true)
        assert(heard[#heard]==manual)
    end
    entry.id="PersistentLevel.LiSInteractionActor_MaxSlate_13"
    local written="E1_3C_Corridor_MaxSlate_Interact01_Triggered"
    assert(looks.describe(entry,controller)==nil)
    states[written]=true
    assert(looks.describe(entry,controller):find("straight mouth",1,true))
    states[written]=false
    assert(looks.describe(entry,controller):find("blank",1,true))

    states.E1_5B_Garage_Puzzle_PizzaBoxPullWithTools=false
    for _,variant in ipairs({
        {"E1_3D_CampusPark_LD","DirtyWindow_0","E1_3D_CampusPark_DirtyWindow_Interact01_Triggered","film of dust","I'm so dirty"},
        {"E1_3B_CampusB_LD","CHVictoria_7","E1_3B_CampusB_LD_VictoriaStained","cropped short","Wet paint"},
        {"E1_3C_VicRoom_LD","Photos_21","E1_3C_MIN_VicPhoto","neat grid","middle finger"},
        {"E1_5B_Garage_LD","ToolBox_6","E1_5B_Garage_Puzzle_Tools_Fallen","balances high","beneath the cabinet"},
        {"E1_5A_Bathroom_LD","MakeUpStuff_33","E1_5A_Bathroom_LightsON","bathroom is dark","beside the sink"},
    }) do
        local selected={sublevel=variant[1],id="PersistentLevel.LiSInteractionActor_"..variant[2]}
        assert(looks.describe(selected,controller)==nil)
        states[variant[3]]=true
        assert(looks.describe(selected,controller):find(variant[5],1,true))
        states[variant[3]]=false
        assert(looks.describe(selected,controller):find(variant[4],1,true))
        catalogue_checks=catalogue_checks+3
    end
    local bird={sublevel="E1_5A_ParentsRoom_LD",id="PersistentLevel.LiSInteractionActor_Bird_13"}
    states.E1_5A_ParentsRoom_BirdCrashed=true
    assert(looks.describe(bird,controller)==nil)
    states.E1_5A_ParentsRoom_BirdLoopAlive=false
    assert(looks.describe(bird,controller):find("motionless",1,true))
    states.E1_5A_ParentsRoom_BirdLoopAlive=true
    assert(looks.describe(bird,controller):find("wardrobe",1,true))
    catalogue_checks=catalogue_checks+3

    -- Native Drawer01 Look01 is ONLY_EVENT with LightsON=false, not the
    -- separate lit-room Search cinematic. Captured frames leave it closed.
    local drawer={sublevel="E1_5A_Bathroom_LD",id="PersistentLevel.LiSInteractionActor_Drawer01_29"}
    local drawer_line="Below the sink, a pale round knob stands out against the dark drawer front."
    world.GetFName=function()return {ToString=function()return "E1_5A" end} end
    states.E1_5A_Bathroom_LightsON=false
    states.E1_5A_Bathroom_Drawer01_Look01_Triggered=false
    assert(looks.describe(drawer,controller)==drawer_line,"Home must not reveal closed drawer contents")
    local drawer_lines={}
    local drawer_poll=looks.new(function()return true end)
    local function sample_drawer()
        drawer_poll(controller,true,function(line)drawer_lines[#drawer_lines+1]=line end)
    end
    sample_drawer();assert(#drawer_lines==0)
    states.E1_5A_Bathroom_Drawer01_Look01_Triggered=true;sample_drawer()
    assert(#drawer_lines==1 and drawer_lines[1]==drawer_line,"dark Look describes the drawer exterior")
    catalogue_checks=catalogue_checks+3

    -- The camera owns the first Look at the pencil case. Only the later,
    -- in-world branch should also produce an automatic scanner description.
    world.GetFName=function()return {ToString=function()return "E1_2A" end} end
    local case_prefix="E1_2A_ArtClass_PencilCase_"
    local case_lines={}
    local case_poll=looks.new(function()return true end)
    local function sample_case()
        case_poll(controller,true,function(line)case_lines[#case_lines+1]=line end)
    end
    states[case_prefix.."Look01_Triggered"]=false
    states[case_prefix.."Look02_Triggered"]=false
    sample_case()
    states[case_prefix.."Look01_Triggered"]=true;sample_case()
    assert(#case_lines==0)
    states[case_prefix.."Look02_Triggered"]=true;sample_case()
    assert(#case_lines==1 and case_lines[1]:find("skull patch",1,true))
    catalogue_checks=catalogue_checks+2

    -- Both dorm slates use today's drawing fact. Max's insult also depends
    -- on yesterday's photograph choice, including when Home is used first.
    local dorm="E2_1A_Corridor_"
    local slates={
        {"KateSlate_4", dorm.."KateSlate_", "Will bang for God", "wiped"},
        {"MaxSlate_2", dorm.."MaxSlate_", "Max Selfie", "Surveillance cam ON"},
    }
    for _,slate in ipairs(slates) do
        local selected={sublevel=dorm.."LD",id="PersistentLevel.LiSInteractionActor_"..slate[1]}
        local changed=slate[2].."Interact01_Triggered"
        states[changed]=nil
        assert(looks.describe(selected,controller)==nil)
        states[changed]=false
        if slate[1]=="KateSlate_4" then
            states.E1_3C_MIN_KateSlate=nil
            assert(looks.describe(selected,controller)==nil)
            states.E1_3C_MIN_KateSlate=false
            assert(looks.describe(selected,controller):find("Will bang 4 Jesus",1,true))
            states.E1_3C_MIN_KateSlate=true
            catalogue_checks=catalogue_checks+2
        else
            states.E1_3C_MIN_VicPhoto=false
            assert(looks.describe(selected,controller)==nil)
            states.E1_3C_MIN_VicPhoto=true
        end
        local initial=looks.describe(selected,controller)
        assert(initial:find(slate[3],1,true))
        states[changed]=true
        assert(looks.describe(selected,controller):find(slate[4],1,true))
        states[changed]=false
        assert(looks.describe(selected,controller)==initial)
        catalogue_checks=catalogue_checks+4
    end
    catalogue_checks=catalogue_checks+1

    -- A rewind while Max is speaking must cancel the erased-slate caption.
    world.GetFName=function()return {ToString=function()return "E2_1A" end} end
    local kate=dorm.."KateSlate_"
    local quiet=false
    local tick=looks.new(function()return quiet end)
    local spoken={}
    local function sample_slate()
        tick(controller,true,function(line)spoken[#spoken+1]=line end)
    end
    states.E1_3C_MIN_KateSlate=true
    states[kate.."Interact01_Triggered"]=true
    states[kate.."Look01_Triggered"]=false
    states[kate.."Look02_Triggered"]=false
    sample_slate()
    states[kate.."Look02_Triggered"]=true
    sample_slate()
    assert(#spoken==0)
    states[kate.."Interact01_Triggered"]=false
    states[kate.."Look02_Triggered"]=false
    quiet=true
    sample_slate()
    assert(#spoken==0)
    states[kate.."Look01_Triggered"]=true
    sample_slate()
    assert(#spoken==1 and spoken[1]:find("Will bang for God",1,true))
    catalogue_checks=catalogue_checks+3

    local changing_objects={
        {"E2_3A_Junkyard_LD","Graffiti07_27","E2_3A_Junkyard_Graffiti07_Interact01_Triggered","Two lines","Max was here"},
        {"E2_3A_Junkyard_LD","CHChloe_0","E2_3A_Junkyard_LD_AfterEllipse","beanie","couch"},
        {"E2_2A_DinerPark_LD","FrankRVWindow_17","E1_3D_MIN_DirtyRV","film of dust","I'm so dirty"},
    }
    for _,object in ipairs(changing_objects) do
        local room,actor,state=table.unpack(object)
        local selected={sublevel=room,id="PersistentLevel.LiSInteractionActor_"..actor}
        states[state]=nil
        assert(looks.describe(selected,controller)==nil)
        states[state]=false
        local before=looks.describe(selected,controller)
        assert(before:find(object[4],1,true))
        states[state]=true
        assert(looks.describe(selected,controller):find(object[5],1,true))
        states[state]=false
        assert(looks.describe(selected,controller)==before)
        catalogue_checks=catalogue_checks+4
    end

    -- Count each scanner instance, including aliases, against the shipped maps.
    local episode2=require("descriptions.episode2_world_objects")
    local totals={}
    local function count(room,facts)
        local total=totals[room] or {0,0}
        total[1]=total[1]+1
        total[2]=total[2]+#facts
        totals[room]=total
    end
    episode2.register(function(room,actor,entry) count(room,entry.facts) end)
    for room,entries in pairs(episode2.fixed) do
        for _,row in ipairs(entries) do
            count(room,row[2])
            for _ in ipairs(row[4] or {}) do count(room,row[2]) end
        end
    end
    local expected={
        E2_1A_Bathroom_LD={5,12}, E2_1A_Corridor_LD={11,16}, E2_1A_DanaRoom_LD={7,8},
        E2_1A_KateRoom_LD={5,6}, E2_1A_MaxRoom_LD={12,13}, E2_1B_CampusB_LD={12,14},
        E2_2A_DinerPark_LD={9,10}, E2_2A_Diner_LD={16,17}, E2_3A_Junkyard_LD={15,17},
        E2_3B_Railroad_LD={9,11}, E2_4A_CampusA_LD={1,1}, E2_4B_ArtClass_LD={12,14},
        E2_4B_Corridor_LD={22,22}, E2_4B_SciClass_LD={7,10}, E2_4C_CampusB_LD2={1,1},
    }
    for room,total in pairs(expected) do
        assert(totals[room] and totals[room][1]==total[1] and totals[room][2]==total[2],room)
        totals[room]=nil
        catalogue_checks=catalogue_checks+1
    end
    assert(next(totals)==nil)
    catalogue_checks=catalogue_checks+1

    -- Each exact scanner instance and each Look branch must reach the same
    -- caption. Prime completed facts on entry to simulate a loaded save.
    for _,catalogue in ipairs(require("descriptions.world_catalogues")) do
        for room,entries in pairs(catalogue.fixed) do
            local level=room:match("^(E%d+_%d+%u)_")
            world.GetFName=function()return {ToString=function()return level end} end
            local seen={}
            for _,row in ipairs(entries) do
                local selected={sublevel=room,id="PersistentLevel."..row[1]}
                assert(not seen[row[1]],"duplicate scanner instance "..selected.id)
                seen[row[1]]=true
                assert(looks.describe(selected,controller)==row[3],selected.id)
                local poll_fixed,request_fixed=looks.new(function()return true end)
                local spoken={}
                local function sample()
                    poll_fixed(controller,true,function(line)spoken[#spoken+1]=line end)
                end
                for _,fact in ipairs(row[2]) do states[fact]=true end
                sample()
                assert(#spoken==0,"loading completed Looks in "..room)
                for index,fact in ipairs(row[2]) do
                    states[fact]=false;sample()
                    states[fact]=true;sample()
                    assert(#spoken==index and spoken[index]==row[3],fact)
                end
                for _,alias in ipairs(row[4] or {}) do
                    assert(not seen[alias],"duplicate scanner instance "..alias)
                    seen[alias]=true
                    selected.id="PersistentLevel."..alias
                    assert(looks.describe(selected,controller)==row[3],selected.id)
                    states[row[2][1]]=false;sample()
                    local manual_id
                    request_fixed(selected,controller,function(id)manual_id=id end)
                    states[row[2][1]]=true;sample()
                    assert(manual_id==selected.id and #spoken==#row[2],"Home during Look on "..selected.id)
                    catalogue_checks=catalogue_checks+3
                end
                catalogue_checks=catalogue_checks+3+#row[2]
            end
        end
    end
end)
FName=old_fname
assert(ok,err)
local original_find=FindAllOf
local passed,reason=pcall(function()
    local quiet=require("dialogue.playback").quiet
    local function valid()return true end
    local max={IsValid=valid,bPlayFinished=true}
    local courtney={IsValid=valid,bPlayFinished=false}
    local environment={IsValid=valid,RegisteredDNECues={ForEach=function(_,fn)
        for i,cue in ipairs({max,courtney}) do fn(i,{get=function()return cue end}) end
    end}}
    local widget={IsValid=valid,bIsShowSubtitle=false}
    FindAllOf=function(name)
        if name=="AudioEnvironment" then return {environment} end
        return {widget}
    end
    assert(quiet()==false,"another character's speech blocks narration with subtitles off")
    courtney.bPlayFinished=true;widget.bIsShowSubtitle=true
    assert(quiet()==false,"an active subtitle still holds the line")
    widget.bIsShowSubtitle=false
    assert(quiet()==true,"registered, finished cues allow narration")
    FindAllOf=function()return nil end
    assert(quiet()==nil,"a missing audio environment is unknown")
    FindAllOf=function()error("unavailable")end
    assert(quiet()==nil,"a failed playback query is unknown")
end)
FindAllOf=original_find
assert(passed,reason)
return 40+catalogue_checks+dofile("tests/lua/world_preservation.lua")
