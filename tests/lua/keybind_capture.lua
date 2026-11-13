package.path='src/?.lua;'..package.path
local Keys=require('core.keys')
local n=0
local function check(ok,why)n=n+1;assert(ok,why)end
local k=Keys.new()
local action=function()end
k:bind(0x22,'none',action,{['repeat']=true})
k:update(0,0)
check(#k:update(1,.1,true)==0,'capture consumes the assignment key')
check(#k:update(1,1,true)==0,'capture consumes held-key repeats')
check(#k:update(1,2,false)==0,'leaving capture while held cannot trigger a shortcut')
check(#k:update(1,3,false)==0,'no stale repeat timer survives capture')
k:update(0,4)
check(k:update(1,5)[1]==action,'the next deliberate press works normally')
check(k:update(1,6)[1]==action,'ordinary repeat still works')
check(#k:update(1,7,true)==0,'entering capture clears a repeat already in progress')
check(#k:update(1,8,false)==0,'that old repeat cannot resume on capture exit')
k:update(0,9)
check(k:update(1,10)[1]==action,'ordinary input resumes after release')
for _,vk in ipairs({0x57,0x53,0x41,0x44}) do
    local letters=Keys.new();letters:bind(vk,'none',action,{['repeat']=true})
    letters:update(0,0)
    check(#letters:update(1,.1,true)==0,'WASD binding can be captured without navigating')
    check(#letters:update(1,.8,false)==0,'held captured letter cannot start a repeat')
    letters:update(0,1)
    check(letters:update(1,1.1)[1]==action,'released letter resumes deliberate navigation')
end
print('Keybind capture input: '..n..' checks passed')
return n
