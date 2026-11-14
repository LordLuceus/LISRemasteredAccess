-- First-run/updated-policy dialog, ToS_PP_Widget_C (LiSPPToSWidget).
-- Native Enter/Space/A checks PP, then ToS, then confirms via Ok_on. These
-- controls are deliberately NOT focusable; never synthesize confirmation or
-- use Button_0:IsEnabled() as the acceptance gate. Only explicit document-key
-- requests call the same zero-argument View TOS/View PP events as the buttons.
local M={text=function(k)return k end,log=function(_)end}
local text=require('core.text')
local reported={}
local function valid(o)
    local f=EObjectFlags
    return o and o:IsValid() and not o:HasAnyFlags(f.RF_BeginDestroyed|f.RF_FinishDestroyed|
        (f.RF_ClassDefaultObject or 0)|(f.RF_ArchetypeObject or 0))
end
local function shown(o)
    for _=1,32 do
        if not valid(o) or not o:IsVisible() or o:GetRenderOpacity()<=0 then return false end
        local parent=o:GetParent()
        if not parent or not parent:IsValid() then return true end
        o=parent
    end
    return false
end
local function read(tag,fn)
    local ok,a,b=pcall(fn)
    if ok then return a,b end
    if not reported[tag] then reported[tag]=true;M.log('consent_error field='..tag..' error='..tostring(a))end
end
function M.live()
    return read('live',function()
        for _,w in ipairs(FindAllOf('ToS_PP_Widget_C') or {})do
            if valid(w) and (w:IsInViewport() or valid(w:GetParent())) and shown(w) then return w end
        end
    end)
end
local function field(w,name,optional_hidden)
    local o=w[name]
    if not valid(o) then return nil end
    if optional_hidden and not shown(o) then return '' end
    local raw=o:GetText():ToString()
    if type(raw)~='string' or raw:find('$GT_',1,true) or raw=='Text Block' then return nil end
    return text.clean(raw)
end
local function joined(rows)
    local s
    for _,row in ipairs(rows)do s=text.join(s,row)end
    return s
end
function M.snapshot()
    local w=M.live()
    if not w then return nil end
    return read('snapshot',function()
        local id='consent@'..w:GetAddress()..':'..w:GetFullName()
        local quiet={screen=id,index=0,key='pending',label='',silent=true,consent=true}
        if valid(w.TOSorPP) then
            -- This native branch uses an embedded document viewer. Do not read
            -- the consent controls underneath it or claim its text was read.
            return {screen=id..':document',index=0,label=M.text('consent_document_unreadable'),consent=true},'screen=consent document=embedded'
        end
        local pp,tos,ok=w.PP,w.ToS,w.Ok_on
        if type(pp)~='boolean' or type(tos)~='boolean' or type(ok)~='boolean' then return quiet end
        local privacy,terms,confirm=field(w,'TextBlock_PP'),field(w,'TextBlock_ToS'),field(w,'TextBlock_Download')
        if not privacy or privacy=='' or not terms or terms=='' or not confirm or confirm=='' then return quiet end
        local parts={}
        -- Actual WrapBox_0 child order, including both native link captions.
        for _,name in ipairs({'TextBlock_2','TextButton_ToS','TextBlock_477','TextButton_PP','TextBlock_480','TextBlock_1'})do
            local s=field(w,name,true)
            if s==nil then return quiet end
            if s~='' then parts[#parts+1]=s end
        end
        local heading=text.clean(table.concat(parts,' '))
        local rows={text.join(privacy,M.text(pp and 'consent_checked' or 'consent_unchecked')),
            text.join(terms,M.text(tos and 'consent_checked' or 'consent_unchecked')),
            text.join(confirm,M.text(ok and 'consent_available' or 'consent_unavailable'))}
        local label=joined(rows)
        return {screen=id,index=0,label=label,key=label,context=heading,rows=rows,entry_interrupt=false,reread=text.join(heading,label),consent=true},
            'screen=consent pp='..tostring(pp)..' tos='..tostring(tos)..' ok='..tostring(ok)
    end)
end
function M.help(gamepad)
    local w=M.live()
    if not w then return nil end
    return M.text(gamepad and 'consent_help_pad' or 'consent_help_keys')
end
function M.open_document(slot)
    local w=M.live()
    if not w then return false end
    if slot~=1 and slot~=2 then return true end
    local child=read('document_child',function()return valid(w.TOSorPP)==true end)
    if child==nil then return true,M.text('consent_link_unavailable')end
    if child then return true,M.text('consent_document_open')end
    local ok,err=pcall(function()
        -- 1/X = Terms; 2/Y = Privacy, matching the game's face-button actions.
        -- Do not broadcast pawn input delegates (they have priority branches).
        local fn=slot==1 and 'View TOS' or 'View PP'
        w[fn](w)
    end)
    if not ok then
        M.log('consent_document_error='..tostring(err))
        return true,M.text('consent_link_unavailable')
    end
    return true
end
return M
