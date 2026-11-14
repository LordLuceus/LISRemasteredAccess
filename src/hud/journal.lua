-- Journal reader (DiaryWrapper_Widget). One item at a time, like the original:
-- Up/Down (D-pad up/down) move between items, each spoken with "N of M" last;
-- a new tab or page announces its name, the first item and, for the diary, the
-- page number. Captured in Chloe's house:
-- * diary: DiaryBook_Widget (TextBlock_Objective, TextBlock_PNum "Page  1/12")
--   with one DiaryElement_Widget per paragraph (Text_Data);
-- * characters: DiaryCharacterPortrait_Widget names (TextBlock_NAME);
-- * messages: DiaryMessageEmitter_Widget contacts (TextBlock_Data).
-- Widget enumeration is NOT reading order (it changed between two visits).
-- Read positioned paragraphs using the native centred page layout. Text keys
-- remain a best-effort fallback only when usable positions are unavailable;
-- neither key names nor the authored element array always follow reading order.
local M={}
local photo_reader=require('hud.journal_photos')
-- Designer placeholder text shipped in the journal widgets, never real content.
M.PLACEHOLDERS={["I should go back upstairs and repair my camera"]=true,["Text Block"]=true}
M.text=function(key,p)return key end
M.clean=function(s)return s end
-- Paragraph text -> legacy sortable text key (E0_Page00_C...). Built per
-- language from the game's translator; NOT a guaranteed reading-order index.
M.key_order=function(_)return nil end
-- Pure: a sortable key from "E1_Page05_C" (episode, page, letter).
function M.sort_key(key)
    local e,p,l=key:match("^E(%d+)_[Pp]age(%d+)_(%a+)$")
    if e then return string.format("D%02d%04d%s",tonumber(e),tonumber(p),l) end
    local who,part=key:match("^Chara_([%w]+)_(%a+)$")
    if who then return "C"..who.."_"..part end
    return nil
end
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
-- Paragraph widgets with their position on the page (their canvas slot, laid
-- out from the page data's PositionX/Y).
local function paragraph_items()
    local out={}
    for _,w in ipairs(live("DiaryElement_Widget_C")) do
        local t=nil;pcall(function()t=w.Text_Data end)
        if valid(t) and shown(t) then
            local s=text_of(t)
            if s and s:find("%S") then
                local x,y=nil,nil
                pcall(function()
                    local slot=w.Slot
                    if valid(slot) and slot:IsA("/Script/UMG.CanvasPanelSlot") then
                        local p=slot:GetPosition();x,y=p.X,p.Y
                    end
                end)
                out[#out+1]={text=M.clean(s),x=x,y=y}
            end
        end
    end
    return out
end
-- Pure: left page top to bottom, then right. In Steam build 11330282,
-- DiaryParentalObject.SetElementSlot (used by diary AND character profiles)
-- sets anchors to (.5,.5), position to authored PositionX/Y * 1.5 and text
-- alignment to (0,0). Thus x=0 is the native gutter, not a fitted threshold.
-- Do not infer it from visible text bounds: an indented left-page paragraph
-- (E4_Page05_C) can lie beyond their midpoint. Story visibility and one-sided
-- spreads must not change the boundary. Without usable positions retain the
-- existing best-effort key fallback, then unrecognized text as given.
function M.reading_order(items,key_of)
    local have=true
    for _,it in ipairs(items) do
        if type(it.x)~="number" or type(it.y)~="number" then have=false;break end
    end
    if have and #items>1 then
        local all_same=true
        for _,it in ipairs(items) do if it.x~=items[1].x or it.y~=items[1].y then all_same=false end end
        if not all_same then
            local list={}
            for i,it in ipairs(items) do list[i]={it=it,i=i,col=(it.x>=0) and 1 or 0} end
            table.sort(list,function(a,b)
                if a.col~=b.col then return a.col<b.col end
                if a.it.y~=b.it.y then return a.it.y<b.it.y end
                if a.it.x~=b.it.x then return a.it.x<b.it.x end
                return a.i<b.i end)
            local out={};for _,e in ipairs(list) do out[#out+1]=e.it.text end
            return out,"position"
        end
    end
    local texts={};for _,it in ipairs(items) do texts[#texts+1]=it.text end
    return M.order(texts,key_of),"key"
end
local function field_texts(class,field)
    local out={}
    for _,w in ipairs(live(class)) do
        local t=nil;pcall(function()t=w[field]end)
        if valid(t) and shown(t) then
            local s=text_of(t)
            if s and s:find("%S") then out[#out+1]=M.clean(s) end
        end
    end
    return out
end
-- The game's highlighted entry on a list screen: ButtonInFocusIndex into
-- AvailableButtonsSorted (seen on the days, characters, photos, places and
-- messages screens). The button reference is copied out of the array walk and
-- checked before any field is read through it.
local function highlighted(screen)
    local idx=nil;pcall(function()idx=screen.ButtonInFocusIndex end)
    if type(idx)~="number" then return nil end
    local b=nil
    pcall(function()
        screen.AvailableButtonsSorted:ForEach(function(i,v)if i==idx+1 then b=v:get() end end)
    end)
    if not valid(b) then return nil end
    return b
end
local function field_string(o,f)
    local s=nil
    pcall(function()local v=o[f];if type(v)=="userdata" then s=v:ToString() elseif type(v)=="string" then s=v end end)
    if s and s~="" and s~="None" then return s end
end
M.translate=function(key)return key end
M.language=function()return 'en' end
M.say=function(_)end
M.log=function(_)end
-- Pure: one message as spoken, like the original: "Sender, time: text".
function M.message_text(sender,meta,body)
    local s=(sender and sender~="" and not M.PLACEHOLDERS[sender]) and sender or M.text("journal_unknown_sender")
    if meta and meta~="" then s=s..", "..meta end
    return s..": "..(body or "")
end
-- The open thread, or nil when the contact list is showing.
function M.thread_items(wrapper)
    local box=nil;pcall(function()box=wrapper.VerticalBox_Content end)
    if not (valid(box) and shown(box)) then return nil end
    local count=0;pcall(function()count=box:GetChildrenCount()end)
    if type(count)~="number" or count<1 then return nil end
    -- The sender is the contact highlighted in the list when the thread was
    -- opened (the screen's own DiaryMessageEmitter_Widget keeps its designer
    -- text, "Text Block"). Remembered from the contact list (M.last_contact).
    -- The other party: the thread's sender portrait texture is named after the
    -- contact (WarrenThumb, DadThumb...), which also works when the game opens
    -- a thread itself (a new text). The list highlight is only the fallback.
    local contact=nil
    pcall(function()
        local tex=wrapper.SenderPortrait
        if valid(tex) then
            local n=tex:GetFName():ToString():match("^(%a+)Thumb$")
            if n then
                local s=M.translate("$GT_Menus_Journal_"..n)
                contact=(type(s)=="string" and not s:find("^%$")) and s or n
            end
        end
    end)
    contact=contact or M.last_contact
    local items,ids={},{}
    for i=0,count-1 do
        local w=nil;pcall(function()w=box:GetChildAt(i)end)
        local is_sms=false;pcall(function()is_sms=valid(w) and w:IsA("/Game/Packages/Widgets/DiaryWidgets/DiaryMessageSMS_Widget.DiaryMessageSMS_Widget_C")end)
        if is_sms and shown(w) then
            local body,meta,mine=nil,nil,false
            pcall(function()body=text_of(w.TextBlock_Body)end)
            pcall(function()meta=text_of(w.TextBlock_Meta)end)
            pcall(function()mine=w.IsMax==true end)
            -- A body of only dots is the "typing" bubble, not a delivered
            -- message; it is announced when its real text arrives.
            if body and body:find("%S") and not body:find("^[%s%.\226\128\166]+$") then
                local sender=mine and M.text("journal_max") or contact
                items[#items+1]=M.message_text(sender,meta and M.clean(meta),M.clean(body))
                local addr=nil;pcall(function()addr=w:GetAddress()end)
                ids[#ids+1]=tostring(addr)
            end
        end
    end
    if #items==0 then return nil end
    return {kind="thread",title=contact or M.text("journal_messages"),items=items,ids=ids,ref=contact}
end
-- Pure: order paragraphs by authored key where known, keeping the rest after
-- them in their given order.
function M.order(paragraphs,key_of)
    local keyed,rest={},{}
    for i,p in ipairs(paragraphs) do
        local k=key_of(p)
        if k then keyed[#keyed+1]={k=k,i=i,p=p} else rest[#rest+1]=p end
    end
    table.sort(keyed,function(a,b)if a.k~=b.k then return a.k<b.k end return a.i<b.i end)
    local out={}
    for _,e in ipairs(keyed) do out[#out+1]=e.p end
    for _,p in ipairs(rest) do out[#out+1]=p end
    return out
end
-- Pure: names in a stable order (the game's widget order changes).
function M.sorted(list)
    local out={}
    for _,s in ipairs(list) do out[#out+1]=s end
    table.sort(out)
    return out
end
-- The page being shown: {kind,title,items,page} or nil when the journal is closed.
function M.page()
    local wrapper=live("DiaryWrapper_Widget_C")[1]
    if not wrapper then return nil end
    local ok,on=pcall(function()return wrapper:IsInViewport()end)
    if not (ok and on) then return nil end
    -- Order matters: screens opened on top of a list or the book come first.
    -- A character's profile (its paragraphs, over the character list).
    local profile=live("DiaryCharacterPage_Widget_C")[1]
    if profile then
        local who=field_string(profile,"CharacterName")
        local paras,how=M.reading_order(paragraph_items(),M.key_order)
        return {kind="profile",title=who or M.text("journal_characters"),items=paras,ref=who,order=how}
    end
    -- The days menu (opened by backing out of the diary, over the book).
    local days=live("DiaryBookDay_Widget_C")[1]
    if days then
        local b=highlighted(days)
        local title=b and field_string(b,"DayTitle")
        if title and title:find("^%$") then title=M.translate(title) end
        return {kind="days",title=M.text("journal_days"),items={title and M.clean(title) or "?"},list=true}
    end
    local book=live("DiaryBook_Widget_C")[1]
    if book then
        local items={}
        local paras,how=M.reading_order(paragraph_items(),M.key_order)
        for _,p in ipairs(paras) do items[#items+1]=p end
        -- The objective box is read only when the game shows it (ShowObjective
        -- and its panel visible). Otherwise TextBlock_Objective still holds the
        -- widget's designer placeholder.
        local objective=nil
        pcall(function()
            local panel_ok=book.ShowObjective==true and shown(book.Objectives)
            if panel_ok and shown(book.TextBlock_Objective) then objective=text_of(book.TextBlock_Objective) end
        end)
        if objective and objective:find("%S") and not M.PLACEHOLDERS[objective] then
            local title=text_of(book.TextBlock_ObjectiveTitle) or ""
            items[#items+1]=M.clean((title~="" and (title..": ") or "")..objective)
        end
        local pnum=nil;pcall(function()pnum=text_of(book.TextBlock_PNum)end)
        local page=nil
        if pnum then local a,b=pnum:match("(%d+)%s*/%s*(%d+)");if a then page={tonumber(a),tonumber(b)} end end
        return {kind="diary",title=M.text("journal_diary"),items=items,page=page,order=how}
    end
    -- List screens: the game's highlighted entry, as the game moves it.
    local chars=live("DiaryCharacterOverall_Widget_C")[1]
    if chars then
        local b=highlighted(chars)
        local name=b and (field_string(b,"Name") or field_string(b,"CharacterName"))
        return {kind="characters",title=M.text("journal_characters"),items={name or "?"},list=true}
    end
    local msgs=live("DiaryMessageWrapper_Widget_C")[1]
    -- An open thread: one DiaryMessageSMS_Widget per message, added to the
    -- thread's vertical box in conversation order (the box's own child order).
    if msgs then
        local thread=M.thread_items(msgs)
        if thread then return thread end
    end
    if msgs then
        local b=highlighted(msgs)
        local name=nil
        if b then
            local t=nil;pcall(function()t=b.TextBlock_Data end)
            if valid(t) then name=text_of(t) end
            name=name or field_string(b,"Title") or field_string(b,"Name")
            if name and not M.PLACEHOLDERS[name] then M.last_contact=M.clean(name) end
            local unread=nil;pcall(function()unread=b.Unread_SMS end)
            if name and type(unread)=="number" and unread>0 then name=M.text("journal_unread",{name=M.clean(name),count=unread}) end
        end
        return {kind="messages",title=M.text("journal_messages"),items={name and M.clean(name) or "?"},list=true}
    end
    local photos=live("DiaryPhotos_Widget_C")[1]
    if photos then
        photo_reader.text=M.text
        photo_reader.language=M.language
        photo_reader.log=M.log
        local detail=photo_reader.page(photos)
        if detail then return detail end
        local b=highlighted(photos)
        local name=b and field_string(b,"LocalizedEpisodeTitle")
        return {kind="photos",title=M.text("journal_photos"),items=name and {M.clean(name)} or {},list=name~=nil}
    end
    if live("DiaryPlaces_Widget_C")[1] then return {kind="places",title=M.text("journal_places"),items={}} end
    return {kind="unknown",title=M.text("journal_title"),items={}}
end
-- Pure: one item, with its position last.
function M.describe_item(page,index)
    if #page.items==0 then return M.text("journal_no_items") end
    return M.text("journal_item",{text=page.items[index],index=index,count=#page.items})
end
-- Pure: entering a page. Diary page numbers only when the page changes.
function M.describe_entry(page,index,with_page)
    local parts={page.title}
    if with_page and page.page then parts[#parts+1]=M.text("journal_page",{index=page.page[1],count=page.page[2]}) end
    if page.kind=="thread" then index=#page.items end
    parts[#parts+1]=M.describe_item(page,index)
    return table.concat(parts," ")
end
-- Reader state across ticks.
local Cursor={}
Cursor.__index=Cursor
function M.cursor()return setmetatable({id=nil,index=1,page=nil},Cursor)end
local function identity(page)
    -- Threads grow at the end, so their length is part of what counts as a
    -- change; other pages are identified by their first item, so paragraphs
    -- that appear over a few ticks do not re-announce the page.
    local n=page.kind=="thread" and #page.items or ""
    return page.kind..":"..tostring(page.ref)..":"..tostring(page.page and page.page[1])..":"..n..":"..tostring(page.items[1])
end
-- Returns text to speak when the page changed, else nil.
function Cursor:update(page)
    if not page then self.id=nil;return nil end
    local id=identity(page)
    if id==self.id then self.page=page;return nil end
    if page.kind=="thread" and self.page and self.page.kind=="thread" and self.page.ref==page.ref then
        -- Same thread, more messages: announce only the new ones, once.
        local known={};for _,id in ipairs(self.page.ids or {}) do known[id]=true end
        local fresh={}
        for i,id in ipairs(page.ids or {}) do if not known[id] then fresh[#fresh+1]=page.items[i] end end
        local at_end=self.index>=#self.page.items
        self.id,self.page=id,page
        if #fresh==0 then return nil end
        if at_end then self.index=#page.items end
        return M.text("journal_new_message").." "..table.concat(fresh," ")
    end
    local new_kind=not self.page or self.page.kind~=page.kind or self.page.ref~=page.ref
    local page_changed=page.page and (not self.page or not self.page.page or self.page.page[1]~=page.page[1])
    self.id,self.page,self.index=id,page,1
    if page.kind=="thread" then self.index=#page.items end -- latest message first
    if page.list and not new_kind then return M.describe_item(page,1) end
    return M.describe_entry(page,1,new_kind or page_changed)
end
function Cursor:move(direction)
    local page=self.page
    -- On list screens the game moves its own highlight; it is announced as it changes.
    if page and page.list then return nil end
    if not page or #page.items==0 then return M.text("journal_no_items") end
    local wanted=self.index+direction
    if wanted<1 then return M.text("journal_first") end
    if wanted>#page.items then return M.text("journal_last") end
    self.index=wanted
    return M.describe_item(page,wanted)
end
function Cursor:current()
    if not self.page then return nil end
    return M.describe_item(self.page,self.index)
end
-- Re-read the live page before a photo command: native left/right replaces the
-- detail owner, and a key can arrive before the ordinary journal polling pass.
-- Preserve other journal readers' established behavior.
function M.photo_context(cursor)
    local page=cursor and cursor.page
    return type(page)=='table' and (page.kind=='photos' or page.kind=='photo_detail')
end
function M.photo_read(cursor,direction)
    if not M.photo_context(cursor) then return nil,false end
    local page=M.page()
    local changed=cursor:update(page)
    if changed then return changed,true end
    if not page then return nil,true end
    if direction then return cursor:move(direction),true end
    return cursor:current(),true
end
return M
