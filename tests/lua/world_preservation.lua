-- Compare against files frozen BEFORE the authoring extraction, not current rows.
local baseline=dofile("tests/lua/world_looks_baseline.lua")
local current=require("descriptions.world_looks")
local checks=0
local function equal(a,b,label)
    checks=checks+1
    assert(a==b,label..": "..tostring(a).." ~= "..tostring(b))
end
local function upvalue(fn,name)
    for i=1,100 do
        local key,value=debug.getupvalue(fn,i)
        if key==name then return value end
        if not key then break end
    end
    error("missing upvalue "..name)
end
local function objects(module)
    return upvalue(upvalue(module.describe,"object_for"),"objects")
end
local old_objects,new_objects=objects(baseline),objects(current)
local function same_keys(a,b,label)
    for key in pairs(a) do assert(b[key],label.." missing "..key);checks=checks+1 end
    for key in pairs(b) do assert(a[key],label.." added "..key);checks=checks+1 end
end
same_keys(old_objects,new_objects,"rooms")
local old_fname=FName
FName=function(name)return name end
local ok,err=pcall(function()
    local function reader_trace(module,room,actor,fact,initial)
        local states={}
        for key,value in pairs(initial) do states[key]=value end
        states[fact]=false
        local address,controller_address=1,2
        local world={GetAddress=function()return address end,
            GetFName=function()return {ToString=function()return room:match("^(E%d+_%d+%u)_") end} end}
        local controller={GetWorld=function()return world end,GetAddress=function()return controller_address end,
            IsFactActive=function(_,key)return states[key] end}
        local entry={sublevel=room,id="PersistentLevel."..actor}
        local quiet,other=false,false
        local tick,request,pending_action=module.new(function()return quiet end)
        local trace,again={},nil
        local function sample(enabled)
            tick(controller,enabled,function(line,interrupt,repeat_when_quiet)
                trace[#trace+1]="say:"..line..":"..tostring(interrupt)
                again=repeat_when_quiet
            end,other)
            trace[#trace+1]="pending:"..tostring(pending_action())
        end
        local function manual(id,repeat_when_quiet)
            trace[#trace+1]="manual:"..id;again=repeat_when_quiet
        end
        sample(true);states[fact]=true;sample(true)
        quiet=nil;sample(true);quiet=true;other=true;sample(true)
        other=false;sample(true);sample(true)
        if again then again();sample(true) end
        states[fact]=false;sample(true)
        quiet=false;request(entry,controller,manual);states[fact]=true;sample(true)
        quiet=true;sample(true)
        -- Disabled/context changes invalidate pending ownership and stale callbacks.
        quiet=false;request(entry,controller,manual);sample(false);quiet=true;sample(true)
        quiet=false;states[fact]=false;sample(true);states[fact]=true;sample(true)
        address=3;quiet=true;sample(true)
        if again then again();sample(true) end
        quiet=false;request(entry,controller,manual);controller_address=4;quiet=true;sample(true)
        -- Rewind cancels pending automatic output.
        states[fact]=false;sample(true);quiet=false;states[fact]=true;sample(true)
        states[fact]=false;quiet=true;sample(true)
        return table.concat(trace,"\n")
    end
    local entries=0
    for room,actors in pairs(old_objects) do
        same_keys(actors,assert(new_objects[room]),room)
        for actor,old in pairs(actors) do
            entries=entries+1
            local new=new_objects[room][actor]
            equal(#old.facts,#new.facts,actor.." facts count")
            for i,fact in ipairs(old.facts) do equal(fact,new.facts[i],actor.." fact order") end
            -- Explore each dependency with nil/false/true, including conditional
            -- second facts (toolbox and bird). Unknown is represented by sentinel.
            local unknown={}
            local values={}
            local function explore()
                local missing
                local function read(key)
                    if values[key]==nil then missing=missing or key;return nil end
                    if values[key]~=unknown then return values[key] end
                end
                local expected=old.description(read)
                local actual=new.description(read)
                if missing then
                    for _,value in ipairs({unknown,false,true}) do values[missing]=value;explore() end
                    values[missing]=nil
                    return
                end
                equal(expected,actual,actor.." exact caption/state")
                local initial={}
                for key,value in pairs(values) do if value~=unknown then initial[key]=value end end
                for _,fact in ipairs(old.facts) do
                    equal(reader_trace(baseline,room,actor,fact,initial),
                        reader_trace(current,room,actor,fact,initial),actor.." reader "..fact)
                end
            end
            explore()
            -- Alias equivalence must be preserved, not merely alias wording.
            for alias,old_alias in pairs(actors) do
                if old_alias==old then equal(new_objects[room][alias],new,actor.." alias identity") end
            end
        end
    end
    assert(entries>200,"baseline catalogue must not be vacuous")
    -- Check ordering as consumed by the reader, including scanner-derived rows.
    local old_worlds=upvalue(baseline.new(function()return true end),"worlds")
    local new_worlds=upvalue(current.new(function()return true end),"worlds")
    same_keys(old_worlds,new_worlds,"worlds")
    for world,rows in pairs(old_worlds) do
        equal(#rows,#new_worlds[world],world.." count")
        for i,row in ipairs(rows) do
            equal(table.concat(row.facts,"|"),table.concat(new_worlds[world][i].facts,"|"),world.." registration order")
        end
    end
end)
FName=old_fname
assert(ok,err)
return checks
