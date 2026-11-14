-- Invoke the actual registered lifecycle callbacks, not only M.clear directly.
package.path='src/?.lua;'..package.path
local previous={StaticFindObject=StaticFindObject,RegisterHook=RegisterHook,diag=rawget(_G,'diag')}
local hooks={}
StaticFindObject=function()return {IsValid=function()return true end,GetAddress=function()return 123 end}end
RegisterHook=nil -- Load the pure module without native-DLL startup.
rawset(_G,'diag',nil) -- Production has no diagnostic object or generation global.
package.loaded['dialogue.choices']=nil
local C=require('dialogue.choices')
C.configure_uncached({enabled=false})
RegisterHook=function(path,callback)hooks[path:match(':([^:]+)$')]=callback end
local count=0
local function check(value,label)count=count+1;assert(value,label)end
check(C.install(),'real lifecycle hooks installed')
for _,event in ipairs({'ChooseSentense','Destruct'}) do
    C.clear('fixture')
    C.set_all({'Close the door.','No fight.','No weapons.'},false)
    check(C.options() and #C.options()==3,'captured choice list present')
    check(type(hooks[event])=='function','callback registered: '..event)
    local ok,err=pcall(hooks[event])
    check(ok,'callback must not reference removed diagnostics: '..tostring(err))
    check(C.options()==nil,'callback clears answers: '..event)
    check(C.current(false)==nil,'no stale answer readout after '..event)
end
StaticFindObject,RegisterHook=previous.StaticFindObject,previous.RegisterHook
rawset(_G,'diag',previous.diag)
package.loaded['dialogue.choices']=nil
print('Choice lifecycle: '..count..' checks passed')
return count
