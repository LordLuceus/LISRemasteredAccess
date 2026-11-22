-- Actual module callbacks: absence, early unready functions, partial registration,
-- first SpawnDigits, native dial changes, reopen and class reload. No game needed.
local count=0
local function check(ok,label)count=count+1;assert(ok,label)end
local view_path='/Game/Packages/Widgets/TimeTravel/BP_LiSPickLockWidget_View.BP_LiSPickLockWidget_View_C'
local names={'OpenMenuImplementable','SpawnDigits','DialFocused','Up Pressed','Down Pressed','Left Pressed','Right Pressed','Code_Touched','Exit','Cancel Pressed'}
local addresses,ready,callbacks,registered={},{},{},{}
for i,name in ipairs(names)do addresses[name]=i end
local notify,notifications,searches,reads,presences= nil,0,0,0,0
local available=false
local visible_view
-- This suite isolates construction timing. The separate uncached suite executes
-- the real typed resolver/provider against userdata, including class reloads.
local snapshot_reader={configure=function()return true end,configured=function()return true end}
local env=setmetatable({
    require=function(name)
        if name=='hud.padlock_view' then return snapshot_reader end
        return require(name)
    end,
    NotifyOnNewObject=function(class,callback)
        check(class=='/Script/LiS.LiSPickLockWidget','notification targets the native base')
        notifications=notifications+1;notify=callback
    end,
    StaticFindObject=function(path)
        searches=searches+1
        local name=path:match(':([^:]+)$');check(addresses[name]~=nil,'only expected padlock functions are searched')
        if not available then return nil end
        return{IsValid=function()return true end,GetAddress=function()return addresses[name]end}
    end,
    RegisterHook=function(path,callback)
        local name=path:match(':([^:]+)$')
        if not ready[name]then error('UFunction::Func: 0x0')end
        registered[name]=(registered[name]or 0)+1;callbacks[name]=callback
    end,
    FindAllOf=function(class)
        check(class=='BP_LiSPickLockWidget_View_C','presence uses the view class')
        presences=presences+1;return visible_view and{visible_view}or{}
    end,
},{__index=_G})
local P=assert(loadfile('src/hud/padlock.lua','t',env))()
local now=0;P.clock=function()return now end
P.text=function(key,p)
    if key=='padlock_code'then return p.digits end
    if key=='padlock_digit'then return p.value..':'..p.position..'/'..p.count end
    return key
end
P.start();P.start()
check(notifications==1 and searches==0,'startup registers once without any function search')
for _=1,20 do P.check_presence()end
check(presences==0,'inactive presence check does no engine lookup')
local opaque=setmetatable({},{__index=function()error('notification must not read the new object')end})
notify(opaque)
check(searches==10 and not next(callbacks),'absent class is harmless; no speculative hook')
available=true;notify(opaque)
check(not next(callbacks),'early unbound functions are not marked installed')
for _,name in ipairs(names)do ready[name]=name~='SpawnDigits'end
notify(opaque)
check(callbacks.OpenMenuImplementable~=nil and callbacks.SpawnDigits==nil,'partial readiness installs only ready functions')
ready.SpawnDigits=true;notify(opaque)
for _,name in ipairs(names)do check(registered[name]==1,'ready instance retries without duplicate hook: '..name)end
notify(opaque)
for _,name in ipairs(names)do check(registered[name]==1,'later notification is idempotent: '..name)end
local digits={}
local v={Digit=-1,id=101,visible=true}
function v:GetAddress()return self.id end
function v:IsValid()return true end
function v:IsVisible()return self.visible end
function v:IsInViewport()return self.visible end
v.DigitWidgets_Array={ForEach=function(_,fn)
    reads=reads+1
    for i,value in ipairs(digits)do fn(i,{TextBlock_Digit={GetText=function()return{ToString=function()return value end}end}})end
end}
snapshot_reader.snapshot=function(view)
    local values={}
    view.DigitWidgets_Array:ForEach(function(i,d)values[i]=d.TextBlock_Digit:GetText():ToString()end)
    return true,{id=view:GetAddress(),digits=values,selected=view.Digit}
end
check(reads==0,'installation never dereferences widget fields')
callbacks.OpenMenuImplementable(v)
check(not P.active(),'empty pre-spawn view does not invent opening digits')
digits={'0','0','0','0'};visible_view=v;callbacks.SpawnDigits(v);now=.11
local opening=P.due()
check(opening and opening:find('0, 0, 0, 0',1,true),'first SpawnDigits announces actual opening digits')
check(opening:find('padlock_no_selection',1,true),'first open preserves native unselected dial')
v.Digit=1;callbacks.DialFocused(v);now=.22
check(P.due()=='0:2/4','native focus change is spoken')
digits[2]='1';callbacks['Up Pressed'](v);now=.33
check(P.due()=='1:2/4','native dial value change is spoken')
P.check_presence();check(P.active(),'visible current view remains active')
callbacks['Cancel Pressed']();check(not P.active(),'native cancel clears state')
v.id=102;v.Digit=-1;callbacks.SpawnDigits(v);now=.44
check(P.due():find('0, 1, 0, 0',1,true),'reopening reads current digits rather than stale initial values')
v.visible=false;P.check_presence();check(not P.active(),'native removal without cancel clears state')
local before=presences;P.check_presence();check(presences==before,'inactive cleanup returns to zero lookups')
for _,name in ipairs(names)do addresses[name]=addresses[name]+100 end
notify(opaque)
for _,name in ipairs(names)do check(registered[name]==2,'class reload receives fresh hooks: '..name)end
v.visible=true;callbacks.SpawnDigits(v);callbacks.Exit();check(not P.active(),'exit hook also clears state')
print('Padlock construction hooks: '..count..' checks passed')
return count
