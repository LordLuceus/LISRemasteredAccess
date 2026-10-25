-- Development aid: when the menu reader finds a highlighted option without a
-- label, log that widget's class, own fields and nearby text, once per class
-- and index, so the label's real location can be found. Read-only.
local M={}
local seen={}
-- Struct/array values are userdata without HasAnyFlags; only call it on objects.
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end)
    return ok and r==true
end
local function cls(o)return o:GetClass():GetFName():ToString()end
local function text_of(w)
    local ok,s=pcall(function()return w:GetText():ToString()end)
    if ok and type(s)=="string" then return s end
    return nil
end
-- Text under a widget through its own tree, bounded.
local function texts(w,out,depth)
    if depth>6 or #out>12 or not valid(w) then return end
    local t=text_of(w)
    if t and t~="" then out[#out+1]=cls(w).."("..w:GetFName():ToString()..")=\""..t:gsub("[\r\n]+"," / ").."\"" end
    local ok,n=pcall(function()return w:GetChildrenCount()end)
    if ok and type(n)=="number" then
        for i=0,math.min(n,32)-1 do local cok,c=pcall(function()return w:GetChildAt(i)end);if cok then texts(c,out,depth+1) end end
    end
    local rok,root=pcall(function()return w.WidgetTree.RootWidget end)
    if rok and valid(root) then texts(root,out,depth+1) end
end
function M.describe(log)
    return function(screen,option,index)
        local key=cls(screen).."|"..cls(option).."|"..tostring(index)
        if seen[key] then return end
        seen[key]=true
        log("unlabelled screen="..cls(screen).." index="..tostring(index).." option="..cls(option).." name="..option:GetFName():ToString())
        local kind=option:GetClass()
        for _=1,3 do
            if not valid(kind) or kind:GetFullName():find("/Script/UMG.",1,true) then break end
            kind:ForEachProperty(function(p)
                local name=p:GetFName():ToString();local pc=p:GetClass():GetFName():ToString()
                local ok,v=pcall(function()return option[name]end)
                local s=""
                if ok and (type(v)=="number" or type(v)=="boolean" or type(v)=="string") then s="="..tostring(v)
                elseif ok and type(v)=="userdata" then
                    local t=nil
                    pcall(function()t=v:ToString()end)
                    if type(t)~="string" and valid(v) then t=text_of(v) end
                    if type(t)=="string" and t~="" then s="=\""..t.."\"" end
                end
                log("unlabelled_field option="..cls(option).." "..pc.." "..name..s)
            end)
            kind=kind:GetSuperStruct()
        end
        local found={};texts(option,found,0)
        for _,t in ipairs(found) do log("unlabelled_text option="..cls(option).." "..t) end
    end
end
return M
