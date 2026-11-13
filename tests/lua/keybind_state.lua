package.path='src/?.lua;'..package.path
local Model=require('menus.keybind_state')
local Tracker=require('menus.tracker')
local function text(key,p)
    local words={menu_unlabelled='Unknown action',keybind_primary='Primary',keybind_secondary='Secondary',
        keybind_unknown='Unknown key',keybind_capture='Press a key.',
        keybind_swapped='Swapped with {name}; now {key}.',keybind_position='{index} of {count}.'}
    return (words[key] or key):gsub('{(%w+)}',function(k)return tostring(p[k])end)
end
local n=0
local function check(ok,why)n=n+1;assert(ok,why)end
local function entries()
    local out={}
    for _,row in ipairs(Model.rows) do
        for slot=1,2 do out[#out+1]={label=row.action,key='None',display='Unbound'} end
    end
    out[1]={label='Move Forward',key='W',display='W'}
    out[23]={label='Quick Undo',key='LeftControl',display='Left Ctrl'}
    out[24]={label='Quick Undo',key='RightControl',display='Right Ctrl'}
    return out
end
check(#Model.rows==12 and Model.rows[12].field=='QuickKey','native row order and quick-undo field')
check(Model.rows[2].field=='LeftKEy' and Model.rows[4].field=='BackKEy','authored field case is preserved')
local s=Model.new(text);local t=Tracker.new();local e=entries()
local function step(focus,capture,id)return t:update(s:snapshot(id or 'view','Key bindings',e,focus,capture))end
local first=step(23)
check(first:find('Key bindings',1,true) and first:find('Primary',1,true) and first:find('Left Ctrl',1,true),'entry has title, slot and current key')
check(first:sub(-9)=='12 of 12.','position is last')
check(step(23)==nil,'unchanged row is quiet')
check(step(24):find('Right Ctrl',1,true)~=nil,'secondary is independently readable')
check(not t:current():find('Key bindings',1,true),'stable title is not repeated with every row')
check(step(24,24):find('Press a key.',1,true)~=nil,'capture reports waiting, not the old key')
check(step(24):find('Right Ctrl',1,true)~=nil,'unchanged binding is reread on leaving capture')
step(23,23);e[23].key='U';e[23].display='U'
check(step(23):find('U',1,true)~=nil,'assignment reads its new key')
check(step(23)==nil,'assignment does not repeat')
step(24,24);e[24].key='W';e[24].display='W';e[1].key='RightControl';e[1].display='Right Ctrl'
local swapped=step(24)
check(swapped:find('Swapped with Move Forward, Primary; now Right Ctrl.',1,true)~=nil,'conflict reports the other affected binding and its new key')
check(step(24)==nil,'swap notice does not disappear and cause a duplicate readout next poll')
step(23);check(not step(24):find('Swapped',1,true),'old swap notice clears after leaving its row')
e[1].key='W';e[1].display='W';e[23].key='LeftControl';e[23].display='Left Ctrl';e[24].key='RightControl';e[24].display='Right Ctrl'
check(not step(24):find('Swapped',1,true),'multi-binding reset is not misreported as a swap')
check(step(nil):find('Key bindings',1,true)~=nil,'unknown focus does not pretend a slot is selected')
s:clear();e=entries();check(not step(23,nil,'another'):find('Swapped',1,true),'new/reopened view has no stale change history')
print('Keybind presentation: '..n..' checks passed')
return n
