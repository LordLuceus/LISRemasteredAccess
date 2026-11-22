-- Execute the real scoped resolver with engine-free userdata, never cached fields.
local saved_path=package.path
package.path='src/?.lua;src/?/init.lua;'..package.path
local count=0
local function check(v,label) count=count+1;assert(v,label) end
local root='__lisr_padlock_resolve_v1'
local globals={root,'EObjectFlags','StaticFindObject','RegisterHook','NotifyOnNewObject','FindAllOf'}
local saved={};for _,k in ipairs(globals)do saved[k]=rawget(_G,k)end
local modules={'hud.padlock_view','hud.padlock'}
local loaded={};for _,k in ipairs(modules)do loaded[k]=package.loaded[k];package.loaded[k]=nil end
local files,meta={},{}
local address=10000
local forbidden={DigitWidgets_Array=true,TextBlock_Digit=true,Digit=true}
local ordinary,indexreads=0,0
local function object(methods,fields,addr)
    local u=assert(io.tmpfile());files[#files+1]={u,debug.getmetatable(u)};u:close()
    address=address+16
    local data={address=addr or address,valid=true,flags=0};meta[u]=data
    local m={type=function()return 'UObject'end,IsValid=function()return data.valid end,
        GetAddress=function()return data.address end,HasAnyFlags=function(flags)return (data.flags & flags)~=0 end,
        GetFlags=function()return data.flags end,IsA=function(n)return n=='/Script/UMG.Widget'end,
        IsVisible=function()return true end,IsInViewport=function()return true end}
    for k,v in pairs(methods or {})do m[k]=v end
    debug.setmetatable(u,{__name='PadlockFake',__index=function(_,k)
        if forbidden[k]then ordinary=ordinary+1;error('cached field access forbidden: '..k)end
        if m[k]then return function(_,...)return m[k](...)end end
        if type(k)=='number'then indexreads=indexreads+1 end
        return (fields or {})[k]
    end})
    return u
end
local function fname(s)return{ToString=function()return s end}end
local function class(name,props,addr,super)
    return object({GetFName=function()return fname(name)end,
        ForEachProperty=function(fn)for _,p in ipairs(props)do if fn(p)then break end end end,
        GetSuperStruct=function()return super end},nil,addr)
end
local function property(name,kind,offset,inner,reflected,wrapper)
    -- Exact 83330635 LuaXProperty.cpp uses generic Property for IntProperty.
    return object({type=function()return wrapper or (kind=='IntProperty' and 'Property' or kind) end,GetFName=function()return fname(name)end,
        GetClass=function()return class(reflected or kind,{})end,GetOffset_Internal=function()return offset end,
        GetInner=function()return inner or property('Inner','ObjectProperty',8)end})
end
local R,view,children,captions,props,values,selected,provider,opts,calls,resolver
local function fixture(options)
    opts=options or {};children={};captions={};values=opts.values or {'0','4','7','2'};selected=opts.selected or -1;calls={}
    props={DigitWidgets_Array=property('DigitWidgets_Array',opts.arraykind or 'ArrayProperty',opts.offset or 24,
        opts.inner and property('Inner',opts.inner,8)),Digit=property('Digit',opts.digitkind or 'IntProperty',32),
        TextBlock_Digit=property('TextBlock_Digit',opts.textkind or 'ObjectProperty',40)}
    if opts.reflected then props.Digit=property('Digit','IntProperty',32,nil,'ObjectProperty')end
    if opts.scalarbinding then props.Digit=property('Digit','IntProperty',32,nil,nil,opts.scalarbinding)end
    local fields=opts.missing and {} or {props.DigitWidgets_Array,props.Digit}
    local parent
    if opts.depth then
        parent=class('Base',fields);fields={}
        for _=1,opts.depth do parent=class('Intermediate',{},nil,parent)end
    end
    local vc=class(opts.classname or 'BP_LiSPickLockWidget_View_C',fields,7000,parent)
    local bc=class('DigitWidget',{props.TextBlock_Digit},7100)
    for i=1,#values do
        captions[i]=object({IsA=function(n)return not opts.badcaption and (n=='/Script/UMG.TextBlock' or n=='/Script/UMG.Widget')end,
            GetText=function()if opts.partial and i==2 then error('caption unavailable')end;return fname(values[i])end})
        children[i]=object({GetClass=function()return bc end,IsA=function(n)return not opts.badchild and n=='/Script/UMG.Widget'end})
    end
    view=object({GetClass=function()return vc end},nil,8000)
    local array=object({type=function()return 'TArray'end,GetArrayNum=function()return opts.length or #values end},children)
    provider=function(owner,name)
        local a,p,offset,kind=_G[root](owner,name)
        check(a==meta[owner].address,'resolver returns current owner')
        check(p==meta[props[name]].address,'resolver returns current descriptor for '..name)
        check(offset==(name=='DigitWidgets_Array' and (opts.offset or 24) or name=='Digit' and 32 or 40),'reflected offset '..name)
        check(kind==(name=='DigitWidgets_Array' and 1 or name=='Digit' and 3 or 2),'reflected kind '..name)
        calls[name]=(calls[name]or 0)+1
        if name=='DigitWidgets_Array'then return array end
        if name=='Digit'then return selected end
        for i,child in ipairs(children)do if owner==child then return captions[i]end end
        error('unexpected owner')
    end
    check(R.configure(provider),'configure test provider');resolver=_G[root]
end
local function rejected(label)
    local ok,s,id=R.snapshot(view);check(not ok,label);check(type(s)=='string',label..' gives reason')
    check(not pcall(resolver,view,'Digit'),'failed snapshot releases scope')
end
local function run()
    _G.EObjectFlags={RF_ClassDefaultObject=16,RF_ArchetypeObject=32,RF_BeginDestroyed=32768,RF_FinishDestroyed=65536}
    R=require('hud.padlock_view')
    fixture();check(R.configured(),'configured state')
    local ok,s,id=R.snapshot(view)
    check(ok and s.id==8000 and id==8000,'validated numeric owner')
    check(table.concat(s.digits)== '0472' and s.selected==-1,'copies digits and native unselected state')
    check(calls.DigitWidgets_Array==1 and calls.TextBlock_Digit==4 and calls.Digit==1,'all three reflected fields')
    local function scalars(t)for _,v in pairs(t)do check(type(v)~='userdata','snapshot retains no wrapper');if type(v)=='table'then scalars(v)end end end
    scalars(s)
    check(not pcall(_G[root],view,'Digit'),'successful snapshot releases scope')
    local stale=props.DigitWidgets_Array
    fixture({values={'9','8'},selected=1}) -- same raw view/class addresses, different current descriptors
    check(meta[stale].address~=meta[props.DigitWidgets_Array].address,'reload changes current descriptor')
    local stale_proxy=property('DigitWidgets_Array','ObjectProperty',0)
    check(meta[stale_proxy].address~=meta[props.DigitWidgets_Array].address,'stale wrong-type zero-offset proxy is distinct')
    ok,s=R.snapshot(view);check(ok and table.concat(s.digits)=='98' and s.selected==1,'address reuse uses fresh metadata')
    check(ordinary==0,'cached proxy is never read')
    for _,case in ipairs({{arraykind='ObjectProperty',offset=0},{arraykind='ObjectProperty'},{inner='IntProperty'},{digitkind='ObjectProperty'},
        {textkind='IntProperty'},{offset=0},{classname='OtherView'},{badchild=true},{badcaption=true},
        {partial=true},{values={'1','12'}},{values={'x'}},{selected=4},{selected=-2},{selected=.5},
        {length=17},{length=-1},{length=1.5},{reflected=true},{scalarbinding='IntProperty'},{missing=true},{depth=17}})do fixture(case);rejected('invalid snapshot rejected')end
    for _,flag in pairs(_G.EObjectFlags)do fixture();meta[view].flags=flag;rejected('unsafe owner flags')end
    fixture();meta[view].valid=false;rejected('invalid owner')
    fixture();meta[view].address=0;rejected('zero owner address')
    fixture();meta[children[2]].valid=false;rejected('invalid child')
    fixture();meta[captions[2]].flags=16;rejected('default caption')
    fixture({depth=2});check(R.snapshot(view),'fresh bounded superclass traversal')
    -- Missing native DLL is tested without loading any real native library.
    local loadlib=package.loadlib
    package.loadlib=function()return nil,'test helper unavailable'end
    local configured_ok,configured=pcall(R.configure)
    package.loadlib=loadlib
    check(configured_ok and not configured and not R.configured(),'missing native helper remains disabled')
    rejected('snapshot without helper')
    fixture({values={}});ok,s=R.snapshot(view);check(ok and #s.digits==0,'empty pre-spawn snapshot')
    fixture({values={},selected=0});ok,s=R.snapshot(view)
    check(ok and #s.digits==0 and s.selected==0,'empty pre-spawn retains native class-default selection')
    local sixteen={};for i=1,16 do sixteen[i]='1'end
    fixture({values=sixteen,selected=15});ok,s=R.snapshot(view);check(ok and #s.digits==16,'sixteen dial bound supported')
    fixture({length=100000});local before=indexreads;rejected('oversized count');check(indexreads==before,'oversized count never indexed')
    fixture();local original=provider;local once=false
    check(R.configure(function(owner,name)
        if not once then
            once=true
            check(not R.snapshot(view),'nested snapshot rejected')
            local changed,result=pcall(R.configure,original);check(not changed or not result,'configure during scope rejected')
            local co=coroutine.create(function()return pcall(_G[root],owner,name)end)
            local resumed,accepted=coroutine.resume(co);check(resumed and not accepted,'foreign coroutine resolver rejected')
            check(not pcall(_G[root],owner,'Other'),'field whitelist')
            check(not pcall(_G[root],captions[1],'TextBlock_Digit'),'foreign child rejected')
        end
        return original(owner,name)
    end),'configure adversarial provider')
    check(R.snapshot(view),'outer scope survives refused nested operations')
    local co=coroutine.create(function()return R.snapshot(view)end);local resumed,accepted=coroutine.resume(co)
    check(resumed and accepted,'hook coroutine owns its scope')
    fixture();check(R.configure(function()error('provider failed')end),'configure throwing helper');rejected('provider exception')
    fixture();check(R.snapshot(view),'scope recovers after exception')
    fixture();_G[root]=function()error('impostor must not run')end;rejected('resolver replacement')
    fixture();check(R.configure(function()return nil,'missing helper result'end),'configure unavailable helper');rejected('missing helper result')
    fixture();check(R.configure(function(owner,name)local value=provider(owner,name);_G[root]=function()end;return value end),'configure tampering helper');rejected('in-scope resolver replacement')
    fixture();check(R.snapshot(view),'reconfiguration restores resolver')
    -- Real registered callbacks consume the same resolver, not a mocked reader.
    local hooks={}
    _G.StaticFindObject=function()return object()end
    _G.RegisterHook=function(path,fn)hooks[path:match(':([^:]+)$')]=fn end
    _G.FindAllOf=function()return {view}end
    local P=require('hud.padlock');local now=0
    P.clock=function()return now end
    P.text=function(k,p)
        if k=='padlock_code'then return p.digits end
        if k=='padlock_digit'then return p.value..':'..p.position..'/'..p.count end
        return k
    end
    fixture({values={}});P.install()
    check(hooks.SpawnDigits and hooks['Up Pressed'] and hooks.Exit,'actual event hooks registered')
    hooks.OpenMenuImplementable(view);check(not P.active(),'pre-spawn empty view remains inactive')
    fixture({values={},selected=0});hooks.OpenMenuImplementable(view)
    check(not P.active() and P.due()==nil,'class-default selection before SpawnDigits does not announce failure')
    fixture();check(P.configure_reader(provider),'callback provider configured')
    hooks.SpawnDigits(view);now=.11
    local speech=P.due();check(speech and speech:find('0, 4, 7, 2',1,true),'first opening reads current fields')
    check(speech:find('padlock_no_selection',1,true),'first opening preserves unselected dial')
    selected=1;hooks.DialFocused(view);now=.22;check(P.due()=='4:2/4','native focus callback')
    values[2]='5';hooks['Up Pressed'](view);now=.33;check(P.due()=='5:2/4','native dial callback')
    check(P.configure_reader(function()return nil,'unavailable'end),'callback helper fails closed')
    hooks['Down Pressed'](view);check(P.due()=='padlock_unavailable','read failure announces localized unavailable')
    hooks['Down Pressed'](view);check(P.due()==nil,'repeat failure stays silent')
    check(P.active() and P.current()=='padlock_unavailable' and P.help(false)=='padlock_keyboard','known view retains Home and help context')
    check(P.configure_reader(provider),'callback helper recovers');hooks.DialFocused(view);now=.44
    check(P.due()~=nil and P.current():find('0, 5, 7, 2',1,true),'later snapshot recovers')
    hooks['Cancel Pressed']();check(not P.active(),'cancel clears context')
    fixture({values={'9','0'},selected=-1});hooks.SpawnDigits(view);now=.55
    check(P.due():find('9, 0',1,true),'reopen gets new values at reused address')
    hooks.Exit();check(not P.active(),'exit clears context')
    check(ordinary==0,'no ordinary reflected field access in any test')
    local weak=setmetatable({view,children[1],captions[1],props.Digit},{__mode='v'})
    -- The provider is intentionally allowed to own fixture wrappers; release it
    -- before asking whether reader/callback state retained any engine wrapper.
    check(R.configure(function()return nil end),'release fixture provider')
    view,children,captions,props,provider,values,opts=nil,nil,nil,nil,nil,nil,nil
    original=nil
    for _,f in ipairs(files)do debug.setmetatable(f[1],f[2])end
    files={};meta={}
    collectgarbage('collect');collectgarbage('collect')
    check(next(weak)==nil,'reader and callbacks retain no wrappers after scope')
end
local success,err=xpcall(run,debug.traceback)
for _,k in ipairs(globals)do rawset(_G,k,saved[k])end
for _,k in ipairs(modules)do package.loaded[k]=loaded[k]end
for _,f in ipairs(files)do debug.setmetatable(f[1],f[2])end
package.path=saved_path
assert(success,err)
print('Padlock uncached reader: '..count..' checks passed')
return count
