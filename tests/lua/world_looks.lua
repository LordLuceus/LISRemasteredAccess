local looks=require("descriptions.world_looks")
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
    local poll,request=looks.new(function()return quiet end)
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
    states[look]=true;tick(false);tick(true)
    tick(true)
    assert(#heard==1,"a suppressed completion must not replay")
    local second=prefix.."Look02_Triggered"
    states[second]=false;tick(true)
    quiet=false;states[second]=true;tick(true)
    states[draw]=false
    quiet=true;tick(true)
    assert(#heard==1,"discard the pending description when the board changes")
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
    states[draw]=true;states[draw_action]=false;tick(true)
    quiet=false;states[draw_action]=true;tick(true)
    assert(#heard==1,"Draw waits if another line is playing")
    quiet=true;tick(true)
    assert(heard[2]==require("lang.en").scene_e1_3c_corridor_kateslate_interact01_1)
    entry.sublevel="E2_3C_Corridor_LD"
    assert(looks.describe(entry,controller)==nil)
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
return 25
