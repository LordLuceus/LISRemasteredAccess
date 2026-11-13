-- Scalar presentation of the native keyboard editor. No engine objects,
-- assignments or input injection. Row order/fields come from the shipped
-- Settings_Keybinds_Menu widget, including its separate primary/secondary slots.
local M={}
M.rows={
    {field='ForwardKey',label='TextBlock_12',action='MoveForward'},
    {field='LeftKEy',label='TextBlock',action='MoveLeft'},
    {field='RightKey',label='TextBlock_1',action='MoveRight'},
    {field='BackKEy',label='TextBlock_2',action='MoveBack'},
    {field='JogKey',label='TextBlock_3',action='SpeedUp'},
    {field='RewindKey',label='TextBlock_4',action='Rewind'},
    {field='SkipKEy',label='TextBlock_5',action='Skip'},
    {field='PauseKey',label='TextBlock_6',action='Pause'},
    {field='JournKey',label='TextBlock_7',action='Journal'},
    {field='InteractKey',label='TextBlock_8',action='Interact'},
    {field='ResetCamKey',label='TextBlock_9',action='RecenterCamera'},
    {field='QuickKey',label='TextBlock_10',action='Undo'},
}
local join=require('core.text').join
function M.slot(index)return index%2==1 and 'keybind_primary' or 'keybind_secondary' end
function M.new(text)
    local state={id=nil,keys={},notice=nil}
    local function label(entry,index)
        return join(entry.label or text('menu_unlabelled'),text(M.slot(index)))
    end
    function state:clear()self.id=nil;self.keys={};self.notice=nil end
    -- Entries contain only label, canonical key name and native display text.
    -- focus/capture are 1-based slot indices, never guessed from row order.
    function state:snapshot(id,title,entries,focus,capture)
        local same=id==self.id
        local changed={}
        if same then
            for i,e in ipairs(entries) do
                if e.key and self.keys[i] and e.key~=self.keys[i] then changed[#changed+1]=i end
            end
        else self.notice=nil end
        local selected=capture or focus
        if self.notice and (self.notice.index~=selected or capture) then self.notice=nil end
        if #changed>0 then self.notice=nil end
        if #changed==2 and selected then
            local a,b=changed[1],changed[2]
            if entries[a].key==self.keys[b] and entries[b].key==self.keys[a] then
                local other=selected==a and b or (selected==b and a or nil)
                if other then
                    self.notice={index=selected,text=text('keybind_swapped',{
                        name=label(entries[other],other),key=entries[other].display or text('keybind_unknown')})}
                end
            end
        end
        self.id=id;self.keys={}
        for i,e in ipairs(entries) do self.keys[i]=e.key end
        local e=selected and entries[selected]
        if not e then return {screen='keybinds@'..id,index='overview',label=title} end
        local value=capture and text('keybind_capture') or (e.display or text('keybind_unknown'))
        if not capture and self.notice then value=join(value,self.notice.text) end
        value=join(value,text('keybind_position',{index=math.ceil(selected/2),count=#M.rows}))
        return {screen='keybinds@'..id,index=selected,label=label(e,selected),value=value,
            key=label(e,selected)..(capture and ':capture' or ':browse'),context=title}
    end
    return state
end
return M
