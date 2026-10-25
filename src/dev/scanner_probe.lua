-- Development probe for the scanner: lists what the scanner would offer, with
-- each name as the game translates it, and finds a translator that works
-- outside widgets. Read-only; runs once per scene.
local M={}
local function valid(o)
    local ok,r=pcall(function()return o~=nil and o:IsValid()end)
    return ok and r==true
end
-- Candidate translators: the game's LiSWidget:GetLocalizedString on any live
-- widget (the title or any UI widget), and the LiS localization manager.
function M.translators(emit)
    local found={}
    for _,class in ipairs({"LiSWidget","UserWidget"}) do
        for _,w in ipairs(FindAllOf(class) or {}) do
            local ok,s=pcall(function()return w:GetLocalizedString("$GT_Sensen_Int_Bottle01")end)
            if ok and s~=nil then
                local str=type(s)=="string" and s or (pcall(function()s=s:ToString()end) and s)
                emit("scanner_translator class="..class.." widget="..w:GetClass():GetFName():ToString().." result="..tostring(str))
                found[#found+1]=w
                if #found>=2 then return found end
            end
        end
    end
    for _,m in ipairs(FindAllOf("LiSLocalizationManager") or {}) do
        if valid(m) then
            m:GetClass():ForEachFunction(function(f)emit("scanner_locman function="..f:GetFullName())end)
            emit("scanner_locman object="..m:GetFullName())
        end
    end
    emit("scanner_translators found="..#found)
    return found
end
function M.run(controller,emit)
    M.translators(emit)
    local src=require("scanner.sources")
    src.report=emit
    local entries=src.collect(controller)
    local pawn=controller.Pawn
    local p=pawn:K2_GetActorLocation()
    local yaw=controller:GetControlRotation().Yaw
    local L=require("scanner.list")
    local list=L.new():update(entries,{X=p.X,Y=p.Y,Z=p.Z})
    emit("scanner_entries count="..#list)
    for i,e in ipairs(list) do
        if i<=60 then
            local h,m=L.height({X=p.X,Y=p.Y,Z=p.Z},e.pos)
            emit(string.format("scanner_entry i=%d name=%s kind=%s distance=%.1fm dir=%s height=%s stand=%s id=%s",
                i,e.name,e.kind,e.distance/100,L.direction(p,yaw,e.pos),h and string.format("%s %.1f",h,m) or "-",tostring(e.stand~=nil),e.id:match("[^.:]+$") or e.id))
        end
    end
end
return M
