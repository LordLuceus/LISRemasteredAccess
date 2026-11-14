-- Fields, active splash indices and alpha shapes from build11330282's cooked
-- SplashScreenController and ChoiceDisclaimer_Widget. Native display timings
-- are not simulated as acceptance of real startup/hook ordering.
package.path='src/?.lua;'..package.path
local old_find,old_flags=FindAllOf,EObjectFlags
EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2,RF_ClassDefaultObject=4,RF_ArchetypeObject=8}
local count,serial,forbidden=0,0,0
local function check(ok,label)count=count+1;assert(ok,label)end
local function banned()forbidden=forbidden+1;error('Notice reader must not mutate the game')end
local function object(parent)
    serial=serial+1
    local o={id=serial,name='Widget_'..serial,valid=true,visible=true,viewport=false,alpha=1,parent=parent,flags=0}
    function o:IsValid()return self.valid end
    function o:IsVisible()return self.visible end
    function o:IsInViewport()return self.viewport end
    function o:HasAnyFlags(f)return self.flags & f ~= 0 end
    function o:GetRenderOpacity()return self.alpha end
    function o:GetParent()return self.parent end
    function o:GetAddress()return self.id end
    function o:GetFullName()return self.name end
    for _,f in ipairs({'SetText','SetVisibility','Skip','ChangeSplash','Cleanup','PauseMenu','UnPauseMenu','PlayAnimation','SetRenderOpacity'})do o[f]=banned end
    return o
end
local function text(parent,value)
    local o=object(parent);o.raw=value;o.ColorAndOpacity={SpecifiedColor={A=1}}
    function o:GetText()return {ToString=function()return self.raw end}end
    return o
end
local canvas=object()
local splash=object();splash.viewport=true;splash.SplashIndex=0;splash.Timer=2;splash.CanSkip=true
for _,name in ipairs({'Disclaimer','Middleware','HealthSafety','SaveGameIcon'}) do splash[name]=object(canvas)end
splash.DisclaimerText=text(splash.Disclaimer,'Fiction notice.')
splash.CopyrightText=text(splash.Disclaimer,'Copyright notice.')
splash.MiddlewareText=text(splash.Middleware,'Platform-specific middleware notice.')
splash.WarningText=text(splash.HealthSafety,'Health warning.')
splash.AutosaveText=text(splash.SaveGameIcon,'Localized autosave notice.')
splash.FGImage_1=object(canvas);splash.FGImage_1.ColorAndOpacity={A=0}
local story=object();story.DisclaimerTimer=0;story.PlayedFadeOut=false
story.DisclaimerText=text(canvas,'Story choices. Choose wisely...')
story.DisclaimerText.ColorAndOpacity.SpecifiedColor.A=0
local titles={}
FindAllOf=function(class)
    if class=='SplashScreenController_C' then return {splash} end
    if class=='ChoiceDisclaimer_Widget_C' then return {story} end
    if class=='BP_LiS_Main_Menu_Widget_C' then return titles end
    return {}
end
package.loaded['menus.notices']=nil
local N=require('menus.notices');local errors={};N.log=function(s)errors[#errors+1]=s end
local Tracker=require('menus.tracker')
local tr=Tracker.new()
local function poll()
    local s=N.snapshot();local words,fallback,interrupt=tr:update(s)
    check(not fallback,'Blank/hidden notices must not announce an unlabelled menu')
    return s,words,interrupt
end
local s,words=poll()
check(s.silent and not words,'Logo page is silent but still covers underlying menus')
splash.SplashIndex=1;splash.DisclaimerText.raw='$GT_Menus_Splashes_DISCLAIMER'
s,words=poll();check(s.silent and not words,'Wait for native localization, never speak tokens')
splash.DisclaimerText.raw='Fiction notice.';splash.CopyrightText.ColorAndOpacity.SpecifiedColor.A=0
s,words=poll();check(s.silent and not words,'Wait for both displayed blocks, not an incomplete combined readout')
splash.CopyrightText.ColorAndOpacity.SpecifiedColor.A=1;splash.FGImage_1.ColorAndOpacity.A=1
s,words=poll();check(s.silent and not words,'Opaque black overlay is not a visible notice')
splash.FGImage_1.ColorAndOpacity.A=.5
local interrupt;s,words,interrupt=poll()
check(words=='Fiction notice. Copyright notice.' and interrupt==false,'Localized disclaimer and copyright queued once')
check(tr:current()==words,'Current visible text available for deliberate reread')
for i=1,20 do local _,t=poll();check(t==nil,'Repeated samples stay silent '..i)end
splash.FGImage_1.ColorAndOpacity.A=1;poll()
splash.FGImage_1.ColorAndOpacity.A=0;s,words=poll()
check(not words and tr:current()=='Fiction notice. Copyright notice.','A temporary fade does not repeat the same presentation')
splash.SplashIndex=2;splash.Middleware.visible=false
s,words=poll();check(s.silent and not words,'Current index alone does not authorize a hidden panel')
splash.Middleware.visible=true;canvas.alpha=0
s,words=poll();check(s.silent and not words,'Ancestor render opacity is respected')
canvas.alpha=1;canvas.visible=false
s,words=poll();check(s.silent and not words,'Hidden ancestor is respected')
canvas.visible=true
s,words,interrupt=poll();check(words==splash.MiddlewareText.raw and interrupt==false,'Read actual platform text, not a replacement token')
splash.SplashIndex=3;s,words=poll();check(words=='Health warning.','Health page only, no hidden sibling text')
splash.SplashIndex=4;s,words=poll();check(words=='Localized autosave notice.','Autosave notice')
for _,index in ipairs({0,5,6,7,8})do splash.SplashIndex=index;s,words=poll();check(s.silent and not words,'No invented text/logo page '..index)end
splash.viewport=false
check(N.snapshot()==nil,'Removed splash does not remain readable')
story.viewport=true
s,words=poll();check(s.silent and not words,'Story alpha0 stays silent despite Visible flag')
story.DisclaimerText.ColorAndOpacity.SpecifiedColor.A=1
s,words,interrupt=poll();check(words=='Story choices. Choose wisely...' and interrupt==false,'Actual story widget, not sequence dialog text')
local first_id=s.screen
s,words=poll();check(not words,'Story once per presentation')
story.DisclaimerText.ColorAndOpacity.SpecifiedColor.A=0;poll()
story.DisclaimerText.ColorAndOpacity.SpecifiedColor.A=1;s,words=poll();check(not words,'Story fade/recovery does not duplicate')
story.viewport=false;poll();story.viewport=true
s,words=poll();check(s.screen~=first_id and words~=nil,'Later episode beginning repeats the notice, even with reused address')
story.flags=4;check(N.snapshot()==nil,'CDO excluded');story.flags=8;check(N.snapshot()==nil,'Archetype excluded')
story.flags=1;check(N.snapshot()==nil,'Destroying instance excluded');story.flags=0
story.viewport=false;splash.viewport=true;splash.SplashIndex=3
splash.alpha=0;s,words=poll();check(s.silent and not words,'Owner opacity also gates native text')
splash.alpha=1;splash.WarningText.alpha=0;s,words=poll();check(s.silent and not words,'Text render opacity also gates color alpha')
splash.WarningText.alpha=1
check(forbidden==0 and splash.Timer==2 and splash.CanSkip and story.DisclaimerTimer==0 and not story.PlayedFadeOut,'No timer, pause, skip, input or animation changes')
check(#errors==0,'All expected native field reads succeeded')

-- Real menu adapter integration: notices and silent gaps precede title/menu
-- content. Automatic title speech queues; normal menu navigation interrupts.
local title=object();title.viewport=true;title.CanAdvance=true
title.TapToStart=text(nil,'Click To Start');titles={title}
package.loaded['menus.main_menu']=nil
local Menu=require('menus.main_menu')
splash.SplashIndex=0
check(Menu.snapshot().silent,'Do not leak Click To Start through a logo/fade gap')
splash.SplashIndex=3
check(Menu.snapshot().label=='Health warning.','Menu adapter exposes visible notice for Home')
local q=Tracker.new();local queue={}
local function emit(snap)
    local t,_,stop=q:update(snap)
    if t then if stop~=false then queue={} end;queue[#queue+1]=t end
end
emit(Menu.snapshot());splash.SplashIndex=4;emit(Menu.snapshot())
splash.viewport=false;local title_snap=Menu.snapshot();emit(title_snap)
check(title_snap.screen=='title' and title_snap.interrupt==false and #queue==3,'Automatic title does not cancel either queued notice')
emit({screen='main-menu',index=0,label='Continue'})
check(#queue==1 and queue[1]=='Continue','Normal menu navigation cancels queued notices')
local f=assert(io.open('src/main.lua','r'));local main=f:read('*a');f:close()
check(main:find('local text,fallback,interrupt=tracker:update(snap)',1,true) and main:find('say(text,interrupt~=false)',1,true),'Main speech dispatcher honors tracker queue policy')
check(main:find('speech.say(text or last_speech,true)',1,true),'Deliberate Home reread still interrupts')

-- Unexpected native failures are logged once, not swallowed every poll.
story.viewport=true;story.DisclaimerText.GetText=function()error('test text read failure')end
N.snapshot();N.snapshot();check(#errors==1 and errors[1]:find('notice_error=',1,true),'Read failure reported once')
FindAllOf,EObjectFlags=old_find,old_flags
package.loaded['menus.main_menu']=nil;package.loaded['menus.notices']=nil
print('Startup notices: '..count..' checks passed')
return count
