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
local menu_snapshot=nil
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

-- Keys. Home describes: the live menu readout in menus (so a countdown is
-- current), the selected scanner object in play. Ctrl+Home repeats the last
-- announcement. Page Up/Down select scanner objects in play. Each key runs on
-- the game thread; the loader only fires a binding for its exact modifiers.
local reread=nil
local scanner=require("scanner.scanner")
local function in_menu()return menu_snapshot and menu_snapshot()~=nil end
-- Scanner and autowalk work only while the player controls Max (see core/control.lua).
local control=require("core.control").new()
local control_world=nil
local function playable()return not in_menu() and control:has_control() end
-- Key presses are queued and run by the game-thread loop below, never handed to
-- the game thread from the loader's input thread (that hand-off is what the
-- loader dropped and crashed in). The input thread only appends to a table.
local key_queue={}
local function on_game(fn)
    return function()key_queue[#key_queue+1]=fn end
end
local function run_keys()
    if #key_queue==0 then return end
    local pending=key_queue;key_queue={}
    for _,fn in ipairs(pending) do
        local ok,err=pcall(fn)
        if not ok then log("key_error="..tostring(err)) end
    end
end
RegisterKeyBindAsync(Key.HOME,on_game(function()
    if not playable() then
        local text=nil
        if reread then local ok,t=pcall(reread);if ok then text=t end end
        speech.say(text or last_speech,true)
    else
        scanner.command("describe")
    end
end))
RegisterKeyBindAsync(Key.HOME,{ModifierKey.CONTROL},on_game(function()speech.say(last_speech,true)end))
RegisterKeyBindAsync(Key.PAGE_DOWN,on_game(function()if playable() then scanner.command("next") end end))
RegisterKeyBindAsync(Key.PAGE_UP,on_game(function()if playable() then scanner.command("previous") end end))
-- Shift+Home walks to the selected object; pressing it again while walking stops.
local autowalk=require("autowalk.autowalk")
local function walk_toggle()
    if autowalk.cancel() then return end
    if not playable() then return end
    local c=scanner.controller()
    if c then autowalk.start(c,scanner.selected()) end
end
RegisterKeyBindAsync(Key.HOME,{ModifierKey.SHIFT},on_game(walk_toggle))
-- F faces the selected object; F1 help; F2 sound preview (help and preview
-- also work in menus and while the game has control).
local face=require("scanner.face")
local face_probe_tick=nil
local help=require("core.help")
local preview=require("core.preview")
local function face_selected()
    if not playable() then return end
    local c=scanner.controller()
    if c then face.start(c,scanner.selected()) end
end
local function show_help()say(help.speech(controls.using_gamepad()),true)end
-- The cue plays ~0.9 s after its name (18 loop beats), on the game-thread loop.
local delayed={}
local function after_beats(n,fn)delayed[#delayed+1]={n=n,fn=fn} end
local function run_delayed()
    for i=#delayed,1,-1 do
        local d=delayed[i];d.n=d.n-1
        if d.n<=0 then table.remove(delayed,i);pcall(d.fn) end
    end
end
local function next_preview()preview.next(function(play)after_beats(18,play)end)end
RegisterKeyBindAsync(Key.F,on_game(face_selected))
-- 1-4 use the actions of the object the game has focused.
local actions=require("scanner.actions")
for n,k in ipairs({Key.ONE,Key.TWO,Key.THREE,Key.FOUR}) do
    RegisterKeyBindAsync(k,on_game(function()
        if not playable() then return end
        local c=scanner.controller();if c then actions.trigger(c,n) end
    end))
end
RegisterKeyBindAsync(Key.F1,on_game(show_help))
RegisterKeyBindAsync(Key.F2,on_game(next_preview))

-- Menu narration: the title prompt and the highlighted main menu option,
-- spoken whenever it changes. Four reads a second, menu widgets only.
local menu=require("menus.main_menu")
menu_snapshot=menu.snapshot
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
require("core.text").report=log
reread=function()
    local snap=menu.snapshot()
    if not snap or not snap.label or snap.label=="" then return nil end
    return require("core.text").join(snap.label,snap.value)
end
local menu_errors,settings_tick=0,0
local arrows_done=false
local function menu_step()
        local ok,err=pcall(function()
            settings_tick=settings_tick+1
            -- Arrow keys mirror WASD. Applied once the title screen exists, so the
            -- player's input has been created and can rebuild its key maps.
            if not arrows_done and menu.title_ready() then arrows_done=true;pcall(require("core.arrow_keys").apply,log) end
            if settings_tick%8==1 then refresh_settings() end
            local snap,detail=menu.snapshot()
            local text,fallback=tracker:update(snap)
            if fallback then text=l10n.text("menu_unlabelled") end
            if text then
                say(text,true)
                -- Log exactly what was spoken, so a readout can be checked from the log.
                log("menu_readout "..tostring(detail).." spoken="..text)
            end
        end)
        if not ok and menu_errors<5 then menu_errors=menu_errors+1;log("menu_error="..tostring(err)) end
end

-- Scanner speech, wording and controller input (gameplay only).
scanner.say=function(text)say(text,true)end
autowalk.say=function(text)say(text,true)end
face.say=function(text)say(text,true)end
actions.say=function(text)say(text,true)end
actions.log=log
actions.text=function(key,p)return l10n.text(key,p)end
actions.key_name=function(position,slot)
    if controls.using_gamepad() and slot then return controls.slot_buttons[slot] end
    return tostring(position)
end
actions.translate=function(key)return require("scanner.sources").translate(key)end
face.focused_announce=function(c)actions.announce(c)end
face.log=log
-- Test sessions: record what the game does after each face request.
do local ok,req=pcall(require,"LISNavRequest")
    if ok and type(req)=="table" and req.expected_saved_directory and req.trace_focus then
        local probe=require("dev.focus_probe")
        face.watch=function(c,e)probe.watch(c,e,log)end
        face_probe_tick=probe.tick
        actions.trace_popup=true
    end
end
face.text=function(key,p)return l10n.text(key,p)end
help.text=function(key,p)return l10n.text(key,p)end
preview.text=function(key)return l10n.text(key)end
preview.say=function(text)say(text,true)end
preview.play=function(file)return speech.play and speech.play(speech.audio_dir..file) end
autowalk.log=log
autowalk.moving=function()return speech.moving and speech.moving() or false end
autowalk.text=function(key,p)return l10n.text(key,p)end
-- Control tracking, autowalk, facing and focus announcements.
local walk_errors=0
local function main_step()
        local ok,err=pcall(function()
            local state="unknown"
            local c=scanner.controller()
            -- Gameplay worlds only: the menu world has a stand-in Max. A world
            -- change restarts tracking quietly (see core/control.lua).
            local world=nil
            if c then pcall(function()world=c:GetWorld():GetFName():ToString()end) end
            if world~=control_world then control_world=world;control:reset(os.clock()) end
            if c and world and world~="WhatIf_Menu" and not in_menu() then
                local ready,reason=require("nav.follow").ready(c,c.Pawn)
                if ready then state="control"
                elseif reason=="cinematic_movement_track" or reason=="input_ignored" then state="none" end
            end
            local event=control:update(state,os.clock())
            if event then
                log("control "..event)
                if speech.play then speech.play(speech.audio_dir..(event=="lost" and "control_lost.wav" or "control_back.wav")) end
            end
            autowalk.tick()
            face.tick()
            if c and control:has_control() and not in_menu() then actions.tick(c) end
            if face_probe_tick then face_probe_tick() end
        end)
        if not ok and walk_errors<5 then walk_errors=walk_errors+1;log("autowalk_error="..tostring(err)) end
end
scanner.log=log
do local ok,req=pcall(require,"LISNavRequest");scanner.trace=ok and type(req)=="table" and req.expected_saved_directory~=nil end
scanner.text=function(key,p)return l10n.text(key,p)end
require("scanner.readout").text=function(key,p)return l10n.text(key,p)end
local sources=require("scanner.sources")
sources.translate_ready=true
sources.report=log
sources.text=function(key)return l10n.text(key)end
sources.language=function()return l10n.language()end
local pad=require("scanner.pad").new()
local pad_read=speech.pad
local pad_errors=0
local function pad_step()
        local ok,err=pcall(function()
            local buttons=pad_read and pad_read() or -1
            local active=buttons>=0 and playable()
            for _,cmd in ipairs(pad:update(buttons,active,os.clock())) do
                if cmd=="repeat" then speech.say(last_speech,true)
                elseif cmd=="autowalk" then walk_toggle()
                elseif cmd=="face" then face_selected()
                elseif cmd=="help" then show_help()
                elseif cmd=="preview" then next_preview()
                else scanner.command(cmd) end
            end
        end)
        if not ok and pad_errors<5 then pad_errors=pad_errors+1;log("pad_error="..tostring(err)) end
end

-- ONE background loop for everything that polls the game, run directly on the
-- game thread by the loader (LoopInGameThreadWithDelay). The earlier design
-- created each step on the loader's async thread and handed it to the game
-- thread (LoopAsync + ExecuteInGameThread); the loader dropped such steps at
-- random ("Ref was not function") and the game crashed inside that hand-off.
-- Controller buttons every 50 ms; menus and the main step alternate on the
-- 250 ms beats, so no beat does both.
local beat=0
LoopInGameThreadWithDelay(50,function()
    beat=beat+1
    local ok,err=pcall(function()
        run_keys()
        run_delayed()
        pad_step()
        if beat%5==0 then
            if (beat//5)%2==0 then menu_step() else main_step() end
            -- Facing corrections need a fresh camera reading every 250 ms.
            if (beat//5)%2==0 then face.tick() end
        end
    end)
    if not ok then log("loop_error="..tostring(err)) end
end)

-- Development test session, only with an explicit disposable-profile request.
local request_ok,request=pcall(require,"LISNavRequest")
if not request_ok then
    if not tostring(request):find("not found",1,true) then log("request_error="..tostring(request)) end
elseif type(request)=="table" and request.expected_saved_directory then
    log("test session requested")
    require("dev.session")(request,{l10n=l10n,controls=controls,speech=speech,say=say})
end
