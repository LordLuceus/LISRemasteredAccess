-- LIS Remastered Access entry point, loaded by UE4SS on every launch.
-- Player features here only READ the game (speech, braille, menu narration):
-- they never move Max, load scenes or write saves. The development test
-- session (dev/session.lua) loads only when the test runner wrote a request
-- naming an exact disposable saved directory.
local prefix="[LISAccess] "
local function log(line)print(prefix..line.."\n")end
local l10n=require("core.localization")
local controls=require("core.controls")
local speech=require("core.speech")
l10n.set_logger(log)
log("loaded speech_module "..speech.status())

local last_speech=""
local function say(text,interrupt)
    if type(text)~="string" or text=="" then return end
    last_speech=text
    speech.say(text,interrupt~=false)
end

-- Follow the game's language and input mode; both getters are side-effect free.
local settings_logged=false
local function refresh_settings()
    local controller
    for _,c in ipairs(FindAllOf("LiSPlayerController") or {}) do
        if c:IsValid() then controller=c;break end
    end
    if not controller then return end
    local ok,lang=pcall(function()return controller:GetCurrentLanguage()end)
    if ok then lang=type(lang)=="string" and lang or lang:ToString();l10n.set_language(lang) end
    local changed=controls.refresh(controller)
    if not settings_logged then
        settings_logged=true
        log("settings game_language="..tostring(lang).." catalog="..l10n.language().." gamepad="..tostring(controls.using_gamepad()))
    elseif changed then
        log("input_mode gamepad="..tostring(controls.using_gamepad()))
    end
end

-- Home repeats the last announcement.
RegisterKeyBindAsync(Key.HOME,function()speech.say(last_speech,true)end)

-- Menu narration: the title prompt and the highlighted main menu option,
-- spoken whenever it changes. Four reads a second, menu widgets only.
local menu=require("menus.main_menu")
menu.format_percent=function(p)return l10n.text("percent",{value=p})end
menu.format_choices=function(confirm,cancel)
    local keys={confirm_key=controls.name("confirm"),back_key=controls.name("back")}
    if confirm and cancel then return l10n.text("dialog_confirm_cancel",keys) end
    if confirm then return l10n.text("dialog_confirm",keys) end
end
menu.using_gamepad=controls.using_gamepad
menu.gamma_title=l10n.text("gamma_title")
-- Test sessions can ask for details of options the reader cannot label.
do
    local ok,req=pcall(require,"LISNavRequest")
    if ok and type(req)=="table" and req.expected_saved_directory and req.describe_unlabelled then menu.describe_unlabelled=require("dev.unlabelled").describe(log) end
    if ok and type(req)=="table" and req.expected_saved_directory and req.trace_dialogs then
        local trace=require("dev.dialog_trace")
        LoopAsync(500,function()ExecuteInGameThread(function()pcall(trace.tick,log)end,EGameThreadMethod.EngineTick);return false end)
    end
end
local tracker=require("menus.tracker").new()
local menu_errors,settings_tick=0,0
LoopAsync(250,function()
    ExecuteInGameThread(function()
        local ok,err=pcall(function()
            settings_tick=settings_tick+1
            if settings_tick%8==1 then refresh_settings() end
            local snap,detail=menu.snapshot()
            local text,fallback=tracker:update(snap)
            if fallback then text=l10n.text("menu_unlabelled") end
            if text then
                say(text,true)
                log("menu_readout "..tostring(detail).." label="..tostring(snap and snap.label))
            end
        end)
        if not ok and menu_errors<5 then menu_errors=menu_errors+1;log("menu_error="..tostring(err)) end
    end,EGameThreadMethod.EngineTick)
    return false
end)

-- Development test session, only with an explicit disposable-profile request.
local request_ok,request=pcall(require,"LISNavRequest")
if not request_ok then
    if not tostring(request):find("not found",1,true) then log("request_error="..tostring(request)) end
elseif type(request)=="table" and request.expected_saved_directory then
    log("test session requested")
    require("dev.session")(request,{l10n=l10n,controls=controls,speech=speech,say=say})
end
