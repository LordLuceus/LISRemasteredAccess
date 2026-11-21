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
    local now=0
    local poll=looks.new(function()return now end)
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
    now=4;tick(true);tick(true)
    assert(#heard==1 and heard[1]==looks.describe(entry,controller))
    states[draw]=true
    assert(looks.describe(entry,controller):find("peace sign",1,true))
    states[look]=false;tick(true)
    states[look]=true;tick(false);tick(true)
    now=10;tick(true)
    assert(#heard==1,"a suppressed completion must not replay")
    local second=prefix.."Look02_Triggered"
    states[second]=false;tick(true)
    states[second]=true;tick(true)
    states[draw]=false
    now=15;tick(true)
    assert(#heard==1,"discard the pending description when the board changes")
    assert(looks.describe(entry,controller)==heard[1],"rewind restores the original wording")
    entry.sublevel="E2_3C_Corridor_LD"
    assert(looks.describe(entry,controller)==nil)
end)
FName=old_fname
assert(ok,err)
return 10
