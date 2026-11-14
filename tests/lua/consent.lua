-- Native ToS_PP_Widget fields and authored greeting order; consent itself is
-- NEVER activated by the reader. Actual native Enter/A dispatch needs live proof.
package.path='src/?.lua;'..package.path
local old_find,old_flags=FindAllOf,EObjectFlags
EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2,RF_ClassDefaultObject=4,RF_ArchetypeObject=8}
local count,mutations=0,0
local function check(ok,label)count=count+1;assert(ok,label)end
local function object()
    local o={valid=true,visible=true,viewport=true,alpha=1,flags=0}
    function o:IsValid()return self.valid end
    function o:IsVisible()return self.visible end
    function o:IsInViewport()return self.viewport end
    function o:HasAnyFlags(f)return self.flags&f~=0 end
    function o:GetParent()return self.parent end
    function o:GetRenderOpacity()return self.alpha end
    function o:GetAddress()return 123 end
    function o:GetFullName()return 'ToS_PP_Widget_C test' end
    return o
end
local function widget(s)
    local w=object();w.raw=s
    function w:GetText()return {ToString=function()return self.raw end}end
    return w
end
local view=object();view.PP=false;view.ToS=false;view.Ok_on=false
view.TextBlock_PP=widget('I have read and understand the Privacy Policy')
view.TextBlock_ToS=widget('I accept the Terms of Service')
view.TextBlock_Download=widget('Ok')
view.TextBlock_2=widget('Hello, please accept our ')
view.TextButton_ToS=widget('Terms of Service');view.TextBlock_477=widget(' and ')
view.TextButton_PP=widget('Privacy Policy');view.TextBlock_480=widget('');view.TextBlock_1=widget('')
view.Button_0=object();view.Button_0.GetIsEnabled=function()return true end -- NOT the native gate
local calls={}
view['View TOS']=function(self)check(self==view,'Terms receiver');calls[#calls+1]='terms'end
view['View PP']=function(self)check(self==view,'Privacy receiver');calls[#calls+1]='privacy'end
local function forbidden()mutations=mutations+1;error('Unrequested consent mutation')end
for _,name in ipairs({'Confirm Pressed','Check PP','Check TOS','Click OK','OnCloseWidget','On_OK','Off_OK','SetKeyboardFocus'})do view[name]=forbidden end
view.CheckBox_PP=object();view.CheckBox_ToS=object()
view.CheckBox_PP.SetIsChecked=forbidden;view.CheckBox_ToS.SetIsChecked=forbidden
view.CheckBox_PP.SetKeyboardFocus=forbidden;view.CheckBox_ToS.SetKeyboardFocus=forbidden
FindAllOf=function(c)return c=='ToS_PP_Widget_C' and {view} or {}end
package.loaded['menus.consent']=nil
local C=require('menus.consent');local en=require('lang.en');C.text=function(k)return en[k]end
local errors={};C.log=function(s)errors[#errors+1]=s end
local tr=require('menus.tracker').new()
-- Polls from unrelated menu gates must not consume narration transitions.
view.TextBlock_PP.raw='$GT_Mobile_UI_Menu_PP_accept'
local pending=C.snapshot();check(pending.silent and tr:update(pending)==nil,'Unlocalized consent stays silent and modal')
view.TextBlock_PP.raw='I have read and understand the Privacy Policy'
local s=C.snapshot();C.snapshot();C.snapshot()
local text,_,interrupt=tr:update(s)
check(text and text:find('Hello, please accept our Terms of Service and Privacy Policy',1,true)==1,'Native greeting order, even after initialization wait')
check(text:find('I have read and understand the Privacy Policy, not checked',1,true)~=nil,'Privacy state read')
check(text:find('I accept the Terms of Service, not checked',1,true)~=nil,'Terms state read')
check(text:find('Ok, unavailable',1,true)~=nil,'Ok_on overrides apparently enabled button')
check(interrupt==false,'Automatic first-run dialog queues behind startup notices')
check(not text:find('Enter',1,true) and not text:find('Press',1,true),'No automatic mod instructions')
check(s.reread==text,'Deliberate reread has full current context')
for _=1,20 do check(tr:update(C.snapshot())==nil,'Unchanged consent does not repeat')end
view.PP=true -- native event result, NOT a reader action
C.snapshot();s=C.snapshot();text,_,interrupt=tr:update(s)
check(text=='I have read and understand the Privacy Policy, checked','Read only changed checkbox after native action')
check(interrupt==true,'User state change interrupts queued speech')
check(s.reread:find('I accept the Terms of Service, not checked',1,true)~=nil,'Reread retains unchanged checkbox')
view.ToS=true;view.Ok_on=true
s=C.snapshot();text=tr:update(s)
check(text=='I accept the Terms of Service, checked, Ok, available','Terms and confirmation availability changes both announced')
view.PP=false;view.Ok_on=false -- native mouse uncheck is also faithfully read
text=tr:update(C.snapshot())
check(text=='I have read and understand the Privacy Policy, not checked, Ok, unavailable','Read native reversal without inventing enabled state')
local keys=C.help(false);local pad=C.help(true)
check(keys:find('1 opens the Terms of Service',1,true) and keys:find('2 opens the Privacy Policy',1,true),'Explicit keyboard document help')
check(pad:find('X opens the Terms of Service',1,true) and pad:find('Y opens the Privacy Policy',1,true),'Help matches native controller bindings')
check(not keys:find('D%-pad') and not pad:find('Enter',1,true),'Help only names active device')
check(keys:find('do not toggle them off',1,true) and pad:find('do not toggle them off',1,true),'Native check-only behavior disclosed')
check(C.open_document(1)==true and calls[1]=='terms','1 calls native View TOS')
check(C.open_document(2)==true and calls[2]=='privacy','2 calls native View PP')
check(C.open_document(3)==true and #calls==2,'Other world action numbers inert inside consent')
check(mutations==0 and not view.PP and view.ToS and not view.Ok_on,'Reader/help/link access never accepts, checks or enables consent')
view.TOSorPP=object()
s=C.snapshot();check(s.label==en.consent_document_unreadable,'Embedded viewer does not leak underlying consent state')
local handled,message=C.open_document(1);check(handled and message==en.consent_document_open and #calls==2,'No second document while native child is open')
view.TOSorPP=nil
view['View TOS']=function()error('native document test failure')end
handled,message=C.open_document(1);check(handled and message~=nil,'Native link failure is reported, not silently accepted')
view.visible=false;check(C.snapshot()==nil and C.help(false)==nil and C.open_document(2)==false,'Closed consent yields to existing controls')
view.visible=true;view.viewport=false;check(C.snapshot()==nil,'Detached dialog rejected')
view.viewport=true;view.flags=4;check(C.snapshot()==nil,'Consent CDO rejected')
view.flags=8;check(C.snapshot()==nil,'Consent archetype rejected')
view.flags=1;check(C.snapshot()==nil,'Destroying consent rejected');view.flags=0
view.parent=object();view.parent.visible=false;check(C.snapshot()==nil,'Hidden ancestor rejected');view.parent=nil
view.alpha=0;check(C.snapshot()==nil,'Transparent consent rejected');view.alpha=1
view.TextBlock_1.visible=false;view.TextBlock_1.raw='Text Block'
check(C.snapshot().label~=nil,'Hidden greeting fragments do not leak designer placeholders')
view.TextBlock_1.visible=true;view.TextBlock_1.raw=''

package.loaded['menus.main_menu']=nil
local menu=require('menus.main_menu');s=menu.snapshot()
check(s and s.screen:find('consent@',1,true)==1,'Actual menu adapter discovers standalone first-run dialog')
local f=assert(io.open('src/main.lua','r'));local main=f:read('*a');f:close()
check(main:find('consent.open_document(n)',1,true) and main:find('consent.help(gamepad)',1,true),'Number dispatch and contextual help wired')
check(main:find('return snap.reread or',1,true),'Home uses full current consent state')
check(not main:find("bind_key(Key.RETURN",1,true) and not main:find("bind_key(Key.ENTER",1,true),'No added confirm binding that could accept twice')
-- Execute the actual registered number callbacks, including modal ownership.
local start=assert(main:find('for n,k in ipairs({Key.ONE,Key.TWO,Key.THREE,Key.FOUR}) do',1,true))
local finish=assert(main:find('bind_key(Key.UP_ARROW',start,true))
local callbacks={};local top=s;local spoken={}
view['View TOS']=function(self)check(self==view,'Registered Terms receiver');calls[#calls+1]='terms'end
local env=setmetatable({Key={ONE=1,TWO=2,THREE=3,FOUR=4},consent=C,
    bind_key=function(k,fn)callbacks[k]=fn end,on_game=function(fn)return fn end,
    menu_snapshot=function()return top end,in_menu=function()return top~=nil end,
    say=function(t)spoken[#spoken+1]=t end}, {__index=_G})
assert(load(main:sub(start,finish-1),'registered consent number keys','t',env))()
local before=#calls;callbacks[1]();callbacks[2]()
check(#calls==before+2 and calls[#calls-1]=='terms' and calls[#calls]=='privacy','Registered keys dispatch native links in the actual consent context')
top={screen='popup',label='A higher-priority native dialog'}
callbacks[1]();callbacks[2]()
check(#calls==before+2,'A popup above consent blocks link actions behind it')
check(mutations==0,'All registered readers remain non-mutating')
local changed_screen=require('menus.tracker').new()
changed_screen:update({screen='old',index=0,label='A, B',rows={'A','B'}})
check(changed_screen:update({screen='new',index=0,label='A, C',rows={'A','C'}})=='A, C','New screen without a heading still reads all rows, not just a delta')
FindAllOf,EObjectFlags=old_find,old_flags
package.loaded['menus.main_menu']=nil;package.loaded['menus.consent']=nil
print('Consent dialog: '..count..' checks passed')
return count
