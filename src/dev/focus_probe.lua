-- Read-only: after a face request, record what the game does for two seconds.
-- Every quarter second: the game's focused interaction, the target's zone
-- (inner/visible/far lists), whether its interaction widget is open, the
-- widget's action texts (TextValues) and which action buttons it shows. Never
-- calls TriggerActionBP or any setter.
local M={}
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid()end)
    return ok and r==true
end
local function name(o)return valid(o) and o:GetFName():ToString() or "none" end
local function contains(array,target)
    local found=false
    pcall(function()
        local list={}
        array:ForEach(function(_,v)local ok,o=pcall(function()return v:get()end);if ok then list[#list+1]=o end end)
        for _,o in ipairs(list) do if valid(o) and o:GetAddress()==target:GetAddress() then found=true end end
    end)
    return found
end
local active=nil
function M.watch(controller,entry,log)
    active={controller=controller,entry=entry,log=log,ticks=0,last=nil}
end
local function component(controller)
    for _,c in ipairs(FindAllOf("LiSInteractionComponent") or {}) do
        local ok,own=pcall(function()return valid(c) and c:GetOwner():GetAddress()==controller:GetAddress()end)
        if ok and own then return c end
    end
end
function M.tick()
    local s=active
    if not s then return end
    s.ticks=s.ticks+1
    if s.ticks>8 then active=nil;s.log("focus_watch end target="..s.entry.name);return end
    local c=component(s.controller)
    local a=s.entry.actor
    local parts={"t="..(s.ticks*250).."ms"}
    if c then
        parts[#parts+1]="focused="..name(c.ActorInteractionFocused)
        parts[#parts+1]="current="..name(c.CurrentInteraction)
        if valid(a) then
            parts[#parts+1]="inner="..tostring(contains(c.InnerZoneActorsCurrentlyActionable,a))
            parts[#parts+1]="visible="..tostring(contains(c.VisibleZoneActorsCurrentlyActionable,a))
            parts[#parts+1]="far="..tostring(contains(c.TooFarZoneActorsCurrentlyActionable,a))
        end
    end
    if valid(a) then
        pcall(function()parts[#parts+1]="zone="..tostring(a.CurrentZoneStatus)end)
        pcall(function()parts[#parts+1]="ui_open="..tostring(a.bIsInteractionUIOpened)end)
        local enabled={}
        pcall(function()
            local list={}
            a.Actions:ForEach(function(i,v)local ok,x=pcall(function()return v:get()end);if ok then list[#list+1]={i,x} end end)
            for _,p in ipairs(list) do
                local ok,on=pcall(function()return p[2].bEnabled end)
                local nok,n=pcall(function()return p[2].ActionName:ToString()end)
                if ok and on then enabled[#enabled+1]=(nok and n or "?").."#"..p[1] end
            end
        end)
        parts[#parts+1]="enabled="..table.concat(enabled,",")
        local w=nil;pcall(function()w=a:GetInteractionWidget()end)
        if valid(w) then
            parts[#parts+1]="widget="..w:GetClass():GetFName():ToString()
            local texts={}
            pcall(function()
                local list={}
                w.TextValues:ForEach(function(_,v)local ok,x=pcall(function()return v:get()end);if ok then list[#list+1]=x end end)
                for _,x in ipairs(list) do local ok,t=pcall(function()return x:ToString()end);texts[#texts+1]=ok and t or "?" end
            end)
            parts[#parts+1]="texts="..table.concat(texts,"|")
            -- Per-slot state records: copy plain field values out inside the walk.
            local states={}
            for _,f in ipairs({"DesiredStates","InternalStates"}) do
                local rows={}
                pcall(function()
                    w[f]:ForEach(function(i,v)
                        local row={}
                        pcall(function()local x=v:get();row.real=x.RealIndex;row.fake=x.FakeIndex;row.ghost=x.IsGhostButton end)
                        rows[#rows+1]=string.format("%d:r%s/f%s/g%s",i,tostring(row.real),tostring(row.fake),tostring(row.ghost))
                    end)
                end)
                states[#states+1]=f.."="..table.concat(rows,",")
            end
            for k=1,4 do
                pcall(function()states[#states+1]="b"..k.."="..tostring(w["button"..k.."_visible"]).."/"..tostring(w["action_name"..k]) end)
            end
            parts[#parts+1]=table.concat(states," ")
        else
            parts[#parts+1]="widget=none"
        end
    end
    local line=table.concat(parts," ")
    local key=line:gsub("^t=%d+ms ","")
    if key~=s.last then s.last=key;s.log("focus_watch target="..s.entry.name.." "..line) end
end
return M
