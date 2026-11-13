package.path='src/?.lua;'..package.path
local old_find,old_flags,old_all,old_hook=StaticFindObject,EObjectFlags,FindAllOf,RegisterHook
local old=package.loaded['menus.keybindings'];package.loaded['menus.keybindings']=nil
local K=require('menus.keybindings')
local rows=require('menus.keybind_state').rows
local n=0
local function check(ok,why)n=n+1;assert(ok,why)end
local function obj(t)
    t=t or {};t.IsValid=function()return true end;t.HasAnyFlags=function()return false end;return t
end
local function text(s)return {ToString=function()return s end}end
local function label(s)return obj({GetText=function()return text(s)end})end
local focus,capture=23,nil
local open,popup,focus_calls=true,false,0
local errors={};K.log=function(s)errors[#errors+1]=s end
K.text=function(key,p)
    local values={keybind_primary='Primary',keybind_secondary='Secondary',keybind_title='Key bindings',keybind_unbound='Unbound',keybind_unknown='Unknown key',keybind_capture='Press a key.'}
    if key=='keybind_position' then return p.index..' of '..p.count end
    return values[key] or key
end
EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
local native_display_calls=0
StaticFindObject=function(path)
    if path==K.FUNCTION then return obj({GetAddress=function()return 901 end}) end
    check(path=='/Script/Engine.Default__KismetInputLibrary','native display-name library is used')
    return obj({Key_GetDisplayName=function(_,key)
        native_display_calls=native_display_calls+1
        return text('Native '..key.KeyName:ToString())
    end})
end
local view=obj({GetAddress=function()return 401 end,Title=label('Native keyboard heading'),
    IsVisible=function()return open end,IsInViewport=function()return open end})
FindAllOf=function(class)
    if class==K.CLASS then return {view} end
    if class=='KeybindPopUp_C' and popup then return {obj({IsVisible=function()return true end,IsInViewport=function()return true end})} end
    return {}
end
local post,hook_count=nil,0
RegisterHook=function(path,_,after)
    check(path==K.FUNCTION,'only the native assignment entry point is hooked')
    hook_count=hook_count+1;post=after
end
local keynames={}
for r,row in ipairs(rows) do
    view[row.label]=label('Native '..row.action)
    for slot=1,2 do
        local index=(r-1)*2+slot
        keynames[index]=index==23 and 'LeftControl' or (index==24 and 'RightControl' or 'None')
        view[row.field..(slot==2 and '_1' or '')]=obj({
            SelectedKey={Key={KeyName={ToString=function()return keynames[index]end}}},
            HasKeyboardFocus=function()return focus==index end,
            HasFocusedDescendants=function()return false end,
            SetKeyboardFocus=function()focus=index;focus_calls=focus_calls+1 end,
            GetIsSelectingKey=function()return capture==index end})
    end
end
local s=K.snapshot(view)
check(K.active and not K.capturing,'open editor is recognized independently of title-menu parenting')
check(s.index==23 and s.label=='Native Undo, Primary','native action label and exact primary selector')
check(s.value:find('Native LeftControl',1,true)~=nil,'native key display, not an invented spelling')
check(s.context=='Native keyboard heading','native heading')
focus=24;s=K.snapshot(view)
check(s.index==24 and s.value:find('Native RightControl',1,true)~=nil,'secondary Ctrl is separately exposed')
focus=nil;capture=23;s=K.snapshot(view)
check(K.capturing and s.index==23 and s.value:find('Press a key.',1,true)~=nil,'capture identifies a selector without keyboard focus')
capture=nil;focus=23;keynames[23]='U';s=K.snapshot(view)
check(s.value:find('Native U',1,true)~=nil,'fresh key data is read after assignment')
check(native_display_calls>0 and #errors==0,'native reads succeeded without suppressed errors')
K.closed();check(not K.active and not K.capturing,'closing clears editor/capture state')
focus=nil;s=K.snapshot(view)
check(s.index==1 and focus_calls==1,'opening without focus sets the first native selector once')
focus=nil;s=K.snapshot(view)
check(s.index=='overview' and focus_calls==1,'later focus loss never forces the player back to the first row')
K.closed();popup=true;K.snapshot(view,true)
check(focus_calls==1 and K.capturing,'capture overlay prevents initial focus theft and blocks shortcuts')
popup=false;K.block_keyboard(0);K.block_pad(0)
K.install();K.install();check(hook_count==1,'native assignment hook installed once')
view.IsRefreshing=true;post({get=function()return view end})
check(not K.block_keyboard(1),'programmatic refresh does not arm the user-input guard')
view.IsRefreshing=false;post({get=function()return view end})
check(K.block_keyboard(1) and K.block_pad(1),'assignment between polls consumes held keyboard/controller shortcuts')
check(K.block_keyboard(0) and not K.block_keyboard(0),'keyboard guard clears only after neutral input')
check(K.block_pad(0) and not K.block_pad(0),'controller guard clears independently after release')
focus=1
local visited={[1]=true}
for i=2,24 do local next=K.move(1);check(next and next.index==i,'sequential next reaches slot '..i);visited[next.index]=true end
check(K.move(1).index==1,'next wraps after the secondary quick-undo slot')
for i=24,1,-1 do check(K.move(-1).index==i,'sequential previous reaches slot '..i) end
local total=0;for _ in pairs(visited) do total=total+1 end
check(total==24,'all actual native selector fields reachable without spatial navigation')
capture=23;local prior=focus;check(K.move(1)==nil and focus==prior,'sequential browsing never steals native capture')
capture=nil;popup=true;check(K.move(-1)==nil and focus==prior,'capture popup also blocks browsing')
popup=false
open=false;K.closed()
StaticFindObject,EObjectFlags,FindAllOf,RegisterHook=old_find,old_flags,old_all,old_hook;package.loaded['menus.keybindings']=old
print('Keybind adapter: '..n..' checks passed')
return n
