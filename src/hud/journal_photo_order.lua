-- Official Remastered photo numbers -> original zero-based journal child indices.
-- Numbering follows episode progression, not an enforced walking route within a
-- scene. In Episode4 Slideshow is #9 and Tripod #10, despite some route guides
-- visiting those two in the opposite order. Never sort resource/scene filenames.
-- Primary numbers: https://steamcommunity.com/stats/1265920/achievements/
-- Subject cross-checks: Steam guides2193441363 +408771150 (E1-3),
-- 453782434 (E4),453784671 +538378604 (E5). Guide2193441363 reverses E4's
-- last two official numbers; the Remastered achievement descriptions settle it.
local order={
    Episode1={0,1,5,6,9,2,3,7,8,4},
    Episode2={0,1,5,6,9,2,3,7,8,4},
    Episode3={0,1,5,6,9,2,3,7,8,4},
    Episode4={0,1,5,6,9,2,3,7,4,8},
    Episode5={0,1,5,6,9,2,3,4,7,8},
}
for _,indices in pairs(order) do
    assert(#indices==10,'incomplete photo order')
    local seen={}
    for _,index in ipairs(indices) do
        assert(type(index)=='number' and index%1==0 and index>=0 and index<10 and not seen[index],
            'invalid photo-order permutation')
        seen[index]=true
    end
end
local M={}
function M.native_index(episode,position)
    if type(position)~='number' or position%1~=0 then return nil end
    local indices=order[episode]
    return indices and indices[position] or nil
end
return M
