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
    local known={menu_key=true,cancel_key=true,value=true,confirm_key=true,back_key=true,index=true,count=true,name=true,label=true,actions=true,options=true,key=true,text=true}
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
    plan_result=false
    check("no route",aw.start(c,mail)==false and spoken[#spoken]=="walk_no_route:Mail")
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
    check("stall near goal is still blocked",single("stalled",20).say=="walk_blocked")
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
    check("gives up after 8 corrections",requests==9 and spoken[#spoken]=="face_turned_unfocused:Mail",tostring(requests))
    -- Time limit.
    requests=0;F.start(c,{name="Mail",kind="interaction",pos={X=0,Y=100,Z=0},actor=mail})
    now=now+3;F.tick();F.tick()
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
    P.next();P.next();P.next()
    check("preview cycles",played[1]=="control_lost.wav" and played[2]=="control_back.wav" and played[3]=="control_lost.wav")
    check("preview names each",said[2]=="cue_control_back" and en.cue_control_back~=nil)
    local delayed=nil;P.next(function(f)delayed=f end)
    check("sound waits for the name",#played==3 and delayed~=nil)
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
-- Dialogue choices: key names and wording, and choosing through the game's button.
do
    package.loaded["dialogue.choices"]=nil
    local C=require("dialogue.choices")
    local en=require("lang.en")
    C.text=function(k,p)return (en[k]:gsub("{(%w+)}",function(n)return tostring(p[n]) end)) end
    local opts={{text="The Daguerreian Process.",direction="Up"},{text="I don't know.",direction="Down"}}
    C.keys(opts,false)
    local tidy=require("core.text").tidy
    check("choice keyboard keys (as spoken)",tidy(C.announce_text(opts,false))=="Choose: 1, The Daguerreian Process. 2, I don't know.",tidy(C.announce_text(opts,false)))
    C.keys(opts,true)
    check("choice controller buttons",opts[1].key=="Y" and opts[2].key=="A")
    local cap={{text="You're asking me?",slot=2},{text="I did know...",slot=3}} -- captured: icons hidden
    C.keys(cap,true,false);check("minor choice: slot 2 is X, slot 3 is B (confirmed in play)",cap[1].key=="X" and cap[2].key=="B")
    local all={{slot=1},{slot=2},{slot=3},{slot=4}}
    C.keys(all,true,false);check("minor slots Y X B A",all[1].key=="Y" and all[4].key=="A")
    C.keys(all,true,true);check("major slots X B Y A",all[1].key=="X" and all[2].key=="B" and all[3].key=="Y" and all[4].key=="A")
    C.keys(cap,false);check("keyboard numbers ignore slots",cap[1].key=="1" and cap[2].key=="2")
    check("no doubled full stop after a question",C.announce_text({{text="Why?",key="1"}},false)=="Choose: 1, Why?")
    check("full stop added after a bare answer",C.announce_text({{text="Sure",key="1"}},false)=="Choose: 1, Sure.")
    check("major choice wording",C.announce_text(opts,true):find("^Major choice: ")~=nil)
    -- Choosing calls the shown button's own ClickButton (the game's face-button path).
    local clicked=nil
    local function b(t,i,vis)return {IsValid=function()return true end,IsVisible=function()return vis end,DialogText={GetText=function()return {ToString=function()return t end}end},
        ActionIndex=i,OptionPosition=i,ClickButton=function()clicked=i end,Image_Up={IsValid=function()return true end,IsVisible=function()return false end}} end
    local buttons={b("A",0,true),b("",1,false),b("C",2,true)}
    local v={IsValid=function()return true end,IsInViewport=function()return true end,IsVisible=function()return true end,IsMajorChoice=function()return false end,
        DialogButtons_Array={ForEach=function(_,cb)for i,x in ipairs(buttons) do cb(i,{get=function()return x end}) end end}}
    _G.FindAllOf=function(n)return n=="BP_LiSDialogWidget_View_C" and {v} or {} end
    local said={};C.say=function(t)said[#said+1]=t end
    local list=C.read()
    check("hidden and empty answers skipped",#list==2 and list[2].text=="C")
    check("second announced answer clicks its own button",C.choose(2) and clicked==2)
    check("missing answer refused",not C.choose(3) and said[#said]=="No answer 3.")
    _G.FindAllOf=nil;package.loaded["dialogue.choices"]=nil
end
-- Actions press the pop-up's own button for the slot (the door has three
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
-- Actions press the pop-up's own button for the slot (the door has three
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
print(string.format("%d checks, %d failures",count,failures))
os.exit(failures==0 and 0 or 1)
