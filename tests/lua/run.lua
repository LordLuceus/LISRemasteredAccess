-- Offline Lua tests for game-independent mod logic. Run from the repository root:
--   artifacts\lua-5.4.7\lua54.exe tests\lua\run.lua
package.path="src/?.lua;tests/lua/?.lua;"..package.path
local failures,count=0,0
local function check(name,cond,detail)
    count=count+1
    if not cond then failures=failures+1;print("FAIL "..name..(detail and (": "..detail) or "")) end
end
local logged={}
local function fresh_l10n()
    package.loaded["core.localization"]=nil
    local l=require("core.localization")
    logged={}
    l.set_logger(function(line)logged[#logged+1]=line end)
    return l
end

-- Localization: English default and substitution.
do
    local l=fresh_l10n()
    check("default language",l.language()=="en")
    check("plain key",l.text("arrived")=="Test destination reached.")
    check("substitution",l.text("starting",{cancel_key="F8"})=="Starting the navigation test. F8 stops it.")
end
-- Missing key: marked placeholder, logged once, never empty.
do
    local l=fresh_l10n()
    local a=l.text("no_such_key");local b=l.text("no_such_key")
    check("missing key marked",a=="[missing text: no_such_key]",a)
    local n=0;for _,line in ipairs(logged) do if line:find("localization_missing key=no_such_key",1,true) then n=n+1 end end
    check("missing key logged once",n==1,tostring(n))
end
-- Missing placeholder value stays visible and is logged.
do
    local l=fresh_l10n()
    local s=l.text("starting",{})
    check("missing param visible",s:find("{cancel_key}",1,true)~=nil,s)
    check("missing param logged",logged[1] and logged[1]:find("starting.cancel_key",1,true)~=nil,tostring(logged[1]))
end
-- Language fallback: exact, base language, then English; English fills gaps.
do
    package.loaded["lang.fr"]={arrived="Destination de test atteinte."}
    package.loaded["lang.pt_br"]={arrived="Destino alcançado."}
    local l=fresh_l10n()
    check("exact language",l.set_language("fr")=="fr")
    check("translated key",l.text("arrived")=="Destination de test atteinte.")
    check("untranslated key falls back to English",l.text("stopped")=="Navigation test stopped.")
    check("region code exact",l.set_language("pt-BR")=="pt-br")
    check("region text",l.text("arrived")=="Destino alcançado.")
    check("region falls back to base",l.set_language("fr-CA")=="fr")
    check("unknown language is English",l.set_language("xx")=="en")
    check("nil language is English",l.set_language(nil)=="en")
    check("English after fallback",l.text("arrived")=="Test destination reached.")
    package.loaded["lang.fr"]=nil;package.loaded["lang.pt_br"]=nil
end
-- Every English placeholder must be one the mod knows how to fill.
do
    local known={menu_key=true,cancel_key=true,value=true,confirm_key=true,back_key=true}
    local en=require("lang.en")
    for key,s in pairs(en) do
        check("string type "..key,type(s)=="string")
        for name in s:gmatch("{([%w_]+)}") do check("known placeholder "..key.."."..name,known[name]==true) end
    end
end
-- Controls: keyboard by default, controller names only in controller mode,
-- keyboard fallback when a command has no controller binding.
do
    package.loaded["core.controls"]=nil
    local c=require("core.controls")
    check("keyboard default",c.name("cancel")=="F8")
    c.commands.test_cmd={keyboard="Page Up",controller="D-pad left"}
    c.set_gamepad(true)
    check("controller name",c.name("test_cmd")=="D-pad left")
    check("keyboard fallback in controller mode",c.name("cancel")=="F8")
    c.set_gamepad(false)
    check("keyboard name",c.name("test_cmd")=="Page Up")
    check("unknown command marked",c.name("nope"):find("unknown command",1,true)~=nil)
    -- refresh() follows the game flag, and keeps the mode when unreadable.
    local fake={Pawn={IsValid=function()return true end,IsGamepadOn=true}}
    check("refresh reports change",c.refresh(fake)==true and c.using_gamepad())
    check("refresh no change",c.refresh(fake)==false)
    local broken={Pawn={IsValid=function()error("gone")end}}
    c.refresh(broken)
    check("unreadable keeps mode",c.using_gamepad()==true)
    c.commands.test_cmd=nil;c.set_gamepad(false)
end

-- Menu tracker: speaks on screen/option/label change only, never repeats.
do
    package.loaded["menus.tracker"]=nil
    local t=require("menus.tracker").new()
    check("no menu says nothing",t:update(nil)==nil)
    check("title spoken",t:update({screen="title",index=0,label="Click To Start"})=="Click To Start")
    check("same snapshot silent",t:update({screen="title",index=0,label="Click To Start"})==nil)
    check("new screen spoken",t:update({screen="main",index=0,label="Episodes"})=="Episodes")
    check("next option spoken",t:update({screen="main",index=1,label="Settings"})=="Settings")
    check("repeat silent",t:update({screen="main",index=1,label="Settings"})==nil)
    check("label change spoken",t:update({screen="main",index=1,label="Settings (new)"})=="Settings (new)")
    local text,fallback=t:update({screen="main",index=2,label=nil})
    check("unlabelled reported",text==nil and fallback==true)
    check("menu gone resets",t:update(nil)==nil)
    check("same option after reopen spoken",t:update({screen="main",index=2,label="Extras"})=="Extras")
    check("other screen same index spoken",t:update({screen="sub",index=2,label="Extras"})=="Extras")
end
-- Snapshot reader against fake game objects (no game needed).
do
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local function obj(fields)
        local o=fields or {}
        o.IsValid=function()return true end
        o.HasAnyFlags=function()return false end
        return o
    end
    local function textw(s)return obj({GetText=function()return {ToString=function()return s end}end})end
    local function option(label)return obj({Button_Text=textw(label)})end
    local opts={option("Episodes"),option("Settings"),option("Extras")}
    local screen=obj({IsVisible=function()return true end,CurrentInteractableIndex=1,CurrentInteractable=opts[2],
        InteractablesArray=opts,GetClass=function()return {GetFName=function()return {ToString=function()return "BP_LiS_MainMenu_Start_Widget_C" end}end}end,
        GetAddress=function()return 0x1234 end})
    local title=obj({IsInViewport=function()return true end,LastCreatedWidget=screen,CanAdvance=true,
        TapToStart=obj({IsVisible=function()return true end,GetText=function()return {ToString=function()return "Click To Start" end}end})})
    _G.FindAllOf=function(name)return name=="BP_LiS_Main_Menu_Widget_C" and {title} or {} end
    package.loaded["menus.main_menu"]=nil
    local mm=require("menus.main_menu")
    local s=mm.snapshot()
    check("reads highlighted option",s and s.label=="Settings" and s.index==1,s and tostring(s.label))
    screen.CurrentInteractable=nil;screen.CurrentInteractableIndex=2
    s=mm.snapshot()
    check("falls back to option list",s and s.label=="Extras",s and tostring(s.label))
    screen.IsVisible=function()return false end
    s=mm.snapshot()
    check("title prompt when no screen",s and s.screen=="title" and s.label=="Click To Start")
    title.CanAdvance=false
    check("nothing before title accepts input",mm.snapshot()==nil)
    title.IsInViewport=function()return false end
    check("nothing when title gone",mm.snapshot()==nil)
    _G.FindAllOf=nil;_G.EObjectFlags=nil
end
-- Settings rows: name plus value, value-only on change, percent formatting.
do
    package.loaded["menus.tracker"]=nil
    local t=require("menus.tracker").new()
    check("row with value",t:update({screen="video",index=1,label="Screen resolution",value="1920x1080"})=="Screen resolution, 1920x1080")
    check("value change speaks value only",t:update({screen="video",index=1,label="Screen resolution",value="1280x720"})=="1280x720")
    check("unchanged value silent",t:update({screen="video",index=1,label="Screen resolution",value="1280x720"})==nil)
    check("next row speaks name and value",t:update({screen="video",index=2,label="V-Sync",value="On"})=="V-Sync, On")
    check("value lost speaks label",t:update({screen="video",index=2,label="V-Sync",value=nil})=="V-Sync")
    check("row without value",t:update({screen="video",index=3,label="Reset To Defaults"})=="Reset To Defaults")
    package.loaded["menus.main_menu"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local mm=require("menus.main_menu")
    check("percent mid",mm.percent(0.5,0,1)==50)
    check("percent rounds",mm.percent(0.666,0,1)==67)
    check("percent custom range",mm.percent(2.2,1.6,2.8)==50)
    check("percent clamps",mm.percent(-1,0,1)==0 and mm.percent(5,0,1)==100)
    -- Selector and slider rows from fake widgets.
    local function obj(fields)local o=fields or {};o.IsValid=function()return true end;o.HasAnyFlags=function()return false end;return o end
    local function textw(s)return obj({GetText=function()return {ToString=function()return s end}end})end
    -- Real structure (from the game's widget files): names and values sit in
    -- LocalizedString_Widget wrappers that have NO GetText of their own.
    local function wrapped(s)return obj({TextBlock_0=textw(s)})end
    local selector=obj({Selector_Name=wrapped("V-Sync"),Selector_Option=obj({Text=wrapped("On")})})
    local slider=obj({Slider_Text=wrapped("Master"),Slider_Slider=obj({GetValue=function()return 0.8 end,MinValue=0,MaxValue=1})})
    local opts={selector,slider}
    local screen=obj({IsVisible=function()return true end,CurrentInteractableIndex=0,CurrentInteractable=selector,InteractablesArray=opts,
        GetClass=function()return {GetFName=function()return {ToString=function()return "Settings_Video_Widget_C" end}end}end,GetAddress=function()return 1 end})
    local title=obj({IsInViewport=function()return true end,LastCreatedWidget=screen})
    _G.FindAllOf=function(n)return n=="BP_LiS_Main_Menu_Widget_C" and {title} or {} end
    local s=mm.snapshot()
    check("selector name and option",s and s.label=="V-Sync" and s.value=="On",s and (tostring(s.label)..","..tostring(s.value)))
    screen.CurrentInteractable=slider;screen.CurrentInteractableIndex=1
    s=mm.snapshot()
    check("slider name and percent",s and s.label=="Master" and s.value=="80%",s and (tostring(s.label)..","..tostring(s.value)))
    -- Selector whose shown text is empty falls back to Options[SelectedOption].
    local sel2=obj({Selector_Name=wrapped("Subtitles"),Selector_Option=obj({Text=wrapped(""),SelectedOption=1,
        Options={{get=function()return {ToString=function()return "Off" end}end},{get=function()return {ToString=function()return "On" end}end}}})})
    screen.CurrentInteractable=sel2;screen.CurrentInteractableIndex=2
    s=mm.snapshot()
    check("selector falls back to option list",s and s.label=="Subtitles" and s.value=="On",s and (tostring(s.label)..","..tostring(s.value)))
    _G.FindAllOf=nil;_G.EObjectFlags=nil
end
-- Popups and save slots, built from values captured in the game.
do
    package.loaded["menus.main_menu"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local mm=require("menus.main_menu")
    local function obj(f)local o=f or {};o.IsValid=function()return true end;o.HasAnyFlags=function()return false end;o.GetAddress=o.GetAddress or function()return 7 end;return o end
    local function textw(s,hidden)return obj({GetText=function()return {ToString=function()return s end}end,IsVisible=function()return not hidden end})end
    local function cls(n)return function()return {GetFName=function()return {ToString=function()return n end}end}end end
    -- Save slots exactly as captured: a used slot and an empty one.
    local used=obj({Text_Button_Slot=textw("Game 1"),TextBlock_Episode=textw("Episode 1: Chrysalis"),TextBlock_Level=textw("Nightmare"),
        TextBlock_Date=textw("Date: 10/24/2026 18:56:48"),TextBlock_NewGame=textw("$GT_Mobile_UI_Menu_SlotStartNewGame",true)})
    local empty=obj({Text_Button_Slot=textw("Game 2",true),TextBlock_Episode=textw(""),TextBlock_Level=textw(""),TextBlock_Date=textw(""),TextBlock_NewGame=textw("New game")})
    check("used slot",mm.save_slot_text(used)=="Game 1, Episode 1: Chrysalis, Nightmare, Date: 10/24/2026 18:56:48",mm.save_slot_text(used))
    check("empty slot",mm.save_slot_text(empty)=="New game",mm.save_slot_text(empty))
    -- Save menu screen follows ActiveSlot.
    local saves=obj({IsVisible=function()return true end,GetClass=cls("BP_LiS_Main_Menu_SaveMenu_C"),ActiveSlot=0,
        BP_LiS_Main_Menu_SaveSlot_1=used,BP_LiS_Main_Menu_SaveSlot_2=empty,CurrentInteractableIndex=0})
    local title=obj({IsInViewport=function()return true end,LastCreatedWidget=saves})
    local popups={}
    _G.FindAllOf=function(n)if n=="BP_LiS_Main_Menu_Widget_C" then return {title} end;return popups[n] or {} end
    local s=mm.snapshot()
    check("save menu slot 1",s and s.label:find("^Game 1, Episode 1") and s.index==0,s and tostring(s.label))
    saves.ActiveSlot=1;s=mm.snapshot()
    check("save menu slot 2",s and s.label=="New game" and s.index==1,s and tostring(s.label))
    -- Exit popup takes priority over the screen underneath.
    popups["MainMenu_2Option_PopUp_Widget_C"]={obj({IsInViewport=function()return true end,IsVisible=function()return true end,
        TextBlock_Message=textw("Quit the game?"),TextBlock_Confirm=textw("Confirm"),TextBlock_Cancel=textw("Cancel")})}
    s=mm.snapshot()
    check("exit popup",s and s.label=="Quit the game?" and s.value=="Enter to confirm, Escape to cancel",s and (tostring(s.label).."/"..tostring(s.value)))
    package.loaded["menus.tracker"]=nil
    local tr=require("menus.tracker").new()
    check("popup spoken with choices",tr:update(s)=="Quit the game? Enter to confirm, Escape to cancel")
    popups["MainMenu_2Option_PopUp_Widget_C"]=nil
    -- Video Apply confirmation: hidden panel is ignored, visible one is read.
    local panel=obj({IsVisible=function()return false end})
    local video=obj({IsVisible=function()return true end,GetClass=cls("Settings_Video_Widget_C"),Confirmation=panel,
        TextBlock_Message=textw("Keep these settings?"),TextBlock_Confirm=textw("Confirm"),TextBlock_Cancel=textw("Cancel"),
        CurrentInteractableIndex=9,CurrentInteractable=obj({Button_Text=textw("Apply Settings")})})
    title.LastCreatedWidget=video
    s=mm.snapshot()
    check("hidden confirmation ignored",s and s.label=="Apply Settings",s and tostring(s.label))
    panel.IsVisible=function()return true end
    s=mm.snapshot()
    check("apply confirmation read",s and s.label=="Keep these settings?" and s.value=="Enter to confirm, Escape to cancel",s and tostring(s.label))
    _G.FindAllOf=nil;_G.EObjectFlags=nil
end
-- Countdown messages, controller key names and the gamma screen.
do
    package.loaded["menus.tracker"]=nil;package.loaded["menus.main_menu"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local mm=require("menus.main_menu")
    local tr=require("menus.tracker").new()
    -- Exact text the game showed, ticking down each second.
    local function apply(n)
        local m="Do you want to keep your modifications?  Initial settings will be restored in "..n.." second(s)..."
        return {screen="popup@1",index=0,label=m,key=mm.message_key(m),value="Enter to confirm, Escape to cancel"}
    end
    local first=tr:update(apply(22))
    check("countdown message spoken once",first and first:find("restored in 22 second",1,true)~=nil,first)
    check("countdown tick silent",tr:update(apply(21))==nil)
    check("countdown tick silent again",tr:update(apply(9))==nil)
    check("different message spoken",tr:update({screen="popup@1",index=0,label="Quit the game?",key=mm.message_key("Quit the game?"),value="x"})=="Quit the game? x")
    -- Controller names for confirm/back.
    package.loaded["core.controls"]=nil
    local c=require("core.controls")
    c.set_gamepad(true)
    check("controller confirm",c.name("confirm")=="A" and c.name("back")=="B")
    c.set_gamepad(false)
    check("keyboard confirm",c.name("confirm")=="Enter" and c.name("back")=="Escape")
    check("markup stripped",mm.strip_markup("Press <b>this</b>  now")=="Press this now",mm.strip_markup("Press <b>this</b>  now"))
    -- Gamma screen: device-appropriate instruction plus slider value.
    local function obj(f)local o=f or {};o.IsValid=function()return true end;o.HasAnyFlags=function()return false end;o.GetAddress=function()return 3 end;return o end
    local function textw(s)return obj({GetText=function()return {ToString=function()return s end}end})end
    local gamma=obj({IsVisible=function()return true end,IsInViewport=function()return true end,PCTooltip=textw("Use A and D to adjust"),
        GamepadTooltipRich=textw("Use <img id=\"LStick36\"/> to adjust"),Slider_Slider=obj({GetValue=function()return 0.5 end,MinValue=0,MaxValue=1})})
    local title=obj({IsInViewport=function()return true end})
    _G.FindAllOf=function(n)if n=="BP_LiS_Main_Menu_Widget_C" then return {title} elseif n=="GammaWidget_C" then return {gamma} end return {} end
    local s=mm.snapshot()
    check("gamma keyboard instruction",s and s.label=="Use A and D to adjust" and s.value=="50%",s and (tostring(s.label).."/"..tostring(s.value)))
    mm.using_gamepad=function()return true end
    s=mm.snapshot()
    check("gamma controller instruction",s and s.label=="Use left stick to adjust",s and tostring(s.label))
    mm.using_gamepad=function()return false end
    local t2=require("menus.tracker").new();t2:update(s)
    gamma.Slider_Slider.GetValue=function()return 0.6 end
    check("gamma value change speaks value",t2:update(mm.snapshot())=="60%")
    gamma.IsVisible=function()return false end
    check("closed gamma screen ignored",mm.snapshot()==nil or mm.snapshot().screen:find("^gamma")==nil)
    _G.FindAllOf=nil;_G.EObjectFlags=nil
end
-- Text cleanup and joining, with exact strings from the game's Menus.ini/HUD.ini.
do
    package.loaded["core.text"]=nil
    local tx=require("core.text")
    local reports={};tx.report=function(l)reports[#reports+1]=l end
    local gamma='Adjust the gamma cursor with <img id="LStick36"/> until the first logo is barely visible.\nMake sure your screen is set up properly before changing the gamma.'
    local cleaned=tx.clean(gamma)
    check("icon named",cleaned:find("with left stick until",1,true)~=nil,cleaned)
    check("line break kept as sentence break",cleaned:find("barely visible. Make sure",1,true)~=nil,cleaned)
    check("no double punctuation on join",tx.join(cleaned,"42 percent"):find("the gamma. 42 percent$")~=nil,tx.join(cleaned,"42 percent"))
    check("comma join after plain label",tx.join("Master","80 percent")=="Master, 80 percent")
    local pc='Adjust the gamma by clicking on the cursor until the first logo is barely visible.\nMake sure your monitor is properly set before changing the gamma.'
    check("pc text unchanged apart from break",tx.clean(pc)=="Adjust the gamma by clicking on the cursor until the first logo is barely visible. Make sure your monitor is properly set before changing the gamma.")
    check("missing full stop added at break",tx.clean("First line\nSecond line")=="First line. Second line")
    check("escaped quotes from ini",tx.clean('Use <img id=\\"RStick36\\"/> to aim')=="Use right stick to aim",tx.clean('Use <img id=\\"RStick36\\"/> to aim'))
    check("all scanned icons known",tx.clean('<img id="LStick36B"/><img id="RStick36B"/><img id="LStick36Bordered"/><img id="RStick36Bordered"/><img id="Mouse"/><img id="MouseB"/>'):find("%[icon")==nil)
    local unknown=tx.clean('Press <img id="NewThing"/> now')
    check("unknown icon marked not dropped",unknown=="Press [icon NewThing] now",unknown)
    check("unknown icon reported",reports[1]=="unknown_icon id=NewThing",tostring(reports[1]))
    check("ellipsis ends sentence",tx.join("Restored in 29 second(s)...","Enter to confirm")=="Restored in 29 second(s)... Enter to confirm")
    tx.report=function()end
end
-- Live reread: tracker:current reflects the newest countdown though it was not spoken.
do
    package.loaded["menus.tracker"]=nil;package.loaded["menus.main_menu"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local mm=require("menus.main_menu");local tr=require("menus.tracker").new()
    local function apply(n)local m="Initial settings will be restored in "..n.." second(s)...";return {screen="p",index=0,label=m,key=mm.message_key(m),value="Enter to confirm"}end
    tr:update(apply(29));tr:update(apply(17))
    check("reread has current countdown",tr:current()=="Initial settings will be restored in 17 second(s)... Enter to confirm",tr:current())
    _G.EObjectFlags=nil
end
print(string.format("%d checks, %d failures",count,failures))
os.exit(failures==0 and 0 or 1)
