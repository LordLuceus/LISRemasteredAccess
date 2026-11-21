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
local dialogue=require('cutscenes.dialogue')
local language,level='en','E1_3A'
local function controller()
    return {IsValid=function()return true end,GetCurrentLanguage=function()return language end,
        GetWorld=function()return {IsValid=function()return true end,
            GetFName=function()return {ToString=function()return level end}end}end}
end
local drone={[2]="I'd love to.",[3]="Is this legal?"}
C.set_all(drone,false)
check(dialogue.key(controller,C.options())=='scene_choice_brooke_drone','Brooke shot matches the real prompt')
local after_rewind={{text="That's a HiFly drone."},{text=drone[2]},{text=drone[3]}}
check(dialogue.key(controller,after_rewind)=='scene_choice_brooke_drone','rewind answer may occupy an earlier button')
local stella={{text="He's aloof."},{text='I think so.'},{text='Not sure yet.'}}
check(dialogue.key(controller,stella)=='scene_choice_stella','Stella asks about Jefferson on campus')
local evan={{text='Robert Capa.'},{text='Robert Doisneau.'},{text='Eugene Smith.'},{text='Steve McCurry.'}}
check(dialogue.key(controller,evan)=='scene_choice_evan','Evan asks Max to name a photographer')
local skaters={{text='Oh yeah.'},{text='Thrash?'}}
check(dialogue.key(controller,skaters)=='scene_choice_justin','first meeting with Justin')
table.insert(skaters,{text='I came to Noseslide.'})
check(dialogue.key(controller,skaters)=='scene_choice_justin','Justin after learning the skate trick')
local vortex={{text='Vortex Club.'},{text='Nathan Prescott.'},{text="Let's talk later."}}
check(dialogue.key(controller,vortex)=='scene_choice_hayden','Hayden without the Rachel option')
table.insert(vortex,{text='Rachel.'})
check(dialogue.key(controller,vortex)=='scene_choice_hayden','Hayden with the Rachel option')
local truck={{text='I have no idea.'},{text='Hopefully nothing.'}}
check(not dialogue.key(controller,truck),'truck shot is restricted to the drive')
level='E1_4A'
check(dialogue.key(controller,truck)=='scene_choice_truck_nathan','truck shot matches both replies')
level='E1_3C'
local juliet={{text='What did she do?'},{text="She's your friend."}}
check(dialogue.key(controller,juliet)=='scene_choice_juliet_dorm','Juliet at the locked door')
table.insert(juliet,{text='Juliet Watson, be nice.'})
check(dialogue.key(controller,juliet)=='scene_choice_juliet_dorm','Juliet after learning her last name')
level='E1_3D'
check(not dialogue.key(controller,juliet),'dorm prompt does not carry over to the parking lot')
level='E1_6A'
local angry={{text="I'm sorry..."},{text='Are you pissed at me?'}}
local friendly={{text="You're in a good mood."},{text='My pleasure.'}}
check(dialogue.key(controller,angry)=='scene_choice_cliff_bench','cliff bench after leaving Chloe to face David')
check(dialogue.key(controller,friendly)=='scene_choice_cliff_bench','cliff bench after backing Chloe up')
level='E1_5A'
C.set_all({'STEP IN','STAY HIDDEN'},true)
check(dialogue.key(controller,C.options())=='scene_choice_closet','closet viewpoint during the major choice')
C.set_all({'BLAME CHLOE','TAKE THE BLAME'},true)
check(dialogue.key(controller,C.options())=='scene_choice_blame','room viewpoint when David finds Max')
C.set_all(drone,false)
level='E1_3B'
check(not dialogue.key(controller,C.options()),'same answers outside the main campus')
level='E1_3A';language='fr'
check(not dialogue.key(controller,C.options()),'English scene requires English game audio')
language='en'
local changes=0
C.on_change=function()changes=changes+1 end
C.set_all(drone,false)
check(changes==0,'stable answer buttons leave narration alone')
C.update(0,'Another answer',false)
check(changes==1 and not dialogue.key(controller,C.options()),'changed prompt expires the description')
for _,event in ipairs({'ChooseSentense','Destruct'}) do
    C.clear('fixture')
    C.set_all({'Close the door.','No fight.','No weapons.'},false)
    check(C.options() and #C.options()==3,'captured choice list present')
    check(type(hooks[event])=='function','callback registered: '..event)
    local before=changes
    local ok,err=pcall(hooks[event])
    check(changes==before+1,'answer and close events expire owned narration')
    check(ok,'callback must not reference removed diagnostics: '..tostring(err))
    check(C.options()==nil,'callback clears answers: '..event)
    check(C.current(false)==nil,'no stale answer readout after '..event)
end
StaticFindObject,RegisterHook=previous.StaticFindObject,previous.RegisterHook
rawset(_G,'diag',previous.diag)
package.loaded['dialogue.choices']=nil
print('Choice lifecycle: '..count..' checks passed')
return count
