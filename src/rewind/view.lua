-- Read Blueprint object fields through the existing fresh-property primitive,
-- not UE4SS's cached short-name property lookup. This view has NO Blueprint Tick
-- to hook. Reads run only in the main game-thread loop, on the exact widget the
-- native writer currently uses; no UObject/FProperty survives this scope.
local M={};M.log=function(_)end
local NAME='__lisr_rewind_view_resolve_v1'
local CLASS='BP_LiSRewindWidget_View_C'
local fields={RewindBarMaterialInstance=true,Overlay_Rewind=true,CanvasPanel_Rewind=true,
    Button_RewindIndicator=true,Image_RewindButtonIndicator=true}
local reader,active
local errors={}
local function valid(o)
    local f=EObjectFlags
    return o and o:IsValid() and not o:HasAnyFlags(f.RF_BeginDestroyed|f.RF_FinishDestroyed|
        (f.RF_ClassDefaultObject or 0)|(f.RF_ArchetypeObject or 0))
end
local function resolve(owner,name)
    assert(active and active.thread==coroutine.running() and owner==active.view,'outside current rewind view')
    assert(rawget(_G,NAME)==resolve and fields[name] and valid(owner),'rewind resolver ownership')
    assert(owner:GetClass():GetFName():ToString()==CLASS,'wrong rewind view class')
    local class=owner:GetClass();local visited={};local found
    for _=1,16 do
        if not class or not class:IsValid() then break end
        local id=class:GetAddress();assert(not visited[id],'class cycle');visited[id]=true
        class:ForEachProperty(function(p)
            if p:GetFName():ToString()==name then
                assert(p:type()=='ObjectProperty' and p:GetClass():GetFName():ToString()=='ObjectProperty','wrong property type')
                found=p;return true
            end
        end)
        if found then break end
        class=class:GetSuperStruct()
    end
    assert(found,'rewind view property missing')
    local a,p,o=owner:GetAddress(),found:GetAddress(),found:GetOffset_Internal()
    assert(type(a)=='number' and a>0 and type(p)=='number' and p>0 and type(o)=='number' and o>=0 and o%1==0 and o<=2147483647,'bad property address')
    return a,p,o,2
end
function M.configure(provider)
    reader=provider
    if not reader then
        local here=debug.getinfo(1,'S').source:gsub('^@',''):gsub('[^/\\]+$','')
        reader=package.loadlib(here:gsub('rewind[/\\]$','')..'lisr_reflection.dll','lisr_rewind_view_read')
    end
    if type(reader)~='function' then return false end
    rawset(_G,NAME,resolve);return true
end
local function shown(o)
    for _=1,32 do
        if not valid(o) or not o:IsVisible() then return false end
        local opacity=o:GetRenderOpacity()
        if type(opacity)~='number' or not(opacity>0) then return false end
        local parent=o:GetParent()
        if not parent or not parent:IsValid() then return true end
        o=parent
    end
    return false
end
local function field(owner,name)
    local value,why=reader(owner,name)
    assert(valid(value),why or 'invalid rewind child')
    return value
end
function M.visible(frame)
    if not frame.writer_gate or type(reader)~='function' then return false end
    assert(not active,'nested rewind view read')
    local ok,result=pcall(function()
        for _,w in ipairs(FindAllOf(CLASS) or {})do
            if valid(w) and w:GetAddress()==frame.writer_widget then
                active={view=w,thread=coroutine.running()}
                local material=field(w,'RewindBarMaterialInstance')
                if material:GetAddress()~=frame.writer_material then return false end
                if not w:IsInViewport() and not valid(w:GetParent())then return false end
                if not shown(w) then return false end
                -- The touch button is not an independent visibility gate:
                -- ShowOrHideRewindSpiral changes Overlay_Rewind by itself.
                -- If the button is an actual ancestor, shown() still checks it.
                for _,name in ipairs({'Overlay_Rewind','CanvasPanel_Rewind','Image_RewindButtonIndicator'})do
                    if not shown(field(w,name))then return false end
                end
                return true
            end
        end
        return false
    end)
    active=nil
    if not ok then
        local why=tostring(result)
        if not errors[why] then errors[why]=true;M.log('rewind_view_error='..why) end
        return false
    end
    return result
end
return M
