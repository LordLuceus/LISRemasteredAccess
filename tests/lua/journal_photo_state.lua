package.path='src/?.lua;src/?/init.lua;'..package.path
local State=require('hud.journal_photo_state')
local canonical=require('descriptions.catalog').canonical
local definitions=require('hud.journal_photo_slots')
local count=0
local function check(value,label) count=count+1;assert(value,label) end
local function copy(row)
    local result={};for key,value in pairs(row) do result[key]=value end;return result
end
local first=definitions[1]
check(first.episode=='Episode1' and first.index==0,'zero-based first native slot')
check(first.locked=='/Game/Packages/Gameplay/Collectible/E1/TX_Collectible_E1/TX_E1_2A_ArtClass_DanielTable_Locked.TX_E1_2A_ArtClass_DanielTable_Locked','real first locked fixture')
local model=State.new(definitions)
check(#definitions==50,'all fifty definitions shipped')
for _,row in ipairs(definitions) do
    for _,expected in ipairs({'locked','unlocked'}) do
        local state,asset=model.classify(row.episode,row.index,row[expected])
        check(state==expected and asset==canonical(row[expected]),'all 100 variants reachable')
    end
end
for _,path in ipairs({first.locked,first.locked:upper(),'Texture2D '..first.locked:upper()}) do
    local state,asset=model.classify('Episode1',0,path)
    check(state=='locked' and asset==canonical(first.locked),'case and engine prefix normalization')
end
local calls=0
local function lookup(asset,language)
    calls=calls+1
    check(asset==canonical(first.locked) and language=='fr','lookup receives only canonical matched state')
    return 'Reviewed locked preview.'
end
local cases={
    {'Episode1',1,first.locked}, {'Episode2',0,first.locked},
    {'Episode1',0,definitions[2].unlocked}, {'Episode1',0,'/Game/Unknown.Unknown'},
    {'Episode1',0,false}, {'Episode1',0}, {'Episode1',-1,first.unlocked},
    {'Episode1',10,first.unlocked}, {'Episode1',0.5,first.unlocked},
    {'Episode1','0',first.unlocked}, {'episode1',0,first.unlocked},
    {'Episode1',0,'TX_E1_2A_ArtClass_DanielTable_Locked'},
}
for _,case in ipairs(cases) do
    local result=model.describe(case[1],case[2],case[3],'fr',lookup)
    check(result.state=='unknown' and result.asset==nil and result.caption==nil,'mismatches fail closed')
end
check(calls==0,'no lookup calls for unknown or mismatched identities')
local result=model.describe('Episode1',0,first.locked,'fr',lookup)
check(result.state=='locked' and result.caption=='Reviewed locked preview.' and calls==1,'matched locked lookup')
local missing_calls=0
result=model.describe('Episode1',0,first.unlocked,'en',function(asset)
    missing_calls=missing_calls+1;check(asset==canonical(first.unlocked),'only actual unlocked resource');return nil
end)
check(result.state=='unlocked' and result.caption==nil and result.asset==canonical(first.unlocked) and missing_calls==1,'known state missing caption remains known without fallback')
result=model.describe('Episode1',0,first.locked,'en',nil)
check(result.state=='locked' and result.caption==nil,'optional missing lookup')
local original=copy(first);local isolated=State.new({original})
original.episode='Episode5';original.index=9;original.locked=first.unlocked
check(isolated.classify('Episode1',0,first.locked)=='locked','metadata copied on construction')
check(isolated.classify('Episode5',9,first.unlocked)=='unknown','caller mutation cannot create new identity')
for _,change in ipairs({{index=-1},{index=10},{index=0.5},{index='0'},{episode='Episode6'},
    {locked='basename'},{locked='/Game//X.X'},{locked='/Engine/X.X'},{locked=first.unlocked}}) do
    local row=copy(first);for key,value in pairs(change) do row[key]=value end
    check(not pcall(State.new,{row}),'invalid metadata rejected')
end
check(not pcall(State.new,{first,first}),'duplicate slot rejected')
local collision=copy(definitions[2]);collision.unlocked=first.locked
check(not pcall(State.new,{first,collision}),'cross-slot state collision rejected')
check(not pcall(State.new,{[2]=first}),'sparse metadata rejected')
check(not pcall(State.new,{named=first}),'non-array metadata rejected')
check(not pcall(State.new,nil),'non-table metadata rejected')
print('Journal photo state: '..count..' checks passed')
return count
