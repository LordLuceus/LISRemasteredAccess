-- Version-pinned fresh property reads. No hooks or retained widgets in this module.
local M={enabled=false,TTL=2}
local native,active=nil,nil
local NAME='__lisr_reflection_resolve_83330635'
local VIEW='BP_LiSDialogWidget_View_C'
local function integer(n)return type(n)=='number' and n==math.floor(n) end
local function binding(o)
    assert(type(o)=='userdata','expected live userdata')
    assert(o:type()=='UObject','expected UObject binding')
    assert(o:IsValid(),'invalid object')
end
local function class_name(o)return o:GetClass():GetFName():ToString()end
local function resolve(owner,name)
    assert(M.enabled and active and active.thread==coroutine.running(),'outside owned Tick')
    assert(rawget(_G,NAME)==resolve,'resolver identity changed')
    binding(owner)
    if name=='DialogButtons_Array' then
        assert(owner==active.view and class_name(owner)==VIEW,'wrong view')
    elseif name=='DialogText' then
        assert(active.buttons[owner],'button outside current array')
    else error('property not allowed') end
    local found=nil
    local class=owner:GetClass()
    local visited={}
    for _=1,16 do
        if not class or not class:IsValid() then break end
        local address=class:GetAddress()
        assert(not visited[address],'class cycle');visited[address]=true
        class:ForEachProperty(function(p)
            if p:GetFName():ToString()==name then
                local expected=name=='DialogButtons_Array' and 'ArrayProperty' or 'ObjectProperty'
                assert(p:type()==expected,'wrong property binding')
                assert(p:GetClass():GetFName():ToString()==expected,'wrong property type')
                if expected=='ArrayProperty' then
                    local inner=p:GetInner()
                    assert(inner:type()=='ObjectProperty' and inner:GetClass():GetFName():ToString()=='ObjectProperty','wrong inner')
                end
                found=p;return true
            end
        end)
        if found then break end
        class=class:GetSuperStruct()
    end
    assert(found,'current property missing')
    local a,p,offset=owner:GetAddress(),found:GetAddress(),found:GetOffset_Internal()
    assert(integer(a) and a>0 and integer(p) and p>0 and integer(offset) and offset>=0 and offset<=2147483647,'invalid reflected address')
    return a,p,offset,name=='DialogButtons_Array' and 1 or 2
end
-- Explicit opt-in. Tests may supply a provider following the identical call contract.
-- The choice reader opts in during game startup. A DLL merely existing does not enable it.
function M.configure(opts)
    assert(not active,'cannot configure during Tick')
    M.enabled=false;native=nil
    if rawget(_G,NAME)==resolve then rawset(_G,NAME,nil) end
    if not opts or opts.enabled~=true then return false end
    local f=opts.provider
    if not f and opts.path then f=package.loadlib(opts.path,'lisr_reflection_read') end
    if type(f)~='function' then return false end
    native=f;rawset(_G,NAME,resolve);M.enabled=true;return true
end
function M.scope(view,fn)
    if not M.enabled then return false,'disabled' end
    if active then return false,'nested Tick' end
    if rawget(_G,NAME)~=resolve then return false,'resolver identity changed' end
    active={view=view,buttons={},thread=coroutine.running()}
    local result=table.pack(pcall(fn))
    active=nil
    return table.unpack(result,1,result.n)
end
function M.array(view)
    assert(active and active.view==view,'outside owned Tick')
    assert(rawget(_G,NAME)==resolve,'resolver identity changed')
    binding(view)
    local array,err=native(view,'DialogButtons_Array')
    assert(array,err or 'uncached helper unavailable')
    assert(type(array)=='userdata' and array:type()=='TArray','expected TArray')
    local n=array:GetArrayNum()
    assert(integer(n) and n>=0 and n<=4,'unexpected array size')
    return array,n
end
function M.button(array,i,n)
    assert(active and integer(i) and i>=1 and i<=n and i<=4,'invalid array index')
    local b=array[i]
    binding(b)
    assert(b:IsA('/Script/UMG.Widget'),'array element is not a widget')
    active.buttons[b]=true
    return b
end
function M.caption(button)
    assert(active and active.buttons[button],'button outside owned Tick')
    assert(rawget(_G,NAME)==resolve,'resolver identity changed')
    local text,err=native(button,'DialogText')
    assert(text,err or 'uncached text unavailable');binding(text)
    assert(text:IsA('/Script/UMG.Widget'),'text object is not a widget')
    local s=text:GetText():ToString()
    assert(type(s)=='string','invalid caption')
    return s:gsub('^%s+',''):gsub('%s+$','')
end
return M
