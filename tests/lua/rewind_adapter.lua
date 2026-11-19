package.path='src/?.lua;'..package.path
local N=require('rewind.native');local count=0
local function check(v,label)count=count+1;assert(v,label)end
local packet='r2 0 1 101 1 64.25 100 1 1 60.5 0 0 1 1 10 20'
local f=N.parse(packet)
check(f and f.reference==64.25 and f.marker==60.5 and f.writer_gate and f.writer_widget==10,'Native protocol preserves fractional absolute timestamps and identity')
check(N.parse(packet..' extra')==nil,'Extra fields rejected')
check(N.parse(packet:gsub('r2','r1'))==nil,'Old ABI rejected')
check(N.parse(packet:gsub('64.25','nan'))==nil,'Nonfinite numeric payload rejected')
check(N.parse('r2 4 -1 0 -1 0 0 0 0 0 0 0 0 0 0 0')==nil,'Unsupported executable never supplies state')
f=N.parse('r2 3 1 101 4 0 0 0 0 0 0 0 0 0 0 0')
check(f and f.state==4 and not f.valid,'Revalidated rewind state survives an unavailable gauge')
local old_find,old_flags=FindAllOf,EObjectFlags
EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2,RF_ClassDefaultObject=4,RF_ArchetypeObject=8}
local function obj(id)
    local o={id=id,on=true,alpha=1,viewport=true,flags=0}
    function o:IsValid()return true end
    function o:GetAddress()return self.id end
    function o:HasAnyFlags(bits)return self.flags&bits~=0 end
    function o:IsVisible()return self.on end
    function o:GetRenderOpacity()return self.alpha end
    function o:GetParent()return self.parent end
    function o:IsInViewport()return self.viewport end
    return o
end
local w=obj(10);local fields={RewindBarMaterialInstance=obj(20),Overlay_Rewind=obj(21),CanvasPanel_Rewind=obj(22),Image_RewindButtonIndicator=obj(23),Button_RewindIndicator=obj(24)}
local class=obj(30);function class:GetFName()return {ToString=function()return 'BP_LiSRewindWidget_View_C'end}end
function class:GetSuperStruct()return nil end
function class:ForEachProperty(fn)
    for name,value in pairs(fields)do
        local p={};function p:GetFName()return {ToString=function()return name end}end
        function p:type()return 'ObjectProperty'end
        function p:GetClass()return {GetFName=function()return {ToString=function()return 'ObjectProperty'end}end}end
        function p:GetAddress()return value.id+100 end
        function p:GetOffset_Internal()return value.id*8 end
        if fn(p)then return end
    end
end
function w:GetClass()return class end
FindAllOf=function(name)check(name=='BP_LiSRewindWidget_View_C','Exact view class discovery');return {w}end
local V=require('rewind.view');local calls=0
local resolver_name='__lisr_rewind_view_resolve_v1';local old_resolver=rawget(_G,resolver_name)
V.configure(function(owner,name)
    calls=calls+1
    local a,p,offset,kind=rawget(_G,resolver_name)(owner,name)
    check(a==10 and p==fields[name].id+100 and offset==fields[name].id*8 and kind==2,'Actual fresh-property resolver exercised')
    return fields[name]
end)
f=N.parse(packet)
check(V.visible(f),'Current native writer widget/material and authored visible panels pass')
fields.Overlay_Rewind.on=false;check(not V.visible(f),'Hidden spiral rejected');fields.Overlay_Rewind.on=true
fields.CanvasPanel_Rewind.alpha=0;check(not V.visible(f),'Disable HUD opacity rejected');fields.CanvasPanel_Rewind.alpha=1
fields.Image_RewindButtonIndicator.on=false;check(not V.visible(f),'Hidden actual image rejected');fields.Image_RewindButtonIndicator.on=true
fields.Button_RewindIndicator.on=false;check(V.visible(f),'A hidden touch button alone must not suppress a visible spiral')
fields.Image_RewindButtonIndicator.parent=fields.Button_RewindIndicator
check(not V.visible(f),'Actual hidden image ancestor still suppresses it');fields.Image_RewindButtonIndicator.parent=nil
f.writer_material=99;check(not V.visible(f),'Stale material does not prove the active gauge');f.writer_material=20
f.writer_widget=99;check(not V.visible(f),'Unowned view cannot prove visibility');f.writer_widget=10
w.viewport=false;check(not V.visible(f),'Detached view rejected');w.viewport=true
w.flags=4;check(not V.visible(f),'Templates rejected');w.flags=0
local before=calls;f.writer_gate=false;check(not V.visible(f) and calls==before,'Closed native writer never enters view property reads')
check(not pcall(rawget(_G,resolver_name),w,'Overlay_Rewind'),'Resolver cannot escape its same-thread owned scope')
-- Exercise the runtime coordinator with the real parser/policy, including its
-- independent state mute when no visible gauge or foreground is available.
local Runtime=require('rewind.runtime');local muted,focused,menu,visible=false,true,false,true
local sample=N.parse(packet);local audio={};local identity=true
local rt=Runtime.new({native={sample=function()return sample,'fixture'end},view={visible=function()return visible end},
    control={suppress_cues=function(_,on)muted=on end},log=function()end,text=function(k)return k end,say=function()end,
    play=function(file)audio[#audio+1]=file;return true end,focused=function()return focused end,
    in_menu=function()return menu end,identity=function()if identity then return 'world',1 end end})
rt:tick(0);check(muted and audio[1]=='rewind_approach.wav','Runtime routes native rewind state and approach cue together')
focused=false;sample.reference=59;rt:tick(.05);check(muted and #audio==1,'Background cancels cues but not actual-rewind suppression')
focused=true;menu=true;rt:tick(.1);check(muted and #audio==1,'Menu blocks audio without a fake crossing')
sample=N.parse('r2 3 1 101 4 0 0 0 0 0 0 0 0 0 0 0');rt:tick(.15)
check(muted and #audio==1,'Invalid timeline still silences competing control cues using revalidated state')
identity=false;rt:tick(.2);check(not muted,'Lost world cancels the session')
-- Run the actual registered game-thread loop, not just a helper it might never
-- reach. No game or native input is involved in this fake environment.
local file=assert(io.open('src/main.lua'));local main=file:read('*a');file:close()
local start=assert(main:find('local beat=0',1,true));local finish=assert(main:find('-- Development test session',start,true))
local callback,ticks,mains,cancels,errors=nil,0,0,0,{}
local noop=function()end
local fake_rewind={tick=function()ticks=ticks+1 end,cancel=function()cancels=cancels+1 end}
local env=setmetatable({LoopInGameThreadWithDelay=function(ms,fn)check(ms==50,'Existing 50ms loop retained');callback=fn end,
    padlock={install=noop,check_presence=noop,due=noop},run_keys=noop,picture={poll=noop},run_delayed=noop,
    rewind=fake_rewind,cutscenes={tick=noop,cancel=noop},pad_step=noop,lighthouse_fast_step=noop,polarewind={tick=noop},menu_step=noop,
    main_step=function()mains=mains+1;check(ticks>=mains*5,'Rewind tick precedes slow control processing')end,
    face={tick=noop},log=function(e)errors[#errors+1]=e end}, {__index=_G})
assert(load(main:sub(start,finish-1),'registered rewind loop','t',env))()
for _=1,20 do callback()end
check(ticks==20 and mains==2 and #errors==0,'Registered callback actually reaches rewind polling every beat')
fake_rewind.tick=function()error('injected rewind error')end;callback()
check(cancels==1 and #errors==1 and errors[1]:find('rewind_error=',1,true),'Registered failure path clears stale rewind state')
rawset(_G,resolver_name,old_resolver);FindAllOf,EObjectFlags=old_find,old_flags
package.loaded['rewind.view']=nil
print('Rewind native/view adapter: '..count..' checks passed')
return count
