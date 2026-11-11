-- Exercise normal startup without loading any real DLL or reading game objects.
package.path='src/?.lua;'..package.path
local loadlib,hook=package.loadlib,RegisterHook
local loads,reads=0,0
local function fresh()
    package.loaded['dialogue.choices']=nil
    package.loaded['dialogue.uncached']=nil
    return require('dialogue.choices')
end
package.loadlib=function(path,symbol)
    loads=loads+1
    assert(path:match('lisr_reflection%.dll$'))
    assert(not path:match('dialogue[/\\]lisr_reflection'))
    assert(symbol=='lisr_reflection_read')
    return function()reads=reads+1;error('No native read allowed during startup')end
end
RegisterHook=nil
local c=fresh();assert(loads==0 and not require('dialogue.uncached').enabled)
RegisterHook=function()error('Startup must not register hooks itself')end
c=fresh();assert(loads==1 and reads==0 and require('dialogue.uncached').enabled)
c.configure_uncached(nil)
package.loadlib=function()return nil,'intentional missing DLL'end
c=fresh();assert(not require('dialogue.uncached').enabled)
c.set_all({[1]='Existing choice'},false);assert(c.options()[1].text=='Existing choice')
package.loadlib=function()error('intentional loader exception')end
c=fresh();assert(not require('dialogue.uncached').enabled)
package.loadlib,RegisterHook=loadlib,hook
print('choice startup: host-only loading, activation, no native reads, missing/throwing loader fallback passed')
