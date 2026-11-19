package.path='src/?.lua;'..package.path
local count=0
local function check(ok,why)count=count+1;assert(ok,why)end
local old_loadlib,old_speech,old_print=package.loadlib,package.loaded['core.speech'],print
local events={}
package.loaded['core.speech']=nil
package.loadlib=function(_,symbol)
    if symbol=='lisr_speak' then return function(text,interrupt)events[#events+1]={'say',text,interrupt};return true end end
    if symbol=='lisr_stop' then return function()events[#events+1]={'stop'}end end
    if symbol=='lisr_status' then return function()return 'fake' end end
end
print=function()end
local ok,err=pcall(function()
    local speech=require('core.speech');local movie={}
    speech.say('Ordinary queued speech.',false)
    speech.say('Another ordinary line.',false)
    check(#events==2 and events[2][1]=='say','normal callers retain queue behavior')
    check(not speech.stop_owned(movie) and not speech.stop_owned(nil),'no cancellation of ordinary speech')
    speech.say('A movie description.',true,movie)
    check(events[#events][3]==true,'first description may replace old menu speech')
    speech.say('Another description.',false,movie)
    check(events[#events-1][1]=='say','same owner does not stop its queue')
    speech.say('Important native prompt.',false)
    check(events[#events-1][1]=='stop' and events[#events][2]=='Important native prompt.','foreign announcement clears owned narration first')
    local n=#events
    check(not speech.stop_owned(movie) and #events==n,'movie end preserves newer prompt')
    speech.say('New current description.',false,movie)
    check(events[#events][3]==true,'new owned group never queues behind unowned speech')
    speech.say('One last description.',true,movie)
    check(speech.stop_owned(movie) and events[#events][1]=='stop','movie end stops its own narration')
    check(not speech.stop_owned(movie),'stop is one shot')
    speech.say('Invalid calls must not acquire ownership.',false)
    speech.say('',true,movie)
    check(not speech.stop_owned(movie),'empty speech does not claim ownership')
end)
package.loadlib,package.loaded['core.speech'],print=old_loadlib,old_speech,old_print
assert(ok,err)
print('Cutscene speech ownership: '..count..' checks passed')
return count
