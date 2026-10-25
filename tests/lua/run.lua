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
    local known={menu_key=true,cancel_key=true}
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
print(string.format("%d checks, %d failures",count,failures))
os.exit(failures==0 and 0 or 1)
