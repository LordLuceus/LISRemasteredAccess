-- Native Steam build 11330282: E4_Journal_C, Pages[PageNumber=5].
-- Only IDs and layout facts, not localized game prose. The user's page57/61
-- screenshot independently establishes A,B,B2,C,D,E (C is REVENGE).
-- DiaryParentalObject.SetElementSlot centres BOTH anchors at (.5,.5) and
-- writes (PositionX*1.5, PositionY*1.5) to the paragraph's CanvasPanelSlot.
package.path='src/?.lua;'..package.path
package.loaded['hud.journal']=nil
local J=require('hud.journal')
local en=require('lang.en')
J.text=function(k,p)return (en[k]:gsub('{(%w+)}',function(n)return tostring(p[n])end))end
local count=0
local function check(ok,label)count=count+1;assert(ok,label)end
local authored={
    {text='E4_Page05_A',x=-490,y=-260},
    {text='E4_Page05_B',x=-600,y=-20},
    {text='E4_Page05_B2',x=-560,y=140},
    {text='E4_Page05_C',x=-260,y=280},
    {text='E4_Page05_D',x=40,y=-290},
    {text='E4_Page05_E',x=20,y=0},
}
local function native_slot(row)
    return {text=row.text,x=row.x*1.5,y=row.y*1.5}
end
local function no_keys()error('Valid native positions must not use localization-key guesses')end
local items={}
for i=#authored,1,-1 do items[#items+1]=native_slot(authored[i])end
local ordered,how=J.reading_order(items,no_keys)
check(table.concat(ordered,',')=='E4_Page05_A,E4_Page05_B,E4_Page05_B2,E4_Page05_C,E4_Page05_D,E4_Page05_E',
    'REVENGE stays fourth on the left page, before both Nathan-room paragraphs')
check(how=='position','Native positioned reader used')

-- Fact gates and partial population change which paragraphs are present, not
-- the book's centre. In particular, all-left pages must not become two columns.
for mask=1,63 do
    local subset,expected={},{}
    for i,row in ipairs(authored) do
        if mask & (1 << (i-1)) ~= 0 then
            table.insert(subset,1,native_slot(row));expected[#expected+1]=row.text
        end
    end
    local out=J.reading_order(subset,function()return nil end)
    check(table.concat(out,',')==table.concat(expected,','),'Stable native order for subset '..mask)
end

-- Independent native array-order counterexample: E4 PageNumber=10 stores
-- C,D,A,B, all gated by Diary_E4_8C_CP01. Visual order is A,B on the left,
-- C,D on the right. Reading the authored array verbatim would still be wrong.
local later={
    {text='E4_Page10_C',x=20,y=-310}, {text='E4_Page10_D',x=20,y=-10},
    {text='E4_Page10_A',x=-540,y=-120}, {text='E4_Page10_B',x=-560,y=160},
}
for i,row in ipairs(later)do later[i]=native_slot(row)end
check(table.concat(J.reading_order(later,no_keys),',')=='E4_Page10_A,E4_Page10_B,E4_Page10_C,E4_Page10_D',
    'Layout, not native array order, determines reading order')

-- Exercise the actual page producer, not only the pure comparator. Objects
-- expose the same CanvasPanelSlot API read by paragraph_items; lookup order
-- is deliberately reversed. No authored strings, story gates or saves read.
local function object()
    return {IsValid=function()return true end,IsVisible=function()return true end,
        IsInViewport=function()return true end}
end
local function text(s)
    local t=object();function t:GetText()return {ToString=function()return s end}end;return t
end
local elements={}
for _,row in ipairs(items) do
    local w=object();w.Text_Data=text(row.text);w.Slot=object()
    function w.Slot:IsA(name)return name=='/Script/UMG.CanvasPanelSlot'end
    function w.Slot:GetPosition()return {X=row.x,Y=row.y}end
    elements[#elements+1]=w
end
local wrapper,book=object(),object()
book.TextBlock_PNum=text('Page 57/61');book.ShowObjective=false
local old_find=FindAllOf
FindAllOf=function(class)
    if class=='DiaryWrapper_Widget_C' then return {wrapper} end
    if class=='DiaryBook_Widget_C' then return {book} end
    if class=='DiaryElement_Widget_C' then return elements end
    return {}
end
J.key_order=no_keys
local page=J.page()
check(page.kind=='diary' and page.page[1]==57 and page.page[2]==61,'Actual diary snapshot')
check(table.concat(page.items,',')==table.concat(ordered,','),'Native slot adapter preserves the correct sequence')
local cursor=J.cursor();cursor:update(page)
for i=2,6 do check(cursor:move(1)==ordered[i],'Cursor reaches paragraph '..i)end
local reversed={};for i=#elements,1,-1 do reversed[#reversed+1]=elements[i]end;elements=reversed
check(cursor:update(J.page())==nil and cursor.index==6,'Enumeration changes do not reset the reader')
FindAllOf=old_find
package.loaded['hud.journal']=nil
print('Journal authored layout: '..count..' checks passed')
return count
