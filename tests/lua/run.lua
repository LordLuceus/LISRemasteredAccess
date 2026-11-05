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
    local known={menu_key=true,cancel_key=true,value=true,confirm_key=true,back_key=true,index=true,count=true,name=true,label=true,actions=true,options=true,key=true,text=true,total=true}
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
    -- Regression: a menu screen exists but is not shown (Episodes open in its
    -- place). The title still reports its prompt visible; it must NOT be read.
    screen.IsVisible=function()return false end
    check("no stale title prompt over another screen",mm.snapshot()==nil)
    -- Real title screen: no menu screen created yet.
    title.LastCreatedWidget=nil
    s=mm.snapshot()
    check("title prompt before any menu screen",s and s.screen=="title" and s.label=="Click To Start")
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
-- Arrow keys: each arrow is added to the matching WASD direction action, once,
-- rebuilding keymaps only on the last add, and never saving to Input.ini.
do
    package.loaded["core.arrow_keys"]=nil
    local calls,saved,rebuilt={},false,false
    local settings={IsValid=function()return true end,
        AddActionMapping=function(_,m,rebuild)calls[#calls+1]={action=m.ActionName.n,key=m.Key.KeyName.n,rebuild=rebuild}end,
        GetActionMappingByName=function(_,name,out)for _,c in ipairs(calls) do if c.action==name.n then out[#out+1]={Key={KeyName={ToString=function()return c.key end}}} end end end,
        SaveKeyMappings=function()saved=true end,ForceRebuildKeymaps=function()rebuilt=true end}
    _G.FName=function(n)return {n=n}end
    _G.StaticFindObject=function(p)return p=="/Script/Engine.Default__InputSettings" and settings or nil end
    local logs={}
    local ak=require("core.arrow_keys")
    check("arrow mappings applied",ak.apply(function(l)logs[#logs+1]=l end)==true)
    local want={DPadUp="Up",DPadDown="Down",DPadLeft="Left",DPadRight="Right"}
    local ok=#calls==4
    for i,c in ipairs(calls) do ok=ok and want[c.action]==c.key and (c.rebuild==(i==4)) end
    check("each arrow on its WASD action, one rebuild",ok)
    check("bindings not saved to Input.ini",saved==false)
    check("live key maps rebuilt like the game editor",rebuilt==true)
    local readback=false;for _,l in ipairs(logs) do if l=="arrow_keys bound action=DPadUp keys=Up" then readback=true end end
    check("binding read back and logged",readback)
    _G.StaticFindObject=function()return nil end
    check("missing settings reported",ak.apply(function(l)logs[#logs+1]=l end)==false and logs[#logs]:find("no_input_settings",1,true)~=nil)
    _G.FName=nil;_G.StaticFindObject=nil
end
-- Episodes screen (standalone widget): heading, options and episode switching,
-- with the values captured in the game.
do
    package.loaded["menus.main_menu"]=nil;package.loaded["menus.tracker"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local mm=require("menus.main_menu");local tr=require("menus.tracker").new()
    local function obj(f)local o=f or {};o.IsValid=function()return true end;o.HasAnyFlags=function()return false end;o.GetAddress=o.GetAddress or function()return 9 end;return o end
    local function textw(s)return obj({GetText=function()return {ToString=function()return s end}end,IsVisible=function()return true end})end
    local function button(s)return obj({Button_Text=textw(s)})end
    local opts={button("Continue"),button("Restart"),button("Collectible Mode")}
    local ep=obj({IsVisible=function()return true end,IsInViewport=function()return true end,EpisodeNumber=0,EpisodeTitle=textw("Episode 1: Chrysalis"),
        CurrentInteractableIndex=0,CurrentInteractable=opts[1],InteractablesArray=opts,
        GetClass=function()return {GetFName=function()return {ToString=function()return "BP_LiS_ChangeEpisode_Widget_C" end}end}end})
    local start=obj({IsVisible=function()return false end,GetClass=function()return {GetFName=function()return {ToString=function()return "BP_LiS_MainMenu_Start_Widget_C" end}end}end})
    local title=obj({IsInViewport=function()return true end,LastCreatedWidget=start,CanAdvance=true,
        TapToStart=obj({IsVisible=function()return true end,GetText=function()return {ToString=function()return "Click To Start" end}end})})
    _G.FindAllOf=function(n)if n=="BP_LiS_Main_Menu_Widget_C" then return {title} elseif n=="BP_LiS_ChangeEpisode_Widget_C" then return {ep} end return {} end
    check("episodes screen opens with heading",tr:update(mm.snapshot())=="Episode 1: Chrysalis, Continue")
    ep.CurrentInteractableIndex=1;ep.CurrentInteractable=opts[2]
    check("option change speaks option only",tr:update(mm.snapshot())=="Restart")
    ep.EpisodeNumber=1;ep.EpisodeTitle=textw("Episode 2: Out of Time")
    check("episode change speaks new heading",tr:update(mm.snapshot())=="Episode 2: Out of Time, Restart")
    ep.IsVisible=function()return false end
    check("closed episodes screen, no stale title prompt",mm.snapshot()==nil)
    _G.FindAllOf=nil;_G.EObjectFlags=nil
end
-- Chapter list (captured values): selected chapter read over the Episodes screen.
do
    package.loaded["menus.main_menu"]=nil;package.loaded["menus.tracker"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local mm=require("menus.main_menu");local tr=require("menus.tracker").new()
    local function obj(f)local o=f or {};o.IsValid=function()return true end;o.HasAnyFlags=function()return false end;o.GetAddress=function()return 5 end;return o end
    local function textw(s,hidden)return obj({GetText=function()return {ToString=function()return s end}end,IsVisible=function()return not hidden end})end
    local cls=function(n)return function()return {GetFName=function()return {ToString=function()return n end}end}end end
    local opts={obj({Button_Text=textw("Collectible Mode")})}
    local ep=obj({IsVisible=function()return true end,IsInViewport=function()return true end,GetClass=cls("BP_LiS_ChangeEpisode_Widget_C"),EpisodeNumber=0,
        EpisodeTitle=textw("Episode 1: Chrysalis"),CurrentInteractableIndex=0,CurrentInteractable=opts[1],InteractablesArray=opts})
    local ch=obj({IsVisible=function()return true end,IsInViewport=function()return true end,GetClass=cls("BP_LiS_ChangeLevelMenu_Widget_C"),
        EpisodeName_TextBlock=textw("Episode 1: Nightmare"),TextBlock_Collected=textw("1/1 Collected",true),LevelIndex=0,SelectedButtonIndex=1,SelectedEpisode=0})
    local title=obj({IsInViewport=function()return true end,LastCreatedWidget=obj({IsVisible=function()return false end,GetClass=cls("X")})})
    local live={BP_LiS_Main_Menu_Widget_C={title},BP_LiS_ChangeEpisode_Widget_C={ep},BP_LiS_ChangeLevelMenu_Widget_C={ch}}
    _G.FindAllOf=function(n)return live[n] or {} end
    check("chapter list read over Episodes",tr:update(mm.snapshot())=="Episode 1: Nightmare")
    ch.TextBlock_Collected=textw("1/1 Collected")
    check("collected count added when shown",tr:update(mm.snapshot())=="1/1 Collected")
    ch.LevelIndex=1;ch.EpisodeName_TextBlock=textw("Episode 1: High School")
    check("next chapter spoken",tr:update(mm.snapshot())=="Episode 1: High School, 1/1 Collected")
    live.BP_LiS_ChangeLevelMenu_Widget_C=nil
    check("back to Episodes after closing",tr:update(mm.snapshot())=="Episode 1: Chrysalis, Collectible Mode")
    _G.FindAllOf=nil;_G.EObjectFlags=nil
end
-- Locked-episode heading (game's own English text, user-verified in play).
do
    package.loaded["menus.main_menu"]=nil;package.loaded["menus.tracker"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local mm=require("menus.main_menu");local tr=require("menus.tracker").new()
    local function obj(f)local o=f or {};o.IsValid=function()return true end;o.HasAnyFlags=function()return false end;o.GetAddress=function()return 6 end;return o end
    local function textw(s,hidden)return obj({GetText=function()return {ToString=function()return s end}end,IsVisible=function()return not hidden end})end
    local cls=function(n)return function()return {GetFName=function()return {ToString=function()return n end}end}end end
    local opts={obj({Button_Text=textw("Continue")})}
    local ep=obj({IsVisible=function()return true end,IsInViewport=function()return true end,GetClass=cls("BP_LiS_ChangeEpisode_Widget_C"),EpisodeNumber=1,
        EpisodeTitle=textw("Episode 2: Out of Time"),FinishPrevEp=textw("Finish Previous Episode to Play"),CurrentInteractableIndex=0,CurrentInteractable=opts[1],InteractablesArray=opts})
    local title=obj({IsInViewport=function()return true end,LastCreatedWidget=obj({IsVisible=function()return false end,GetClass=cls("X")})})
    local live={BP_LiS_Main_Menu_Widget_C={title},BP_LiS_ChangeEpisode_Widget_C={ep}}
    _G.FindAllOf=function(n)return live[n] or {} end
    check("locked episode says why",tr:update(mm.snapshot())=="Episode 2: Out of Time, Finish Previous Episode to Play, Continue",tostring(tr:current()))
    ep.FinishPrevEp=textw("Finish Previous Episode to Play",true);ep.EpisodeNumber=0;ep.EpisodeTitle=textw("Episode 1: Chrysalis")
    check("hidden notice line not read",tr:update(mm.snapshot())=="Episode 1: Chrysalis, Continue",tostring(tr:current()))
    _G.FindAllOf=nil;_G.EObjectFlags=nil
end
-- Pause menu in play: no title screen exists; pause options, its settings list
-- and its confirmation popup (game's own English text).
do
    package.loaded["menus.main_menu"]=nil;package.loaded["menus.tracker"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local mm=require("menus.main_menu");local tr=require("menus.tracker").new()
    local function obj(f)local o=f or {};o.IsValid=function()return true end;o.HasAnyFlags=function()return false end;o.GetAddress=function()return 8 end;return o end
    local function textw(s)return obj({GetText=function()return {ToString=function()return s end}end,IsVisible=function()return true end})end
    local cls=function(n)return function()return {GetFName=function()return {ToString=function()return n end}end}end end
    local function button(s)return obj({Button_Text=textw(s)})end
    local opts={button("Resume game"),button("Reload last checkpoint"),button("Settings"),button("How to play"),button("Exit to main menu")}
    local pause=obj({IsVisible=function()return true end,IsInViewport=function()return true end,GetClass=cls("PauseMenu_Widget_C"),
        CurrentInteractableIndex=0,CurrentInteractable=opts[1],InteractablesArray=opts})
    local live={PauseMenu_Widget_C={pause}}
    _G.FindAllOf=function(n)return live[n] or {} end
    check("pause menu read without a title screen",tr:update(mm.snapshot())=="Resume game")
    pause.CurrentInteractableIndex=4;pause.CurrentInteractable=opts[5]
    check("pause option change",tr:update(mm.snapshot())=="Exit to main menu")
    local msg="All unsaved progress will be lost. Do you still want to exit?"
    live.PauseMenu_PopUp_Widget_C={obj({IsVisible=function()return true end,IsInViewport=function()return false end,GetParent=function()return obj() end,
        TextBlock_Message=textw(msg),TextBlock_Confirm=textw("Confirm"),TextBlock_Cancel=textw("Cancel")})}
    check("pause confirmation (child widget) read",tr:update(mm.snapshot())==msg.." Enter to confirm, Escape to cancel",tostring(tr:current()))
    live.PauseMenu_PopUp_Widget_C=nil
    local cats={button("Video Settings"),button("Audio & Language Settings")}
    live.Settings_Widget_C={obj({IsVisible=function()return true end,IsInViewport=function()return true end,GetClass=cls("Settings_Widget_C"),
        CurrentInteractableIndex=0,CurrentInteractable=cats[1],InteractablesArray=cats})}
    check("pause settings list over the pause menu",tr:update(mm.snapshot())=="Video Settings")
    live.Settings_Widget_C=nil
    check("back to the pause menu",tr:update(mm.snapshot())=="Exit to main menu")
    live.PauseMenu_Widget_C=nil
    check("gameplay with nothing open is silent",mm.snapshot()==nil)
    _G.FindAllOf=nil;_G.EObjectFlags=nil
end
-- Scanner list: nearest first, stable letters for duplicates, sticky selection,
-- wrapping, direction words and height.
do
    package.loaded["scanner.list"]=nil
    local L=require("scanner.list")
    local s=L.new()
    local function e(id,label,x,y,z)return {id=id,label=label,pos={X=x,Y=y,Z=z or 0}} end
    local me={X=0,Y=0,Z=0}
    local list=s:update({e("b2","Bottle",300,0),e("car","Car",100,0),e("b1","Bottle",200,0)},me)
    check("nearest first",list[1].id=="car" and list[2].id=="b1" and list[3].id=="b2")
    check("duplicate letters by identity",list[2].name=="Bottle, A" and list[3].name=="Bottle, B" and list[1].name=="Car")
    check("first next picks nearest",s:move(1).id=="car")
    check("next",s:move(1).id=="b1")
    -- Walk past: b2 becomes nearest. Letters stay; selection stays on b1.
    list=s:update({e("b2","Bottle",300,0),e("car","Car",100,0),e("b1","Bottle",200,0)},{X=320,Y=0,Z=0})
    check("order follows distance",list[1].id=="b2")
    check("letters follow identity",list[1].name=="Bottle, B")
    local cur,i=s:current()
    check("selection sticks to the object",cur.id=="b1" and i==2)
    check("wraps forward",(function()s:move(1);return s:move(1).id=="b2" end)())
    check("wraps backward",s:move(-1).id=="car")
    s:update({e("car","Car",100,0)},me)
    check("selection dropped when object gone",s:current().id=="car")
    s:update({e("b1","Bottle",200,0)},me)
    check("vanished selection cleared",s:current()==nil)
    check("first previous picks farthest",(function()s:update({e("a","A",100,0),e("b","B",500,0)},me);return s:move(-1).id=="b" end)())
    check("empty list",(function()local t=L.new();t:update({},me);return t:move(1)==nil end)())
    -- Direction relative to facing (yaw 0 = +X).
    check("ahead",L.direction(me,0,{X=100,Y=0})=="ahead")
    check("right",L.direction(me,0,{X=0,Y=100})=="right")
    check("behind",L.direction(me,0,{X=-100,Y=0})=="behind")
    check("left",L.direction(me,0,{X=0,Y=-100})=="left")
    check("facing rotates",L.direction(me,90,{X=0,Y=100})=="ahead")
    check("ahead left",L.direction(me,0,{X=100,Y=-100})=="ahead left")
    local h,m=L.height(me,{X=0,Y=0,Z=850})
    check("height up in metres",h=="up" and math.abs(m-8.5)<0.01)
    check("small height ignored",L.height(me,{X=0,Y=0,Z=100})==nil)
end
-- Scanner names: game translator, cached per language, readable fallback.
do
    package.loaded["scanner.sources"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local calls=0
    local widget={IsValid=function()return true end,HasAnyFlags=function()return false end,GetFullName=function()return "LiSWidget /Game/x.y" end,
        GetLocalizedString=function(_,k)calls=calls+1;return ({["$GT_Sensen_Int_Bottle01"]="Bottle"})[k] or k end}
    _G.FindAllOf=function(n)return n=="LiSWidget" and {widget} or {} end
    _G.StaticFindObject=function()return nil end
    local src=require("scanner.sources")
    local reports={};src.report=function(l)reports[#reports+1]=l end
    local lang="en";src.language=function()return lang end
    check("translated by the game",src.translate("$GT_Sensen_Int_Bottle01")=="Bottle")
    src.translate("$GT_Sensen_Int_Bottle01")
    check("cached",calls==1)
    lang="fr";src.translate("$GT_Sensen_Int_Bottle01")
    check("cache cleared on language change",calls==2)
    check("readable fallback",src.translate("$GT_Sensen_Int_AnsweringMachine01")=="Answering Machine")
    local found=false;for _,l in ipairs(reports) do if l:find("untranslated key=$GT_Sensen_Int_AnsweringMachine01",1,true) then found=true end end
    check("fallback reported",found)
    check("readable fallback simple",src.readable("$GT_Sensen_Int_TV01")=="TV")
    _G.FindAllOf=nil;_G.StaticFindObject=nil;_G.EObjectFlags=nil
end
-- Scanner readout wording.
do
    package.loaded["scanner.readout"]=nil
    local R=require("scanner.readout")
    local me={X=0,Y=0,Z=0}
    check("mail readout",R.describe({name="Mail",pos={X=150,Y=0,Z=0}},3,38,me,0)=="Mail, 1.5 metres, ahead, 3 of 38",R.describe({name="Mail",pos={X=150,Y=0,Z=0}},3,38,me,0))
    check("one metre singular",R.describe({name="Door, A",pos={X=0,Y=-100,Z=0}},1,2,me,0)=="Door, A, 1 metre, left, 1 of 2")
    check("whole metres above 10",R.metres(4238)=="42")
    check("rounds to one decimal",R.metres(87)=="0.9" and R.metres(800)=="8")
    local s=R.describe({name="Lighthouse",pos={X=3000,Y=-3000,Z=850}},1,1,me,0)
    check("height when it matters",s=="Lighthouse, 42 metres, ahead left, 8.5 metres up, 1 of 1",s)
end
-- Controller scanner input: D-pad commands, hold-repeat, stick-click face vs modifier.
do
    package.loaded["scanner.pad"]=nil
    local P=require("scanner.pad")
    local p=P.new()
    local function cmds(t)return table.concat(t,",") end
    check("right is next",cmds(p:update(8,true,0))=="next")
    check("held right waits",cmds(p:update(8,true,0.3))=="")
    check("held right repeats",cmds(p:update(8,true,0.46))=="next")
    check("repeat rate",cmds(p:update(8,true,0.66))=="next")
    check("release",cmds(p:update(0,true,0.7))=="")
    check("up describes",cmds(p:update(1,true,1))=="describe")
    p:update(0,true,1.1)
    check("down autowalks",cmds(p:update(2,true,1.2))=="autowalk")
    p:update(0,true,1.3)
    check("stick press alone does nothing yet",cmds(p:update(0x40,true,2))=="")
    check("stick release faces",cmds(p:update(0,true,2.1))=="face")
    p:update(0x40,true,3)
    check("stick+up is help",cmds(p:update(0x41,true,3.1))=="help")
    p:update(0x40,true,3.2)
    check("modifier use suppresses face",cmds(p:update(0,true,3.3))=="")
    p:update(0x40,true,4)
    check("stick+right repeats",cmds(p:update(0x48,true,4.1))=="repeat")
    p:update(0,true,4.2)
    check("inactive ignores",cmds(p:update(8,false,5))=="")
    check("no controller",cmds(p:update(-1,true,6))=="")
end
-- Autowalk decisions: legs, arrival, cancellation, hand-over, blockage.
do
    package.loaded["autowalk.plan"]=nil
    local W=require("autowalk.plan")
    local w=W.new("Lighthouse",{{X=1},{X=2},{X=3}})
    check("first leg",w:next_leg().X==1)
    check("leg arrival continues",w:leg_result("arrived_test_region").continue==true)
    w:next_leg();w:leg_result("arrived_test_region");w:next_leg()
    local r=w:leg_result("arrived_test_region")
    check("last leg arrival announces",r.done and r.say=="walk_arrived" and r.params.name=="Lighthouse")
    check("nothing after finish",w:next_leg()==nil)
    local function single(result)local x=W.new("Mail",{{X=1}});x:next_leg();return x:leg_result(result) end
check("stalled against the object counts as arrival",(function()local x=W.new("Bed",{{X=1}});x:next_leg();return x:leg_result("stalled",38).say=="walk_arrived" end)())
check("stalled well short is still blocked",(function()local x=W.new("Dana",{{X=1}});x:next_leg();return x:leg_result("stalled",586).say=="walk_blocked" end)())
check("stalled near a middle point is not arrival",(function()local x=W.new("Dana",{{X=1},{X=2}});x:next_leg();return x:leg_result("stalled",20).say=="walk_blocked" end)())
    check("cancel",single("cancelled").say=="walk_stopped")
    check("cutscene takes over",single("cinematic_movement_track").say=="walk_interrupted")
    check("paused takes over",single("paused").say=="walk_interrupted")
    check("stall is blocked",single("stalled").say=="walk_blocked")
    check("timeout",single("timeout").say=="walk_timeout")
    check("other failure",single("observation_error").say=="walk_failed")
    local y=W.new("Mail",{{X=1},{X=2}});y:next_leg()
    check("failure on first of two legs stops",y:leg_result("stalled").done==true and y:next_leg()==nil)
    check("refusal mapping",W.refusal("no_route")=="walk_no_route" and W.refusal("paused")=="walk_not_now" and W.refusal("whatever")=="walk_no_route")
end
-- Autowalk wiring with fake follower, route and door planner (no game).
do
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors"}) do package.loaded[m]=nil end
    local started,stopped={},{}
    local fake_follow={active=nil}
    fake_follow.ready=function()return fake_follow.ready_value~=false,fake_follow.ready_reason end
    fake_follow.start=function(_,_,goal,emit)started[#started+1]=goal;fake_follow.active={emit=emit} end
    fake_follow.stop=function(reason)local s=fake_follow.active;fake_follow.active=nil;stopped[#stopped+1]=reason;if s then s.emit("follow_end="..reason.." stop_ok=true") end end
    fake_follow.tick=function()end
    package.loaded["nav.follow"]=fake_follow
    package.loaded["nav.route"]={project=function(_,p)return true,{X=p.X,Y=p.Y,Z=p.Z} end}
    local plan_result=nil
    package.loaded["nav.doors"]={plan=function()return plan_result end}
    local aw=require("autowalk.autowalk")
    local spoken={}
    aw.say=function(t)spoken[#spoken+1]=t end
    aw.text=function(k,p)return k..(p and p.name and (":"..p.name) or "") end
    local pawn={CapsuleComponent={K2_GetComponentLocation=function()return {X=0,Y=0,Z=100}end,GetScaledCapsuleHalfHeight=function()return 84 end}}
    local c={Pawn=pawn}
    local mail={name="Mail",stand={X=150,Y=0,Z=0},pos={X=160,Y=0,Z=50}}
    -- Direct walk: start, arrive.
    check("direct walk starts",aw.start(c,mail)==true and spoken[#spoken]=="walk_start:Mail")
    check("aims at the stand point",started[1].X==150)
    fake_follow.stop("arrived_test_region");aw.tick()
    check("arrival announced",spoken[#spoken]=="walk_arrived:Mail" and not aw.walking())
    -- Detour: two-plus legs, then arrival only after the last.
    plan_result={{10,0,0},{20,0,0},{150,0,0}}
    aw.start(c,mail)
    check("detour announced",spoken[#spoken]=="walk_start_detour:Mail")
    fake_follow.stop("arrived_test_region");aw.tick()
    check("second leg started",#started==3 and started[3].X==20)
    fake_follow.stop("arrived_test_region");aw.tick()
    fake_follow.stop("arrived_test_region");aw.tick()
    check("arrived after last leg",spoken[#spoken]=="walk_arrived:Mail")
    plan_result=nil
    -- Cancel by pressing again.
    aw.start(c,mail)
    check("cancel while walking",aw.cancel()==true);aw.tick()
    check("cancel announced",spoken[#spoken]=="walk_stopped" and not aw.walking())
    check("cancel when idle does nothing",aw.cancel()==false)
    -- Cutscene takes over mid-walk.
    aw.start(c,mail);fake_follow.stop("cinematic_movement_track");aw.tick()
    check("hand-over announced",spoken[#spoken]=="walk_interrupted")
    -- Refusals.
    check("no selection",aw.start(c,nil)==false and spoken[#spoken]=="walk_no_target")
    fake_follow.ready_value=false;fake_follow.ready_reason="paused"
    check("not now",aw.start(c,mail)==false and spoken[#spoken]=="walk_not_now")
    fake_follow.ready_value=nil
    plan_result=nil
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors"}) do package.loaded[m]=nil end
end
-- Movement cancels autowalk, but only after the start key's movement is released.
do
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors"}) do package.loaded[m]=nil end
    local ff={active=nil}
    ff.ready=function()return true end
    ff.start=function(_,_,_,emit)ff.active={emit=emit} end
    ff.stop=function(r)local s=ff.active;ff.active=nil;if s then s.emit("follow_end="..r.." stop_ok=true") end end
    ff.tick=function()end
    package.loaded["nav.follow"]=ff
    package.loaded["nav.route"]={project=function(_,p)return true,{X=p.X,Y=p.Y,Z=p.Z} end}
    package.loaded["nav.doors"]={plan=function()return nil end}
    local aw=require("autowalk.autowalk")
    local spoken={};aw.say=function(t)spoken[#spoken+1]=t end;aw.text=function(k)return k end
    local moving=false;aw.moving=function()return moving end
    local pawn={CapsuleComponent={K2_GetComponentLocation=function()return {X=0,Y=0,Z=100}end,GetScaledCapsuleHalfHeight=function()return 84 end}}
    local c={Pawn=pawn};local e={name="Mail",stand={X=150,Y=0,Z=0},pos={X=150,Y=0,Z=0}}
    aw.start(c,e);aw.tick();aw.tick()
    check("walk continues without movement input",aw.walking())
    moving=true;aw.tick()
    check("movement cancels",not aw.walking() and spoken[#spoken]=="walk_stopped")
    -- Started while a movement key is already held: ignored until released.
    aw.start(c,e);aw.tick()
    check("held key at start does not cancel",aw.walking())
    moving=false;aw.tick()
    check("still walking after release",aw.walking())
    moving=true;aw.tick()
    check("new movement then cancels",not aw.walking())
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors"}) do package.loaded[m]=nil end
end
-- A cutscene starting at the goal counts as arrival; elsewhere it is a hand-over.
do
    package.loaded["autowalk.plan"]=nil
    local W=require("autowalk.plan")
    local function single(result,rem)local x=W.new("Lighthouse",{{X=1}});x:next_leg();return x:leg_result(result,rem) end
    check("cutscene 0.4 m from goal is arrival",single("cinematic_movement_track",39).say=="walk_arrived")
    check("cutscene far from goal is hand-over",single("cinematic_movement_track",2000).say=="walk_interrupted")
    check("cutscene with unknown distance is hand-over",single("cinematic_movement_track",nil).say=="walk_interrupted")
    local y=W.new("Tools",{{X=1},{X=2}});y:next_leg()
    check("cutscene near an intermediate point is not arrival",y:leg_result("cinematic_movement_track",10).say=="walk_interrupted")
    -- 29 Oct (Episode 3 dorm): stalls 32-40 cm from the point were at the
    -- object and usable; within 60 cm of the final point a stall is arrival.
    check("stall at the goal is arrival",single("stalled",20).say=="walk_arrived")
    check("stall with unknown distance is still blocked",single("stalled",nil).say=="walk_blocked")
end
-- Control tracking: settle time, silent first state, unknown ignored.
do
    package.loaded["core.control"]=nil
    local C=require("core.control");local c=C.new()
    check("first state silent",c:update("none",0)==nil and c:update("none",0.5)==nil and not c:has_control())
    check("control needs to settle",c:update("control",1)==nil and c:update("control",1.2)==nil)
    check("control back after settle",c:update("control",1.5)=="back" and c:has_control())
    check("flicker ignored",c:update("none",2)==nil and c:update("control",2.1)==nil and c:has_control())
    check("unknown ignored",c:update("unknown",3)==nil and c:has_control())
    c:update("none",4)
    check("lost after settle",c:update("none",4.5)=="lost" and not c:has_control())
    check("no repeat",c:update("none",5)==nil)
end
-- Pass-through goal: aim beyond the centre along Max's approach line.
do
    package.loaded["autowalk.autowalk"]=nil
    package.loaded["nav.follow"]={};package.loaded["nav.route"]={};package.loaded["nav.doors"]={}
    local aw=require("autowalk.autowalk")
    local p=aw.beyond({X=0,Y=0,Z=0},{X=1000,Y=0,Z=50},200)
    check("aims 2 m past the trigger",math.abs(p.X-1200)<0.01 and p.Y==0 and p.Z==50)
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors"}) do package.loaded[m]=nil end
end
-- Loading a level: brief control then a cutscene stays quiet; later changes cue.
do
    package.loaded["core.control"]=nil
    local C=require("core.control");local c=C.new()
    c:reset(0)
    c:update("control",0.5);local a=c:update("control",1)
    c:update("none",2.3);local b=c:update("none",2.8)
    check("load flicker quiet",a==nil and b==nil)
    c:update("control",10);check("back after cutscene",c:update("control",10.5)=="back")
    c:update("none",20);check("lost later",c:update("none",20.5)=="lost")
end
-- Cutscene check reads single values only (never walks the cutscene's lists).
do
    package.loaded["nav.follow"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local f=require("nav.follow")
    local walked=false
    local function o(t)t=t or {};t.IsValid=function()return true end;t.HasAnyFlags=function()return false end;return t end
    local function arr(n)return {GetArrayNum=function()return n end,ForEach=function()walked=true end} end
    local pawn=o({GetAddress=function()return 7 end})
    local view=pawn
    pawn.Controller=o({GetViewTarget=function()return view end})
    pawn.ControllingMatineeActors=arr(0)
    check("free when camera on Max and no cutscene",f.cinematic_control(pawn)==false)
    pawn.ControllingMatineeActors=arr(1)
    check("cutscene count holds",f.cinematic_control(pawn)==true)
    pawn.ControllingMatineeActors=arr(0);view=o({GetAddress=function()return 99 end})
    check("camera elsewhere holds",f.cinematic_control(pawn)==true)
    check("cutscene lists never walked",walked==false)
    _G.EObjectFlags=nil;package.loaded["nav.follow"]=nil
end
-- Facing: the camera's one-shot request, focus read back afterwards.
do
    package.loaded["scanner.face"]=nil
    local F=require("scanner.face")
    local spoken={};F.say=function(t)spoken[#spoken+1]=t end;F.text=function(k,p)return k..(p and p.name and (":"..p.name) or "") end
    check("goal turn",select(1,F.outcome({name="Lighthouse",kind="goal"},false,true))=="face_turned")
    check("object focused leaves speech to focus announcement",F.outcome({name="Mail",kind="interaction"},true,true)==nil)
    check("never claims a cause it cannot know",select(1,F.outcome({name="Mail",kind="interaction"},false,true,false))=="face_turned_unfocused")
    check("object in reach but not focused",select(1,F.outcome({name="Mail",kind="interaction"},false,true,true))=="face_turned_unfocused")
    check("unsupported camera",select(1,F.outcome({name="Mail"},false,false))=="face_unsupported")
    local function o(t)t=t or {};t.IsValid=function()return true end;return t end
    local behaviour=o({IsA=function(_,c)return c=="/Script/LiS.CBA_3RD_Basic" end})
    local mail=o({GetAddress=function()return 42 end})
    -- Fake camera that lands short of each request in pitch (offset -10, like
    -- the real seated camera), so only error feedback converges.
    local cam_actual={Pitch=0,Yaw=0}
    local c=o({GetAddress=function()return 1 end,PlayerCameraManager={CamBhv_Current=behaviour,GetCameraLocation=function()return {X=0,Y=0,Z=0}end,
        GetCameraRotation=function()local r=(c and c.PlayerCameraManager.CamBhv_Current or behaviour).NextWantedCameraRotationForced;if r then cam_actual={Pitch=r.Pitch+10,Yaw=r.Yaw} end;return cam_actual end}})
    local comp=o({GetOwner=function()return c end,ActorInteractionFocused=mail,InnerZoneActorsCurrentlyActionable={ForEach=function(_,cb)cb(1,{get=function()return mail end})end}})
    local announced=false;F.focused_announce=function()announced=true end
    _G.FindAllOf=function(n)return n=="LiSInteractionComponent" and {comp} or {} end
    _G.StaticFindObject=function()return {FindLookAtRotation=function()return {Pitch=-5,Yaw=90,Roll=0}end} end
    local focus_after=3 -- the game focuses the object after the 3rd request
    local requests=0
    -- A proxy camera behaviour: count every one-shot request the mod makes.
    local store={}
    local orig=setmetatable({},{__index=function(_,k)if k=="IsA" then return behaviour.IsA elseif k=="IsValid" then return behaviour.IsValid end return store[k] end,
        __newindex=function(_,k,v)store[k]=v;if k=="bWantNextCameraRotationForced" then requests=requests+1;if requests>=focus_after then comp.ActorInteractionFocused=mail end end end})
    c.PlayerCameraManager.CamBhv_Current=orig
    comp.ActorInteractionFocused=nil
    local now=0;F.clock=function()return now end
    check("request sent",F.start(c,{name="Mail",kind="interaction",pos={X=0,Y=100,Z=0},actor=mail})==true)
    check("one-shot set",orig.WantNextCameraRotationRemainingTick==1 and orig.NextWantedCameraRotationForced.Yaw==90)
    for i=1,10 do now=now+0.1;F.tick() end
    check("corrected until focused",requests==3 and announced and #spoken==0,tostring(requests))
    -- Never focused: stops after 8 corrections and says so.
    requests=0;focus_after=99;comp.ActorInteractionFocused=nil;announced=false
    F.start(c,{name="Mail",kind="interaction",pos={X=0,Y=100,Z=0},actor=mail})
    for i=1,40 do now=now+0.01;F.tick() end
    -- The fake camera never moves, so the error never shrinks: it gives up
    -- after STALL_STEPS corrections (31 Oct: was a fixed 8).
    check("gives up when the error stops shrinking",requests==1+F.STALL_STEPS and spoken[#spoken]=="face_turned_unfocused:Mail",tostring(requests))
    -- Time limit.
    requests=0;F.start(c,{name="Mail",kind="interaction",pos={X=0,Y=100,Z=0},actor=mail})
    now=now+F.LIMIT+0.5;F.tick();F.tick()
    check("stops at the time limit",requests==1)
    setmetatable(orig,nil)    behaviour.IsA=function()return false end
    check("cutscene camera refused",F.start(c,{name="Mail",pos={X=0,Y=0,Z=0}})==false and spoken[#spoken]=="face_unsupported:Mail")
    check("nothing selected",F.start(c,nil)==false and spoken[#spoken]=="walk_no_target")
    _G.FindAllOf=nil;_G.StaticFindObject=nil;package.loaded["scanner.face"]=nil
end
-- Help follows the device; preview cycles cues and names each.
do
    package.loaded["core.help"]=nil;package.loaded["core.preview"]=nil
    local H=require("core.help");H.text=function(k)return k end
    check("keyboard help",H.lines(false)[1]=="help_keys_select" and #H.lines(false)==7)
    check("controller help",H.lines(true)[3]=="help_pad_walk")
    local en=require("lang.en")
    local all=true;for _,g in ipairs({false,true}) do for _,k in ipairs(H.lines(g)) do if not en[k] then all=false end end end
    check("every help line has English text",all)
    local P=require("core.preview");local said,played={},{}
    P.say=function(t)said[#said+1]=t end;P.play=function(f)played[#played+1]=f end;P.text=function(k)return k end
    for _=1,#P.cues+1 do P.next() end
    check("preview cycles",played[1]=="control_lost.wav" and played[2]=="control_back.wav" and played[#P.cues+1]=="control_lost.wav")
    check("every preview cue has a name",(function()local en=require("lang.en");for _,c in ipairs(P.cues) do if not en[c.key] then return false end end;return true end)())
    check("preview names each",said[2]=="cue_control_back" and en.cue_control_back~=nil)
    local before=#played;local delayed=nil;P.next(function(f)delayed=f end)
    check("sound waits for the name",#played==before and delayed~=nil)
end
-- Controller: L3+left is preview.
do
    package.loaded["scanner.pad"]=nil
    local p=require("scanner.pad").new()
    p:update(0x40,true,1)
    check("stick+left previews",table.concat(p:update(0x44,true,1.1),",")=="preview")
end
-- Interactions: labels, announcement wording, trigger on the game-focused object.
do
    package.loaded["scanner.actions"]=nil
    local A=require("scanner.actions")
    check("label from action name",A.label_key("Look01")=="$GT_Sensen_Action_Look")
    check("label override",A.label_key("Interact01","Open")=="$GT_Sensen_Action_Open")
    check("override already a full key",A.label_key("Interact02","$GT_Sensen_Action_Read")=="$GT_Sensen_Action_Read")
    local en=require("lang.en")
    A.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return tostring(p[n]) end)) end
    check("announcement",A.announce_text("Mail",{"Look","Take"})=="Mail. 1, Look, 2, Take.",A.announce_text("Mail",{"Look","Take"}))
    check("no actions",A.announce_text("Car",{})=="Car. No actions available.")
    local function o(t)t=t or {};t.IsValid=function()return true end;return t end
    local triggered=nil
    local function act(name,on)return {ActionName={ToString=function()return name end},bEnabled=on,OverrideDisplayName={ToString=function()return "None" end}} end
    local list={act("Look01",true),act("Take01",false),act("Speak01",false),act("Photo01",false),act("Interact01",true)}
    local door=o({GetAddress=function()return 5 end,bIsInteractionUIOpened=true,objectName={ToString=function()return "$GT_Sensen_Int_Door01" end},
        Actions={ForEach=function(_,cb)for i,v in ipairs(list) do cb(i,{get=function()return v end}) end end},
        TriggerActionBP=function(_,i)triggered=i;return true end})
    local c=o({GetAddress=function()return 1 end})
    local comp=o({GetOwner=function()return c end,ActorInteractionFocused=door})
    _G.FindAllOf=function(n)return n=="LiSInteractionComponent" and {comp} or {} end
    local spoken={};A.say=function(t)spoken[#spoken+1]=t end;A.translate=function(k)return ({["$GT_Sensen_Action_Look"]="Look",["$GT_Sensen_Action_Interact"]="Open",["$GT_Sensen_Int_Door01"]="Door"})[k] or k end
    A.reset();A.tick(c)
    check("focus announced once",spoken[1]=="Door. 1, Look, 2, Open.",tostring(spoken[1]))
    A.tick(c);check("not repeated",#spoken==1)
    check("slot 2 triggers full-list index 4",A.trigger(c,2)==true and triggered==4)
    check("slot 1 triggers index 0",A.trigger(c,1)==true and triggered==0)
    check("missing slot refused",A.trigger(c,3)==false and spoken[#spoken]=="No action 3.")
    door.bIsInteractionUIOpened=false;triggered=nil
    check("closed interaction refused",A.trigger(c,1)==false and triggered==nil and spoken[#spoken]=="Nothing to interact with here.")
    _G.FindAllOf=nil;package.loaded["scanner.actions"]=nil
end
-- Focus flicker: the same object is not re-announced within 3 s.
do
    package.loaded["scanner.actions"]=nil
    local A=require("scanner.actions")
    local now=0;A.clock=function()return now end
    local function o(t)t=t or {};t.IsValid=function()return true end;return t end
    local mail=o({GetAddress=function()return 9 end,bIsInteractionUIOpened=true,objectName={ToString=function()return "Mail" end},Actions={ForEach=function()end}})
    local c=o({GetAddress=function()return 1 end})
    local comp=o({GetOwner=function()return c end,ActorInteractionFocused=mail})
    _G.FindAllOf=function(n)return n=="LiSInteractionComponent" and {comp} or {} end
    local n=0;A.say=function()n=n+1 end;A.text=function(k)return k end
    A.reset();A.tick(c);check("first announced",n==1)
    comp.ActorInteractionFocused=nil;now=1;A.tick(c)
    comp.ActorInteractionFocused=mail;now=2;A.tick(c)
    check("flicker within 3 s silent",n==1)
    comp.ActorInteractionFocused=nil;now=4;A.tick(c)
    comp.ActorInteractionFocused=mail;now=5;A.tick(c)
    check("back after 3 s announced",n==2)
    _G.FindAllOf=nil;package.loaded["scanner.actions"]=nil
end
-- Correction maths (ported from the original): error feedback converges on a
-- camera that lands offset from each request; repeating the same request does not.
do
    package.loaded["scanner.face"]=nil
    local F=require("scanner.face")
    local desired={Pitch=-52,Yaw=112}
    local function camera(req)return {Pitch=req.Pitch+7,Yaw=req.Yaw} end -- lands 7 deg high
    local req={Pitch=-52,Yaw=112}
    for i=1,3 do local a=camera(req);req=F.correct(req,a,desired) end
    local final=camera(req)
    check("error feedback converges",math.abs(final.Pitch-desired.Pitch)<0.01 and math.abs(final.Yaw-desired.Yaw)<0.01,string.format("%.2f",final.Pitch))
    check("yaw wraps across 180",math.abs(F.wrap(190)-(-170))<0.001 and math.abs(select(2,F.correct({Pitch=0,Yaw=170},{Pitch=0,Yaw=170},{Pitch=0,Yaw=-170}))-20)<0.001)
    check("pitch request clamped",F.correct({Pitch=-85,Yaw=0},{Pitch=0,Yaw=0},{Pitch=-60,Yaw=0}).Pitch==-89)
    package.loaded["scanner.face"]=nil
end
-- Focus that lands after aiming (seen: 0.5 s later) still counts within the limit.
do
    package.loaded["scanner.face"]=nil
    local F=require("scanner.face")
    local function o(t)t=t or {};t.IsValid=function()return true end;return t end
    local obj=o({GetAddress=function()return 77 end})
    local beh=o({IsA=function()return true end})
    local cam={CamBhv_Current=beh,GetCameraLocation=function()return {X=0,Y=0,Z=0}end,GetCameraRotation=function()local r=beh.NextWantedCameraRotationForced or {Pitch=0,Yaw=0};return {Pitch=r.Pitch,Yaw=r.Yaw}end}
    local c=o({GetAddress=function()return 1 end,PlayerCameraManager=cam})
    local comp=o({GetOwner=function()return c end,ActorInteractionFocused=nil,InnerZoneActorsCurrentlyActionable={ForEach=function()end}})
    _G.FindAllOf=function(n)return n=="LiSInteractionComponent" and {comp} or {} end
    _G.StaticFindObject=function()return {FindLookAtRotation=function()return {Pitch=-30,Yaw=40,Roll=0}end} end
    local now=0;F.clock=function()return now end
    local spoken,announced={},false;F.say=function(t)spoken[#spoken+1]=t end;F.text=function(k)return k end;F.focused_announce=function()announced=true end
    F.start(c,{name="Bag",kind="interaction",pos={X=1,Y=1,Z=0},actor=obj})
    for i=1,4 do now=now+0.25;F.tick() end -- aimed, holding
    check("holds after aiming",#spoken==0 and not announced)
    comp.ActorInteractionFocused=obj;now=now+0.25;F.tick()
    check("late focus counts",announced and #spoken==0)
    _G.FindAllOf=nil;_G.StaticFindObject=nil;package.loaded["scanner.face"]=nil
end
-- Actions come from the pop-up's visible buttons (captured classroom values).
do
    package.loaded["scanner.actions"]=nil
    local A=require("scanner.actions")
    local look={index=0,name="Look01",key="$GT_Sensen_Action_Look",label="Look"}
    local look2={index=8,name="Look02",key="$GT_Sensen_Action_Look",label="Look"}
    local read={index=4,name="Interact01",key="$GT_Sensen_Action_Read",label="Read"}
    -- Photo: pop-up " |Look| | |Photo", button 2 visible; raw has Look01+Look02.
    local p=A.from_popup({" ","$GT_Sensen_Action_Look"," "," ","Photo"},{false,true,false,false},{look,look2})
    check("one Look, not two",#p==1 and p[1].label=="Look" and p[1].index==0)
    -- Journal: " |Look| |Read|Journal", buttons 2 and 4.
    local j=A.from_popup({" ","$GT_Sensen_Action_Look"," ","$GT_Sensen_Action_Read","Journal"},{false,true,false,true},{look,read,look2})
    check("journal Look and Read",#j==2 and j[1].label=="Look" and j[2].label=="Read" and j[2].index==4)
    check("hidden buttons ignored",#A.from_popup({"$GT_Sensen_Action_Look"},{false,false,false,false},{look})==0)
    package.loaded["scanner.actions"]=nil
end
-- Facing's announcement and the automatic one don't both speak the same object.
do
    package.loaded["scanner.actions"]=nil
    local A=require("scanner.actions")
    local now=0;A.clock=function()return now end
    local function o(t)t=t or {};t.IsValid=function()return true end;return t end
    local pc=o({GetAddress=function()return 9 end,bIsInteractionUIOpened=true,objectName={ToString=function()return "Pencil" end},Actions={ForEach=function()end},GetInteractionWidget=function()return nil end})
    local c=o({GetAddress=function()return 1 end})
    local comp=o({GetOwner=function()return c end,ActorInteractionFocused=nil})
    _G.FindAllOf=function(n)return n=="LiSInteractionComponent" and {comp} or {} end
    local n=0;A.say=function()n=n+1 end;A.text=function(k)return k end
    A.reset();A.tick(c)
    comp.ActorInteractionFocused=pc;A.announce(c) -- facing announces
    now=0.4;A.tick(c)                            -- automatic check sees the change
    check("facing then automatic: spoken once",n==1)
    _G.FindAllOf=nil;package.loaded["scanner.actions"]=nil
end
-- Controller: actions are named by the pop-up slot's face button.
do
    package.loaded["scanner.actions"]=nil
    local A=require("scanner.actions")
    local en=require("lang.en")
    A.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return tostring(p[n]) end)) end
    local journal={{label="Look",slot=2},{label="Read",slot=4}}
    check("keyboard numbers",A.announce_text("Journal",journal)=="Journal. 1, Look, 2, Read.")
    local buttons={"X","Y","B","A"}
    A.key_name=function(pos,slot)return slot and buttons[slot] or tostring(pos) end
    check("controller face buttons",A.announce_text("Journal",journal)=="Journal. Y, Look, A, Read.",A.announce_text("Journal",journal))
    check("controller without slot falls back to number",A.announce_text("Car",{"Look"})=="Car. 1, Look.")
    package.loaded["scanner.actions"]=nil
end
-- Tutorial prompts: captured classroom texts; drag prompts rewritten by block name.
do
    package.loaded["hud.tutorial"]=nil
    local T=require("hud.tutorial");T.text=function(k)return k end
    check("look rewritten (keyboard)",T.compose({{name="Look_M+K",text="Hold Left Mouse Button, drag <img id=\"Mouse\"/> towards “Look”"}},false)=="tutorial_look_keys")
    check("look rewritten (controller)",T.compose({{name="Look_GamepadRich",text="Aim at the photo with <img id=\"RStick36\"/>"}},true)=="tutorial_look_pad")
    check("selfie rewritten",T.compose({{name="Selfie_GamepadRich",text="press Left Mouse Button"}},true)=="tutorial_selfie_pad")
    check("images spoken",T.compose({{name="SpiralRich",text="Hold <img id=\"LTXB1_0\"/> to rewind"}},true)=="Hold left trigger to rewind")
    local en0=require("lang.en");T.text=function(k)return en0[k] or k end
    check("split move prompt names the stick",T.compose({{name="MoveTutorialPad1",text="Use "},{name="MoveTutorialPad2",text=" to move"}},true)=="Use the left stick to move")
    check("split camera prompt names the stick",T.compose({{name="CameraPad1",text="Use "},{name="CameraPad2",text=" to look around"}},true)=="Use the right stick to look around")
    check("split mouse camera prompt",T.compose({{name="CameraMouse1",text="Use "},{name="CameraMouse2",text=" to look around"}},false)=="Use the mouse to look around")
    check("split rewind prompts name the trigger",T.compose({{name="TextBlock_SpiralPad1",text="Hold "},{name="TextBlock_SpiralPad2",text=" to rewind"}},true)=="Hold the left trigger to rewind")
    check("split quick undo names the bumper",T.compose({{name="QuickUndoTutorialPad1",text="Press "},{name="QuickUndoTutorialPad2",text=" to quickly undo"}},true)=="Press the left bumper to quickly undo")
    T.text=function(k)return k end
    check("keyboard text as shown",T.compose({{name="MoveTutorialMouse",text="Use W, S, A, D to move."}},false)=="Use W, S, A, D to move.")
    check("untranslated key dropped",T.compose({{name="Selfie_Gamepad_1x",text="$GT_Mobile_UI_Tuto_SelfieGamepad2"}},true)==nil)
    check("quotes and lines normalised",T.speakable("A “Look”\r\nB")=='A "Look" B')
    local en=require("lang.en")
    check("rewrite strings exist",en.tutorial_look_keys and en.tutorial_look_pad and en.tutorial_selfie_keys and en.tutorial_selfie_pad)
    package.loaded["hud.tutorial"]=nil
end
-- Dialogue choices (hook-fed): answers arrive per slot from the view's own
-- update event; spoken once settled; chosen through the slot's button.
do
    package.loaded["dialogue.choices"]=nil
    local C=require("dialogue.choices")
    local en=require("lang.en")
    C.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return tostring(p[n]) end)) end
    local t=0;C.clock=function()return t end
    local tidy=require("core.text").tidy
    -- Captured 28 Oct (diner): slots 0-3 of a minor choice.
    C.update(0,"Cigarettes.",false);C.update(1,"Keys.",false);C.update(2,"Money.",false)
    check("not spoken before the updates settle",C.due(true)==nil)
    C.update(3,"Parking ticket.",false);t=1
    local s=C.due(true)
    check("settled list spoken, controller buttons by slot",s and tidy(s)=="Choose: Y, Cigarettes. X, Keys. B, Money. A, Parking ticket.",s)
    check("spoken once",C.due(true)==nil)
    check("keyboard numbers",tidy(C.current(false))=="Choose: 1, Cigarettes. 2, Keys. 3, Money. 4, Parking ticket.")
    -- The game refilling the same answers: silent.
    C.update(0,"Cigarettes.",false);C.update(1,"Keys.",false);t=1.5
    check("unchanged refill is silent",C.due(true)==nil)
    -- A choice made (the view's ChooseSentense) clears; the next, shorter list has no stale slots.
    C.clear("chosen_event")
    C.update(1,"Keys.",false);C.update(2,"Money.",false);C.update(3,"Parking ticket.",false);t=2
    local s2=C.due(true)
    check("next list replaces the old one",s2 and not s2:find("Cigarettes") and s2:find("^Choose: X, Keys"),s2)
    C.update(0,"",false);check("blank text hides a slot",#C.options()==3)
    C.clear("test");check("cleared",C.options()==nil and C.due(true)==nil)
    -- 29 Oct test: after choosing, the buttons still showed the chosen list
    -- for a moment and a read announced it again.
    C.clear("test");C.set_all({nil,"You're asking me?","I did know...",nil},false);t=2.5;C.due(false)
    C.clear("chosen")
    check("chosen list still on the buttons is ignored",C.set_all({nil,"You're asking me?","I did know...",nil},false)==0 and C.options()==nil)
    check("a new list after it is read",C.set_all({nil,"Do I have to?","I didn't have any time...",nil},false)==2)
    C.clear("chosen");C.set_all({},false)
    check("after an empty screen the same answers count again",C.set_all({nil,"Do I have to?","I didn't have any time...",nil},false)==2)
    C.clear("test")    C.update(0,"Banjo tune",true);C.update(1,"Guitar tune",true);t=3
    check("major wording and layout",(C.due(true) or ""):find("^Major choice: X, Banjo tune")~=nil)
    -- 29 Oct: the layout flag is true for the jukebox; the game's MajorChoiceOn fact decides the label.
    C.is_major=function()return false end
    check("not major when the game's fact is off; layout keys kept",(C.current(true) or ""):find("^Choose: X, Banjo tune")~=nil)
    C.is_major=function()return true end
    check("major when the fact is on",(C.current(true) or ""):find("^Major choice:")~=nil)
    C.is_major=function()return nil end
    check("falls back to the layout flag when the fact cannot be read",(C.current(true) or ""):find("^Major choice:")~=nil)
    C.is_major=nil
    check("out-of-range slot ignored",not C.update(7,"x",false) and not C.update(nil,"x",false))
    check("no doubled full stop after a question",C.announce_text({{text="Why?",key="1"}},false)=="Choose: 1, Why?")
    check("full stop added after a bare answer",C.announce_text({{text="Sure",key="1"}},false)=="Choose: 1, Sure.")
    -- Choosing presses the slot's button in the view found at that moment.
    C.clear("test");C.update(0,"A",false);C.update(2,"C",false)
    local clicked=nil
    local function b(i)return {ClickButton=function()clicked=i end} end
    local buttons={b(1),b(2),b(3),b(4)}
    local v={IsValid=function()return true end,IsInViewport=function()return true end,IsVisible=function()return true end,
        DialogButtons_Array={ForEach=function(_,cb)for i,x in ipairs(buttons) do cb(i,{get=function()return x end}) end end}}
    _G.FindAllOf=function(n)return n=="BP_LiSDialogWidget_View_C" and {v} or {} end
    local said={};C.say=function(x)said[#said+1]=x end
    check("second answer presses slot 3",C.choose(2) and clicked==3)
    check("list cleared after choosing",C.options()==nil)
    check("nothing to choose",not C.choose(1) and said[#said]==en.choice_none)
    C.update(0,"A",false);_G.FindAllOf=function()return {} end
    C.tick();check("view gone: list dropped",C.options()==nil)
    _G.FindAllOf=nil;package.loaded["dialogue.choices"]=nil
end-- Actions press the pop-up's own button for the slot (the door has three
-- enabled "Open" actions; only the game knows which its button runs).
do
    package.loaded["scanner.actions"]=nil
    local A=require("scanner.actions")
    local function o(t)t=t or {};t.IsValid=function()return true end;return t end
    local pressed,triggered=nil,nil
    local function act(name,on)return {ActionName={ToString=function()return name end},bEnabled=on,OverrideDisplayName={ToString=function()return "$GT_Sensen_Action_Open" end}} end
    local list={act("Look01",false),act("Interact01",false),act("Interact02",true),act("Interact03",true),act("Interact04",true)}
    local popup=o({TextValues={ForEach=function(_,cb)for i,s in ipairs({" "," "," ","$GT_Sensen_Action_Open","Door"}) do cb(i,{get=function()return {ToString=function()return s end}end}) end end},
        button1_visible=false,button2_visible=false,button3_visible=false,button4_visible=true,["Bottom Action"]=function()pressed="Bottom" end})
    local door=o({GetAddress=function()return 5 end,bIsInteractionUIOpened=true,objectName={ToString=function()return "Door" end},
        Actions={ForEach=function(_,cb)for i,v in ipairs(list) do cb(i,{get=function()return v end}) end end},
        GetInteractionWidget=function()return popup end,TriggerActionBP=function(_,i)triggered=i end})
    local c=o({GetAddress=function()return 1 end})
    local comp=o({GetOwner=function()return c end,ActorInteractionFocused=door})
    _G.FindAllOf=function(n)return n=="LiSInteractionComponent" and {comp} or {} end
    A.say=function()end;A.text=function(k)return k end;A.translate=function(k)return k end
    check("door: key 1 presses the pop-up's Bottom button",A.trigger(c,1) and pressed=="Bottom" and triggered==nil)
    popup["Bottom Action"]=nil -- pop-up can't be pressed: fall back to the action index
    check("fallback to the action index",A.trigger(c,1) and triggered==2)
    _G.FindAllOf=nil;package.loaded["scanner.actions"]=nil
end
-- Scanner skips objects the story has hidden (bHidden), as captured in the
-- classroom for students not yet in the scene.
do
    package.loaded["scanner.sources"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local function o(t)t=t or {};t.IsValid=function()return true end;t.HasAnyFlags=function()return false end;return t end
    local function actor(name,hidden)return o({bIsRegistered=true,bNeedToHide=false,bHidden=hidden,objectName={ToString=function()return name end},
        Actions={ForEach=function(_,cb)cb(1,{get=function()return {bEnabled=true} end})end},GetFullName=function()return name end,
        K2_GetActorLocation=function()return {X=0,Y=0,Z=0}end,GetFName=function()return {ToString=function()return name end}end}) end
    local c=o({GetAddress=function()return 1 end})
    local list={actor("Camera",false),actor("Daniel",true),actor("Butterfly",false)}
    list[3].ObjectActor=o({bHidden=true}) -- captured: the butterfly's model starts hidden
    list[1].ObjectActor=o({bHidden=false})
    local comp=o({GetOwner=function()return c end,RegisteredActors={ForEach=function(_,cb)for i,a in ipairs(list) do cb(i,{get=function()return a end}) end end}})
    _G.FindAllOf=function(n)return n=="LiSInteractionComponent" and {comp} or {} end
    _G.StaticFindObject=function()return nil end
    local src=require("scanner.sources");src.translate=function(k)return k end
    local got=src.collect(c)
    local names={};for _,e in ipairs(got) do names[#names+1]=e.label end
    check("hidden actor and hidden model left out",#got==1 and got[1].label=="Camera",table.concat(names,","))
    _G.FindAllOf=nil;_G.StaticFindObject=nil;_G.EObjectFlags=nil;package.loaded["scanner.sources"]=nil
end
-- Story availability: each action's fact conditions, the game's rule.
do
    package.loaded["scanner.availability"]=nil
    local V=require("scanner.availability")
    local facts={E1_2A_REWINDED=false,E1_2A_Toilets_FireAlarm_Look02_Triggered=false,E1_2A_Toilets_FireAlarm_Interact01_Triggered=false}
    local is=function(f)return facts[f] end
    -- Trolley (captured from the bathroom map): needs a rewind and the alarm looked at.
    local trolley={["and"]={{fact="E1_2A_REWINDED",want=true},{fact="E1_2A_Toilets_FireAlarm_Look02_Triggered",want=true},{fact="E1_2A_Toilets_FireAlarm_Interact01_Triggered",want=false}}}
    check("trolley gated on entry",not V.action_ok(trolley,is))
    facts.E1_2A_REWINDED=true;facts.E1_2A_Toilets_FireAlarm_Look02_Triggered=true
    check("trolley available after rewind and look",V.action_ok(trolley,is))
    local hammer={["and"]={{fact="E1_2A_Toilets_FireAlarm_Interact01_Triggered",want=false}}}
    facts.E1_2A_Toilets_FireAlarm_Interact01_Triggered=true
    check("hammer gone after the alarm",not V.action_ok(hammer,is))
    check("unknown fact never hides",V.action_ok({["and"]={{fact="Nope",want=true}}},is))
    check("no conditions is available",V.action_ok({},is))
    check("OR needs one match",not V.action_ok({["or"]={{fact="E1_2A_REWINDED",want=false}}},is) and V.action_ok({["or"]={{fact="E1_2A_REWINDED",want=false},{fact="E1_2A_REWINDED",want=true}}},is))
    package.loaded["scanner.availability"]=nil
end
-- Every spoken string passes core.text.tidy (in core/speech.lua): no added
-- punctuation after an authored sentence ending, whatever joined the parts.
do
    package.loaded["core.text"]=nil
    local T=require("core.text")
    check("user's report",T.tidy("Choose: X, I feel sick., B, I have to use the bathroom.")=="Choose: X, I feel sick. B, I have to use the bathroom.")
    check("question then comma",T.tidy("Choose: 1, Why?, 2, Fine.")=="Choose: 1, Why? 2, Fine.")
    check("question then full stop",T.tidy("Facing Why?.")=="Facing Why?")
    check("dots ellipsis then comma",T.tidy("I did know..., 2, No.")=="I did know... 2, No.")
    check("dots ellipsis then full stop kept as three",T.tidy("I did know....")=="I did know...")
    check("ellipsis character then comma",T.tidy("Wait\226\128\166, 2, Go.")=="Wait\226\128\166 2, Go.")
    check("ellipsis character then full stop",T.tidy("Wait\226\128\166.")=="Wait\226\128\166")
    check("ordinary commas untouched",T.tidy("Mail, 1.5 metres, ahead, 3 of 38")=="Mail, 1.5 metres, ahead, 3 of 38")
    check("decimal untouched",T.tidy("Door, 0.8 metres")=="Door, 0.8 metres")
    check("space before punctuation",T.tidy("Hold the left trigger , to rewind .")=="Hold the left trigger, to rewind.")
    -- And it is actually applied on the speech path.
    package.loaded["core.speech"]=nil
    local printed=nil;local real=print;print=function(s)printed=s end
    local S=require("core.speech");S.say("Choose: X, I feel sick., B, Go.",true)
    print=real
    check("speech path tidies",printed and printed:find("sick. B, Go.",1,true)~=nil,tostring(printed))
    package.loaded["core.speech"]=nil
end
-- Actor conditions become the target action's own triggered fact (captured:
-- the hammer needs the cart's Interact01 to have run).
do
    package.loaded["scanner.availability"]=nil
    local V=require("scanner.availability")
    local function arr(list)return {ForEach=function(_,cb)for i,v in ipairs(list) do cb(i,{get=function()return v end}) end end} end
    local function name(s)return {ToString=function()return s end} end
    local cart={IsValid=function()return true end,Actions=arr({{ActionName=name("Look01"),AutogeneratedFactName=name("E1_2A_Toilets_Trolley_Look01_Triggered")},
        {ActionName=name("Interact01"),AutogeneratedFactName=name("E1_2A_Toilets_Trolley_Interact01_Triggered")}})}
    local hammer_action={FactCondAND=arr({{FactName=name("E1_2A_Toilets_FireAlarm_Interact01_Triggered"),bFactActive=false}}),FactCondOR=arr({}),
        ActorCondAND=arr({{WhatIfInteractionActor=cart,ActionName=name("Interact01"),bTriggered=true}}),ActorCondOR=arr({})}
    local c=V.read_conditions(hammer_action)
    check("actor condition read as the cart's fact",#c["and"]==2 and c["and"][2].fact=="E1_2A_Toilets_Trolley_Interact01_Triggered" and c["and"][2].want==true)
    local facts={E1_2A_Toilets_FireAlarm_Interact01_Triggered=false,E1_2A_Toilets_Trolley_Interact01_Triggered=false}
    check("hammer hidden on entry",not V.action_ok(c,function(f)return facts[f] end))
    facts.E1_2A_Toilets_Trolley_Interact01_Triggered=true
    check("hammer appears after the cart",V.action_ok(c,function(f)return facts[f] end))
    package.loaded["scanner.availability"]=nil
end
-- Conditions are read once per object (nested walks are not repeated on every
-- key press), while each action's enabled switch is read fresh.
do
    package.loaded["scanner.sources"]=nil;package.loaded["scanner.availability"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local function o(t)t=t or {};t.IsValid=function()return true end;t.HasAnyFlags=function()return false end;return t end
    local cond_walks=0
    local function arr(list)return {ForEach=function(_,cb)for i,v in ipairs(list) do cb(i,{get=function()return v end}) end end} end
    local function counted(list)return {ForEach=function(_,cb)cond_walks=cond_walks+1;for i,v in ipairs(list) do cb(i,{get=function()return v end}) end end} end
    local action={bEnabled=true,FactCondAND=counted({}),FactCondOR=counted({}),ActorCondAND=counted({}),ActorCondOR=counted({})}
    local a=o({bIsRegistered=true,bNeedToHide=false,bHidden=false,objectName={ToString=function()return "Mail" end},Actions=arr({action}),
        GetFullName=function()return "LiSInteractionActor /Game/L.L:Mail" end,K2_GetActorLocation=function()return {X=0,Y=0,Z=0}end,GetFName=function()return {ToString=function()return "Mail" end}end})
    local c=o({GetAddress=function()return 1 end,IsFactActive=function()return false end})
    local comp=o({GetOwner=function()return c end,RegisteredActors=arr({a})})
    _G.FindAllOf=function(n)return n=="LiSInteractionComponent" and {comp} or {} end
    _G.StaticFindObject=function()return nil end;_G.FName=function(s)return s end
    local src=require("scanner.sources");src.translate=function(k)return k end
    for _=1,5 do src.collect(c) end
    check("conditions read once for five refreshes",cond_walks==4,tostring(cond_walks))
    action.bEnabled=false
    check("enabled switch read fresh",#src.collect(c)==0)
    _G.FindAllOf=nil;_G.StaticFindObject=nil;_G.EObjectFlags=nil;_G.FName=nil
    package.loaded["scanner.sources"]=nil;package.loaded["scanner.availability"]=nil
end
-- Exits: an active loading-zone volume with the game's exit prompt is listed,
-- named from the prompt; an inactive one is not.
do
    package.loaded["scanner.sources"]=nil
    _G.EObjectFlags={RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    local function o(t)t=t or {};t.IsValid=function()return true end;t.HasAnyFlags=function()return false end;return t end
    local vol=o({GetAddress=function()return 50 end,GetFullName=function()return "DNEVolume /Game/E1_2A_Corridor_LD.x:DNEVolume_5" end,
        GetActorBounds=function(...)assert(select("#",...)==4,"engine GetActorBounds takes 3 arguments");local _,_,orig,ext=...;orig.X,orig.Y,orig.Z=-590,-3197,99;ext.X,ext.Y,ext.Z=81,199,99 end})
    local param=o({GetOuter=function()return vol end,ParamValue={ToString=function()return "$GT_HUD_Int_GoToCampusA" end}})
    local comp=o({GetOuter=function()return vol end,bActive=true})
    local c=o({GetAddress=function()return 1 end})
    local ic=o({GetOwner=function()return c end,RegisteredActors={ForEach=function()end}})
    _G.FindAllOf=function(n)return ({DNEVolume={vol},ExposParam_STRING={param},DNEBehaviorComponent={comp},LiSInteractionComponent={ic}})[n] or {} end
    _G.StaticFindObject=function()return nil end
    local src=require("scanner.sources")
    src.translate=function(k)return k=="$GT_HUD_Int_GoToCampusA" and "[action_interact] Go To The Main Campus" or k end
    local en=require("lang.en");src.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return p[n] end)) end
    local got=src.collect(c)
    check("active exit listed with the prompt's name",#got==1 and got[1].kind=="exit" and got[1].label=="Go To The Main Campus, exit",got[1] and got[1].label)
    check("exit stand point is the volume's floor, not the pivot",got[1] and got[1].stand.Z==0 and got[1].pos.X==-590)
    comp.bActive=false
    check("inactive exit not listed",#src.collect(c)==0)
    _G.FindAllOf=nil;_G.StaticFindObject=nil;_G.EObjectFlags=nil;package.loaded["scanner.sources"]=nil
end
-- Object viewer: the page's text version (captured: the mail), or a plain
-- "No text version." (captured: the classroom photo); page position last.
do
    package.loaded["hud.viewer"]=nil
    local V=require("hud.viewer")
    local en=require("lang.en")
    V.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return tostring(p[n]) end)) end
    V.clean=require("core.text").clean
    local mail="Your statement is enclosed \nURGENT \nYour electricity bill is inside \nPAST DUE"
    check("mail text read",V.describe(mail,1,1)=="Your statement is enclosed. URGENT. Your electricity bill is inside. PAST DUE",V.describe(mail,1,1))
    check("photo without text",V.describe("",1,1)=="No text version.")
    check("page position at the end when several",V.describe("Hello.",2,3)=="Hello. Page 2 of 3.")
    package.loaded["hud.viewer"]=nil
end
-- Journal: one item at a time with its position; diary paragraphs restored to
-- authored order (captured: the game's order changed between two visits).
do
    package.loaded["hud.journal"]=nil
    local J=require("hud.journal")
    local en=require("lang.en")
    J.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return tostring(p[n]) end)) end
    check("sort key",J.sort_key("E0_Page00_C")=="D000000C" and J.sort_key("E1_Page12_A")>J.sort_key("E1_Page05_F") and J.sort_key("E1_page06_D")~=nil)
    check("character page keys",J.sort_key("Chara_Kate_B")>J.sort_key("Chara_Kate_A"))
    local key={["July 10, 2013"]="000000A",["I GOT ACCEPTED."]="000000B",["My mom cried."]="000000E"}
    local scrambled={"My mom cried.","July 10, 2013","I GOT ACCEPTED."}
    local o=J.order(scrambled,function(p)return key[p] end)
    check("paragraphs in authored order",o[1]=="July 10, 2013" and o[2]=="I GOT ACCEPTED." and o[3]=="My mom cried.")
    check("unknown paragraphs kept after",J.order({"x","July 10, 2013"},function(p)return key[p] end)[2]=="x")
    check("names in stable order",table.concat(J.sorted({"Max","David","Kate"}),",")=="David,Kate,Max")
    local page={kind="diary",title="Journal",items={"July 10, 2013","I GOT ACCEPTED."},page={1,12}}
    local c=J.cursor()
    check("entry: title, page, first item",c:update(page)=="Journal Page 1 of 12. July 10, 2013",c:update(page) or "")
    check("same page again is silent",c:update(page)==nil)
    check("down reads the next item",c:move(1)=="I GOT ACCEPTED.")
    check("past the end",c:move(1)=="Last item.")
    check("up again",c:move(-1)=="July 10, 2013" and c:move(-1)=="First item.")
    local page2={kind="diary",title="Journal",items={"August 18, 2013"},page={2,12}}
    check("new page announced with its number",c:update(page2)=="Journal Page 2 of 12. August 18, 2013")
    check("closing resets",c:update(nil)==nil and c:update(page2)~=nil)
    local empty={kind="photos",title="Photos",items={}}
    check("tab without readable items",J.cursor():update(empty)=="Photos Nothing to read on this page.")
    package.loaded["hud.journal"]=nil
end
-- Controller: D-pad up/down step through a reader, ignoring keys held on entry.
do
    package.loaded["scanner.pad"]=nil
    local p=require("scanner.pad").new()
    check("held on entry ignored",p:reader(0x2,0)==nil)
    p:reader(0,0.1)
    check("down",p:reader(0x2,0.2)==1)
    check("repeat after hold",p:reader(0x2,0.5)==nil and p:reader(0x2,0.7)==1)
    p:reader(0,0.8)
    check("up",p:reader(0x1,0.9)==-1)
    package.loaded["scanner.pad"]=nil
end
-- Controller chords work without control (object viewer), scanner keys do not.
do
    package.loaded["scanner.pad"]=nil
    local p=require("scanner.pad").new()
    p:update(0x40,false,1)
    check("repeat chord while inactive",table.concat(p:update(0x48,false,1.1),",")=="repeat")
    p:update(0,false,1.2)
    check("scanner keys stay off while inactive",#p:update(0x8,false,1.3)==0)
    p:update(0x40,false,1.4)
    check("stick click alone does not face while inactive",#p:update(0,false,1.5)==0)
    package.loaded["scanner.pad"]=nil
end
-- Journal lists follow the game's highlight; profiles read before the list.
do
    package.loaded["hud.journal"]=nil
    local J=require("hud.journal")
    local en=require("lang.en")
    J.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return tostring(p[n]) end)) end
    local c=J.cursor()
    local function chars(name)return {kind="characters",title="Characters",items={name},list=true} end
    check("list entry announced with title",c:update(chars("Max"))=="Characters Max")
    check("game moved highlight: only the name",c:update(chars("Jefferson"))=="Jefferson")
    check("Up/Down leave lists to the game",c:move(1)==nil)
    local profile={kind="profile",title="Max",items={"\"Say Cheese!\"","On a scholarship even!"},ref="Max"}
    check("profile announced with its name and first paragraph",c:update(profile)=="Max \"Say Cheese!\"")
    check("profile paragraphs step",c:move(1)=="On a scholarship even!")
    local days={kind="days",title="Days",items={"Monday"},list=true}
    check("days menu",J.cursor():update(days)=="Days Monday")
    package.loaded["hud.journal"]=nil
end
-- Paragraph order from page positions: left column top-down, then right (the
-- original's rule; Victoria's authored keys C,B,D,E,A read in that layout).
do
    package.loaded["hud.journal"]=nil
    local J=require("hud.journal")
    local items={{text="A",x=900,y=500},{text="B",x=100,y=300},{text="C",x=100,y=50},{text="D",x=100,y=600},{text="E",x=900,y=80}}
    local o,how=J.reading_order(items,function()return nil end)
    check("columns then top-down",table.concat(o,",")=="C,B,D,E,A" and how=="position",table.concat(o,","))
    local single={{text="B",x=100,y=300},{text="A",x=110,y=40},{text="C",x=105,y=700}}
    check("single column top-down",table.concat((J.reading_order(single,function()return nil end)),",")=="A,B,C")
    local nopos={{text="x"},{text="July"}}
    local o2,how2=J.reading_order(nopos,function(p)return p=="July" and "D0000A" or nil end)
    check("no positions: authored keys",o2[1]=="July" and how2=="key")
    local same={{text="b",x=0,y=0},{text="a",x=0,y=0}}
    check("all at origin counts as no positions",select(2,J.reading_order(same,function()return nil end))=="key")
    package.loaded["hud.journal"]=nil
end
-- Message threads: one message at a time, starting at the latest; new
-- messages announced once.
do
    package.loaded["hud.journal"]=nil
    local J=require("hud.journal")
    local en=require("lang.en")
    J.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return tostring(p[n]) end)) end
    check("message wording",J.message_text("Kate","10:42 AM","Hi Max!")=="Kate, 10:42 AM: Hi Max!")
    check("message without time",J.message_text("Max",nil,"On my way.")=="Max: On my way.")
    check("designer placeholder never spoken as sender",J.message_text("Text Block","09/25 10:51 am","Hey Max u around?")=="Unknown sender, 09/25 10:51 am: Hey Max u around?")
    local c=J.cursor()
    local thread={kind="thread",title="Kate",ref="Kate",items={"Kate: Hi.","Max: Hey.","Kate: Bye."},ids={"1","2","3"}}
    check("opens at the latest message",c:update(thread)=="Kate Kate: Bye.")
    check("up reads older",c:move(-1)=="Max: Hey.")
    check("down back to latest",c:move(1)=="Kate: Bye." and c:move(1)=="Last item.")
    local grown={kind="thread",title="Kate",ref="Kate",items={"Kate: Hi.","Max: Hey.","Kate: Bye.","Kate: Wait!"},ids={"1","2","3","4"}}
    check("new message announced once",c:update(grown)=="New message. Kate: Wait!" and c:update(grown)==nil)
    check("cursor follows to the new message when at the end",c:move(1)=="Last item.")
    package.loaded["hud.journal"]=nil
end
-- Message threads: sender from the portrait texture (works when the game opens
-- the thread itself); typing bubbles (".", "..") are not messages.
do
    package.loaded["hud.journal"]=nil
    local J=require("hud.journal")
    J.text=function(k)return k=="journal_max" and "Max" or k end
    J.translate=function(k)return k=="$GT_Menus_Journal_Warren" and "Warren" or k end
    local function o(t)t=t or {};t.IsValid=function()return true end;t.IsVisible=function()return true end;return t end
    local function tb(s)return o({GetText=function()return {ToString=function()return s end} end}) end
    local function sms(body,mine)return o({IsA=function()return true end,TextBlock_Body=tb(body),TextBlock_Meta=tb("10/07 4:23 pm"),IsMax=mine,GetAddress=function()return body end}) end
    local kids={sms("I hope so.",false),sms(".",false),sms("..",true)}
    local box=o({GetChildrenCount=function()return #kids end,GetChildAt=function(_,i)return kids[i+1] end})
    J.last_contact="Dad"
    local w=o({VerticalBox_Content=box,SenderPortrait=o({GetFName=function()return {ToString=function()return "WarrenThumb" end} end})})
    local th=J.thread_items(w)
    check("sender from the portrait, not the list",th and th.title=="Warren" and th.items[1]=="Warren, 10/07 4:23 pm: I hope so.",th and th.items[1])
    check("typing bubbles skipped",th and #th.items==1)
    package.loaded["hud.journal"]=nil
end
-- Keyboard shortcuts polled on the game thread (no loader key binds).
do
    package.loaded["core.keys"]=nil
    local K=require("core.keys").new()
    local log={}
    local HOME,PGDN=0x24,0x22
    K:bind(HOME,"none",function()log[#log+1]="describe" end)
    K:bind(HOME,"ctrl",function()log[#log+1]="repeat" end)
    K:bind(HOME,"shift",function()log[#log+1]="walk" end)
    K:bind(PGDN,"none",function()log[#log+1]="next" end)
    local SHIFT,CTRL=1<<30,1<<31
    local function run(mask)for _,f in ipairs(K:update(mask)) do f() end end
    check("one slot per key",#K.vks==2 and K.vks[1]==HOME and K.vks[2]==PGDN)
    run(1)  -- Home already held at the first reading: ignored
    check("key held at start ignored",#log==0)
    run(0);run(1)
    check("press fires once",table.concat(log,",")=="describe")
    run(1)
    check("holding does not repeat",#log==1)
    run(0);run(1|SHIFT)
    check("Shift+Home is its own shortcut",log[#log]=="walk" and #log==2)
    run(0);run(1|CTRL)
    check("Ctrl+Home is its own shortcut",log[#log]=="repeat" and #log==3)
    run(0);run(2)
    check("other key",log[#log]=="next")
    run(0);run(3)
    check("two keys pressed together both fire",log[#log-1]=="describe" and log[#log]=="next")
    check("no reading (game not focused) is harmless",#K:update(nil)==0)
    package.loaded["core.keys"]=nil
end
-- Held Page Down repeats like the D-pad (0.45 s, then every 0.18 s); keys bound
-- without repeat do not.
do
    package.loaded["core.keys"]=nil
    local K=require("core.keys").new()
    local n,h=0,0
    K:bind(0x22,"none",function()n=n+1 end,{["repeat"]=true})
    K:bind(0x24,"none",function()h=h+1 end)
    local function at(mask,t)for _,f in ipairs(K:update(mask,t)) do f() end end
    at(0,0);at(3,0.0)
    check("first press",n==1 and h==1)
    at(3,0.3);check("no repeat before the delay",n==1)
    at(3,0.46);check("repeats after the delay",n==2)
    at(3,0.6);check("not before the rate",n==2)
    at(3,0.65);check("then at the rate",n==3)
    check("non-repeating key stays single",h==1)
    at(0,0.7);at(1,0.8)
    check("released and pressed again fires once",n==4)
    at(1,1.0);check("and waits the full delay again",n==4)
    at(1,1.26);check("then repeats",n==5)
    package.loaded["core.keys"]=nil
end
-- Off the navigation mesh: our own planner and walker take over.
do
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors","nav.offmesh"}) do package.loaded[m]=nil end
    local loops={}
    _G.LoopInGameThreadWithDelay=function(_,fn)loops[#loops+1]=fn;return #loops end
    _G.CancelDelayedAction=function(h)loops[h]=false end
    local function pump(n)for _=1,n or 1 do for i,f in ipairs(loops) do if f then f() end end end end
    local ff={active=nil};ff.ready=function()return true end;ff.start=function()end;ff.stop=function()end;ff.tick=function()end
    package.loaded["nav.follow"]=ff
    local projectable=false
    package.loaded["nav.route"]={project=function(_,p)return projectable,{X=p.X,Y=p.Y,Z=p.Z} end}
    package.loaded["nav.doors"]={plan=function()return false end}
    local plan_state,steps="found",0
    local walked=nil
    package.loaded["nav.offmesh"]={
        planner=function()return {g={samples=0},waypoints={{X=150,Y=0,Z=0}},step=function(self)steps=steps+1;if plan_state=="failed" then self.reason="no_path" end;return plan_state end} end,
        walk=function(_,_,wps,done)walked={wps=wps,done=done} end,
        cancel=function()if walked then walked.done("cancelled",50);walked=nil;return true end;return false end,
        ground_below=function(_,_,p)return p.Z-130 end}
    local aw=require("autowalk.autowalk")
    local spoken={};aw.say=function(t)spoken[#spoken+1]=t end
    aw.text=function(k,p)return k..(p and p.name and (":"..p.name) or "") end
    local pawn={CapsuleComponent={K2_GetComponentLocation=function()return {X=0,Y=0,Z=100}end,GetScaledCapsuleHalfHeight=function()return 84 end}}
    local c={Pawn=pawn};local pump_e={name="Water Pump",stand={X=150,Y=0,Z=0},pos={X=160,Y=0,Z=50}}
    check("unprojected target plans off the mesh",aw.start(c,pump_e)==true and aw.walking())
    pump(1)
    check("found: walk starts and is announced",walked~=nil and spoken[#spoken]=="walk_start:Water Pump")
    walked.done("arrived_test_region",20)
    check("off-mesh arrival announced",spoken[#spoken]=="walk_arrived:Water Pump" and not aw.walking())
    aw.start(c,pump_e);pump(1)
    check("cancel stops the off-mesh walk",aw.cancel()==true and spoken[#spoken]=="walk_stopped" and not aw.walking())
    plan_state="failed"
    aw.start(c,pump_e);pump(1)
    check("no way found says no route",spoken[#spoken]=="walk_no_route:Water Pump" and not aw.walking())
    projectable=true
    aw.start(c,pump_e);pump(1)
    check("no navmesh route also tries the grid",steps>=4 and spoken[#spoken]=="walk_no_route:Water Pump")
    _G.LoopInGameThreadWithDelay=nil;_G.CancelDelayedAction=nil
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors","nav.offmesh"}) do package.loaded[m]=nil end
end
-- Own grid planner (levels whose navigation mesh leaves ground uncovered).
do
    package.loaded["nav.grid"]=nil
    local G=require("nav.grid")
    -- A 20 x 20 m lawn at z=0 with a wall from y=-500..500 at x=1000 (gap at
    -- y>500), a raised 1 m platform at x>1600, and nothing outside 2500 cm.
    local function sample(x,y)
        if math.abs(x)>2500 or math.abs(y)>2500 then return nil end
        if x>=950 and x<=1050 and y>=-1500 and y<=500 then return nil end
        if x>1600 and y<-1000 then return 100 end
        return 0
    end
    local function run(s)local st;repeat st=s:step(200) until st~="running";return st end
    local s=G.new({X=0,Y=0,Z=0},{X=2000,Y=0,Z=0},{sample=sample})
    check("grid finds a way round the wall",run(s)=="found")
    local through=false;for _,p in ipairs(s.path) do if p.X>=950 and p.X<=1050 and p.Y<=500 then through=true end end
    check("grid path never crosses the wall",not through)
    local endp=s.path[#s.path];check("grid ends at the target",(endp.X-2000)^2+endp.Y^2<=60^2)
    local s2=G.new({X=0,Y=0,Z=0},{X=2000,Y=-2000,Z=0},{sample=sample})
    check("grid refuses a 1 m step up",run(s2)=="failed")
    local s3=G.new({X=0,Y=0,Z=0},{X=1550,Y=-2000,Z=0},{sample=sample})
    check("reaches the foot of the platform",run(s3)=="found")
    local function boxed(x,y)if math.abs(x)>=200 or math.abs(y)>=200 then return nil end;return 0 end
    local s4=G.new({X=0,Y=0,Z=0},{X=1000,Y=0,Z=0},{sample=boxed})
    check("grid reports an enclosed start",run(s4)=="failed" and s4.reason=="no_path")
    -- The closest reachable point when there is no way (the diner's truck):
    -- inside the 4 m box, the cell nearest the target at x=1000.
    local cp=s4:closest_path()
    check("a failed search keeps the way to its closest point",cp and #cp>=2 and cp[#cp].X>=100 and cp[#cp].X<200 and math.abs(cp[#cp].Y)<60,cp and string.format("%d pts end %.0f,%.0f",#cp,cp[#cp].X,cp[#cp].Y) or "nil")
    check("that way starts at Max",cp and cp[1].X==0 and cp[1].Y==0)
    local rep=s4:report(60)
    check("failure report names the cause and maps the area",rep[1]:find("refused=") and rep[2]:find("^grid_target") and rep[3] and rep[3]:find("^grid_area") and #rep>4)
    -- A diagonal line of refused cells (x+y=500, cell 50) is crossable only by
    -- diagonal steps past two refused side cells: impossible without a corner
    -- check, possible when the sweep says Max fits.
    local function diag(x,y)
        if math.abs(x)>1000 or math.abs(y)>1000 then return nil end
        if math.abs((x+y)-500)<1 then return nil end
        return 0
    end
    local s7=G.new({X=0,Y=0,Z=0},{X=1000,Y=0,Z=0},{sample=diag})
    check("diagonal wall: no way without a corner check",run(s7)=="failed")
    local corner_calls=0
    local s8=G.new({X=0,Y=0,Z=0},{X=1000,Y=0,Z=0},{sample=diag,corner=function()corner_calls=corner_calls+1;return true end})
    check("diagonal wall: crossed when the corner sweep allows it",run(s8)=="found" and corner_calls>0)
    local s9=G.new({X=0,Y=0,Z=0},{X=1000,Y=0,Z=0},{sample=diag,corner=function()return false end})
    check("diagonal wall: still refused when the sweep is blocked",run(s9)=="failed")
    check("best distance recorded",s7.best_d<1000)
    local big=G.new({X=0,Y=0,Z=0},{X=1000,Y=0,Z=0},{sample=function(x,y)if x>=900 then return nil end;return 0 end,reach=150})
    check("a target inside an obstacle is reached from beside it with a larger reach",run(big)=="found")
    -- Zachary (27 Oct): a person's centre is inside their collision, so with a
    -- 60 cm arrival radius only a thin ring of cells could count, and whether
    -- any grid cell landed in it depended on where Max started - failed from
    -- one spot, found from another. Person: refused within 55 cm.
    local function person(x,y)if (x-1000)^2+y^2<55^2 then return nil end;return 0 end
    local a1=G.new({X=0,Y=0,Z=0},{X=1000,Y=0,Z=0},{sample=person,reach=60})
    local a2=G.new({X=0,Y=25,Z=0},{X=1000,Y=0,Z=0},{sample=person,reach=60})
    check("60 cm round a person: depends on the starting spot",run(a1)=="failed" and run(a2)=="found")
    local b1=G.new({X=0,Y=0,Z=0},{X=1000,Y=0,Z=0},{sample=person,reach=150})
    check("150 cm round a person: found from either spot",run(b1)=="found")
    local far=G.new({X=0,Y=0,Z=0},{X=4270,Y=0,Z=0},{sample=function()return 0 end,radius=4000})
    check("search area always contains the target",far.radius>=4270+2000)
    local s5=G.new({X=0,Y=0,Z=0},{X=2000,Y=0,Z=0},{sample=sample,max_samples=100})
    check("grid stops at its sample budget",run(s5)=="failed" and s5.reason=="too_far")
    local s6=G.new({X=0,Y=0,Z=0},{X=2000,Y=0,Z=0},{sample=sample})
    check("grid works in small steps",s6:step(10)=="running" and s6.samples<=18)
    -- Shortening keeps only the corner at the wall's gap.
    local function clear(a,b)
        for t=0,1,0.02 do local x,y=a.X+(b.X-a.X)*t,a.Y+(b.Y-a.Y)*t;if not sample(x,y) then return false end end
        return true
    end
    local short=G.shorten(s.path,clear)
    check("shortened path has few waypoints",#short>=2 and #short<=4,#short)
    local ok=true;local prev=s.path[1];for _,p in ipairs(short) do if not clear(prev,p) then ok=false end;prev=p end
    check("every shortened leg is clear",ok)
    local wp=s:waypoints()
    local ok2=true;local pv=s.path[1];for _,p in ipairs(wp) do if not clear(pv,p) then ok2=false end;pv=p end
    check("waypoints from the grid's own cells are clear",ok2 and #wp<=6,#wp)
    check("line over an unsampled cell is not open",not s:line_open({X=0,Y=0},{X=0,Y=2400}))
    package.loaded["nav.grid"]=nil
end
-- Action tooltips: the exit prompt with the device's interact key.
do
    package.loaded["hud.tooltip"]=nil
    local T=require("hud.tooltip")
    local key=function(a)return a=="action_interact" and "Space" or nil end
    check("exit prompt with key",T.speakable("[action_interact] Go To The Main Campus",key)=="Go To The Main Campus, Space")
    check("unknown action dropped",T.speakable("[action_mystery] Leave",function()return nil end)=="Leave")
    check("developer placeholder ignored",T.speakable("dsfasdfasfd",key)==nil)
    check("empty ignored",T.speakable("  ",key)==nil and T.speakable(nil,key)==nil)
    check("untranslated key ignored",T.speakable("$GT_HUD_Int_GoToCampusA",key)==nil)
    -- Standing in an exit (its live bounds) gives that exit's prompt.
    local list={{id="a",pos={X=0,Y=0,Z=100},extent={X=200,Y=100,Z=100},prompt="[action_interact] Go To The Parking Lot"}}
    check("inside the exit",T.exit_at(list,{X=150,Y=50,Z=5})~=nil)
    check("outside the exit",T.exit_at(list,{X=260,Y=0,Z=5})==nil)
    check("margin keeps it while at the edge",T.exit_at(list,{X=240,Y=0,Z=5},50)~=nil)
    check("exit prompt spoken with the key",T.speakable(T.exit_at(list,{X=0,Y=0,Z=5}).prompt,key)=="Go To The Parking Lot, Space")
    -- Activity prompts: the words plus the key, never a bare key.
    check("stop prompt with key",T.prompt_text("Stop Playing","Space")=="Stop Playing, Space")
    check("stop prompt on a controller",T.prompt_text("  Stop  Flying ","B")=="Stop Flying, B")
    check("no words, nothing spoken",T.prompt_text("","Space")==nil and T.prompt_text(nil,"Space")==nil)
    check("placeholder words ignored",T.prompt_text("dsfasdfasfd","Space")==nil and T.prompt_text("$GT_HUD_Skip","Space")==nil)
    package.loaded["hud.tooltip"]=nil
end
-- New text message notifications (HUD).
do
    package.loaded["hud.sms"]=nil
    local S=require("hud.sms")
    local en=require("lang.en")
    S.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return tostring(p[n]) end)) end
    check("one message",S.announce("Chloe","1")=="New message from Chloe.")
    check("several unread",S.announce("Warren","3")=="New message from Warren. 3 unread.")
    check("placeholder sender ignored",S.announce("Text Block","1")==nil and S.announce("","1")==nil)
    local a={hud=1,sms=true,playing=false,sender="Chloe",count="1"}
    check("first look only records",not S.is_new(nil,a))
    check("unchanged, not new",not S.is_new(a,{hud=1,sms=true,playing=false,sender="Chloe",count="1"}))
    check("animation starting is new (same sender and count)",S.is_new(a,{hud=1,sms=true,playing=true,sender="Chloe",count="1"})=="animation")
    check("still playing is not new again",not S.is_new({hud=1,sms=true,playing=true,sender="Chloe",count="1"},{hud=1,sms=true,playing=true,sender="Chloe",count="1"}))
    check("another sender is new",S.is_new(a,{hud=1,sms=true,playing=false,sender="Warren",count="1"})=="change")
    -- 27 Oct: a scene load made a new HUD whose Sender holds its designer text.
    check("a new scene's HUD is only recorded",not S.is_new({hud=1,sms=true,playing=false,sender="Victoria",count="1"},{hud=2,sms=true,playing=true,sender="Chloe",count="1"}))
    check("a new photo is not a message",not S.is_new(a,{hud=1,sms=false,playing=true,sender="Chloe",count="1"}))
    package.loaded["hud.sms"]=nil
end
-- Ending nightmare guide: steps follow Max's position, reversibly.
do
    package.loaded["nightmare.guide"]=nil
    local G=require("nightmare.guide")
    local never=function()return false end
    check("at the start the first step is current",G.current(G.START,never)==1)
    check("past the rocks trigger, the tree is next",G.current({X=3470,Y=1300},never)==2)
    check("rewound back before the rocks, the rocks are current again",G.current({X=3530,Y=2300},never)==1)
    local s=G.STEPS
    local shelter;for i,v in ipairs(s) do if v.id=="shelter" then shelter=i end end
    local held=function(h)return h=="logs" end
    check("waiting in the shelter holds the guide there",G.current({X=s[shelter].X,Y=s[shelter].Y},held)==shelter)
    check("once the logs have passed, the next step",G.current({X=s[shelter].X,Y=s[shelter].Y},never)==shelter+1)
    check("standing at the newspaper, it is the last step",G.current({X=-1453,Y=566},never)==#s)
    -- Every step, from just short of it on its own leg: that step is current.
    local ok=true
    local prev=G.START
    for i,v in ipairs(s) do
        local p={X=prev.X+(v.X-prev.X)*0.5,Y=prev.Y+(v.Y-prev.Y)*0.5}
        if G.current(p,never)~=i then ok=false;print("step",i,v.id,"got",G.current(p,never)) end
        prev=v
    end
    check("each leg leads to its own step",ok)
    local shortest=math.huge;prev=G.START
    for _,v in ipairs(s) do shortest=math.min(shortest,math.sqrt((v.X-prev.X)^2+(v.Y-prev.Y)^2));prev=v end
    check("reach is under half the shortest leg",G.REACH<shortest/2,shortest)
    check("only the crossing to the newspaper keeps trying",(function()local n=0;for _,v in ipairs(s) do if v.persist then n=n+1;if v.id~="newspaper" then return false end end end;return n==1 end)())
    check("no step stops at the hole's edge",(function()for _,v in ipairs(s) do if v.id=="hole" then return false end end;return true end)())
    check("reaching a step moves to the next",G.current({X=s[3].X,Y=s[3].Y},never)==4)
    check("ran past the shelter while the logs roll: back to the shelter",G.current({X=s[shelter+1].X*0.5+s[shelter].X*0.5,Y=s[shelter+1].Y*0.5+s[shelter].Y*0.5},held)==shelter)
    local f={RollingLogsBegin=true,RollingLogsDanger=true}
    check("logs rolling: hold",G.logs_held(function(k)return f[k]==true end))
    f.RollingLogsDanger=false
    check("logs passed: go on",not G.logs_held(function(k)return f[k]==true end))
    check("logs not yet started: hold",G.logs_held(function()return false end))
    local c=G.changes({},{RollingLogsDanger=true})
    check("logs start: get into the shelter",c[1]=="guide_logs")
    c=G.changes({SafePlace=true},{SafePlace=true,RollingLogsDanger=true})
    check("logs start while in the shelter: stay",c[1]=="guide_logs_stay")
    c=G.changes({RollingLogsDanger=true,SafePlace=true},{SafePlace=true})
    check("logs over",c[1]=="guide_logs_passed")
    c=G.changes({},{LighthouseDebrisDanger=true,LighthouseFallingDanger=true})
    check("lighthouse said once",#c==1 and c[1]=="guide_lighthouse")
    check("tree falling is not announced as let go",#G.changes({},{LighthouseTree=true})==0)
    local paper;for _,v in ipairs(s) do if v.id=="newspaper" then paper=v end end
    -- 27 Oct: the search reached ground 81-99 cm from the newspaper and failed at 60.
    check("newspaper reach covers the measured approach",paper.reach and paper.reach>=100)
    check("way closed: floor dropped, Max short of the hole",G.lighthouse_closed(11.0,{X=-582,Y=170}))
    check("newspaper position matches its step",G.NEWSPAPER.X==paper.X and G.NEWSPAPER.Y==paper.Y)
    local main_src=io.open("src/main.lua"):read("a")
    check("Shift+Home passes the entry alone",main_src:find("local e=scanner.selected();autowalk.start(c,e)",1,true)~=nil)
    check("not closed before the floor drops",not G.lighthouse_closed(9.0,{X=-582,Y=170}))
    check("not closed once past the hole",not G.lighthouse_closed(12.0,{X=-1191,Y=66}))
    -- 28 Oct playtest: caught past the hole at (-1273,242); let go after the debris.
    check("near side: let go when the tree stands again",G.let_go(3.0,{X=-814,Y=-102},false) and not G.let_go(5.0,{X=-814,Y=-102},true))
    check("past the hole: let go by 6 s, not at 8",G.let_go(5.9,{X=-1273,Y=242},true) and not G.let_go(8.0,{X=-1273,Y=242},true))
    check("past the hole means the newspaper side",G.past_hole({X=-1273,Y=242}) and not G.past_hole({X=-1036,Y=-22}) and not G.past_hole({X=-814,Y=-102}))
    check("first reading says nothing",#G.changes(nil,{RollingRock01Danger=true})==0)
    check("caught during the rocks",G.stall_message({RollingRock01Danger=true})=="guide_caught")
    check("stalled with no danger is just blocked",G.stall_message({SafePlace=true})==nil)
    check("logs begin alone is not a danger",G.danger({RollingLogsBegin=true})==nil)
    local en=require("lang.en")
    local missing={};for _,h in ipairs(G.HAZARDS) do for _,k in ipairs({h.on,h.off}) do if k and not en[k] then missing[#missing+1]=k end end end
    for _,v in ipairs(s) do if not en[v.label] then missing[#missing+1]=v.label end end
    for _,k in ipairs({"guide_logs_stay","guide_entry","guide_done","guide_caught","guide_rewound"}) do if not en[k] then missing[#missing+1]=k end end
    check("every guide phrase is in the catalogue",#missing==0,table.concat(missing,","))
    package.loaded["nightmare.guide"]=nil
end
-- Guide walks carry on to the next step on arrival, and stop at the shelter.
do
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors","nav.offmesh"}) do package.loaded[m]=nil end
    local loops={}
    _G.LoopInGameThreadWithDelay=function(_,fn)loops[#loops+1]=fn;return #loops end
    _G.CancelDelayedAction=function(h)loops[h]=false end
    local function pump()for _,f in ipairs(loops) do if f then f() end end end
    local ff={active=nil};ff.ready=function()return true end;ff.start=function()end;ff.stop=function()end;ff.tick=function()end
    package.loaded["nav.follow"]=ff
    package.loaded["nav.route"]={project=function(_,p)return false,p end}
    package.loaded["nav.doors"]={plan=function()return false end}
    local walked=nil
    package.loaded["nav.offmesh"]={
        planner=function()return {g={samples=0},waypoints={{X=1,Y=0,Z=0}},step=function()return "found" end} end,
        walk=function(_,_,wps,done)walked=done end,cancel=function()return false end,ground_below=function(_,_,p)return p.Z end}
    local aw=require("autowalk.autowalk")
    local spoken={};aw.say=function(t)spoken[#spoken+1]=t end
    aw.text=function(k,p)return k..(p and p.name and (":"..p.name) or "")..(p and p.index and (":"..p.index) or "") end
    local pawn={CapsuleComponent={K2_GetComponentLocation=function()return {X=0,Y=0,Z=100}end,GetScaledCapsuleHalfHeight=function()return 84 end}}
    local c={Pawn=pawn}
    local step=1
    local function entry(i,id)return {name="Guide",kind="guide",step=i,steps=15,step_name="follow the doe",step_id=id or "x",stand={X=i,Y=0,Z=0},pos={X=i,Y=0,Z=0}} end
    aw.next_guide=function()return entry(step,step==8 and "shelter" or "x") end
    aw.start(c,entry(1));pump()
    step=2;walked("arrived_test_region",10)
    check("arrival queues the next step",spoken[#spoken]=="guide_next:follow the doe:2" and not aw.walking())
    local before=#spoken
    aw.continue_guide(c);pump()
    check("next step walked without repeating 'Walking to'",aw.walking() and #spoken==before)
    -- Walking toward the shelter (step 8); arriving there, the guide still says 8.
    step=8;walked("arrived_test_region",10);aw.continue_guide(c);pump()
    walked("arrived_test_region",10)
    check("arriving at the shelter waits there",spoken[#spoken]=="guide_wait" and not aw.walking(),spoken[#spoken])
    aw.continue_guide(c)
    check("nothing walks on from the shelter by itself",not aw.walking())
    -- 28 Oct: Shift+Home passed scanner.selected()'s list index as the third
    -- argument, which silenced "Walking to" for every walk.
    local n_before=#spoken
    aw.start(c,entry(5),3);pump()
    check("a stray third argument does not silence the start",spoken[#spoken]~=nil and spoken[#spoken]:find("^walk_start")~=nil and #spoken>n_before,spoken[#spoken])
    walked("cancelled",0)
    -- 27 Oct: an entry with only a label (straight from sources) crashed the start.
    local before_n=#spoken
    check("an entry with only a label starts",aw.start(c,{label="Guide",kind="guide",step=3,steps=15,stand={X=3,Y=0,Z=0},pos={X=3,Y=0,Z=0}})==true)
    pump();walked("cancelled",0)
    -- Caught by a hazard: the guide says to rewind instead of "blocked".
    aw.stalled_guide=function(_,r)if r=="stalled" then return "guide_caught",{key="R"} end end
    aw.start(c,entry(4));pump();walked("stalled",900)
    check("caught by a hazard says rewind",spoken[#spoken]=="guide_caught" and not aw.walking())
    aw.stalled_guide=function()return nil end
    -- A keep-trying step (the lighthouse crossing): no way yet -> wait and retry.
    local plan_state="failed"
    package.loaded["nav.offmesh"].planner=function()return {g={samples=0,report=function()return {} end},waypoints={{X=1,Y=0,Z=0}},step=function(self)self.reason="no_path";return plan_state end} end
    local hole=entry(14,"hole");hole.persist=true
    step=14;aw.next_guide=function()return hole end
    local n0=#spoken
    aw.start(c,hole);pump()
    check("no way yet: told to wait",spoken[#spoken]=="guide_waiting" and aw.walking())
    local clock=os.clock;local fake=clock()+5;os.clock=function()return fake end
    plan_state="found";pump();pump();os.clock=clock
    check("the way opens: the guide goes",walked~=nil and aw.walking())
    walked("cancelled",0)
    check("waiting said once",(function()local k=0;for i=n0+1,#spoken do if spoken[i]=="guide_waiting" then k=k+1 end end;return k==1 end)())
    aw.next_guide=function()return entry(step,step==8 and "shelter" or "x") end
    -- The lighthouse crossing waits for the tree to fall, then walks at once.
    local tree_down=false
    aw.fact_active=function(_,f)return f=="LighthouseTree" and tree_down end
    plan_state="found";walked=nil
    package.loaded["nav.offmesh"].planner=function()return {g={samples=0},waypoints={{X=1,Y=0,Z=0}},step=function()return plan_state end} end
    local cross=entry(14,"hole");cross.persist=true;cross.wait_fact="LighthouseTree"
    aw.next_guide=function()local e=entry(14,"hole");e.persist=true;e.wait_fact="LighthouseTree";return e end
    aw.start(c,cross);pump();pump()
    check("waits for the tree",aw.walking() and walked==nil and spoken[#spoken]=="guide_waiting")
    tree_down=true;pump();pump();pump()
    check("tree down: walks at once",walked~=nil)
    walked("cancelled",0)
    aw.fact_active=function()return true end    aw.start(c,entry(9));pump();walked("stalled",200)
    check("a blocked guide walk stops and says so",spoken[#spoken]:find("^walk_blocked") and not aw.walking())
    aw.continue_guide(c);check("and does not carry on",not aw.walking())
    _G.LoopInGameThreadWithDelay=nil;_G.CancelDelayedAction=nil
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors","nav.offmesh"}) do package.loaded[m]=nil end
end
-- In the ending nightmare the guide is the only entry until its last step.
do
    package.loaded["scanner.sources"]=nil
    local S=require("scanner.sources")
    local real=S.guide_entry
    local orig_collect=S.collect
    -- Exercise only the merge: interactions + the guide entry.
    local out={{kind="interaction",label="Newspaper"},{kind="exit",label="Way out"}}
    local function merge(g)
        local o={};for _,e in ipairs(out) do o[#o+1]=e end
        if g.step_id~="newspaper" then for i=#o,1,-1 do if o[i].kind=="interaction" then table.remove(o,i) end end end
        o[#o+1]=g;return o
    end
    local m=merge({kind="guide",step_id="rocks"})
    local has_paper=false;for _,e in ipairs(m) do if e.label=="Newspaper" then has_paper=true end end
    check("newspaper hidden behind the guide",not has_paper and m[#m].kind=="guide")
    m=merge({kind="guide",step_id="newspaper"})
    has_paper=false;for _,e in ipairs(m) do if e.label=="Newspaper" then has_paper=true end end
    check("newspaper listed at the last step",has_paper)
    local src=io.open("src/scanner/sources.lua"):read("a")
    check("sources merges the same way",src:find('if g.step_id~="newspaper" then',1,true)~=nil)
    package.loaded["scanner.sources"]=nil
end
-- Rewind cues from a hazard's own sequence (measured 27 Oct, lighthouse).
do
    package.loaded["nightmare.rewind"]=nil
    local R=require("nightmare.rewind")
    local t=R.tracker()
    local seq={
        {pos=5.2,playing=true,rate=1},{pos=10.03,playing=true,rate=0},{pos=10.03,playing=true,rate=0},
        {pos=8.6,playing=true,rate=2,reverse=true},{pos=4.4,playing=true,rate=2,reverse=true},
        {pos=3.99,playing=true,rate=0.6},{pos=4.48,playing=true,rate=1}}
    local ev={};for _,o in ipairs(seq) do local e=t:update(o);if e then ev[#ev+1]=e end end
    check("caught, rewinding, rewind done, once each",table.concat(ev,",")=="caught,rewind_started,rewind_done",table.concat(ev,","))
    check("no sequence, no state",R.state(nil)==nil and R.state({})==nil)
    local en=require("lang.en")
    check("lighthouse phrases present",en.guide_lighthouse_caught and en.guide_lighthouse_more and en.guide_rewound=="Rewound. Going again.")
    package.loaded["nightmare.rewind"]=nil
end
-- Choice statistics: decisions read one at a time (rows from the 28 Oct capture).
do
    package.loaded["menus.choice_stats"]=nil
    local S=require("menus.choice_stats")
    local en=require("lang.en")
    S.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return tostring(p[n]) end)) end
    local rows={
        {text="You comforted Victoria.",pct="77",player=true,group="VerticalBox_1"},
        {text="You reported Nathan.",pct="61",player=true,group="VerticalBox_0"},
        {text="You hid the truth.",pct="39",player=false,group="VerticalBox_0"},
        {text="You made fun of Victoria.",pct="23",player=false,group="VerticalBox_1"}}
    local d=S.group(rows)
    check("rows grouped by decision, in first-seen order",#d==2 and d[1][1].text=="You comforted Victoria." and #d[2]==2)
    check("decision spoken with percent and your choice",S.decision(d[2])=="You reported Nathan. 61 percent your choice. You hid the truth. 39 percent")
    check("blank percentage while loading is not 0",S.outcome({text="You saved the bird.",pct="",player=false})=="You saved the bird.")
    local p={episode="Chrysalis",world=true,major=true,decisions=d}
    local c=S.cursor()
    local first=c:update(p)
    check("entering says the context once, then the first decision",first:find("^Chrysalis, Major choices, World stats ")~=nil and first:find("1 of 2$")~=nil,first)
    check("browse down",c:move(1):find("2 of 2$")~=nil)
    check("end of list",c:move(1)==en.journal_last)
    -- Percentages refresh in place (measured): no re-announcement, place kept.
    local p2={episode="Chrysalis",world=true,major=true,decisions=S.group({
        {text="You comforted Victoria.",pct="54",player=true,group="VerticalBox_1"},{text="You made fun of Victoria.",pct="46",player=false,group="VerticalBox_1"},
        {text="You reported Nathan.",pct="70",player=true,group="VerticalBox_0"},{text="You hid the truth.",pct="30",player=false,group="VerticalBox_0"}})}
    check("refreshed figures are silent",c:update(p2)==nil and c.index==2)
    check("and reading them gives the new figures",c:move(-1):find("54 percent")~=nil)
    local p3={episode="Chrysalis",world=true,major=false,decisions=S.group({{text="You saved the bird.",pct="51",player=true,group="m1"}})}
    check("switching to minor announces it",c:update(p3):find("Minor choices")~=nil)
    local p4={episode="Chrysalis",world=false,major=false,decisions=p3.decisions}
    check("switching to friends announces it",c:update(p4):find("Friends stats")~=nil)
    -- Minor page: both columns, found as the content box's children (the
    -- second column has no field of its own). Fake widget tree from the capture.
    local function W(name,kids,extra)local w={name=name,kids=kids or {}};for k,v in pairs(extra or {}) do w[k]=v end
        w.IsValid=function()return true end;w.IsVisible=function()return true end;w.IsInViewport=function()return true end
        w.GetParent=function()return {}end;w.GetFName=function()return {ToString=function()return name end}end
        w.GetChildrenCount=function()return #w.kids end;w.GetChildAt=function(_,i)return w.kids[i+1] end;return w end
    local function T(s)return {IsValid=function()return true end,GetText=function()return {ToString=function()return s end}end} end
    local function R(t,pct,mine)return W("row",nil,{TextBlock_Choice=T(t),ChoicePercent=T(pct),IsPlayerChoice=mine}) end
    local function D(n,a,b)return W(n,nil,{VerticalBox_Choices=W("vb",{R(a,"50",true),R(b,"50",false)})}) end
    local col1,col2={},{}
    for i=1,5 do col1[i]=D("L"..i,"Left "..i,"Not left "..i);col2[i]=D("R"..i,"Right "..i,"Not right "..i) end
    local page=W("page",nil,{HorizontalBox_ContentWrapper=W("wrap",{W("VerticalBox_0",col1),W("VerticalBox_1",col2)}),VerticalBox_0=W("VerticalBox_0",col1)})
    local wrap=W("wrapper",nil,{IsMajor=false,IsGlobal=true,IsFriendFacts=false,TextBlock_Episode=T("Chrysalis")})
    _G.FindAllOf=function(n)
        if n=="DiaryChoicesWrapperWidget_C" then return {wrap} end
        if n=="DiaryChoicesMinorPageWidget_C" then return {page} end
        return {}
    end
    local mp=S.page()
    check("minor page reads both columns (10 decisions)",mp and #mp.decisions==10,mp and #mp.decisions)
    check("left column first, then right",mp and mp.decisions[5][1].text=="Left 5" and mp.decisions[6][1].text=="Right 1")
    check("world while IsFriendFacts is false",mp.world==true)
    -- 28 Oct: toggling to Friends left IsGlobal true; IsFriendFacts is what changes.
    wrap.IsFriendFacts=true
    check("friends when IsFriendFacts is true, whatever IsGlobal says",S.page().world==false)
    _G.FindAllOf=nil    package.loaded["menus.choice_stats"]=nil
end
-- Story icons: announced once when they appear.
do
    package.loaded["hud.icons"]=nil
    local I=require("hud.icons")
    local a=I.appeared({},{ButterflyIcon_C=true})
    check("butterfly appearing is announced",#a==1 and a[1].key=="icon_consequences")
    check("still showing is not repeated",#I.appeared({ButterflyIcon_C=true},{ButterflyIcon_C=true})==0)
    a=I.appeared({ButterflyIcon_C=true},{NewFactIcon_C=true})
    check("new fact appearing is announced",#a==1 and a[1].key=="icon_new_fact")
    check("shown again after hiding",#I.appeared({ButterflyIcon_C=false},{ButterflyIcon_C=true})==1)
    local en=require("lang.en")
    check("icon phrases present",en.icon_consequences and en.icon_new_fact and en.icon_saving)
    a=I.appeared({},{AutosaveIcon_C=true})
    check("save icon appearing is announced",#a==1 and a[1].key=="icon_saving")
    package.loaded["hud.icons"]=nil
end
-- Junkyard shooting: the shot is described just after Chloe fires.
do
    package.loaded["scenes.junkyard_shooting"]=nil
    local S=require("scenes.junkyard_shooting")
    local b1=S.SHOTS.E2_3A_Junkyard_LD_Bottle01_FailChloe
    local b2=S.SHOTS.E2_3A_Junkyard_LD_Bottle02_FailChloe
    check("not before she fires",S.fired(b1,6.0,7.5,false)==nil)
    check("just after she fires",S.fired(b1,7.6,8.1,false)=="shoot_miss_left")
    check("once: not again later in the shot",S.fired(b1,8.1,8.6,false)==nil)
    check("not while rewinding back through it",S.fired(b1,8.6,7.6,true)==nil and S.fired(b1,9,7.9,true)==nil)
    check("again when the shot plays again",S.fired(b1,7.5,8.0,false)=="shoot_miss_left")
    check("not on the first reading (no crossing seen)",S.fired(b1,nil,9.0,false)==nil)
    check("bottle 2",S.fired(b2,7.7,8.2,false)=="shoot_miss_low")
    local en=require("lang.en")
    check("descriptions never name the answer",not en.shoot_miss_left:find("[Rr]ight") and not en.shoot_miss_low:find("[Uu]p"))
    package.loaded["scenes.junkyard_shooting"]=nil
end
-- Icons: the first reading after start is a baseline (no "Saving." at launch).
do
    package.loaded["hud.icons"]=nil
    local I=require("hud.icons")
    local shown={AutosaveIcon_C=true}
    _G.FindAllOf=function(c)if shown[c] then return {{IsValid=function()return true end,IsVisible=function()return true end,IsInViewport=function()return true end}} end;return {} end
    check("icon already showing at start is not announced",#I.tick()==0)
    shown={};I.tick();shown={AutosaveIcon_C=true}
    check("save icon appearing later is announced",#I.tick()==1)
    _G.FindAllOf=nil;package.loaded["hud.icons"]=nil
end
-- Exits: a route ending inside the exit's volume is good enough.
do
    _G.EObjectFlags=_G.EObjectFlags or {RF_BeginDestroyed=1,RF_FinishDestroyed=2}
    package.loaded["nav.doors"]=nil
    local ok,D=pcall(require,"nav.doors")
    if ok then
        local exit={pos={X=208,Y=-2496,Z=88},extent={X=150,Y=100,Z=88}}
        check("route end 56 cm from the exit centre is inside",D.inside({X=208,Y=-2440,Z=6},exit,20))
        check("outside the volume is not",not D.inside({X=208,Y=-2300,Z=6},exit,20))
        check("near the edge is not, with the inset",not D.inside({X=208,Y=-2410,Z=6},exit,20))
        check("no extent: never",not D.inside({X=208,Y=-2496,Z=88},{pos={X=208,Y=-2496,Z=88}},20))
    else check("nav.doors loads offline",false,tostring(D)) end
    package.loaded["nav.doors"]=nil
end
-- Principal's office: door-line side, the other-side point, and the unlock window.
do
    package.loaded["scenes.principal_office"]=nil
    local O=require("scenes.principal_office")
    local door={X=46,Y=-2004,Z=108}
    -- Positions from the 30 Oct log: the outer office before the bomb and
    -- straight after it (said "inside" wrongly), the hat in the outer office.
    check("outer office before the bomb is outside",O.side({X=48,Y=-2590},door)=="outside")
    check("right after the blast is outside",O.side({X=-223,Y=-2518},door)=="outside")
    check("by the hat is outside",O.side({X=-341,Y=-2229},door)=="outside")
    check("by the principal's computer is inside",O.side({X=-429,Y=-1602},door)=="inside")
    check("in the doorway: no change",O.side({X=46,Y=-2000},door)==nil)
    local t,where=O.other_side({X=49,Y=-2119},door)
    check("from outside, the point is inside past the door",where=="inside" and t.Y>door.Y+100 and O.side(t,door)=="inside")
    t,where=O.other_side({X=0,Y=-1700},door)
    check("from inside, the point is outside",where=="outside" and O.side(t,door)=="outside")
    check("no point from the doorway",O.other_side({X=46,Y=-1990},door)==nil)
    check("first reading is only a baseline",#O.changes({},{open=true})==0)
    local c=O.changes({open=false},{open=true})
    check("the unlock window is announced",#c==1 and c[1]=="office_door_unlockable")
    check("no repeat while it stays open",#O.changes({open=true},{open=true})==0)
    local en=require("lang.en")
    check("office phrases",en.office_door_unlockable and en.office_other_side and not en.office_inside)
    package.loaded["scenes.principal_office"]=nil
end
-- Rooms: sub-level from actor names, door labels, the current room, the filter.
do
    package.loaded["scanner.rooms"]=nil
    local R=require("scanner.rooms")
    local bed="LiSInteractionActor /Game/Maps/Episode03/Sequence01/E3_1A_MaxRoom_LD.E3_1A_MaxRoom_LD:PersistentLevel.LiSInteractionActor_Bed_3"
    local dana="LiSInteractionActor /Game/Maps/Episode03/Sequence01/E3_1A_DanaRoom_LD.E3_1A_DanaRoom_LD:PersistentLevel.LiSInteractionActor_CHDana_0"
    local kate="LiSInteractionActor /Game/Maps/Episode03/Sequence01/E3_1A_Corridor_LD.E3_1A_Corridor_LD:PersistentLevel.LiSInteractionActor_KateDoor_2"
    local max="MaxCharacter_BP_C /Game/Maps/Episode03/Sequence01/E3_1A.E3_1A:PersistentLevel.MaxCharacter_BP_C_2147459678"
    check("sub-level of a room object",R.sublevel(bed)=="E3_1A_MaxRoom_LD")
    check("persistent-level actors have none",R.sublevel(max)==nil)
    check("room name from the table",R.room_name("E3_1A_MaxRoom_LD")=="Max's room" and R.room_name("E3_1A_Corridor_LD")=="corridor")
    check("unlisted room falls back to its word",R.room_name("E9_9A_Boiler_LD")=="Boiler")
    check("door label from the actor name",R.door_label(kate)=="Kate's" and R.door_label("x LiSInteractionActor_SciDoor01_2")=="Science lab")
    check("non-door has no label",R.door_label(bed)==nil)
    local E={
        {pos={X=0,Y=0},sublevel="E3_1A_MaxRoom_LD",kind="interaction"},
        {pos={X=50,Y=0},sublevel="E3_1A_MaxRoom_LD",kind="interaction"},
        {pos={X=120,Y=0},sublevel="E3_1A_Corridor_LD",kind="interaction",is_door=true},
        {pos={X=400,Y=0},sublevel="E3_1A_Corridor_LD",kind="interaction"},
        {pos={X=900,Y=0},sublevel="E3_1A_DanaRoom_LD",kind="interaction"},
        {pos={X=950,Y=0},kind="exit"},
    }
    check("room is where the nearest objects are",R.current(E,{X=10,Y=0})=="E3_1A_MaxRoom_LD")
    check("a door next to Max does not vote",R.current(E,{X=125,Y=0})=="E3_1A_MaxRoom_LD")
    check("in the corridor",R.current(E,{X=420,Y=0})=="E3_1A_Corridor_LD")
    local f=R.filter(E,"E3_1A_MaxRoom_LD")
    check("filter keeps the room, the door and the exit",#f==4 and f[3].is_door and f[4].kind=="exit")
    check("other rooms' objects are dropped",not (function()for _,e in ipairs(f) do if e.sublevel=="E3_1A_DanaRoom_LD" then return true end end end)())
    check("one-level scenes are not narrowed",#R.filter({{pos={X=0,Y=0},sublevel="E3_3A_SwimPool_LD",kind="interaction"},{pos={X=9,Y=0},sublevel="E3_3A_SwimPool_LD",kind="interaction"}},"E3_3A_SwimPool_LD")==2)
    check("no room: nothing removed",#R.filter(E,nil)==#E)
    local en=require("lang.en")
    check("door and room phrases",en.door_label and en.room_changed)
    package.loaded["scanner.rooms"]=nil
end
-- Facing: keep correcting while the error shrinks; stop when it stalls.
do
    package.loaded["scanner.face"]=nil
    local ok,F=pcall(require,"scanner.face")
    if ok then
        local s,b=F.progress(nil,nil,60);check("first error sets the best",s==0 and b==60)
        s,b=F.progress(s,b,50);check("shrinking error resets the stall count",s==0 and b==50)
        s,b=F.progress(s,b,50);s,b=F.progress(s,b,50.2);check("no shrink counts up",s==2 and b==50)
        local st={corrections=10,started=0,stalled=0}
        check("more than 8 corrections allowed while progressing",F.should_correct(st,false,1)==true)
        st.stalled=3;check("stalled: stop",F.should_correct(st,false,1)==false)
        st.stalled=0;st.corrections=24;check("hard cap",F.should_correct(st,false,1)==false)
    else check("scanner.face loads offline",false,tostring(F)) end
    package.loaded["scanner.face"]=nil
end
-- Pool guard: hiding point, sight cone, cue transitions.
do
    package.loaded["scenes.pool_guard"]=nil
    local G=require("scenes.pool_guard")
    local lockers={{X=-521,Y=-1690},{X=-361,Y=-1690},{X=-217,Y=-1690}}
    local h=G.hide_point(lockers,{X=80,Y=-1360})
    check("guard at the locker-room door: the west hiding volume's centre",h and h.X==-521 and h.Y==-1690)
    h=G.hide_point(lockers,{X=-900,Y=-1690})
    check("guard at the west end: the east volume",h and h.X==-217)
    check("inside a hiding volume",G.in_hide(lockers,{X=-500,Y=-1700}) and not G.in_hide(lockers,{X=-882,Y=-1626}))
    -- The game's own test (IA_Behavior_32 VisualDetection): 65-degree half-angle from its eye dummy.
    check("game cone: 60 degrees off is seen",G.in_cone({X=0,Y=0},0,{X=50,Y=87}))
    check("game cone: 70 degrees off is not",not G.in_cone({X=0,Y=0},0,{X=34,Y=94}))
    check("no guard: no spot",G.hide_point(lockers,nil)==nil)
    check("in front of the guard is in the cone",G.in_cone({X=0,Y=0},0,{X=100,Y=10}))
    check("behind him is not",not G.in_cone({X=0,Y=0},0,{X=-100,Y=0}))
    check("at 60 degrees is in a 70-degree cone",G.in_cone({X=0,Y=0},0,{X=50,Y=87},70))
    check("spotted on becoming seen",G.cue("hidden","seen")=="sneak_spotted" and G.cue(nil,"seen")=="sneak_spotted")
    check("hidden again after being seen",G.cue("seen","hidden")=="sneak_hidden")
    check("starting hidden is silent",G.cue(nil,"hidden")==nil and G.cue("hidden","hidden")==nil)
    -- The live entries function, with a fake game (31 Oct: a stale constant
    -- made it raise, and pcall at the call site hid it: no entries at all).
    local oldF,oldN,oldS=_G.FindAllOf,_G.FName,_G.StaticFindObject
    _G.FindAllOf=function()return {} end;_G.FName=function(s)return s end;_G.StaticFindObject=function()return nil end
    local c={GetWorld=function()return {GetFName=function()return {ToString=function()return "E3_3A" end} end} end,
        IsFactActive=function()return false end,Pawn={K2_GetActorLocation=function()return {X=0,Y=-1500,Z=0} end}}
    local ok,list=pcall(G.entries,c)
    check("entries: no error with no actors",ok,tostring(list))
    check("entries: the hall and the hiding spot are listed before the patrol",ok and #list==2 and list[1].id=="pool_hall_way" and list[2].id=="pool_hiding_spot")
    local c2=setmetatable({IsFactActive=function()return true end},{__index=c})
    ok,list=pcall(G.entries,c2)
    check("entries: only the hiding spot while the patrol runs",ok and #list==1 and list[1].id=="pool_hiding_spot")
    _G.FindAllOf,_G.FName,_G.StaticFindObject=oldF,oldN,oldS
    -- The live tick with a fake game (1 Nov: a stale constant raised inside
    -- the tick's pcall on every reading and a whole play run recorded nothing).
    do
        local oldF,oldN,oldS=_G.FindAllOf,_G.FName,_G.StaticFindObject
        local function actor(name,x,y,z,yaw,mesh)
            local a={GetFName=function()return {ToString=function()return name end} end,IsValid=function()return true end,
                K2_GetActorLocation=function()return {X=x,Y=y,Z=z} end,K2_GetActorRotation=function()return {Yaw=yaw or 0,Pitch=0} end,
                GetAddress=function()return name end,bIsPlaying=true,InterpPosition=5.0}
            a.SkeletalMeshComponent={IsValid=function()return true end,SkeletalMesh={IsValid=function()return true end,GetFName=function()return {ToString=function()return mesh or "x" end} end},
                GetAllSocketNames=function()return {ForEach=function()end} end,DoesSocketExist=function()return false end,
                K2_GetComponentLocation=function()return {X=x,Y=y,Z=z} end,K2_GetComponentRotation=function()return {Yaw=yaw or 0} end}
            return a
        end
        local guard=actor("SkeletalMeshActorMAT_2",80,-1360,0,180,"CH_L_DavidGuard01")
        local eye=actor("FSMDummy_1",80,-1360,100,180);local close=actor("FSMDummy_2",0,-13,2,0)
        local patrol=actor("E3_3A_SwimPool_LD_GuardPatrolInLocker",0,0,0)
        _G.FindAllOf=function(c)
            if c=="SkeletalMeshActorMAT" then return {guard} elseif c=="FSMDummy" then return {eye,close} elseif c=="MatineeActor" then return {patrol} elseif c=="DNEVolume" then return {} end
            return {}
        end
        _G.FName=function(s)return s end
        _G.StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b)return b.Y<-1700 end} end
        -- Fake navmesh: everything north of the locker-room door wall (y > -1360)
        -- projects but is unreachable from the pool side.
        -- Fake navmesh: everything is connected; a closed door at x=-150..-50 on the
        -- wall y=-1360 makes goals north of it reachable only through that door.
        package.loaded["nav.route"]={project=function(_,p)return true,{X=p.X,Y=p.Y,Z=0} end,
            query=function(_,_,_,from,goal)return true,0,{from,goal} end}
        package.loaded["nav.doors"]={survey=function()return {{closed=true}} end,
            crosses_closed=function(pts)local a,b=pts[1],pts[#pts];return (a.Y-(-1360))*(b.Y-(-1360))<0 end}
        local logs={};G.log=function(s)logs[#logs+1]=s end
        G.DEBUG=true -- the assertions read the per-reading log
        -- These tests exercise the assisted mode (warning and hiding spot), so the
        -- bypass is off; it has its own tests below.
        G.BYPASS=false
        -- The fake world has its own guard; keep the recorded real path out of it.
        local real_path=G.PATH;G.PATH={}
        local c={GetWorld=function()return {GetFName=function()return {ToString=function()return "E3_3A" end} end} end,
            IsFactActive=function()return true end,Pawn=actor("Max",-400,-1380,0,0)}
        local ok,err=pcall(G.tick,c,100);local ok2=pcall(G.tick,c,100.5)
        local errs=0;for _,s in ipairs(logs) do if s:find("read_error") then errs=errs+1 end end
        check("tick: no error with a fake game",ok and ok2 and errs==0,table.concat(logs," | "))
        check("tick: a reading was logged with the game's eye",(function()for _,s in ipairs(logs) do if s:find("eye=80,%-1360") then return true end end end)())
        -- Max is 480 cm west of the eye, which faces west (yaw 180): in range, in cone, trace clear -> seen.
        check("tick: the game's test says seen",(function()for _,s in ipairs(logs) do if s:find("game_seen=true") then return true end end end)())
        check("tick: the warning fires with the game's test",(function()for _,s in ipairs(logs) do if s:find("warn=true") then return true end end end)())
        -- The chosen spot must be one the game's test cannot see from the eye
        -- (80,-1360 facing west, 800 cm, 65 deg; the fake trace blocks y<-1700).
        -- Scanner entry during the patrol is the live spot (2 Nov: globals made it nil).
        local list=G.entries(c)
        local live=nil;for _,e in ipairs(list) do if e.id=="pool_hiding_spot" then live=e end end
        check("entries: the hiding spot is listed during the patrol and is the live spot",live~=nil and (function()for _,s in ipairs(logs) do local sx,sy=s:match("spot=([-%d]+),([-%d]+)");if sx and math.abs(tonumber(sx)-live.pos.X)<1 and math.abs(tonumber(sy)-live.pos.Y)<1 then return true end end end)(),live and string.format("%.0f,%.0f",live.pos.X,live.pos.Y) or "none")
        -- The spot follows Max: move her 6 m and it must be re-chosen near her.
        c.Pawn=actor("Max",-400,-2100,0,0)
        pcall(G.tick,c,101);pcall(G.tick,c,101.5)
        local lastspot=nil;for i=#logs,1,-1 do lastspot=logs[i]:match("spot=([-%d]+,[-%d]+)");if lastspot then break end end
        check("spot follows Max when she moves away from it",(function()if not lastspot then return false end;local sx,sy=lastspot:match("([-%d]+),([-%d]+)");return math.sqrt((tonumber(sx)+400)^2+(tonumber(sy)+2100)^2)<=G.SPOT_STALE end)(),tostring(lastspot))
        -- Rewind: after the patrol position goes back, the spot is chosen again.
        do
            local seqv=5.0
            patrol.InterpPosition=20.0;pcall(G.tick,c,102);pcall(G.tick,c,102.5)
            local before=#logs
            patrol.InterpPosition=8.0;pcall(G.tick,c,103);pcall(G.tick,c,103.5)
            local researched=false
            for i=before+1,#logs do if logs[i]:find("spot_search reason=rewind") then researched=true end end
            check("a rewind makes the spot be chosen again",researched,table.concat(logs," | ",before+1))
            patrol.InterpPosition=5.0
        end
        -- Aim height: a fake low obstacle (a bench) blocks traces aimed below
        -- 100 cm above the floor. Max standing behind it must still count as SEEN
        -- (2 Nov run 19: knee-height spot traces read "safe" behind such cover).
        do
            local oldS=_G.StaticFindObject
            _G.StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b)return b.Z<100 end} end
            c.Pawn=actor("Max",-400,-1380,88,0)
            local n0=#logs
            pcall(G.tick,c,104);pcall(G.tick,c,104.5)
            local warned=false;for i=n0+1,#logs do if logs[i]:find("warn=true") then warned=true end end
            check("a low obstacle does not hide Max from the warning (chest-height aim)",warned,table.concat(logs," | ",n0+1))
            _G.StaticFindObject=oldS
        end
        -- Aim height: spots and Max are tested at the same height above the floor.
        check("spot and Max share one aim height",G.AIM_HEIGHT and G.AIM_HEIGHT>=100)
        check("warning looks at least 6 s ahead",G.WARN_AHEAD[#G.WARN_AHEAD]>=6)
        check("spot must stay safe at least 10 s",G.SPOT_AHEAD[#G.SPOT_AHEAD]>=10)
        -- Bypass (default on): the game's two detection markers are detached and
        -- parked below the floor during the patrol; the toggle flips it.
        do
            local parked={}
            local function dummy(name,x,y,z)
                local a=actor(name,x,y,z,0)
                a.K2_TeleportTo=function(self,loc)parked[name]=loc.Z;self.K2_GetActorLocation=function()return {X=loc.X,Y=loc.Y,Z=loc.Z} end end
                a.K2_DetachFromActor=function()end
                return a
            end
            local e1,e2=dummy("FSMDummy_1",80,-1360,100),dummy("FSMDummy_2",0,-13,2)
            local oldF2=_G.FindAllOf
            _G.FindAllOf=function(cname)if cname=="FSMDummy" then return {e1,e2} end;return oldF2(cname) end
            local said=nil;G.announce=function(k)said=k end
            G.BYPASS=true
            pcall(G.tick,c,200);pcall(G.tick,c,200.5)
            check("bypass is on by default",(function()package.loaded["scenes.pool_guard"]=nil;local fresh=require("scenes.pool_guard");local v=fresh.BYPASS;package.loaded["scenes.pool_guard"]=G;return v==true end)())
            check("bypass parks the eye marker below the floor",parked["FSMDummy_1"]==G.PARK_Z)
            check("bypass parks the close sensor too",parked["FSMDummy_2"]==G.PARK_Z)
            local k=G.toggle_bypass()
            check("toggle turns the bypass off and names it",G.BYPASS==false and k=="pool_bypass_off")
            parked={};e1.K2_GetActorLocation=function()return {X=80,Y=-1360,Z=100} end
            pcall(G.tick,c,201)
            check("with the bypass off nothing is parked",parked["FSMDummy_1"]==nil)
            -- Bypass on: no cues and no hiding spot (3 Nov: cues still played).
            G.BYPASS=true;local played={};G.play=function(f)played[#played+1]=f end
            c.Pawn=actor("Max",-400,-1380,88,0)
            for k=1,4 do pcall(G.tick,c,210+k*0.5) end
            check("bypass on: no cue plays",#played==0,table.concat(played,","))
            local hs=nil;for _,e in ipairs(G.entries(c)) do if e.id=="pool_hiding_spot" then hs=e end end
            check("bypass on: no hiding spot offered",hs==nil)
            G.play=function()end
            G.BYPASS=false;_G.FindAllOf=oldF2;G.announce=nil
            local en=require("lang.en")
            check("bypass phrases exist and name the key",en.pool_bypass_on:find("{key}") and en.pool_bypass_off:find("{key}"))
        end
        check("tick: the safe spot is out of the eye's view",(function()
            for _,s in ipairs(logs) do
                local sx,sy=s:match("spot=([-%d]+),([-%d]+)")
                if sx then
                    sx,sy=tonumber(sx),tonumber(sy)
                    local far=(sx-80)^2+(sy+1360)^2>800*800
                    local out=not G.in_cone({X=80,Y=-1360},180,{X=sx,Y=sy},65)
                    if far or out or sy<-1700 then return true end
                end
            end
        end)(),table.concat(logs," | "))
        check("unreachable candidates are dropped",(function()for _,s in ipairs(logs) do local n=s:match("unreachable=(%d+)");if n and tonumber(n)>0 then return true end end end)(),table.concat(logs," | "))
        check("the chosen spot is reachable (south of the door wall)",(function()for _,s in ipairs(logs) do local sy=s:match("spot=[-%d]+,([-%d]+)");if sy and tonumber(sy)>-1360 then return false end end;return true end)())
        check("tick: candidate spots were projected",(function()for _,s in ipairs(logs) do if s:find("spots=%d") and not s:find("spots=0") then return true end end end)(),table.concat(logs," | "))
        -- Pure pieces of the warning and the spot search.
        check("exposed: in the loose cone with a clear line",G.exposed({X=0,Y=0},0,{X=500,Y=300},false))
        check("exposed: not when the line is blocked",not G.exposed({X=0,Y=0},0,{X=500,Y=300},true))
        check("exposed: not beyond the loose range",not G.exposed({X=0,Y=0},0,{X=1200,Y=0},false))
        check("grid covers the bounds",#G.grid({minX=0,maxX=300,minY=0,maxY=150},150)==6)
        local en2=require("lang.en")
        G.PATH=real_path
        -- Prediction from the recorded path (2 Nov log).
        local P=G.PATH
        check("path loaded from the log",#P>30)
        local a=G.pose_at(P,P[1][1]);check("pose at the first sample",a and math.abs(a.X-P[1][2])<1)
        local mid=G.pose_at(P,(P[5][1]+P[6][1])/2);check("pose interpolates between samples",mid and mid.X>=math.min(P[5][2],P[6][2])-1 and mid.X<=math.max(P[5][2],P[6][2])+1)
        check("no pose beyond the recorded range",G.pose_at(P,P[#P][1]+5)==nil)
        check("path covers the whole 78 s patrol (decoded from the game's animation)",P[#P][1]>=77)
        -- At seq ~17 he stands at the west end looking north: Max at -886,-1582
        -- (where she was caught) is in danger from seq 14 already (3 s ahead).
        local hit=false
        local function sees(pose,pt)local dx,dy=pt.X-pose.X,pt.Y-pose.Y;return dx*dx+dy*dy<=800*800 and G.in_cone({X=pose.X,Y=pose.Y},pose.yaw,pt,65) end
        check("danger predicted 3 s before the catch",G.danger(P,14.5,G.WARN_AHEAD,{X=-886,Y=-1582},sees,nil))
        check("no danger far behind him (east end, out of range)",not G.danger(P,17,{0},{X=300,Y=-1400},sees,nil))
        _G.FindAllOf,_G.FName,_G.StaticFindObject=oldF,oldN,oldS
        package.loaded["nav.route"]=nil;package.loaded["nav.doors"]=nil
    end
    local en=require("lang.en")
    check("pool phrases",en.pool_hall_way and en.pool_hiding_spot and en.pool_way_out and en.cue_sneak_spotted and en.cue_sneak_hidden)
    package.loaded["scenes.pool_guard"]=nil
end
-- Button prompts: the scene's own "press X" line (TextBlock_Button).
do
    do
        package.loaded["hud.tooltip"]=nil
        local T=require("hud.tooltip")
        local old=_G.FindAllOf
        local walked=false
        local function tb(text,vis)return {IsValid=function()return true end,IsVisible=function()return vis end,GetText=function()return {ToString=function()return text end} end} end
        local function widget(text,vis,on)return {IsValid=function()return true end,IsInViewport=function()return on end,IsVisible=function()return on end,TextBlock_Button=tb(text,vis)} end
        _G.FindAllOf=function(c)
            if c=="TextBlock" then walked=true;return {} end
            if c=="BP_LiSLVLWidget_View_C" then return {widget(" Leave The Swimming Pool",true,true)} end
            return {} end
        T.button_key=function()return "A" end
        check("button prompt read with the key",T.button_prompt()=="Leave The Swimming Pool, A")
        check("button prompt widget class recorded",T.button_class=="BP_LiSLVLWidget_View_C")
        check("the prompt reader never walks every text block",walked==false)
        _G.FindAllOf=function(c)if c=="BP_LiSLVLWidget_View_C" then return {widget("Hidden",false,true),widget("Off screen",true,false)} end;return {} end
        check("no visible button: nothing",T.button_prompt()==nil)
        _G.FindAllOf=old;package.loaded["hud.tooltip"]=nil
    end
end
-- No module writes or reads an undeclared global by accident (2 Nov: a local
-- declared below its first use turned the pool's live hiding spot into a nil
-- global). Lists every global each source file touches, against a whitelist.
do
    local allowed={}
    for w in ("_G _ENV assert error ipairs pairs next pcall print rawget rawset require select setmetatable getmetatable tonumber tostring type unpack xpcall math os string table io utf8 coroutine package debug "..
        "FindAllOf FindFirstOf StaticFindObject FName FText RegisterHook RegisterKeyBind RegisterConsoleCommandHandler ExecuteInGameThread ExecuteWithDelay LoopAsync NotifyOnNewObject "..
        "LoopInGameThreadWithDelay CancelDelayedAction ExecuteAsync RegisterCustomEvent UEHelpers Key ModifierKey IsKeyBindRegistered print_lua CreateInvalidObject EObjectFlags StaticConstructObject FindObject FindObjects RegisterProcessConsoleExecPreHook RegisterProcessConsoleExecPostHook RegisterLoadMapPreHook RegisterLoadMapPostHook RegisterInitGameStatePreHook RegisterInitGameStatePostHook RegisterBeginPlayPreHook RegisterBeginPlayPostHook UnregisterHook"):gmatch("%S+") do allowed[w]=true end
    local luac="artifacts\\lua-5.4.7\\luac54.exe"
    local list=io.popen('cmd /c dir /b /s src\\scenes\\*.lua src\\scanner\\*.lua src\\autowalk\\*.lua src\\nav\\*.lua src\\hud\\*.lua')
    local bad={}
    local listed=0
    if list then
        for path in list:lines() do
            local h=io.popen(luac..' -l -p "'..path..'"')
            if h then
                for line in h:lines() do
                    listed=listed+1
                    local g=line:match('[GS]ETTABUP.-_ENV "([%w_]+)"')
                    if g and not allowed[g] then bad[#bad+1]=path:match("[^\\]+$")..":"..g end
                end
                h:close()
            end
        end
        list:close()
    end
    local scanned=0
    do local h=io.popen('cmd /c dir /b /s src\\scenes\\*.lua');if h then for _ in h:lines() do scanned=scanned+1 end;h:close() end end
    check("global scan actually ran (files found and compiler listing read)",scanned>0 and listed>0,tostring(scanned).."/"..tostring(listed))
    check("no unexpected globals in scene, scanner, autowalk, nav and hud modules",#bad==0,table.concat(bad,", "))
end
-- Stall retries: try again from where Max stopped while each try gets closer.
do
    package.loaded["autowalk.plan"]=nil
    local P=require("autowalk.plan")
    -- The pool walks of 3 Nov: Max moved 107 cm and then 773 cm between the
    -- stalls (remaining 1320, 1290, 668), then arrived.
    check("first stall is retried",P.retry_stall(nil,0))
    check("a stall after moving 107 cm is retried (only 30 cm closer)",P.retry_stall(107,1))
    check("a stall after moving 773 cm is retried",P.retry_stall(773,2))
    check("a stall without moving is reported as blocked",not P.retry_stall(10,1))
    check("retries are limited",not P.retry_stall(500,P.RETRIES))
    package.loaded["autowalk.plan"]=nil
end
-- Stall retry, end to end through autowalk.tick: two stalls with progress,
-- then arrival; and a stall without progress reported as blocked.
do
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors"}) do package.loaded[m]=nil end
    local pos={X=0,Y=0,Z=0}
    local follow={active=false};local script={};local step=0;local emitf=nil
    function follow.ready()return true end
    function follow.start(_,_,goal,emit)
        step=step+1;emitf=emit;follow.active=true;follow.goal=goal
    end
    function follow.stop()follow.active=false end
    function follow.tick()
        if not follow.active then return end
        local s=script[step] or {res="stalled",x=pos.X}
        pos.X=s.x
        emitf(string.format("follow_progress elapsed=1 remaining=%.3f vertical=0 position=%.1f,0,0",math.abs(follow.goal.X-pos.X),pos.X))
        emitf("follow_end="..s.res.." stop_ok=true");follow.active=false
    end
    package.loaded["nav.follow"]=follow
    package.loaded["nav.route"]={project=function(_,p)return true,{X=p.X or p[1],Y=p.Y or p[2] or 0,Z=p.Z or p[3] or 0} end,
        query=function()return true,1000,{{X=0,Y=0,Z=0},{X=1000,Y=0,Z=0}} end}
    package.loaded["nav.doors"]={plan=function()return nil end,survey=function()return {} end,inside=function()return false end}
    local aw=require("autowalk.autowalk")
    local said={};aw.say=function(k)said[#said+1]=k end;aw.text=function(k)return k end
    aw.moving=function()return false end;aw.in_reach=function()return nil end
    aw.log=function()end
    local pawn={K2_GetActorLocation=function()return {X=pos.X,Y=pos.Y,Z=pos.Z} end,GetAddress=function()return 1 end,IsValid=function()return true end,
        CapsuleComponent={K2_GetComponentLocation=function()return {X=pos.X,Y=pos.Y,Z=pos.Z} end,GetScaledCapsuleHalfHeight=function()return 0 end}}
    local c={Pawn=pawn,IsValid=function()return true end}
    local entry={name="Way to the hall",pos={X=1000,Y=0,Z=0},stand={X=1000,Y=0,Z=0},kind="goal"}
    -- Two stalls that each moved Max, then arrival.
    script={{res="stalled",x=300},{res="stalled",x=700},{res="arrived_test_region",x=1000}}
    local okstart=pcall(aw.start,c,entry)
    for _=1,8 do pcall(aw.tick) end
    local function has(k)for _,v in ipairs(said) do if v==k then return true end end end
    check("retry: stalls with progress are retried and the walk arrives",okstart and has("walk_retry") and has("walk_arrived") and not has("walk_blocked"),table.concat(said,","))
    -- A stall that does not move Max: reported as blocked after the first retry.
    said={};pos={X=0,Y=0,Z=0};step=0
    script={{res="stalled",x=300},{res="stalled",x=310}}
    pcall(aw.start,c,entry)
    for _=1,8 do pcall(aw.tick) end
    check("retry: a stall without progress is reported as blocked",has("walk_blocked") and not has("walk_arrived"),table.concat(said,","))
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors"}) do package.loaded[m]=nil end
end
-- Rooms by floor, doors by the floors around them (3 Nov, Chloe's house).
do
    package.loaded["scanner.rooms"]=nil
    local R=require("scanner.rooms")
    local function nm(lvl,actor)return "StaticMeshActor /Game/Maps/Episode03/Sequence05/"..lvl.."."..lvl..":PersistentLevel."..actor end
    check("floor in a room's geometry level names the room",R.room_of(nm("E3_5A_ChloeRoom_GRC","StaticMeshActor_12"))=="E3_5A_ChloeRoom_LD")
    check("second geometry level too",R.room_of(nm("E3_5A_Corridor_GR2","StaticMeshActor_3"))=="E3_5A_Corridor_LD")
    check("object level maps to itself",R.room_of(nm("E3_5B_LivingRoom_LD","LiSInteractionActor_Fridge_0"))=="E3_5B_LivingRoom_LD")
    check("persistent level is no room",R.room_of("StaticMeshActor /Game/Maps/Episode03/Sequence05/E3_5A.E3_5A:PersistentLevel.StaticMeshActor_1")==nil)
    check("the sliding door counts as door-like (BayWindow, Window02)",R.door_like("x LiSInteractionActor_BayWindow_87","$GT_Sensen_Int_Window02","Sliding Door"))
    check("a fridge is not door-like",not R.door_like("x LiSInteractionActor_Fridge_0","$GT_Sensen_Int_Refrigerator01","Fridge"))
    local set,j=R.joins({"A","A",nil,"B"},4);check("two floors around a door, with a missed trace between: a connection",j and set.A and set.B)
    local _,j1=R.joins({"A","A",nil});check("one floor: not a connection",not j1)
    -- Chloe's house: Chloe's room, corridor, parents' room.
    local CR,CO,PR="E3_5A_ChloeRoom_LD","E3_5A_Corridor_LD","E3_5A_ParentsRoom_LD"
    local E={
        {id="bed",kind="interaction",sublevel=CR},
        {id="closet",kind="interaction",sublevel=CR,door_like=true},             -- floors: Chloe's room only
        {id="room door",kind="interaction",sublevel=CR,door_like=true,joins={[CR]=true,[CO]=true}},
        {id="parents door",kind="interaction",sublevel=CO,door_like=true,joins={[CO]=true,[PR]=true}},
        {id="poster",kind="interaction",sublevel=CO},
    }
    local function ids(list)local o={};for _,e in ipairs(list) do o[#o+1]=e.id end;return table.concat(o,",") end
    local f=ids(R.filter(E,CR))
    check("in Chloe's room: her objects and her door; NOT the parents' door",f=="bed,closet,room door",f)
    f=ids(R.filter(E,CO))
    check("in the corridor: the way back to Chloe's room and the parents' door",f=="room door,parents door,poster",f)
    -- Living room / garden: the sliding door (in the living room's level) is
    -- the garden's way back.
    local LR,GA="E3_5B_LivingRoom_LD","E3_5B_Garden_LD"
    local H={{id="fridge",kind="interaction",sublevel=LR},{id="sliding door",kind="interaction",sublevel=LR,door_like=true,joins={[LR]=true,[GA]=true}},
             {id="shed",kind="interaction",sublevel=GA}}
    f=ids(R.filter(H,GA))
    check("in the garden: the sliding door is still there (3 Nov: stranded)",f=="sliding door,shed",f)
    package.loaded["scanner.rooms"]=nil
end
-- The room step of the live collect path (sources.by_room) with a fake world:
-- floors decide the room and the doors; door floors are cached.
do
    package.loaded["scanner.sources"]=nil;package.loaded["scanner.rooms"]=nil
    local S=require("scanner.sources")
    local function lvl(name)return "/Game/Maps/Episode03/Sequence05/"..name.."."..name..":PersistentLevel." end
    -- Chloe's room is y > -460, corridor -460..-900, parents' room below -900.
    local function floor_at(y)
        if y>-460 then return "E3_5A_ChloeRoom_GRC" elseif y>-900 then return "E3_5A_Corridor_GRC" else return "E3_5A_ParentsRoom_GRC" end
    end
    local traces=0
    local oldS=_G.StaticFindObject
    _G.StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b,_,_,_,_,hit)
        traces=traces+1
        local n=floor_at(b.Y)
        hit.Actor={Get=function()return {GetFullName=function()return "StaticMeshActor "..lvl(n).."Floor" end} end}
        return true end} end
    S.report=function()end
    local CR,CO="E3_5A_ChloeRoom_LD","E3_5A_Corridor_LD"
    local function entries()return {
        {id="bed",kind="interaction",sublevel=CR,pos={X=0,Y=0,Z=108}},
        {id="room door",kind="interaction",sublevel=CR,pos={X=20,Y=-454,Z=108},door_like=true},
        {id="parents door",kind="interaction",sublevel=CO,pos={X=-140,Y=-895,Z=108},door_like=true},
        {id="poster",kind="interaction",sublevel=CO,pos={X=-300,Y=-800,Z=108}}} end
    local c={GetWorld=function()return {GetFName=function()return {ToString=function()return "E3_5A" end} end} end,Pawn={}}
    local function ids(list)local o={};for _,e in ipairs(list) do o[#o+1]=e.id end;return table.concat(o,",") end
    local ok,res=pcall(function()
        local a=ids(S.by_room(c,entries(),{X=0,Y=-100,Z=0}));local r1=S.room
        local before=traces
        S.by_room(c,entries(),{X=0,Y=-100,Z=0})
        local second=traces-before
        local b=ids(S.by_room(c,entries(),{X=-200,Y=-700,Z=0}));local r2=S.room
        return {a,r1,second,b,r2}
    end)
    check("room step runs with a fake world",ok,tostring(res))
    if ok then
        check("in Chloe's room by floor: bed and her door, not the parents' door",res[1]=="bed,room door",res[1])
        check("the room is named from the floor under Max",res[2]==CR and res[5]==CO,tostring(res[2]).."/"..tostring(res[5]))
        check("door floors are cached: a repeat traces only the five room samples",res[3]==5,"traced "..tostring(res[3]))
        check("in the corridor: the way back, the parents' door and the poster",res[4]=="room door,parents door,poster",res[4])
    end
    -- A moved object takes its room from the floor where it is now: the bird.
    do
        local LR,GA="E3_5B_LivingRoom_LD","E3_5B_Garden_LD"
        _G.StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b,_,_,_,_,hit)
            local n=b.X>1500 and "E3_5B_Garden_GRC" or "E3_5B_LivingRoom_GRC"
            hit.Actor={Get=function()return {GetFullName=function()return "StaticMeshActor "..lvl(n).."Floor" end} end}
            return true end} end
        local c2={GetWorld=function()return {GetFName=function()return {ToString=function()return "E3_5B" end} end} end,Pawn={}}
        local function birdlist(bx)return {{id="bird",label="Bird",kind="interaction",sublevel=LR,pos={X=bx,Y=0,Z=100}},
            {id="fridge",kind="interaction",sublevel=LR,pos={X=500,Y=0,Z=100}},{id="shed",kind="interaction",sublevel=GA,pos={X=2000,Y=0,Z=0}}} end
        S.by_room(c2,birdlist(800),{X=600,Y=0,Z=0})                      -- first sight, in the living room
        local inside=ids(S.by_room(c2,birdlist(1900),{X=600,Y=0,Z=0}))   -- flown out; Max still inside
        local outside=ids(S.by_room(c2,birdlist(1900),{X=2000,Y=0,Z=0})) -- Max in the garden
        check("a bird that flew out leaves the living room list",not inside:find("bird"),inside)
        check("and is on the garden list",outside:find("bird")~=nil,outside)
    end
    -- The bird in play (3 Nov): 14 m away and high up; a 3 m downward trace
    -- finds nothing. Floors here are only found by traces reaching z < -1000,
    -- and nowhere for x > 3000 (a tree with nothing below): the geometry
    -- fallback must still put it in the garden.
    do
        local LR,GA="E3_5B_LivingRoom_LD","E3_5B_Garden_LD"
        _G.StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b,_,_,_,_,hit)
            if b.Z>-1000 or b.X>3000 then return false end
            local n=b.X>1500 and "E3_5B_Garden_GRC" or "E3_5B_LivingRoom_GRC"
            hit.Actor={Get=function()return {GetFullName=function()return "StaticMeshActor "..lvl(n).."Floor" end} end}
            return true end} end
        local oldF=_G.FindAllOf
        _G.FindAllOf=function(cn)
            if cn=="StaticMeshActor" then return {
                {GetFullName=function()return "StaticMeshActor "..lvl("E3_5B_LivingRoom_GRC").."A" end,K2_GetActorLocation=function()return {X=600,Y=0,Z=0} end},
                {GetFullName=function()return "StaticMeshActor "..lvl("E3_5B_Garden_GRC").."B" end,K2_GetActorLocation=function()return {X=2600,Y=0,Z=0} end}} end
            return {} end
        local function run(world,bx,bz)
            local cc={GetWorld=function()return {GetFName=function()return {ToString=function()return world end} end} end,Pawn={}}
            local function bl(x,z)return {{id="bird",label="Bird",kind="interaction",sublevel=LR,pos={X=x,Y=0,Z=z}},{id="shed",kind="interaction",sublevel=GA,pos={X=2000,Y=0,Z=0}}} end
            S.by_room(cc,bl(800,100),{X=2000,Y=0,Z=0})
            return ids(S.by_room(cc,bl(bx,bz),{X=2000,Y=0,Z=0}))
        end
        check("a bird high in the garden (deep trace) is on the garden list",run("Wbird1",2200,800):find("bird")~=nil)
        -- The real case: under the bird, first the living room's eaves (z=300),
        -- then the garden lawn (z=0). The lowest surface names the room.
        local oldS2=_G.StaticFindObject
        local function hit(n,z)return {get=function()return {Actor={Get=function()return {GetFullName=function()return "StaticMeshActor "..lvl(n).."S" end} end},ImpactPoint={X=0,Y=0,Z=z}} end} end
        _G.StaticFindObject=function()return {
            LineTraceSingle=function(_,_,a,b,_,_,_,_,h)
                -- The first surface down from a high point is the eaves (3 Nov log).
                local n=(a.Z>150 and b.X>1500) and "E3_5B_LivingRoom_GRC" or (b.X>1500 and "E3_5B_Garden_GRC" or "E3_5B_LivingRoom_GRC")
                h.Actor={Get=function()return {GetFullName=function()return "StaticMeshActor "..lvl(n).."Floor" end} end};return true end,
            LineTraceMulti=function(_,_,a,b,_,_,_,_,hits)
                -- As UE4SS does it: the out array filled as a plain Lua list.
                hits[1]={Actor={Get=function()return {GetFullName=function()return "StaticMeshActor "..lvl("E3_5B_LivingRoom_GRC").."S" end} end},ImpactPoint={X=0,Y=0,Z=300}}
                hits[2]={Actor={Get=function()return {GetFullName=function()return "StaticMeshActor "..lvl("E3_5B_Garden_GRC").."S" end} end},ImpactPoint={X=0,Y=0,Z=0}}
                return true end} end
        check("a bird above the eaves goes by the ground below, not the roof",run("Wbird3",2513,147):find("bird")~=nil)
        _G.StaticFindObject=oldS2
        check("a bird with no floor below (geometry fallback) is on the garden list",run("Wbird2",3200,800):find("bird")~=nil)
        _G.FindAllOf=oldF
    end
    -- An open doorway: corridor (y > -1000) and bathroom (y <= -1000) with no
    -- door object between them (3 Nov: the bathroom was unreachable).
    do
        local CO,BA,PR="E3_5A_Corridor_LD","E3_5A_Bathroom_LD","E3_5A_ParentsRoom_LD"
        _G.StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b,_,_,_,_,hit)
            local n=b.Y>-1000 and "E3_5A_Corridor_GRC" or "E3_5A_Bathroom_GRC"
            if b.X>1000 then n="E3_5A_ParentsRoom_GRC" end
            hit.Actor={Get=function()return {GetFullName=function()return "StaticMeshActor "..lvl(n).."Floor" end} end}
            return true end} end
        -- Routes: straight lines; to the parents' room the route passes the bathroom first.
        package.loaded["nav.route"]={project=function(_,q)return true,{X=q.X,Y=q.Y,Z=0} end,
            query=function(_,_,_,a,b)
                if b.X>1000 then return true,0,{a,{X=0,Y=-1200,Z=0},b} end
                return true,0,{a,b} end}
        local c3={GetWorld=function()return {GetFName=function()return {ToString=function()return "E3_5A_way" end} end} end,Pawn={}}
        local list={{id="poster",kind="interaction",sublevel=CO,pos={X=0,Y=-700,Z=100}},
            {id="mirror",kind="interaction",sublevel=BA,pos={X=0,Y=-1150,Z=100}},
            {id="bed",kind="interaction",sublevel=PR,pos={X=1200,Y=-1300,Z=100}}}
        local got=S.by_room(c3,list,{X=0,Y=-700,Z=0})
        local way=nil;local far=nil
        for _,e in ipairs(got) do if e.id=="way:"..BA then way=e end;if e.id=="way:"..PR then far=e end end
        check("an open doorway gets a way into the room",way~=nil and way.kind=="goal",ids(got))
        check("the way's point is just inside the room",way and way.pos.Y<=-1000)
        check("no way into a room reached only through another",far==nil)
        check("mirror is not listed from the corridor",not ids(got):find("mirror"))
        -- No bathroom object registered at all: the way still comes from its geometry.
        local oldF=_G.FindAllOf
        _G.FindAllOf=function(c)
            if c=="StaticMeshActor" then return {{GetFullName=function()return "StaticMeshActor "..lvl("E3_5A_Bathroom_GRC").."StaticMeshActor_9" end,K2_GetActorLocation=function()return {X=0,Y=-1160,Z=0} end}} end
            return {} end
        local c4={GetWorld=function()return {GetFName=function()return {ToString=function()return "E3_5A_geo" end} end} end,Pawn={}}
        local got2=S.by_room(c4,{{id="poster",kind="interaction",sublevel=CO,pos={X=0,Y=-700,Z=100}}},{X=0,Y=-700,Z=0})
        local way2=nil;for _,e in ipairs(got2) do if e.id=="way:"..BA then way2=e end end
        check("a room with no registered object still gets a way (from its geometry)",way2~=nil,ids(got2))
        -- No registered bathroom object, but its objects exist in the world (3 Nov
        -- log: Bathroom_LD=6 in the world, none registered): aim at them.
        _G.FindAllOf=function(c)
            if c=="LiSInteractionActor" then return {{GetFullName=function()return "LiSInteractionActor "..lvl("E3_5A_Bathroom_LD").."LiSInteractionActor_Mirror_20" end,K2_GetActorLocation=function()return {X=239,Y=-1145,Z=105} end}} end
            return {} end
        local c5={GetWorld=function()return {GetFName=function()return {ToString=function()return "E3_5A_world" end} end} end,Pawn={}}
        local got3=S.by_room(c5,{{id="poster",kind="interaction",sublevel=CO,pos={X=0,Y=-700,Z=100}}},{X=0,Y=-700,Z=0})
        local way3=nil;for _,e in ipairs(got3) do if e.id=="way:"..BA then way3=e end end
        check("a room whose objects exist but are unregistered gets a way",way3~=nil,ids(got3))
        -- The real failure (3 Nov log): the mirror is 1 m up a wall; the navmesh
        -- only accepts points near floor height (|Z|<60) and within the search
        -- box of the walkable floor (here: x<200). Default search is 50 cm.
        package.loaded["nav.route"]={project=function(_,q,ext)
                local reach=(ext and ext.X) or 50
                if math.abs(q.Z)>60 then return false,{X=0,Y=0,Z=0} end
                if q.X>200+reach then return false,{X=0,Y=0,Z=0} end
                return true,{X=math.min(q.X,200),Y=q.Y,Z=0} end,
            query=function(_,_,_,a,b)return true,0,{a,b} end}
        local c6={GetWorld=function()return {GetFName=function()return {ToString=function()return "E3_5A_wall" end} end} end,Pawn={}}
        local got4=S.by_room(c6,{{id="poster",kind="interaction",sublevel=CO,pos={X=0,Y=-700,Z=100}}},{X=0,Y=-700,Z=0})
        local way4=nil;for _,e in ipairs(got4) do if e.id=="way:"..BA then way4=e end end
        check("a way is found when the room's object hangs on a wall off the walkable floor",way4~=nil,ids(got4))
        -- A listed door sits at the threshold (the diner's own door): no extra way.
        package.loaded["nav.route"]={project=function(_,q)return true,{X=q.X,Y=q.Y,Z=0} end,query=function(_,_,_,a,b)return true,0,{a,b} end}
        local c7={GetWorld=function()return {GetFName=function()return {ToString=function()return "E3_5A_door" end} end} end,Pawn={}}
        local got5=S.by_room(c7,{{id="poster",kind="interaction",sublevel=CO,pos={X=0,Y=-700,Z=100}},
            {id="bath door",label="Door",kind="interaction",sublevel=CO,pos={X=0,Y=-850,Z=100},door_like=true}},{X=0,Y=-700,Z=0})
        local way5=nil;for _,e in ipairs(got5) do if e.id=="way:"..BA then way5=e end end
        -- Its floor test sees one room only (120 cm out stays above y=-1000), as
        -- the diner door's did; it is 150 cm from the threshold.
        check("no 'Way to' when a listed door is the way",way5==nil and ids(got5):find("bath door")~=nil,ids(got5))
        _G.FindAllOf=oldF
        _G.FindAllOf=oldF
        package.loaded["nav.route"]=nil
    end
    _G.StaticFindObject=oldS
    package.loaded["scanner.sources"]=nil;package.loaded["scanner.rooms"]=nil
end
-- Room filter toggle: off lists everything; the pad chord reaches it.
do
    package.loaded["scanner.sources"]=nil
    local S=require("scanner.sources");S.report=function()end
    local oldS=_G.StaticFindObject
    _G.StaticFindObject=function()return {LineTraceSingle=function(_,_,a,b,_,_,_,_,hit)
        hit.Actor={Get=function()return {GetFullName=function()return "S /Game/Maps/E/R_A_GRC.R_A_GRC:PersistentLevel.F" end} end};return true end} end
    local c={GetWorld=function()return {GetFName=function()return {ToString=function()return "Wt" end} end} end,Pawn={}}
    local list=function()return {{id="a",kind="interaction",sublevel="R_A_LD",pos={X=0,Y=0,Z=0}},{id="b",kind="interaction",sublevel="R_B_LD",pos={X=900,Y=0,Z=0}}} end
    check("room filter on by default",S.ROOM_FILTER==true)
    local on=#S.by_room(c,list(),{X=0,Y=0,Z=0})
    check("toggle reports off",S.toggle_room_filter()==false)
    local off=#S.by_room(c,list(),{X=0,Y=0,Z=0})
    check("filter off lists every object",on==1 and off==2,on.."/"..off)
    S.toggle_room_filter()
    _G.StaticFindObject=oldS;package.loaded["scanner.sources"]=nil
    package.loaded["scanner.pad"]=nil
    local P=require("scanner.pad");local pd=P.new()
    pd:update(0x40,true,0);local cmds=pd:update(0x40|0x80,true,0.1)
    check("hold left stick, click right stick: room filter",cmds[1]=="room_filter")
    local en=require("lang.en");check("room filter phrases",en.room_filter_on and en.room_filter_off:find("{key}"))
end
-- "N in all" hint: once per room, only when the filter hid something.
do
    package.loaded["scanner.scanner"]=nil
    local Sc=require("scanner.scanner")
    Sc.text=function(k,p)return k..":"..tostring(p and p.total)..":"..tostring(p and p.key) end
    check("hint on the first readout in a room that hides objects",Sc.filter_hint("A",6,21,true)=="scanner_filter_hint:21:F4")
    check("not again in the same room",Sc.filter_hint("A",6,21,true)==nil)
    check("again in the next room",Sc.filter_hint("B",4,21,true)~=nil)
    check("no hint when nothing is hidden",Sc.filter_hint("C",5,5,true)==nil)
    check("no hint with the filter off",Sc.filter_hint("D",21,21,false)==nil)
    check("no hint before the room is known",Sc.filter_hint(nil,3,9,true)==nil)
    local en=require("lang.en");check("hint phrase names the total and the key",en.scanner_filter_hint:find("{total}") and en.scanner_filter_hint:find("{key}"))
    -- End to end: the first readout in a new room carries the hint.
    package.loaded["scanner.scanner"]=nil
    local oldF=_G.FindAllOf
    _G.FindAllOf=function()return {{IsValid=function()return true end,Pawn={IsValid=function()return true end,K2_GetActorLocation=function()return {X=0,Y=0,Z=0} end},GetControlRotation=function()return {Yaw=0} end}} end
    local S=require("scanner.sources");local oldC=S.collect
    S.collect=function()S.room="E2E";S.total=9;S.filtered=true;return {{label="Poster",pos={X=100,Y=0,Z=0},id="poster"}} end
    local Sc2=require("scanner.scanner");local said={};Sc2.say=function(t)said[#said+1]=t end;Sc2.text=function(k)return k end
    Sc2.command("next");Sc2.command("next")
    check("first readout in the room speaks the hint",said[1] and said[1]:find("scanner_filter_hint",1,true)~=nil,tostring(said[1]))
    check("the next readout does not",said[2] and not said[2]:find("scanner_filter_hint",1,true),tostring(said[2]))
    S.collect=oldC;_G.FindAllOf=oldF;package.loaded["scanner.scanner"]=nil
end
-- An object's interaction radius is the off-mesh walk's reach (the diner truck:
-- 2350 cm; its Photo appeared at about 23 m).
do
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors","nav.offmesh"}) do package.loaded[m]=nil end
    local pos={X=0,Y=0,Z=0}
    package.loaded["nav.follow"]={ready=function()return true end,active=false,start=function()end,stop=function()end,tick=function()end}
    package.loaded["nav.route"]={project=function(_,p)return true,{X=p.X,Y=p.Y,Z=p.Z or 0} end,query=function()return false,0,{} end}
    package.loaded["nav.doors"]={plan=function()return false end,survey=function()return {} end,inside=function()return false end}
    local got=nil
    package.loaded["nav.offmesh"]={NEAR_MISS=100,cancel=function()end,ground_below=function()return 0 end,
        planner=function(_,_,_,_,reach)got=reach;return {g={samples=1},reason="no_path",step=function()return "failed" end} end,walk=function()end}
    _G.LoopInGameThreadWithDelay=function(_,f)f();return 1 end;_G.CancelDelayedAction=function()end
    local aw=require("autowalk.autowalk")
    aw.say=function()end;aw.text=function(k)return k end;aw.moving=function()return false end;aw.in_reach=function()return nil end;aw.log=function()end
    local pawn={K2_GetActorLocation=function()return pos end,GetAddress=function()return 1 end,IsValid=function()return true end,
        CapsuleComponent={K2_GetComponentLocation=function()return {X=0,Y=0,Z=0} end,GetScaledCapsuleHalfHeight=function()return 0 end}}
    local c={Pawn=pawn,IsValid=function()return true end}
    pcall(aw.start,c,{name="Truck",kind="interaction",pos={X=3380,Y=0,Z=207},actor={},zone=2350})
    check("an object's interaction radius becomes the walk's reach",got==2350-aw.ZONE_MARGIN,tostring(got))
    got=nil;pcall(aw.start,c,{name="Mug",kind="interaction",pos={X=3380,Y=0,Z=0},actor={}})
    check("without a radius the reach is unchanged",got==150,tostring(got))
    _G.LoopInGameThreadWithDelay=nil;_G.CancelDelayedAction=nil
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors","nav.offmesh"}) do package.loaded[m]=nil end
end
-- Focus minigame (PolaRewind): one panned tick per dial, faster as it sharpens.
do
    package.loaded["scenes.polarewind"]=nil
    local P=require("scenes.polarewind")
    check("sharp: fastest ticks",P.interval_for(0.6)==P.FAST and P.interval_for(0.4)==P.FAST)
    check("blurred: slowest ticks",P.interval_for(3.0)==P.SLOW and P.interval_for(9)==P.SLOW)
    check("ticks quicken as it sharpens",P.interval_for(1.0)<P.interval_for(2.0) and P.interval_for(2.0)<P.interval_for(2.8))
    check("the two dials are panned apart and use different sounds",P.CHANNELS[1].pan<0 and P.CHANNELS[2].pan>0 and P.CHANNELS[1].file~=P.CHANNELS[2].file)
    check("tutorial markup and line breaks removed",P.tidy("Use <img id=\"A\"/>A/D keys \\nuntil you find the sweet spot.")=="Use A/D keys until you find the sweet spot.")
    local ticks,said,loads={},{},{}
    P.tick_fn=function(ch,on,pan,ms,vol)ticks[#ticks+1]={ch=ch,on=on,pan=pan,ms=ms}end
    P.load_fn=function(ch,path)loads[#loads+1]=path;return true end
    P.say=function(t)said[#said+1]=t end;P.log=function()end
    local oldFN=_G.FName;_G.FName=function(s)return s end
    local blur={ImageA_PositionAndBlur=2.4,ImageB_PositionAndBlur=0.6}
    local mid={IsValid=function()return true end,K2_GetVectorParameterValue=function(_,n)return {R=0,G=0,B=blur[n],A=0} end}
    local function tb(text)return {IsValid=function()return true end,IsVisible=function()return true end,GetText=function()return {ToString=function()return text end} end} end
    local w={IsValid=function()return true end,IsInViewport=function()return true end,IsVisible=function()return true end,
        PuzzleSolved=false,mEmissiveInstance=mid,KBTutorial=tb("Use A/D keys until you find the sweet spot."),
        GamepadTutorial={IsValid=function()return true end,IsVisible=function()return false end}}
    local oldF=_G.FindAllOf;_G.FindAllOf=function(c)if c=="BP_LiSPolaRewindWidget_New_C" then return {w} end;return {} end
    P.tick(1)
    local a,b=ticks[1],ticks[2]
    check("both sounds loaded once",#loads==2)
    check("dial A ticks on the left, slowly while blurred",a and a.ch==0 and a.on and a.pan<0 and a.ms>P.FAST)
    check("dial B ticks on the right, fast when sharp",b and b.ch==1 and b.on and b.pan>0 and b.ms==P.FAST)
    check("tutorial read once",said[1]=="Use A/D keys until you find the sweet spot.")
    P.tick(1.1);check("not read again while unchanged",#said==1 and #loads==2)
    check("lock detected only when both drop below the sweet spot",P.locked(0.4,0.4) and not P.locked(0.6,0.4) and not P.locked(0.4,2.0) and not P.locked(nil,0.4))
    blur.ImageA_PositionAndBlur=0.243;blur.ImageB_PositionAndBlur=0.243
    local m=#ticks;P.tick(1.15)
    check("ticks off while the game's closing animation runs",ticks[m+1] and ticks[m+1].on==false and ticks[m+2] and ticks[m+2].on==false and #ticks==m+2)
    blur.ImageA_PositionAndBlur=2.4;blur.ImageB_PositionAndBlur=0.6
    P.tick(1.18)  -- the game let go: ticking again
    check("ticks come back if the pictures part again",ticks[#ticks].on==true)
    w.PuzzleSolved=true;local n=#ticks;P.tick(1.2)
    check("ticks off once solved",ticks[n+1] and ticks[n+1].on==false and ticks[n+2] and ticks[n+2].on==false)
    _G.FindAllOf=oldF;_G.FName=oldFN;package.loaded["scenes.polarewind"]=nil
end
-- An exit walk that stalls inside the exit's volume has arrived (3 Nov: Leave
-- Chloe's House, volume centre -48,-256 half-size 330x328, stall at 204,-297).
do
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors"}) do package.loaded[m]=nil end
    local pos={X=216,Y=-277,Z=0}
    local follow={active=false};local emitf
    function follow.ready()return true end
    function follow.start(_,_,goal,emit)emitf=emit;follow.active=true;follow.goal=goal end
    function follow.stop()follow.active=false end
    function follow.tick()
        if not follow.active then return end
        pos={X=204,Y=-297,Z=0}
        emitf(string.format("follow_progress elapsed=4 remaining=%.3f vertical=0 position=%.1f,%.1f,0",math.abs(follow.goal.X-pos.X),pos.X,pos.Y))
        emitf("follow_end=stalled stop_ok=true");follow.active=false
    end
    package.loaded["nav.follow"]=follow
    package.loaded["nav.route"]={project=function(_,p)return true,{X=p.X,Y=p.Y,Z=p.Z or 0} end,query=function(_,_,_,a,b)return true,300,{a,b} end}
    local D=dofile("src/nav/doors.lua")
    package.loaded["nav.doors"]={plan=function()return nil end,survey=function()return {} end,inside=D.inside}
    local aw=require("autowalk.autowalk")
    local said={};aw.say=function(k)said[#said+1]=k end;aw.text=function(k)return k end
    aw.moving=function()return false end;aw.in_reach=function()return nil end;aw.log=function()end
    local pawn={K2_GetActorLocation=function()return pos end,GetAddress=function()return 1 end,IsValid=function()return true end,
        CapsuleComponent={K2_GetComponentLocation=function()return {X=pos.X,Y=pos.Y,Z=pos.Z} end,GetScaledCapsuleHalfHeight=function()return 0 end}}
    local c={Pawn=pawn,IsValid=function()return true end}
    local exit={name="Leave Chloe's House, exit",kind="exit",pos={X=-48,Y=-256,Z=64},stand={X=-48,Y=-256,Z=0},extent={X=330,Y=328,Z=64}}
    local ok=pcall(aw.start,c,exit);for _=1,4 do pcall(aw.tick) end
    local function has(k)for _,v in ipairs(said) do if v==k then return true end end end
    check("exit walk stalled inside the volume counts as arrived",ok and has("walk_arrived") and not has("walk_blocked") and not has("walk_retry"),table.concat(said,","))
    -- Outside the volume it is still blocked (after its retry).
    said={};pos={X=600,Y=-277,Z=0}
    follow.tick=function()
        if not follow.active then return end
        pos={X=500,Y=-297,Z=0}
        emitf("follow_progress elapsed=4 remaining=548 vertical=0 position=500,-297,0")
        emitf("follow_end=stalled stop_ok=true");follow.active=false
    end
    pcall(aw.start,c,exit);for _=1,6 do pcall(aw.tick) end
    check("an exit walk stalled outside the volume is not arrival",not has("walk_arrived"),table.concat(said,","))
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors"}) do package.loaded[m]=nil end
end
-- Room vote from floor samples: a doorstep does not switch the room.
do
    package.loaded["scanner.rooms"]=nil
    local R=require("scanner.rooms")
    local P,D="Park","Diner"
    check("standing on the diner's doorstep (1 of 5 diner): still the park",R.vote({D,P,P,P,P},5,P)==P)
    check("two of five diner: still the park",R.vote({D,D,P,P,P},5,P)==P)
    check("well inside (4 of 5): the diner",R.vote({D,D,D,D,P},5,P)==D)
    check("three of five: the diner",R.vote({D,D,D,P,P},5,P)==D)
    -- Missed traces (outside the walls, into a doorframe) must not let two
    -- doorstep samples outvote one: a change needs a majority of all five.
    check("two diner, one park, two missed: still the park",R.vote({D,D,nil,nil,P},5,P)==P)
    check("three diner, one park, one missed: the diner",R.vote({D,D,D,P,nil},5,P)==D)
    check("missed traces are not votes when nothing else is known",R.vote({D,nil,nil,nil,nil},5,nil)==D)
    check("nothing found: no room",R.vote({nil,nil,nil,nil,nil},5,P)==nil)
    check("no current room: the majority",R.vote({D,P,P,nil,nil},5,nil)==P)
    package.loaded["scanner.rooms"]=nil
end
-- "As close as you can get": an object with no way to it, through autowalk.
do
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors","nav.offmesh"}) do package.loaded[m]=nil end
    local pos={X=0,Y=0,Z=0}
    package.loaded["nav.follow"]={ready=function()return true end,active=false,start=function()end,stop=function()end,tick=function()end}
    package.loaded["nav.route"]={project=function(_,p)return true,{X=p.X,Y=p.Y,Z=p.Z or 0} end,query=function()return false,0,{} end}
    package.loaded["nav.doors"]={plan=function()return false end,survey=function()return {} end,inside=function()return false end}
    local walked=nil
    package.loaded["nav.offmesh"]={NEAR_MISS=100,cancel=function()end,ground_below=function()return 0 end,
        planner=function()return {g={samples=1},reason="no_path",closest_waypoints={{X=0,Y=0,Z=0},{X=1300,Y=0,Z=0}},closest_d=2080,
            step=function(self)return "failed" end} end,
        walk=function(_,_,wps,done)walked=wps;pos={X=1300,Y=0,Z=0};done("arrived_test_region",0) end}
    _G.LoopInGameThreadWithDelay=function(_,f)f();return 1 end
    _G.CancelDelayedAction=function()end
    local aw=require("autowalk.autowalk")
    local said={};aw.say=function(k)said[#said+1]=k end;aw.text=function(k,p)return k..(p and p.value and ("="..p.value) or "") end
    aw.moving=function()return false end;aw.in_reach=function()return nil end;aw.log=function()end
    local pawn={K2_GetActorLocation=function()return pos end,GetAddress=function()return 1 end,IsValid=function()return true end,
        CapsuleComponent={K2_GetComponentLocation=function()return {X=pos.X,Y=pos.Y,Z=pos.Z} end,GetScaledCapsuleHalfHeight=function()return 0 end}}
    local c={Pawn=pawn,IsValid=function()return true end}
    local truck={name="Truck",kind="interaction",pos={X=3380,Y=0,Z=207},actor={}}
    local ok,err=pcall(aw.start,c,truck)
    local joined=table.concat(said,",")
    check("no way to an object: walks as close as it can",ok and walked~=nil and joined:find("walk_closest_start",1,true)~=nil,tostring(err).." "..joined)
    check("and says how far the object still is",joined:find("walk_closest_arrived=21",1,true)~=nil,joined)
    -- An object with its own interaction radius: the planner may stop anywhere
    -- inside it (the truck: 2350 cm, photo seen at ~23 m).
    local got_reach=nil
    local planner0=package.loaded["nav.offmesh"].planner
    package.loaded["nav.offmesh"].planner=function(_,_,_,_,reach)got_reach=reach;return planner0() end
    said={};pos={X=0,Y=0,Z=0}
    pcall(aw.start,c,{name="Truck",kind="interaction",pos={X=3380,Y=0,Z=207},actor={},zone=2350})
    check("an object's interaction radius becomes the walk's reach",got_reach==2350-aw.ZONE_MARGIN,tostring(got_reach))
    got_reach=nil;said={};pos={X=0,Y=0,Z=0}
    pcall(aw.start,c,{name="Mug",kind="interaction",pos={X=3380,Y=0,Z=0},actor={}})
    check("without a radius the reach is unchanged",got_reach==150,tostring(got_reach))
    package.loaded["nav.offmesh"].planner=planner0
    -- A goal (not an object) with no way: reported plainly, no approach.
    said={};walked=nil;pos={X=0,Y=0,Z=0}
    pcall(aw.start,c,{name="Somewhere",kind="goal",pos={X=3380,Y=0,Z=0},stand={X=3380,Y=0,Z=0}})
    check("a goal with no way is still 'no route'",walked==nil and table.concat(said,","):find("walk_no_route",1,true)~=nil,table.concat(said,","))
    _G.LoopInGameThreadWithDelay=nil;_G.CancelDelayedAction=nil
    for _,m in ipairs({"autowalk.autowalk","nav.follow","nav.route","nav.doors","nav.offmesh"}) do package.loaded[m]=nil end
end
print(string.format("%d checks, %d failures",count,failures))
os.exit(failures==0 and 0 or 1)
