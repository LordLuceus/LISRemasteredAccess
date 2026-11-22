-- Fresh, typed property reads owned by one live padlock callback. Never fall
-- back to UObject's cached name lookup, including for child text and selection.
local M = {}
local NAME = '__lisr_padlock_resolve_v1'
local VIEW = 'BP_LiSPickLockWidget_View_C'
local kinds = {DigitWidgets_Array=1, TextBlock_Digit=2, Digit=3}
local types = {'ArrayProperty', 'ObjectProperty', 'IntProperty'}
local reader, active

local function integer(n)
    return type(n)=='number' and n==math.floor(n)
end
local function binding(object)
    assert(type(object)=='userdata' and object:type()=='UObject', 'expected live UObject')
    assert(object:IsValid(), 'invalid object')
    local flags = assert(EObjectFlags, 'object flags unavailable')
    assert(not object:HasAnyFlags(flags.RF_BeginDestroyed | flags.RF_FinishDestroyed |
        flags.RF_ClassDefaultObject | flags.RF_ArchetypeObject), 'object is not a live instance')
end
local function resolve(owner, name)
    assert(active and active.thread==coroutine.running(), 'outside owned padlock callback')
    assert(rawget(_G, NAME)==resolve, 'resolver identity changed')
    local kind = assert(kinds[name], 'property not allowed')
    binding(owner)
    if name=='TextBlock_Digit' then
        assert(active.digits[owner], 'digit outside current array')
    else
        assert(owner==active.view and owner:GetClass():GetFName():ToString()==VIEW, 'wrong view')
    end
    local class, found = owner:GetClass(), nil
    local visited = {}
    for _=1,16 do
        if not class or not class:IsValid() then break end
        local address = class:GetAddress()
        assert(not visited[address], 'class cycle')
        visited[address] = true
        class:ForEachProperty(function(property)
            if property:GetFName():ToString()~=name then return end
            -- 83330635 auto_construct_property has no specialized IntProperty
            -- binding: integers use Property, with reflected class IntProperty.
            local wrapper = kind==3 and 'Property' or types[kind]
            assert(property:type()==wrapper and
                property:GetClass():GetFName():ToString()==types[kind], 'wrong property type')
            if kind==1 then
                local inner = property:GetInner()
                assert(inner:type()=='ObjectProperty' and
                    inner:GetClass():GetFName():ToString()=='ObjectProperty', 'wrong array inner type')
            end
            found = property
            return true
        end)
        if found then break end
        class = class:GetSuperStruct()
    end
    assert(found, 'current property missing')
    local owner_address, property_address, offset = owner:GetAddress(), found:GetAddress(), found:GetOffset_Internal()
    assert(integer(owner_address) and owner_address>0 and integer(property_address) and property_address>0 and
        integer(offset) and offset>0 and offset<=2147483647, 'invalid reflected address')
    return owner_address, property_address, offset, kind
end

function M.configured()
    return type(reader)=='function' and rawget(_G, NAME)==resolve
end
function M.configure(provider)
    assert(not active, 'cannot configure during callback')
    reader = nil
    if rawget(_G, NAME)==resolve then rawset(_G, NAME, nil) end
    if not provider then
        local here = debug.getinfo(1, 'S').source:gsub('^@', ''):gsub('[^/\\]+$', '')
        provider = package.loadlib(here:gsub('hud[/\\]$', '')..'lisr_reflection.dll', 'lisr_padlock_read')
    end
    if type(provider)~='function' then return false end
    reader = provider
    rawset(_G, NAME, resolve)
    return true
end
local function field(owner, name)
    assert(M.configured(), 'padlock reader unavailable')
    local value, why = reader(owner, name)
    assert(value~=nil, why or 'uncached field unavailable')
    return value
end
function M.snapshot(view)
    if active then return false, 'nested padlock callback' end
    active = {view=view, digits={}, thread=coroutine.running()}
    local ok, result = pcall(function()
        binding(view)
        assert(view:GetClass():GetFName():ToString()==VIEW, 'wrong padlock view')
        local id = view:GetAddress()
        assert(integer(id) and id>0, 'invalid view identity')
        active.id = id
        local array = field(view, 'DigitWidgets_Array')
        assert(type(array)=='userdata' and array:type()=='TArray', 'expected TArray')
        local count = array:GetArrayNum()
        assert(integer(count) and count>=0 and count<=16, 'unexpected digit count')
        local digits = {}
        for i=1,count do
            local digit = array[i]
            binding(digit)
            assert(digit:IsA('/Script/UMG.Widget'), 'digit is not a widget')
            active.digits[digit] = true
            local text = field(digit, 'TextBlock_Digit')
            binding(text)
            assert(text:IsA('/Script/UMG.TextBlock'), 'digit text is not a TextBlock')
            local value = text:GetText():ToString()
            assert(type(value)=='string' and value:match('^%d$'), 'invalid displayed digit')
            digits[i] = value
        end
        local selected = field(view, 'Digit')
        -- Before SpawnDigits the array can be empty while Digit still holds its
        -- class default. The reducer clears that not-yet-open snapshot silently.
        assert(integer(selected) and (count==0 or (selected>=-1 and selected<count)), 'invalid dial selection')
        return {id=id, digits=digits, selected=selected}
    end)
    local id = active.id
    active = nil
    return ok, result, id
end
return M
