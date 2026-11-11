-- Engine-free execution of the actual reader, resolver and provider protocol.
package.path='src/?.lua;src/?/init.lua;'..package.path
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local files={}
local inside,strict,outside=false,false,0
local indexreads=0
local address=1000
local function object(methods,fields)
    local u=assert(io.tmpfile());files[#files+1]={u,debug.getmetatable(u)}
    address=address+16;local a=address
    local m={type=function()return 'UObject'end,IsValid=function()return true end,GetAddress=function()return a end,
        IsA=function(name)return name=='/Script/UMG.Widget'end,
        IsInViewport=function()return true end,IsVisible=function()return true end}
    for k,v in pairs(methods or {})do m[k]=v end
    debug.setmetatable(u,{__name=m.type(),__index=function(_,k)
        if strict and not inside then outside=outside+1;error('object access outside Tick: '..tostring(k))end
        if m[k] then return function(_,...)return m[k](...)end end
        if type(k)=='number' then indexreads=indexreads+1 end
        return (fields or {})[k]
    end})
    return u
end
local function fname(s)return {ToString=function()return s end}end
local function property(name,kind)
    return object({type=function()return kind end,GetFName=function()return fname(name)end,
        GetClass=function()return {GetFName=function()return fname(kind)end}end,
        GetOffset_Internal=function()return 24 end,
        GetInner=function()return property('inner','ObjectProperty')end})
end
local function class(name,props)
    return object({GetFName=function()return fname(name)end,
        ForEachProperty=function(fn)for _,p in ipairs(props)do if fn(p) then break end end end,
        GetSuperStruct=function()return nil end})
end
local view,buttons,captions,visible,goodarray,oldarray,viewfields
local clicks,helpercalls,reads,now=0,0,0,0
local viewvisible=true
local M,provider,hooks,utterances
local hookfn
local function tick(t,v)
    now=t or now;inside=true
    local ok,err=pcall(hookfn,v or view)
    inside=false;assert(ok,err)
end
local function setup(mode,enabled)
    strict=false;outside=0;inside=false;now=0;clicks=0;helpercalls=0;reads=0;indexreads=0
    captions={'Nathan','Drone'};visible={true,true};buttons={};hooks={};utterances={};viewvisible=true
    local ap=property('DialogButtons_Array',mode=='wrongmetadata' and 'ObjectProperty' or 'ArrayProperty')
    local tp=property('DialogText','ObjectProperty')
    local vc=class('BP_LiSDialogWidget_View_C',{ap})
    local bc=class('Button',{tp})
    for i=1,2 do
        local cached=captions[i]
        local tx=object({GetText=function()if mode=='partialtext' and i==1 then error('one broken caption')end;return fname(cached)end})
        buttons[i]=object({GetClass=function()return bc end,IsVisible=function()if mode=='partialvisible' and i==1 then error('one broken visibility')end;return visible[i] end,
            ClickButton=function()clicks=clicks+1;if M.onClick then M.onClick()end end}, {DialogText=mode=='badtext' and 99 or tx})
    end
    local function array(failing)
        local a=object({type=function()return 'TArray'end,GetArrayNum=function()return 2 end,
            ForEach=function(fn)
                for i,b in ipairs(buttons)do local value=failing and 12345 or b;fn(i,{get=function()return value end})end
            end},buttons)
        return a
    end
    goodarray=array(false)
    oldarray=mode=='missing' and object({}, {ForEach=object({type=function()return 'TrivialObject'end})}) or array(mode=='numeric')
    viewfields={DialogButtons_Array=oldarray}
    view=object({GetClass=function()return vc end,IsMajorChoice=function()return false end,IsVisible=function()return viewvisible end},viewfields)
    StaticFindObject=function()return object()end
    RegisterHook=function(path,fn)hooks[path]=fn;if path:match(':Tick$')then hookfn=fn end end
    FindAllOf=function()return {view}end
    package.loaded['dialogue.choices']=nil;package.loaded['dialogue.uncached']=nil
    M=require('dialogue.choices');M.clock=function()return now end
    M.text=function(k,p) if k=='choice_option'then return p.text elseif k=='choice_list'then return p.options end return k end
    M.say=function(s)utterances[#utterances+1]=s end
    provider=function(owner,name)
        helpercalls=helpercalls+1
        assert(inside,'provider outside Tick')
        local a,p,offset,kind=_G.__lisr_reflection_resolve_83330635(owner,name)
        assert(a>0 and p>0 and offset==24 and kind==(name=='DialogButtons_Array' and 1 or 2))
        if name=='DialogButtons_Array'then return goodarray end
        for i,b in ipairs(buttons)do if b==owner then
            -- This is not button.DialogText: fresh metadata controls text independently.
            return object({GetText=function()return fname(captions[i])end})
        end end
        error('foreign owner')
    end
    if enabled then assert(M.configure_uncached({enabled=true,provider=provider}))end
    assert(M.install());strict=enabled
    return M
end
local function announce()now=now+0.2;check(M.due(false)~=nil,'announced')end
setup('normal',false);tick(0);announce();check(M.options()[1].text=='Nathan','normal reader');check(helpercalls==0,'default off zero helper');check(M.choose(1),'original activation');check(clicks==1,'original click')
setup('missing',false);tick(0);check(M.options()==nil,'original missing method failure')
local failed,why=pcall(function()oldarray:ForEach(function()end)end)
check(not failed and tostring(why):find('TrivialObject',1,true),'exact callable TrivialObject failure shape')
setup('numeric',false);tick(0);check(M.options()==nil,'original numeric inner failure')
for _,mode in ipairs({'numeric','missing'})do
    setup(mode,true);tick(0);announce();check(M.options()[2].text=='Drone',mode..' recovered')
    check(helpercalls==3,'array and both fresh text reads')
    check(M.choose(2),'queue scalar intent');check(clicks==0,'not clicked outside Tick')
    tick(0.21);check(clicks==1,'consume before throttle');check(outside==0,'no outside object reads')
end
setup('normal',true)
-- Deliberately stale cached text: only fresh DialogText gives this caption.
captions[1]='Fresh';tick(0);announce();check(M.options()[1].text=='Fresh','fresh caption')
check(not require('dialogue.uncached').scope(view,function()error('test cleanup')end),'scope error contained')
check(not pcall(_G.__lisr_reflection_resolve_83330635,view,'DialogButtons_Array'),'resolver outside scope rejects')
check(require('dialogue.uncached').scope(view,function()return true end),'scope cleanup')
setup('normal',true);M.configure_uncached({enabled=true,provider=function()return nil,'unavailable'end});tick(0);announce();check(M.options()[1].text=='Nathan','unavailable helper original fallback');check(M.choose(1),'fallback queued');tick(0.21);check(clicks==1,'working fallback activates')
setup('normal',true);_G.__lisr_reflection_resolve_83330635=function()error('must not execute impostor')end;tick(0);announce();check(M.options()[1].text=='Nathan','identity mismatch original fallback');check(helpercalls==0,'impostor never called')
setup('numeric',true);M.configure_uncached({enabled=true,provider=function()return nil end});tick(0);check(M.options()==nil,'no fabricated options on double failure')
for _,reason in ipairs({'expired','wrongview','caption','hidden','hiddenview'})do
    setup('normal',true);tick(0);announce();check(M.choose(1),'intent accepted '..reason)
    local other
    if reason=='caption'then captions[1]='Changed'elseif reason=='hidden'then visible[1]=false elseif reason=='hiddenview'then viewvisible=false
    elseif reason=='wrongview'then other=object({IsMajorChoice=function()return false end},viewfields)end
    tick(reason=='expired' and 3 or 0.21,other)
    check(clicks==0,reason..' not activated');check(#utterances>0,reason..' honest failure');check(outside==0,reason..' no outside read')
end
setup('normal',true);tick(0);announce();check(M.choose(1),'reentrant intent');M.onClick=function()check(not M.choose(1),'reentrant choose refused');hookfn(view)end;tick(0.21);check(clicks==1,'reentrant single click')
setup('normal',true);tick(0);announce();check(M.choose(1),'pending before lifecycle clear');M.clear('destruct');tick(0.21);check(clicks==0,'destruct cancels pending')
setup('normal',true);tick(0);announce();now=4;M.tick();check(M.options()==nil,'no-Tick expiry clears scalar snapshot');check(outside==0,'poll expiry reads no objects')
setup('normal',true);tick(0);announce();captions[1]='New list';tick(0.3);check(not M.choose(1),'unannounced replacement rejected');check(clicks==0,'no unannounced click');check(M.current(false)~=nil,'Home announces current snapshot');check(M.choose(1),'Home snapshot can queue');tick(0.31);check(clicks==1,'Home snapshot activated')
setup('badtext',false);tick(0);check(M.options()==nil,'old DialogText corruption reproduced')
setup('badtext',true);tick(0);announce();check(M.options()[1].text=='Nathan','fresh DialogText repairs old field failure');check(M.choose(1),'fresh text selection queued');tick(0.21);check(clicks==1,'fresh text activation works')
setup('wrongmetadata',true);tick(0);announce();check(M.options()[1].text=='Nathan','wrong metadata rejected with original fallback');check(helpercalls==1,'bad metadata stopped at array')
setup('normal',true)
M.configure_uncached({enabled=true,provider=function()return object({type=function()return 'TArray'end,GetArrayNum=function()return 5 end},buttons)end})
tick(0);check(indexreads==0,'oversized array never indexed');check(M.options()~=nil,'oversized helper preserves original')
setup('normal',true);tick(0);announce();check(M.choose(1),'intent before scalar expiry');now=3;M.tick();check(clicks==0,'scalar expiry no click');check(#utterances>0,'scalar expiry speaks failure');check(outside==0,'scalar expiry no object reads')
setup('normal',true);tick(0);announce();check(M.choose(1),'intent before snapshot expiry');now=1.1;M.tick();check(clicks==0,'snapshot expiry no click');check(#utterances>0,'snapshot expiry speaks before intent timeout');check(outside==0,'snapshot expiry no object reads')
setup('normal',true);inside=true
check(require('dialogue.uncached').scope(view,function()
    check(not pcall(_G.__lisr_reflection_resolve_83330635,view,'OtherProperty'),'whitelist rejects')
    check(not pcall(_G.__lisr_reflection_resolve_83330635,buttons[1],'DialogButtons_Array'),'wrong owner rejected')
    check(not pcall(require('dialogue.uncached').caption,buttons[1]),'unregistered button rejected')
end),'negative resolver scope');inside=false
-- Parent review: unchanged announced content may move to a new view silently.
local function replacement()
    inside=true;local c=view:GetClass();inside=false
    return object({GetClass=function()return c end,IsMajorChoice=function()return false end},viewfields)
end
setup('normal',true);tick(0);announce();local newview=replacement();tick(0.3,newview)
check(M.due(false)==nil,'identical replacement remains silent');check(M.choose(1),'silent replacement eligible without Home');tick(0.31,newview);check(clicks==1,'new key selects replacement')
setup('normal',true);tick(0);announce();check(M.choose(1),'old-view intent queued');newview=replacement();tick(0.3,newview)
check(clicks==0 and #utterances>0,'queued old-view intent rejected');check(M.due(false)==nil,'replacement still silent after rejection');check(M.choose(1),'future key eligible on replacement');tick(0.31,newview);check(clicks==1,'only future key activates replacement')
setup('normal',true);tick(0);newview=replacement();tick(0.3,newview);check(not M.choose(1),'never-announced content not inherited')
for _,mode in ipairs({'partialtext','partialvisible'})do
    setup(mode,true);M.configure_uncached({enabled=true,provider=function()return nil,'helper unavailable'end})
    tick(0);announce();local opts=M.options()
    check(#opts==1 and opts[1].slot==2 and opts[1].text=='Drone',mode..' preserves valid fallback slot')
    check(M.choose(1),mode..' valid fallback queues');tick(0.21);check(clicks==1,mode..' valid fallback selects');check(outside==0,mode..' remains inside Tick')
end
-- Initialization is on main state; actual resolver works on a hook coroutine.
setup('missing',true);local co=coroutine.create(function()tick(0)end);check(coroutine.resume(co),'coroutine hook works');announce();check(M.options()~=nil,'coroutine capture')
-- A different coroutine cannot use an active scope, and scope retains no state afterwards.
local U=require('dialogue.uncached');inside=true
check(U.scope(view,function()
    local foreign=coroutine.create(function()return pcall(_G.__lisr_reflection_resolve_83330635,view,'DialogButtons_Array')end)
    local resumed,accepted=coroutine.resume(foreign);check(resumed and not accepted,'cross-thread resolver refused')
end),'scope remains usable');inside=false
check(not pcall(_G.__lisr_reflection_resolve_83330635,view,'DialogButtons_Array'),'no scope retained')
M.configure_uncached(nil);check(not U.enabled,'explicit disable')
strict=false
for _,f in ipairs(files)do debug.setmetatable(f[1],f[2]);f[1]:close()end
print(string.format('uncached reader: %d executed checks passed',checks))
