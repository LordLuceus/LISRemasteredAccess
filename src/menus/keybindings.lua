-- Read-only adapter for the game's InputKeySelector keyboard editor.
-- Never edits input settings: assignments/conflicts remain the native editor's
-- responsibility. All retained state is scalar; no widgets or chords escape.
local M={text=function(k)return k end,log=function(_)end,active=false,capturing=false}
local State=require('menus.keybind_state')
local presentation=State.new(function(k,p)return M.text(k,p)end)
local clean=require('core.text').clean
local reported={}
local focused_view=nil
local keyboard_hold,pad_hold=false,false
local hook_address=nil
M.CLASS='Settings_Keybinds_Menu_C'
M.FUNCTION='/Game/Packages/Widgets/Settings_Keybinds_Menu.Settings_Keybinds_Menu_C:AttemptAssignNewKeybind'
M.footer_label=function(_)return nil end
local function read(tag,fn)
    local ok,v=pcall(fn)
    if ok then return v end
    if not reported[tag] then reported[tag]=true;M.log('keybind_read_error field='..tag..' error='..tostring(v)) end
end
local function valid(v)
    return v and v:IsValid() and not v:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)
end
local function text_field(view,field)
    return read(field,function()
        local w=view[field]
        if valid(w) then return clean(w:GetText():ToString()) end
    end)
end
function M.live(class)
    for _,w in ipairs(FindAllOf(class or M.CLASS) or {}) do
        local on=read('visible',function()
            if not valid(w) or not w:IsVisible() then return false end
            return w:IsInViewport() or valid(w:GetParent())
        end)
        if on then return w end
    end
end
-- A selection may finish between keyboard polls. Observe the native assignment
-- callback too, so the captured key cannot become F1/help or another shortcut.
function M.install()
    if type(RegisterHook)~='function' then return end
    read('assignment_hook',function()
        local f=StaticFindObject(M.FUNCTION)
        if not valid(f) then return end
        local address=f:GetAddress()
        if address==hook_address then return end
        RegisterHook(M.FUNCTION,function()end,function(context)
            read('assignment_event',function()
                local view=context:get()
                if valid(view) and view.IsRefreshing~=true then keyboard_hold=true;pad_hold=true end
            end)
        end)
        hook_address=address
    end)
end
function M.poll_capture()
    local view=M.live()
    local capturing=M.live('KeybindPopUp_C')~=nil
    if not view then M.closed() end
    M.active=view~=nil or capturing
    if view then
        M.install()
        for _,row in ipairs(State.rows) do
            for _,suffix in ipairs({'','_1'}) do
                if read('capture',function()
                    local s=view[row.field..suffix]
                    return valid(s) and s:GetIsSelectingKey()
                end)==true then capturing=true end
            end
        end
    end
    M.capturing=capturing
    if capturing then keyboard_hold=true;pad_hold=true end
    return capturing
end
function M.block_keyboard(mask)
    M.poll_capture()
    local blocked=M.capturing or keyboard_hold
    if not M.capturing and type(mask)=='number' and (mask&0x3fffffff)==0 then keyboard_hold=false end
    return blocked
end
function M.block_pad(buttons)
    local blocked=M.capturing or pad_hold
    if not M.capturing and buttons==0 then pad_hold=false end
    return blocked
end
function M.closed()
    M.active=false;M.capturing=false;focused_view=nil;presentation:clear()
end
-- A logical row/column route through both slots, independent of Slate's spatial
-- arrow navigation (which skipped cells in the native editor). Keep arrows
-- untouched; use the same SetKeyboardFocus operation verified in game.
function M.move(row_delta,column)
    if M.poll_capture() then return nil end
    local view=M.live()
    if not view then return nil end
    local selectors,current={},nil
    for r,row in ipairs(State.rows) do
        for slot=1,2 do
            local i=(r-1)*2+slot
            selectors[i]=read('move_selector',function()return view[row.field..(slot==2 and '_1' or '')]end)
            local focused=read('move_focus',function()
                local s=selectors[i]
                return valid(s) and (s:HasKeyboardFocus() or s:HasFocusedDescendants())
            end)
            if focused then current=i end
        end
    end
    if not current then current=1;row_delta=0 end
    local row=((current-1)//2+(row_delta or 0))%#State.rows
    local slot=column or ((current-1)%2+1)
    local target=row*2+slot
    local moved=read('move',function()
        local s=selectors[target]
        if not valid(s) then return false end
        s:SetKeyboardFocus()
        return s:HasKeyboardFocus() or s:HasFocusedDescendants()
    end)
    if moved then return M.snapshot(view) end
end
function M.snapshot(view,overlay)
    local id=read('address',function()return tostring(view:GetAddress())end)
    if not id then return nil end
    M.active=true
    local lib=StaticFindObject('/Script/Engine.Default__KismetInputLibrary')
    local entries,focus,capture={},nil,nil
    for _,row in ipairs(State.rows) do
        local label=text_field(view,row.label)
        for slot=1,2 do
            local field=row.field..(slot==2 and '_1' or '')
            local index=#entries+1
            local e={label=label}
            read(field,function()
                local selector=view[field]
                if not valid(selector) then return end
                local key=selector.SelectedKey.Key
                e.key=key.KeyName:ToString()
                if e.key=='None' or e.key=='' then e.display=M.text('keybind_unbound')
                elseif valid(lib) then e.display=clean(lib:Key_GetDisplayName(key):ToString()) end
                if selector:HasKeyboardFocus() or selector:HasFocusedDescendants() then focus=index end
                if selector:GetIsSelectingKey() then capture=index end
            end)
            entries[index]=e
        end
    end
    local footer,footer_label=nil,nil
    for _,item in ipairs({{'ResetChanges','keybind_reset'},{'BackButton','keybind_back'}}) do
        read(item[1],function()
            local button=view[item[1]]
            if valid(button) and (button:HasKeyboardFocus() or button:HasFocusedDescendants()) then
                footer=item[1];footer_label=M.footer_label(button) or M.text(item[2])
            end
        end)
    end
    -- This screen opens without keyboard focus. One explicit initial focus
    -- restores the game's own arrow navigation; never fight later native focus.
    if focused_view~=id and not overlay and not capture then
        focused_view=id
        if not focus and not footer then
            read('initial_focus',function()
                view.ForwardKey:SetKeyboardFocus()
                if view.ForwardKey:HasKeyboardFocus() or view.ForwardKey:HasFocusedDescendants() then focus=1 end
            end)
        end
    end
    M.capturing=capture~=nil or M.live('KeybindPopUp_C')~=nil
    if M.capturing then keyboard_hold=true;pad_hold=true end
    if footer and not capture then
        return {screen='keybinds@'..id,index=footer,label=footer_label},'screen=keybinds footer='..footer
    end
    local snap=presentation:snapshot(id,text_field(view,'Title') or M.text('keybind_title'),entries,focus,capture)
    return snap,'screen=keybinds focus='..tostring(focus)..' capture='..tostring(capture)
end
return M
