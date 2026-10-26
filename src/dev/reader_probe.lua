-- Read-only (test sessions): what the object viewer and the journal show.
-- Logs only on change. Reads named fields of the specific widget classes (never
-- a scan of every TextBlock - that probe crashed once).
local M={}
local function valid(o)local ok,r=pcall(function()return o~=nil and o:IsValid()end);return ok and r==true end
local function vis(o)local ok,r=pcall(function()return o:IsVisible()end);return ok and r==true end
local function text(o)local ok,s=pcall(function()return o:GetText():ToString()end);return ok and s or nil end
local function val(o,f)local ok,v=pcall(function()return o[f]end);return ok and tostring(v) or "err" end
local function first_live(class)
    for _,w in ipairs(FindAllOf(class) or {}) do
        local ok,on=pcall(function()return w:IsValid() and w:IsInViewport()end)
        if ok and on then return w end
    end
end
local last={}
local function emit(log,key,line)if last[key]~=line then last[key]=line;log(key.." "..line) end end
-- Named text fields per class, from the shipped widget trees.
M.FIELDS={
    BP_LiSPictureWidget_View_C={"TextBlock_PictureText","TextBlock_Next","TextBlock_Previous","Button_Text"},
    DiaryWrapper_Widget_C={"TextBlock_2","TextBlock_3","TextBlock_Placeholder","Txt_Next","Txt_Previous","Button_Text"},
    DiaryBook_Widget_C={"TextBlock_0","TextBlock_2","TextBlock_29","TextBlock_Objective","TextBlock_ObjectiveTitle","TextBlock_PNum"},
    DiaryBookDay_Widget_C={"Prologue_Text","Monday_Text","Tuesday_Text","Wednesday_Text","Thursday_Text","Friday_Text"},
    DiaryElementReader_Widget_C={"TextBlock_Data"},
    DiaryMessageSMS_Widget_C={"TextBlock_Body","TextBlock_Meta"},
    DiaryMessageWrapper_Widget_C={"TextBlock_0","TextBlock_Data"},
    DiaryMessageEmitter_Widget_C={"TextBlock_0","TextBlock_Data"},
    DiaryCharacterPage_Widget_C={"TextBlock_0"},
    DiaryPhotosDetails_Widget_C={"EpisodeTitle","TextBlock_NAME"},
    DiarySubObjectiveWidget_C={"TextBlock_Data"},
    DiaryMainMenuButton_Widget_C={"TextBlock_Placeholder"},
    DiaryElement_Widget_C={"Text_Data"},
    DiaryCharacterOverall_Widget_C={"TextBlock_0","TextBlock_NAME"},
    DiaryCharacterPortrait_Widget_C={"TextBlock_NAME"},
    DiaryPlaces_Widget_C={"TextBlock_0"},
    DiaryPhotos_Widget_C={"Episode1","Episode2","Episode3","Episode4","Episode5"},
    DiaryChoicesPageWidget_C={"TextBlock_0","Text_Data"},
    DiaryChoiceStringWidget_C={"TextBlock_Choice","ChoicePercent"},
    DiaryChoicesWrapperWidget_C={"TextBlock_Episode"},
    DiaryPlacesDetails_Widget_C={},
    DiaryMessageChat_Widget_C={},
    DiaryCharacterPage_Widget_C={"TextBlock_0"},
}
function M.tick(log)
    for class,fields in pairs(M.FIELDS) do
        local live={}
        for _,w in ipairs(FindAllOf(class) or {}) do
            local ok,on=pcall(function()return w:IsValid() and w:IsVisible() and (w:IsInViewport() or w:GetParent()~=nil)end)
            if ok and on then live[#live+1]=w end
        end
        local parts={}
        for n,w in ipairs(live) do
            if n>30 then break end
            for _,f in ipairs(fields) do
                local ok,t=pcall(function()return w[f]end)
                if ok and valid(t) and vis(t) then
                    local s=text(t)
                    if s and s:find("%S") then
                        local pos="?"
                        pcall(function()
                            local g=t:GetCachedGeometry()
                            local abs=StaticFindObject("/Script/UMG.Default__SlateBlueprintLibrary"):LocalToAbsolute(g,{X=0,Y=0})
                            pos=string.format("%.0f,%.0f",abs.X,abs.Y)
                        end)
                        parts[#parts+1]=n..":"..f.."@"..pos.."="..s:gsub("[\r\n]+"," / "):sub(1,160)
                    end
                end
            end
        end
        if class=="DiaryElement_Widget_C" then
            for n,w in ipairs(live) do
                if n>30 then break end
                local ok,s=pcall(function()return w.DataText:ToString()end)
                if ok and s and s:find("%S") then parts[#parts+1]=n..":DataText="..s:gsub("[\r\n]+"," / "):sub(1,160) end
            end
        end
        if class=="BP_LiSPictureWidget_View_C" and live[1] then
            local w=live[1]
            parts[#parts+1]="CurrentPicture="..val(w,"CurrentPicture").." NumPages="..val(w,"NumPages")
            local ok,s=pcall(function()return w.TextBlock_PictureText:GetText():ToString()end)
            parts[#parts+1]="PictureText="..tostring(ok and s or "err"):gsub("[\r\n]+"," / "):sub(1,200)
            for _,f in ipairs({"Button_Read","CanvasPanel_Read","Image_ShowPicture"}) do
                local ok,o=pcall(function()return w[f]end)
                parts[#parts+1]=f.."="..tostring(ok and valid(o) and vis(o))
            end
        end
        -- List screens: the game's highlighted entry (ButtonInFocusIndex into
        -- AvailableButtonsSorted) and that entry's own fields.
        if live[1] then
            local w=live[1]
            local ok,idx=pcall(function()return w.ButtonInFocusIndex end)
            if ok and idx~=nil then
                parts[#parts+1]="focus="..tostring(idx)
                pcall(function()
                    local n=w.AvailableButtonsSorted:GetArrayNum()
                    parts[#parts+1]="buttons="..n
                    local b=nil
                    w.AvailableButtonsSorted:ForEach(function(i,v)if i==idx+1 then b=v:get() end end)
                    -- Check the button still exists before reading through it.
                    if b and valid(b) then
                        parts[#parts+1]="sel_class="..b:GetClass():GetFName():ToString()
                        for _,f in ipairs({"Name","CharacterName","DayTitle","LocalizedEpisodeTitle","EpisodeName","Title","ElementID","FirstPageNumber","CanBeOpened"}) do
                            local fok,v=pcall(function()local x=b[f];if type(x)=="userdata" then return x:ToString() end return x end)
                            if fok and v~=nil then parts[#parts+1]="sel."..f.."="..tostring(v) end
                        end
                    end
                end)
            end
        end
        emit(log,"reader_probe "..class,"count="..#live.." "..table.concat(parts," | "))
    end
end
return M
