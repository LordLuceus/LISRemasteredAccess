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
local room_tick,room_last,room_pending,room_spoken,room_announced_once=0,nil,nil,nil,false
local scanner=require("scanner.scanner")
local function in_menu()return menu_snapshot and menu_snapshot()~=nil end
-- Scanner and autowalk work only while the player controls Max (see core/control.lua).
local control=require("core.control").new()
local control_world=nil
local function playable()return not in_menu() and control:has_control() end
-- The scanner, facing and Home also work while Max chooses a shooting target
-- in the junkyard (the game holds her, but the camera aims; keyboard players
-- have no other way to turn it).
local function can_scan()
    if playable() then return true end
    if in_menu() then return false end
    local c=nil;pcall(function()c=scanner.controller()end)
    local ok,on=pcall(require("scenes.junkyard_shooting").aiming,c)
    return ok and on==true
end
-- Keyboard shortcuts are polled by the game-thread loop below (core/keys.lua):
-- no mod code ever runs on the loader's input thread. bind_key keeps the
-- loader's call shape: bind_key(key, fn) or bind_key(key, {modifier}, fn).
local keys=require("core.keys").new()
local function on_game(fn)return fn end
local function bind_key(key,mods,fn,opts)
    if type(mods)=="function" then fn,mods,opts=mods,nil,fn end
    local m="none"
    if type(mods)=="table" then
        if mods[1]==ModifierKey.CONTROL then m="ctrl" elseif mods[1]==ModifierKey.SHIFT then m="shift" end
    end
    keys:bind(key,m,fn,opts)
end
local keys_reported=false
local function run_keys()
    if not speech.keys then
        if not keys_reported then keys_reported=true;log("keys_unavailable: lisr_keys missing from lisr_speech.dll") end
        return
    end
    for _,fn in ipairs(keys:update(speech.keys(table.unpack(keys.vks)),os.clock())) do
        local ok,err=pcall(fn)
        if not ok then log("key_error="..tostring(err)) end
    end
end
bind_key(Key.HOME,on_game(function()
    if not can_scan() then
        local text=nil
        if reread then local ok,t=pcall(reread);if ok then text=t end end
        speech.say(text or last_speech,true)
    else
        scanner.command("describe")
    end
end))
bind_key(Key.HOME,{ModifierKey.CONTROL},on_game(function()speech.say(last_speech,true)end))
bind_key(Key.PAGE_DOWN,on_game(function()if can_scan() then scanner.command("next") end end),{["repeat"]=true})
bind_key(Key.PAGE_UP,on_game(function()if can_scan() then scanner.command("previous") end end),{["repeat"]=true})
-- Shift+Home walks to the selected object; pressing it again while walking stops.
local autowalk=require("autowalk.autowalk")
local function walk_toggle()
    if autowalk.cancel() then return end
    if not playable() then return end
    local c=scanner.controller()
    -- One value only: selected() also returns the list index.
    if c then local e=scanner.selected();autowalk.start(c,e) end
end
bind_key(Key.HOME,{ModifierKey.SHIFT},on_game(walk_toggle))
-- F faces the selected object; F1 help; F2 sound preview (help and preview
-- also work in menus and while the game has control).
local face=require("scanner.face")
local face_probe_tick=nil
local face_probe_tick_reader=nil
local help=require("core.help")
local preview=require("core.preview")
local tutorial=require("hud.tutorial")
local tooltip=require("hud.tooltip")
local sms=require("hud.sms")
local icons=require("hud.icons")
local shooting=require("scenes.junkyard_shooting")
local office=require("scenes.principal_office")
local rooms=require("scanner.rooms")
local viewer=require("hud.viewer")
local journal=require("hud.journal")
local choice_stats=require("menus.choice_stats")
local stats_cursor=choice_stats.cursor()
local stats_open=false
local journal_cursor=journal.cursor()
local journal_open=false
local journal_move -- defined with the journal step below
local choices=require("dialogue.choices")
local function face_selected()
    if not can_scan() then return end
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
bind_key(Key.F,on_game(face_selected))
-- 1-4 use the actions of the object the game has focused.
local actions=require("scanner.actions")
for n,k in ipairs({Key.ONE,Key.TWO,Key.THREE,Key.FOUR}) do
    bind_key(k,on_game(function()
        if in_menu() then return end
        -- An open dialogue choice takes the number keys (control is not
        -- required: the game holds Max during conversations).
        if choices.options() then choices.choose(n);return end
        -- An open pop-up takes the number keys too, with or without control.
        local c0=scanner.controller()
        local pop=false;pcall(function()local _,open=actions.focused(c0);pop=open==true end)
        if not pop and not playable() then return end
        local c=scanner.controller();if c then actions.trigger(c,n) end
    end))
end
bind_key(Key.UP_ARROW,on_game(function()journal_move(-1)end),{["repeat"]=true})
bind_key(Key.DOWN_ARROW,on_game(function()journal_move(1)end),{["repeat"]=true})
-- Choices screen: Space switches World / Friends stats (Y on a controller;
-- the game has no keyboard key for it). Space does nothing else there.
bind_key(Key.SPACE,on_game(function()
    if not stats_open then return end
    if choice_stats.swap() then
        -- The flag flips a moment later (the swap is the game's own event); say
        -- the new mode as soon as the screen reports it, or after half a second.
        local before=stats_cursor.page and stats_cursor.page.world
        local tries=0
        local h
        h=LoopInGameThreadWithDelay(100,function()
            tries=tries+1
            local ok,p=pcall(choice_stats.page)
            if ok and p and (p.world~=before or tries>=5) then
                CancelDelayedAction(h)
                local text=stats_cursor:update(p) or stats_cursor:current()
                if text then say(text,true);log("choice_stats swap spoken="..text) end
            elseif tries>=10 then CancelDelayedAction(h) end
        end)
    end
end))

bind_key(Key.F1,on_game(show_help))
bind_key(Key.F2,on_game(next_preview))

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
        LoopInGameThreadWithDelay(500,function()pcall(trace.tick,log)end)
    end
end
local tracker=require("menus.tracker").new()
require("core.text").report=log
reread=function()
    if stats_open then return stats_cursor:current() end
    if choices.options() then return choices.current(controls.using_gamepad()) end
    local snap=menu.snapshot()
    if not snap or not snap.label or snap.label=="" then return nil end
    return require("core.text").join(snap.label,snap.value)
end
-- Tutorial prompts: spoken once when a new one appears (Ctrl+Home repeats it).
local last_tutorial=nil
local function tutorial_step()
    if in_menu() then return end
    local ok,text,names,rewrite=pcall(tutorial.current,controls.using_gamepad())
    if not ok then return end
    if text~=last_tutorial then
        last_tutorial=text
        if text then
            say(text,false)
            log("tutorial_prompt blocks="..tostring(names).." rewrite="..tostring(rewrite).." spoken="..text)
        end
    end
end
-- Dialogue choices: announced once when a new set of answers appears.
local choice_install_tick=0
local function choices_step()
    -- Hook the dialogue view's events (once its class is loaded; re-checked
    -- every two seconds in case the game loads a new copy).
    choice_install_tick=choice_install_tick+1
    -- Every step until hooked (the class appears with the first conversation),
    -- then every two seconds in case the game loads a new copy.
    if not choices.hooked() or choice_install_tick%8==1 then choices.install() end
    if in_menu() then return end
    choices.tick()
    local text,options=choices.due(controls.using_gamepad())
    if text then
        say(text,true)
        local d={};for _,o in ipairs(options) do d[#d+1]=tostring(o.slot) end
        log("choice_announce slots="..table.concat(d,",").." spoken="..text)
    end
end
-- Prompts: the game's tooltip line (thoughts such as "I need to get Victoria
-- out of my way" and the objective), spoken once when it changes; and the exit
-- prompt, spoken when Max walks into an active exit. The game draws the exit
-- prompt in a way no widget reports, so it comes from the exit itself (the
-- same text the scanner uses, with the interact key for the device).
local last_tooltip=nil
local exit_inside,exit_check=nil,0
local function exit_step()
    exit_check=exit_check+1
    if exit_check%2~=0 then return end -- twice a second is plenty
    local c=scanner.controller()
    if not (c and control:has_control()) then return end
    local ok,list=pcall(require("scanner.sources").exits)
    if not ok then return end
    local p=nil
    pcall(function()local cap=c.Pawn.CapsuleComponent;local l=cap:K2_GetComponentLocation();p={X=l.X,Y=l.Y,Z=l.Z-cap:GetScaledCapsuleHalfHeight()}end)
    if not p then return end
    local e=tooltip.exit_at(list,p,exit_inside and 50 or 0)
    local id=e and e.id or nil
    if id~=exit_inside then
        exit_inside=id
        if e then
            local text=tooltip.speakable(e.prompt,tooltip.key_name)
            if text then say(text,true);log("exit_prompt spoken="..text) end
        end
    end
end
-- Activity prompts are their own line: the thought line can stay on screen
-- the whole time, so a shared "latest text" would never let the prompt through.
local last_prompt=nil
local function prompt_step()
    if in_menu() then last_prompt=nil;return end
    local ok,text=pcall(tooltip.prompt)
    if not ok then return end
    if text~=last_prompt then
        last_prompt=text
        if text then say(text,true);log("activity_prompt spoken="..text) end
    end
end
-- Ending nightmare guide: hazard and shelter announcements from the game's
-- own danger facts, while the scene is loaded.
local guide=require("nightmare.guide")
local guide_facts=nil
local lighthouse_track=require("nightmare.rewind").tracker()
local pending_guide_restart=false
local lighthouse_closed_told=false
local lighthouse_rewinding=false
local lighthouse_let_go_said=false
local lighthouse_done=false
local lighthouse_matinee=nil
-- The lighthouse falling sequence (not its reversed twin), or nil.
local function lighthouse_obs()
    local m=lighthouse_matinee
    local ok=pcall(function()if not (m and m:IsValid()) then m=nil end end)
    if not ok then m=nil end
    if not m then
        for _,a in ipairs(FindAllOf("MatineeActor") or {}) do
            local n="";pcall(function()n=a:GetFullName()..";"..a.MatineeData:GetFullName()end)
            if n:find("E1_6B",1,true) and n:find("LighthouseFalling",1,true) and not n:find("_REV",1,true) then m=a;break end
        end
        lighthouse_matinee=m
    end
    if not m then return nil end
    local o={}
    pcall(function()o.pos=m.InterpPosition;o.playing=m.bIsPlaying==true;o.reverse=m.bReversePlayback==true;o.rate=m.PlayRate end)
    return o
end
-- Every 50 ms in the ending: being caught by the lighthouse, rewinding past
-- its tree (let go), and walking again from the restart point.
local function lighthouse_fast_step()
    local c=scanner.controller()
    if not c then return end
    local sources=require("scanner.sources")
    if not sources.in_ending(c) then lighthouse_done=false;return end
    if lighthouse_done then return end
    pcall(function()
        local p=c.Pawn:K2_GetActorLocation()
        if (p.X-guide.NEWSPAPER.X)^2+(p.Y-guide.NEWSPAPER.Y)^2<300^2 then lighthouse_done=true;log("guide_lighthouse done") end
    end)
    if lighthouse_done then return end
    local cur={}
    for _,f in ipairs({"LighthouseTree","LighthouseFallingDanger"}) do
        local ok,v=pcall(function()return c:IsFactActive(FName(f))end);cur[f]=ok and v==true
    end
    -- Let go: on the near side, when the tree is standing again (Max is at
    -- the game's restart point); past the hole, once the debris has passed.
    local maxp=nil;pcall(function()maxp=c.Pawn:K2_GetActorLocation()end)
    if lighthouse_rewinding and not lighthouse_let_go_said then
        local o=lighthouse_obs()
        if o and guide.let_go(o.pos,maxp,cur.LighthouseTree) then
            lighthouse_let_go_said=true
            say(l10n.text("guide_let_go"),true);log(string.format("guide_lighthouse let_go pos=%.2f past_hole=%s",o.pos or -1,tostring(guide.past_hole(maxp))))
        end
    end
    -- The lighthouse: its sequence shows being caught (frozen), the rewind
    -- (playing backwards) and its end. Rewound back before the tree, the game
    -- puts Max before the tree; the guide then walks to the newspaper again.
    -- (Pawn:IsRewinding stays false while rewinding - measured - so it is
    -- not used.)
    local obs=lighthouse_obs()
    if obs then
        local ev=lighthouse_track:update(obs)
        if ev then log(string.format("guide_lighthouse event=%s pos=%.2f",ev,obs.pos)) end
        if ev=="rewind_started" then lighthouse_rewinding=true;lighthouse_let_go_said=false elseif ev=="rewind_done" or ev=="caught" then lighthouse_rewinding=false end
        if ev=="caught" then
            autowalk.cancel_quiet()
            say(l10n.text("guide_lighthouse_caught",{key=controls.name("rewind")}),true)
        elseif ev=="rewind_done" and guide.past_hole(maxp) then
            -- Past the hole: walk on now, whatever the tree is doing.
            say(l10n.text("guide_rewound"),true)
            local g=require("scanner.sources").guide_entry(c)
            if g then g.wait_fact=nil;autowalk.start(c,g,true) end
        elseif ev=="rewind_done" then
            if cur.LighthouseTree then
                say(l10n.text("guide_lighthouse_more",{key=controls.name("rewind")}),true)
            else
                say(l10n.text("guide_rewound"),true)
                pending_guide_restart=true
            end
        end
    end
    -- Still on the near side when the floor drops: this fall can't be crossed.
    if obs and obs.reverse~=true then
        local p=nil;pcall(function()p=c.Pawn:K2_GetActorLocation()end)
        if guide.lighthouse_closed(obs.pos,p) and not guide.past_hole(p) then
            if not lighthouse_closed_told then
                lighthouse_closed_told=true
                autowalk.cancel_quiet()
                say(l10n.text("guide_lighthouse_closed",{key=controls.name("rewind")}),true);log("guide_lighthouse closed")
            end
        elseif obs.pos and obs.pos<guide.FLOOR_DROP then lighthouse_closed_told=false end
    end
    if pending_guide_restart and cur.LighthouseTree and control:has_control() and not autowalk.walking() then
        pending_guide_restart=false
        local g=require("scanner.sources").guide_entry(c)
        if g then autowalk.start(c,g,true) end
    end
end
local function guide_step(c)
    if not c then return end
    local sources=require("scanner.sources")
    if not sources.in_ending(c) then guide_facts=nil;return end
    local cur={}
    for _,f in ipairs(guide.FACTS) do
        local ok,v=pcall(function()return c:IsFactActive(FName(f))end)
        cur[f]=ok and v==true
    end
    for _,key in ipairs(guide.changes(guide_facts,cur)) do
        say(l10n.text(key),true);log("guide_hazard "..key)
    end
    guide_facts=cur
end
-- New text messages, announced once when the HUD's notification appears.
-- Consequence butterfly and new-fact icons: queued after current speech, so
-- they never cut off the line or choice that caused them.
local function icons_step()
    if in_menu() then icons.reset();return end
    local ok,lines=pcall(icons.tick)
    if not ok then return end
    for _,t in ipairs(lines) do say(t,false);log("icon spoken="..t) end
end
local function sms_step()
    local ok,text=pcall(sms.tick)
    if ok and text then say(text,true);log("sms_notification trigger="..tostring(sms.trigger).." spoken="..text) end
end
local function tooltip_step()
    if in_menu() then last_tooltip=nil;return end
    local ok,text=pcall(tooltip.current)
    if not ok then return end
    if text~=last_tooltip then
        last_tooltip=text
        -- Queued, not interrupting: a new thought often appears at the same
        -- moment as a choice list, and cut it off (28 Oct, diner).
        if text then say(text,false);log("tooltip source="..tostring(tooltip.source).." spoken="..text) end
    end
end
-- Object viewer: each page read when it is shown (Ctrl+Home repeats).
local last_page=nil
local function viewer_step()
    local ok,page=pcall(viewer.current)
    if not ok or not page then last_page=nil;return end
    if page.key~=last_page then
        last_page=page.key
        local text=viewer.describe(page.text,page.index,page.count)
        say(text,true)
        log("viewer page="..page.index.."/"..page.count.." spoken="..text)
    end
end
-- Journal: a new tab or page is announced with its first item; Up/Down
-- (D-pad up/down) step through items one at a time.
local function journal_step()
    local sok,sp=pcall(choice_stats.page)
    stats_open=sok and sp~=nil
    if stats_open then
        local text=stats_cursor:update(sp)
        if text then say(text,true);log("choice_stats spoken="..text) end
        journal_open=true
        return
    end
    stats_cursor:update(nil)
    local ok,page=pcall(journal.page)
    if not ok then return end
    journal_open=page~=nil
    -- The contact remembered from the list is only valid while the journal
    -- stays open; a thread the game opens itself must never inherit it.
    if not journal_open then journal.last_contact=nil end
    local text=journal_cursor:update(page)
    if text then say(text,true);log("journal "..tostring(page and page.kind).." spoken="..text) end
end
journal_move=function(direction)
    if not journal_open then return false end
    if stats_open then
        local text=stats_cursor:move(direction)
        if text then say(text,true) end
        return true
    end
    local text=journal_cursor:move(direction)
    if text then say(text,true) end
    return true
end
local menu_errors,settings_tick=0,0
local arrows_done=false
local function menu_step()
        local ok,err=pcall(function()
            settings_tick=settings_tick+1
            -- Arrow keys mirror WASD. Applied once the title screen exists, so the
            -- player's input has been created and can rebuild its key maps.
            if not arrows_done and menu.title_ready() then arrows_done=true;pcall(require("core.arrow_keys").apply,log) end
            tutorial_step()
            choices_step()
            tooltip_step()
            prompt_step()
            sms_step()
            icons_step()
            viewer_step()
            journal_step()
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
        tutorial.trace=true
        require("scanner.sources").trace_gates=true
    end
    if ok and type(req)=="table" and req.expected_saved_directory and req.trace_reader then
        local rp=require("dev.reader_probe");local n=0
        face_probe_tick_reader=function()n=n+1;if n%2==0 then pcall(rp.tick,log) end end
    end
end
face.text=function(key,p)return l10n.text(key,p)end
help.text=function(key,p)return l10n.text(key,p)end
preview.text=function(key)return l10n.text(key)end
tutorial.text=function(key,p)return l10n.text(key,p)end
tutorial.log=log
viewer.text=function(key,p)return l10n.text(key,p)end
viewer.clean=require("core.text").clean
journal.text=function(key,p)return l10n.text(key,p)end
journal.clean=require("core.text").clean
journal.translate=function(key)return require("scanner.sources").translate(key)end
journal.say=function(text)say(text,true)end
choice_stats.text=function(key,p)return l10n.text(key,p)end
choice_stats.clean=require("core.text").clean
choice_stats.log=log
journal.log=log
-- Diary paragraphs in authored order: the game's text for each authored key,
-- translated once per language, maps a shown paragraph back to its key.
do
    local keys=require("hud.diary_keys")
    local map,map_lang=nil,nil
    journal.key_order=function(paragraph)
        local lang=l10n.language()
        if map_lang~=lang then
            map,map_lang={},lang
            local translate=require("scanner.sources").translate
            for _,k in ipairs(keys) do
                local ok,s=pcall(translate,"$GT_Menus_Diary_"..k)
                if ok and type(s)=="string" then map[require("core.text").clean(s)]=journal.sort_key(k) end
            end
        end
        return map[paragraph]
    end
end
sms.text=function(key,p)return l10n.text(key,p)end
icons.text=function(key,p)return l10n.text(key,p)end
shooting.text=function(key,p)return l10n.text(key,p)end
office.log=function(line)log(line)end
office.text=function(key,p)return l10n.text(key,p)end
icons.clean=require("core.text").clean
icons.translate=function(key)return require("scanner.sources").translate(key)end
tooltip.key_name=function(action)if action:lower()=="action_interact" then return controls.name("exit_confirm") end end
-- The widget's own key text on the keyboard (it follows the player's binding);
-- the controller button by name, since the controller shows a picture.
tooltip.prompt_key=function(shown)
    if controls.using_gamepad() or not shown or not shown:find("%S") then return controls.name("stop_activity") end
    return shown
end
choices.text=function(key,p)return l10n.text(key,p)end
choices.log=log
choices.is_major=function()
    local c=scanner.controller();if not c then return nil end
    local ok,v=pcall(function()return c:IsFactActive(FName("MajorChoiceOn"))end)
    if ok and type(v)=="boolean" then return v end
end
choices.say=function(text)say(text,true)end
preview.say=function(text)say(text,true)end
preview.play=function(file)return speech.play and speech.play(speech.audio_dir..file) end
autowalk.log=log
autowalk.moving=function()return speech.moving and speech.moving() or false end
autowalk.in_reach=function(c,e)return require("scanner.face").in_reach(c,e) end
autowalk.text=function(key,p)return l10n.text(key,p)end
autowalk.next_guide=function(c)local ok,g=pcall(require("scanner.sources").guide_entry,c);return ok and g or nil end
autowalk.fact_active=function(c,f)local ok,v=pcall(function()return c:IsFactActive(FName(f))end);return ok and v==true end
autowalk.stalled_guide=function(_,result)
    if result~="stalled" and result~="timeout" then return nil end
    if guide_facts and guide_facts.LighthouseFallingDanger then return "",nil end
    local key=guide_facts and guide.stall_message(guide_facts)
    if key then log("guide_caught result="..result);return key,{key=controls.name("rewind")} end
end
-- Control tracking, autowalk, facing and focus announcements.
local walk_errors=0
local function main_step()
    -- Junkyard shooting: describe where Chloe's shot went, just after she
    -- fires (bottles 1 and 2). Every main step (four times a second): the
    -- moment is read from the shot sequence's own position.
    do
        local c0=scanner.controller()
        if c0 then
            local ok,lines=pcall(shooting.tick,c0)
            if ok then for _,k in ipairs(lines) do local t=l10n.text(k);say(t,true);log("shooting spoken="..t) end end
            -- Which room Max is in: re-read once a second from the objects
            -- around her; announced when it has changed for two readings in a
            -- row (a doorway can flip the vote for a moment).
            room_tick=room_tick+1
            if room_tick%4==0 and playable() then
                local src=require("scanner.sources")
                pcall(src.collect,c0)
                local r=src.room
                if r~=room_last then room_last=r;room_pending=1
                elseif room_pending then
                    room_pending=room_pending+1
                    if room_pending>=2 then
                        room_pending=nil
                        if r~=room_spoken then
                            room_spoken=r
                            local name=rooms.room_name(r)
                            if name and room_announced_once then say(l10n.text("room_changed",{name=name}));log("room spoken="..name) end
                            room_announced_once=true
                        end
                    end
                end
            end
            -- Principal's office (Episode 3): when the door can be unlocked
            -- from the inside.
            local ok2,lines2=pcall(office.tick,c0,os.clock())
            if ok2 then for _,k in ipairs(lines2) do local t=l10n.text(k);say(t,k=="office_door_unlockable");log("office spoken="..t) end
            elseif lines2 then log("office_error="..tostring(lines2)) end
        end
    end
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
            if c and control:has_control() then pcall(autowalk.continue_guide,c) end
            pcall(guide_step,c)
            face.tick()
            -- The focused object's pop-up is announced whenever the game opens
            -- one, even while it holds Max (the alarm at the start of Episode 2:
            -- "Snooze" while she lies in bed, before control returns).
            if c and not in_menu() then actions.tick(c) end
            if c and control:has_control() and not in_menu() then pcall(exit_step) end
            if face_probe_tick then face_probe_tick() end
            if face_probe_tick_reader then face_probe_tick_reader() end
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
sources.text=function(key,p)return l10n.text(key,p)end
sources.language=function()return l10n.language()end
local pad=require("scanner.pad").new()
local pad_read=speech.pad
local pad_errors=0
local function pad_step()
        local ok,err=pcall(function()
            local buttons=pad_read and pad_read() or -1
            if journal_open and buttons>=0 then
                local dir=pad:reader(buttons,os.clock())
                if dir then journal_move(dir) end
            else pad:reader_reset() end
            -- While the journal is open the D-pad reads it; scanner commands
            -- (D-pad down = autowalk) must not fire behind it.
            local active=buttons>=0 and can_scan() and not journal_open
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
        -- The lighthouse rewind cue needs a fresh reading: the rewind runs at
        -- twice speed and the safe moment to let go is short (measured).
        pcall(lighthouse_fast_step)
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
    require("dev.session")(request,{l10n=l10n,controls=controls,speech=speech,say=say,bind_key=bind_key})
end
