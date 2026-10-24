-- Read-only dump of interaction action records, fact/angle schema and fact functions.
-- Never calls TriggerActionBP or any fact setter.
local M={}
local function valid(o)return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end
local function scalar(v)
    local t=type(v)
    if t=="number" or t=="boolean" or t=="string" then return tostring(v) end
    if t=="userdata" then
        local ok,s=pcall(function()return v:ToString()end);if ok and type(s)=="string" then return s end
        ok,s=pcall(function()return v:GetFullName()end);if ok and type(s)=="string" then return "obj:"..s end
    end
    return nil
end
-- Generic dumper over reflected struct properties, bounded depth.
local controller_for_facts=nil
local function fact_state(name)
    if not controller_for_facts or name=="None" or name=="" then return nil end
    local ok,v=pcall(function()return controller_for_facts:IsFactActive(FName(name))end)
    return ok and tostring(v) or "query_error"
end
local function dump(emit,prefix,container,struct,depth)
    struct:ForEachProperty(function(p)
        local key=p:GetFName():ToString();local class=p:GetClass():GetFName():ToString()
        local ok,v=pcall(function()return container[key]end)
        if not ok then emit(prefix.."."..key.." read_error");return end
        -- Structs must be expanded before scalar(): a struct wrapper also answers
        -- GetFullName, which would print only its type name.
        if class=="StructProperty" then
            if depth>0 then dump(emit,prefix.."."..key,v,p:GetStruct(),depth-1) end
            return
        end
        if class=="ArrayProperty" then
            local n=v:GetArrayNum();emit(prefix.."."..key.." count="..n)
            local inner=p:GetInner();local ic=inner:GetClass():GetFName():ToString()
            v:ForEach(function(i,e)
                if i>8 then return end
                local item=e:get()
                if ic=="StructProperty" then
                    if depth>0 then dump(emit,prefix.."."..key.."["..i.."]",item,inner:GetStruct(),depth-1) end
                else emit(prefix.."."..key.."["..i.."]="..(scalar(item) or "?")) end
            end)
            return
        end
        local s=scalar(v)
        if s then
            local line=prefix.."."..key.."="..s
            -- Read-only fact query for any fact-name field.
            if class=="NameProperty" and string.find(key,"Fact",1,true) then
                local st=fact_state(s);if st then line=line.." active_now="..st end
            end
            emit(line)
        else emit(prefix.."."..key.." type="..class) end
    end)
end
function M.schema(emit)
    local actor_class=StaticFindObject("/Script/LiS.LiSInteractionActor")
    actor_class:ForEachProperty(function(p)
        local key=p:GetFName():ToString()
        if key=="Actions" or key=="TeleportLocationInfos" then
            local inner=p:GetInner();local s=inner:GetStruct()
            emit("action_schema property="..key.." struct="..s:GetFullName())
            s:ForEachProperty(function(f)emit("action_schema field="..key.."."..f:GetFName():ToString().." type="..f:GetClass():GetFName():ToString())end)
        end
    end)
    local count=0
    ForEachUObject(function(o)
        if count>=200 then return end
        local ok,match=pcall(function()
            if not o:IsA("/Script/CoreUObject.Function") then return false end
            local n=o:GetFullName()
            return string.find(n,"/Script/LiS.",1,true) and (string.find(n,"Fact",1,true) or string.find(n,"Angle",1,true) or string.find(n,"Restrain",1,true))
        end)
        if ok and match then
            count=count+1
            local params={}
            o:ForEachProperty(function(p)params[#params+1]=p:GetFName():ToString()..":"..p:GetClass():GetFName():ToString()end)
            emit("fact_function="..o:GetFullName().." params="..table.concat(params,","))
        end
    end)
    emit("fact_function_count="..count)
end
function M.dump_targets(controller,patterns,emit)
    controller_for_facts=controller
    local component
    for _,c in ipairs(FindAllOf("LiSInteractionComponent") or {}) do
        if valid(c) and valid(c:GetOwner()) and c:GetOwner():GetAddress()==controller:GetAddress() then component=c end
    end
    if not component then emit("action_dump_error=no_component");return end
    local actor_class=StaticFindObject("/Script/LiS.LiSInteractionActor")
    local action_struct,teleport_struct
    actor_class:ForEachProperty(function(p)
        local key=p:GetFName():ToString()
        if key=="Actions" then action_struct=p:GetInner():GetStruct() end
        if key=="TeleportLocationInfos" then teleport_struct=p:GetInner():GetStruct() end
    end)
    local found=0
    component.RegisteredActors:ForEach(function(_,v)
        local a=v:get()
        if not valid(a) then return end
        local name=a:GetFName():ToString();local hit=false
        for _,pat in ipairs(patterns) do if string.find(string.lower(name),string.lower(pat),1,true) then hit=true end end
        if not hit then return end
        found=found+1
        local p=a:K2_GetActorLocation();local r=a:K2_GetActorRotation()
        emit(string.format("action_target=%s objectName=%s position=%.1f,%.1f,%.1f yaw=%.1f restrain=%s range=%s zone=%s",
            a:GetFullName(),scalar(a.objectName) or "?",p.X,p.Y,p.Z,r.Yaw,tostring(a.bRestrainOnAngleRange),tostring(a.RestrainAngleRange),tostring(a.CurrentZoneStatus)))
        local dummy=a.TapToMoveActor
        if valid(dummy) then
            local d=dummy:K2_GetActorLocation();local dr=dummy:K2_GetActorRotation()
            emit(string.format("action_approach target=%s dummy=%.1f,%.1f,%.1f yaw=%.1f",name,d.X,d.Y,d.Z,dr.Yaw))
        end
        a.Actions:ForEach(function(i,e)
            local action=e:get()
            local ok,err=pcall(function()dump(emit,"action "..name.."["..i.."]",action,action_struct,2)end)
            if not ok then emit("action_dump_error="..name.."["..i.."] "..tostring(err)) end
        end)
        if teleport_struct then
            a.TeleportLocationInfos:ForEach(function(i,e)
                local ok,err=pcall(function()dump(emit,"teleport "..name.."["..i.."]",e:get(),teleport_struct,2)end)
                if not ok then emit("teleport_dump_error="..tostring(err)) end
            end)
        end
    end)
    emit("action_targets_found="..found)
end
return M
