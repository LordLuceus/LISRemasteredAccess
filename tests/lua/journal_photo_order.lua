package.path='src/?.lua;'..package.path
local order=require('hud.journal_photo_order')
local definitions=require('hud.journal_photo_slots')
local count=0
local function check(value,label)count=count+1;assert(value,label)end
for episode=1,5 do
    local seen={}
    for position=1,10 do
        local native=order.native_index('Episode'..episode,position)
        check(type(native)=='number' and native%1==0 and native>=0 and native<10,'valid native index')
        check(not seen[native],'every native photo exactly once');seen[native]=true
        local row=definitions[(episode-1)*10+native+1]
        check(row.episode=='Episode'..episode and row.index==native,'original metadata identity preserved')
    end
end
-- Independent subject/number fixtures cross-checked against the Remastered
-- achievement descriptions and guide subjects, not copied index permutations.
-- These pin return visits, misleading scene-name order and disputed numbering.
local fixtures={
    {1,5,'MaxRoom_Mirror'}, {1,6,'VicRoom_Photos'}, {1,7,'CampusB_BrokenWindow'},
    {1,9,'CliffNow_Bird'}, {1,10,'CliffNow_CHChloe'},
    {2,3,'DinerSignSunrise'}, {2,5,'Diner_Selfie'}, {2,10,'ArtClass_CHAlyssa'},
    {3,3,'SciClass_Aquarium'}, {3,5,'Corridor_CHChloe'}, {3,10,'LivingRoom_CAmera'},
    {4,5,'Corridor_BigFoot'}, {4,6,'Beach_Whales'},
    {4,9,'MenToilets_CHJustin'}, {4,10,'Pool_TwoMoons'},
    {5,3,'DarkRoom_CHJefferson'}, {5,4,'DinerPark_CrashedWhale'},
    {5,5,'DinerPark_CrashedCar'}, {5,8,'Corridor_Skeleton'}, {5,10,'BottlesCollectible'},
}
for _,f in ipairs(fixtures) do
    local native=order.native_index('Episode'..f[1],f[2])
    local row=definitions[(f[1]-1)*10+native+1]
    check(row.locked:find(f[3],1,true) and row.unlocked:find(f[3],1,true),
        'official photo '..f[1]..'/'..f[2]..': '..f[3])
end
for _,position in ipairs({0,11,1.5,'1'}) do
    check(order.native_index('Episode1',position)==nil,'invalid position not mapped')
end
check(order.native_index('Episode1',nil)==nil,'nil position')
check(order.native_index('Unknown',1)==nil,'unknown episode')
print('Journal photo ordering: '..count..' checks passed')
return count
