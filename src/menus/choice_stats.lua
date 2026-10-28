-- Choice statistics screen (Extras > Choices, and the end of an episode):
-- DiaryChoicesWrapperWidget. Read like the journal: one decision at a time with
-- Up/Down, each with its outcomes, the percentage shown and which one was
-- Max's; the episode, World/Friends and Major/Minor are said only when they
-- change. The game's own keys still change page (Left/Right), stats mode and
-- episode.
--
-- Measured 28 Oct (Extras > Choices, Chrysalis):
-- * each outcome row is a DiaryChoiceStringWidget (TextBlock_Choice,
--   ChoicePercent without the % sign, IsPlayerChoice);
-- * major page: the rows of one decision share a parent VerticalBox_N (the
--   last decision has four outcomes);
-- * minor page: each DiaryChoicesMinorChoiceWidget is one decision and holds
--   its own rows (two each in Episode 1);
-- * the rows refresh in place when the percentages arrive (the first figures
--   shown are replaced a moment later), so the page identity ignores them.
local M={}
M.text=function(key,p)return key end
M.clean=function(s)return s end
M.log=function(_)end
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local function shown(o)local ok,r=pcall(function()return o:IsVisible()end);return ok and r==true end
local function text_of(o)local ok,s=pcall(function()return o:GetText():ToString()end);if ok and type(s)=="string" then return s end end
local function live(class)
    local out={}
    for _,w in ipairs(FindAllOf(class) or {}) do
        local ok,on=pcall(function()return w:IsValid() and w:IsVisible() and (w:IsInViewport() or w:GetParent()~=nil)end)
        if ok and on then out[#out+1]=w end
    end
    return out
end
-- Pure: one outcome as spoken. pct is the shown text (no % sign); blank while
-- the figures load, which is not 0%.
function M.outcome(o)
    local s=M.clean(o.text)
    if o.pct and o.pct:find("%d") then s=s.." "..M.text("stats_percent",{value=o.pct:match("%d+")}) end
    if o.player then s=s.." "..M.text("stats_yours") end
    return s
end
-- Pure: a decision (its outcomes, in screen order) as spoken.
function M.decision(outcomes)
    local parts={}
    for _,o in ipairs(outcomes) do parts[#parts+1]=M.outcome(o) end
    return table.concat(parts," ")
end
-- Pure: rows {text,pct,player,group} -> decisions, keeping first-seen group
-- order and the rows' own order within each group.
function M.group(rows)
    local order,by={},{}
    for _,r in ipairs(rows) do
        if not by[r.group] then by[r.group]={};order[#order+1]=r.group end
        table.insert(by[r.group],r)
    end
    local out={}
    for _,g in ipairs(order) do out[#out+1]=by[g] end
    return out
end
local function row_of(c,group)
    local t=text_of(c.TextBlock_Choice)
    if not (t and t:find("%S")) then return nil end
    local pct=text_of(c.ChoicePercent)
    local player=false;pcall(function()player=c.IsPlayerChoice==true end)
    return {text=t,pct=pct,player=player,group=group}
end
local function field(o,f)local ok,v=pcall(function()return o[f]end);if ok and valid(v) then return v end end
-- A panel's children in order (copied out; each checked before use).
local function children(panel)
    local out={}
    if not panel then return out end
    pcall(function()
        local n=panel:GetChildrenCount()
        for i=0,n-1 do local c=panel:GetChildAt(i);if valid(c) then out[#out+1]=c end end
    end)
    return out
end
local function parent_name(w)
    local n=nil;pcall(function()n=w:GetParent():GetFName():ToString()end)
    return n
end
-- The screen as {episode, mode, major, decisions} or nil when not shown.
function M.page()
    local wrap=live("DiaryChoicesWrapperWidget_C")[1]
    if not wrap then return nil end
    local major=true;pcall(function()major=wrap.IsMajor~=false end)
    -- Which statistics are shown: IsFriendFacts, the flag the screen itself
    -- branches on (DisplayFriendChoices / DisplayWorldChoices). IsGlobal does
    -- not change when Friends is chosen (28 Oct: still "World" after toggling).
    local world=true;pcall(function()world=wrap.IsFriendFacts~=true end)
    local rows={}
    if major then
        for _,c in ipairs(live("DiaryChoiceStringWidget_C")) do
            local par=parent_name(c)
            if par and par:find("^VerticalBox_%d+$") then
                local r=row_of(c,par)
                if r then rows[#rows+1]=r end
            end
        end
    else
        -- Each decision's rows are the children of its VerticalBox_Choices;
        -- the decisions are the children of the page's columns, which are the
        -- children of HorizontalBox_ContentWrapper, left column first. (Only
        -- the first column is a named field on the page: reading the second
        -- by name lost half the decisions, 28 Oct.)
        local page=live("DiaryChoicesMinorPageWidget_C")[1]
        if page then
            for ci,colw in ipairs(children(field(page,"HorizontalBox_ContentWrapper"))) do
                local col="column"..ci
                for _,m in ipairs(children(colw)) do
                    local id=col..":"..tostring(m)
                    pcall(function()id=m:GetFName():ToString()end)
                    for _,c in ipairs(children(field(m,"VerticalBox_Choices"))) do
                        if shown(c) then
                            local r=row_of(c,id)
                            if r then rows[#rows+1]=r end
                        end
                    end
                end
            end
        end
    end
    local decisions=M.group(rows)
    if major then
        table.sort(decisions,function(a,b)return tonumber(a[1].group:match("%d+"))<tonumber(b[1].group:match("%d+"))end)
    end
    local episode=text_of(wrap.TextBlock_Episode)
    return {episode=episode and M.clean(episode),world=world,major=major,decisions=decisions}
end
-- Switches between World and Friends stats with the screen's own function,
-- the one the controller's Y button calls (Action_Face_Top -> Swap Stats
-- Pressed). The game binds no keyboard key to it. Returns true if called.
function M.swap()
    local wrap=live("DiaryChoicesWrapperWidget_C")[1]
    if not wrap then return false end
    local ok,err=pcall(function()wrap["Swap Stats Pressed"](wrap)end)
    if ok then M.swapped=true end
    if not ok then M.log("choice_stats swap_error="..tostring(err)) end
    return ok
end
-- Reader state: index into decisions; context said once per change.
local Cursor={}
Cursor.__index=Cursor
function M.cursor()return setmetatable({ctx=nil,shape=nil,index=1,page=nil},Cursor)end
local function context(p)return tostring(p.episode).."|"..tostring(p.world).."|"..tostring(p.major) end
local function shape(p)
    local t={}
    for _,d in ipairs(p.decisions) do t[#t+1]=d[1].text end
    return table.concat(t,"|")
end
-- Pure: the decision at i, with its position last.
function M.describe(p,i)
    if #p.decisions==0 then return M.text("stats_loading") end
    return M.text("stats_item",{text=M.decision(p.decisions[i]),index=i,count=#p.decisions})
end
function M.describe_context(p)
    local parts={}
    if p.episode then parts[#parts+1]=p.episode end
    parts[#parts+1]=M.text(p.major and "stats_major" or "stats_minor")
    parts[#parts+1]=M.text(p.world and "stats_world" or "stats_friends")
    return table.concat(parts,", ")
end
-- Returns text to speak when the screen changes, else nil.
function Cursor:update(p)
    if not p then self.ctx,self.shape,self.page=nil,nil,nil;return nil end
    local ctx,sh=context(p),shape(p)
    local was=self.page
    self.page=p
    if ctx==self.ctx and sh==self.shape then return nil end
    local new_ctx=ctx~=self.ctx
    self.ctx,self.shape=ctx,sh
    if not new_ctx and was and #was.decisions>0 then
        -- Same screen, rows re-laid out: keep the place, say nothing.
        if self.index>#p.decisions then self.index=math.max(1,#p.decisions) end
        return nil
    end
    self.index=1
    -- The rows arrived after the context was said: just the first decision.
    if not new_ctx and #p.decisions>0 then return M.describe(p,1) end
    if #p.decisions==0 then return M.describe_context(p) end
    return M.describe_context(p).." "..M.describe(p,1)
end
function Cursor:move(direction)
    local p=self.page
    if not p or #p.decisions==0 then return M.text("stats_loading") end
    local wanted=self.index+direction
    if wanted<1 then return M.text("journal_first") end
    if wanted>#p.decisions then return M.text("journal_last") end
    self.index=wanted
    return M.describe(p,wanted)
end
function Cursor:current()
    if not self.page then return nil end
    return M.describe_context(self.page).." "..M.describe(self.page,self.index)
end
return M
