-- Dialogue choices, redesigned 28 Oct.
--
-- The old reader polled the dialogue view's four answer buttons several times
-- a second and read their fields. The game replaces those widgets between
-- conversations, and a poll landing in that moment crashed the loader (four
-- times, 26-28 Oct, all in FFieldClassVariant::GetFName while reading a
-- button); it also missed answers ("silent choices").
--
-- Now the buttons are read only inside a hook on the view's own Tick
-- (BP_LiSDialogWidget_View), at most four times a second: the game is running
-- the view's code then, so the view and its buttons are alive (proven 29 Oct:
-- Jefferson's question read and answered with key 1 in a test copy, then many
-- conversations in play). Between reads the mod holds only Lua strings and
-- numbers. Script hooks need HookProcessInternal,
-- HookProcessLocalScriptFunction and HookUObjectProcessEvent on in the
-- loader's UE4SS-settings.ini.
--
-- The list is spoken once the updates have settled (no new answer for
-- SETTLE seconds); an unchanged refill is silent. It is cleared when an
-- answer is chosen by any route (the view's ChooseSentense), when the view is
-- destroyed, or when no dialogue view is on screen.
local M={}
M.text=function(key,p)return key end
M.log=function(_)end
M.say=function(_)end
M.SETTLE=0.15
-- Reads of the view's buttons per second, done on its own Tick.
M.READ_RATE=4
M.next_read=0
-- Face button for each slot, as the view's face handlers map it (each
-- branches on IsMajorChoice; 07 is jump-if-NOT):
--   minor: Top slot 1, Left slot 2, Right slot 3, Bottom slot 4
--   major: Left slot 1, Right slot 2, Top slot 3, Bottom slot 4
-- Minor confirmed in play (slot 2 X, slot 3 B); major from the code.
M.SLOT_BUTTONS={minor={"Y","X","B","A"},major={"X","B","Y","A"}}
function M.keys(options,gamepad,major)
    local map=M.SLOT_BUTTONS[major and "major" or "minor"]
    for i,o in ipairs(options) do o.key=(gamepad and map[o.slot or 0]) or tostring(i) end
    return options
end
-- Spoken list. options: {text=,key=} in order. Pure.
function M.announce_text(options,major)
    local parts={}
    for _,o in ipairs(options) do parts[#parts+1]=M.text("choice_option",{key=o.key,text=o.text}) end
    local list=table.concat(parts,", ")
    local s=M.text(major and "choice_major" or "choice_list",{options=list})
    -- End with a full stop unless the last answer already ends a sentence.
    if not s:find("[%.!%?]$") and not s:find("\226\128\166$") then s=s.."." end
    return s
end
-- State: answers by slot (1-4), plain values only.
local answers,major,changed_at,spoken={},false,nil,nil
M.clock=function()return os.clock() end
-- Pure: record one update. Blank text hides that slot. Returns true if the
-- list changed.
function M.update(slot,text,is_major)
    if type(slot)~="number" or slot<0 or slot>3 then return false end
    local s=slot+1
    if type(text)=="string" then text=text:gsub("^%s+",""):gsub("%s+$","") end
    if text=="" then text=nil end
    if answers[s]==text and major==(is_major==true) then return false end
    answers[s]=text;major=is_major==true;changed_at=M.clock()
    return true
end
local stale=nil -- the answers just chosen, still on the buttons for a moment
local function key_of(list)
    local t={}
    for s=1,4 do t[s]=list[s] or "" end
    return table.concat(t,"\31")
end
function M.clear(why)
    if next(answers) then M.log("choice_cleared why="..tostring(why)) end
    if why=="chosen" or why=="chosen_event" then
        if next(answers) then stale=key_of(answers) end
    else stale=nil end
    answers,changed_at,spoken={},nil,nil
end
-- Pure: the whole screen at once (texts by slot 1-4, nil/"" = hidden), as
-- the Tick read sees it. The list just chosen is ignored until the buttons
-- show something else; an empty screen ends that. Returns slots updated.
function M.set_all(texts,is_major)
    local clean={}
    for s=1,4 do
        local x=texts[s]
        if type(x)=="string" then x=x:gsub("^%s+",""):gsub("%s+$","") end
        if x=="" then x=nil end
        clean[s]=x
    end
    local k=key_of(clean)
    if k==key_of({}) then stale=nil end
    if stale and k==stale then return 0 end
    stale=nil
    local n=0
    for s=1,4 do if M.update(s-1,clean[s] or "",is_major) then n=n+1 end end
    return n
end
-- Current answers in slot order: {slot=,text=} (slot 1-4), or nil.
function M.options()
    local out={}
    for s=1,4 do if answers[s] then out[#out+1]={slot=s,text=answers[s]} end end
    if #out==0 then return nil end
    return out,major
end
-- Whether to call the list a major choice. The view's IsMajorChoice only
-- selects its button layout (it is true for the jukebox tune, Chloe's aiming
-- and the railtracks wires); the game's real major choices - the ones with the
-- sound loop - set the story fact MajorChoiceOn while they are up (confirmed
-- 29 Oct: Frank's gun choice true, the conversation after it false). Set by
-- main.lua; falls back to the layout flag when the fact cannot be read.
M.is_major=nil
local function label_major(layout)
    if M.is_major then
        local ok,v=pcall(M.is_major)
        if ok and type(v)=="boolean" then return v end
    end
    return layout
end
-- Returns the text to speak when a settled list is new, else nil.
function M.due(gamepad)
    if not changed_at or M.clock()-changed_at<M.SETTLE then return nil end
    local opts,maj=M.options()
    if not opts then return nil end
    M.keys(opts,gamepad,maj)
    local text=M.announce_text(opts,label_major(maj))
    if text==spoken then return nil end
    spoken=text
    return text,opts
end
-- The answer list for rereading (Home): always the full current list.
function M.current(gamepad)
    local opts,maj=M.options()
    if not opts then return nil end
    M.keys(opts,gamepad,maj)
    return M.announce_text(opts,label_major(maj))
end
function M.read()return M.options() end
-- Hooks (game side). They run on the game thread inside the view's own
-- event (the view is alive then) and copy out plain values only.
local VIEW="/Game/Packages/Widgets/BP_LiSDialogWidget_View.BP_LiSDialogWidget_View_C"
local FN=VIEW..":UpdateTextImplementable"
local hooked=nil -- address of the function object hooked
local function unwrap(p)local ok,v=pcall(function()return p:get()end);if ok then return v end;return p end
local function function_address()
    local a=nil
    pcall(function()local f=StaticFindObject(FN);if f and f:IsValid() then a=f:GetAddress() end end)
    return a
end
-- Called regularly: hooks the view's events once its class is loaded, and
-- again if the game loads a new copy of it.
function M.install()
    if not RegisterHook then return false end
    local a=function_address()
    if not a or a==hooked then return hooked~=nil end
    local ok,err=pcall(function()
        -- UpdateTextImplementable is NOT hooked: it is redundant (the Tick read
        -- below supplies the same answers) and the first time it ever fired -
        -- the railtracks wire puzzle, 29 Oct - the game crashed right after it,
        -- with the hook calling IsMajorChoice inside the game's own event.
        -- A choice made by any route (controller, mouse, the mod's keys) runs
        -- the view's ChooseSentense; the next list then starts empty.
        RegisterHook(VIEW..":ChooseSentense",function()M.clear("chosen_event") end)
        RegisterHook(VIEW..":Destruct",function()M.clear("destruct") end)
        -- Main read: on the view's own Tick (the game is running the view's
        -- code, so the view and its buttons are alive), at most READ_RATE
        -- times a second. The answers already on screen when the hooks are
        -- first installed are caught this way too (28 Oct: the class only
        -- loads with the first conversation, after its answers were filled).
        RegisterHook(VIEW..":Tick",function(self)
            local now=M.clock()
            if now<M.next_read then return end
            M.next_read=now+1/M.READ_RATE
            local v=unwrap(self)
            local maj=false;pcall(function()maj=v:IsMajorChoice()==true end)
            local texts={}
            pcall(function()
                v.DialogButtons_Array:ForEach(function(i,e)
                    if i>4 then return end
                    local b=e:get()
                    local on=false;pcall(function()on=b:IsVisible()end)
                    if on then pcall(function()texts[i]=b.DialogText:GetText():ToString()end) end
                end)
            end)
            local n=M.set_all(texts,maj)
            if n>0 then M.log("choice_tick_read updated="..n) end
        end)
    end)
    if ok then hooked=a;M.next_read=0;M.log(string.format("choice_hooks installed fn=%x",a)) else M.log("choice_hooks error="..tostring(err)) end
    return ok
end
function M.hooked()return hooked~=nil end
-- The dialogue view on screen, found fresh each time (never kept).
local function view_up()
    local found=nil
    pcall(function()
        for _,w in ipairs(FindAllOf("BP_LiSDialogWidget_View_C") or {}) do
            local ok,on=pcall(function()return w:IsValid() and w:IsInViewport() and w:IsVisible()end)
            if ok and on then found=w;break end
        end
    end)
    return found
end
-- Only while answers are held: clear them once the view has gone.
function M.tick()
    if next(answers) and not view_up() then M.clear("closed") end
end
-- Chooses the n-th announced answer: the slot's button, pressed through the
-- view found at this moment (the game's own face-button path).
function M.choose(n)
    local opts=M.options()
    if not opts then M.say(M.text("choice_none"));return false end
    local o=opts[n]
    if not o then M.say(M.text("choice_no_option",{index=n}));return false end
    local v=view_up()
    local ok,err=false,"view gone"
    if v then
        pcall(function()
            v.DialogButtons_Array:ForEach(function(i,e)
                if i==o.slot and not ok then
                    local b=e:get()
                    ok,err=pcall(function()b:ClickButton()end)
                end
            end)
        end)
    end
    M.log("choice_chosen n="..n.." slot="..o.slot.." ok="..tostring(ok)..(ok and "" or " err="..tostring(err)))
    if ok then M.clear("chosen") end
    return ok
end
return M
