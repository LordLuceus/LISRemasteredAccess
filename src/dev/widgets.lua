-- Read-only inventory of visible UMG widgets and their text. No input or clicks.
local M={}
local function valid(o)return o~=nil and o:IsValid() and not o:HasAnyFlags(EObjectFlags.RF_BeginDestroyed|EObjectFlags.RF_FinishDestroyed)end
local function text_of(o)
    local ok,v=pcall(function()return o:GetText()end)
    if ok and v~=nil then
        local sok,s=pcall(function()return v:ToString()end)
        if sok and type(s)=="string" then return s end
    end
    ok,v=pcall(function()return o.Text:ToString()end)
    if ok and type(v)=="string" then return v end
    return nil
end
local function owning_widget(o)
    local outer=o:GetOuter()
    for _=1,8 do
        if not valid(outer) then return nil end
        if outer:IsA("/Script/UMG.UserWidget") then return outer end
        outer=outer:GetOuter()
    end
    return nil
end
function M.run(phase,emit)
    local shown=0
    for _,w in ipairs(FindAllOf("UserWidget") or {}) do
        if valid(w) then
            local ok,inview=pcall(function()return w:IsInViewport()end)
            if ok and inview then
                shown=shown+1
                if shown<=60 then emit("widget phase="..phase.." class="..w:GetClass():GetFName():ToString().." visible="..tostring(w:IsVisible())) end
            end
        end
    end
    emit("widget_viewport_count phase="..phase.." count="..shown)
    local texts,unreadable=0,0
    for _,class in ipairs({"TextBlock","RichTextBlock","EditableTextBox","MultiLineEditableTextBox"}) do
        for _,t in ipairs(FindAllOf(class) or {}) do
            if valid(t) then
                local owner=owning_widget(t)
                local ok,live=pcall(function()return owner and owner:IsInViewport() and t:IsVisible()end)
                if ok and live then
                    local s=text_of(t)
                    if s==nil then unreadable=unreadable+1
                    elseif s~="" and texts<150 then
                        texts=texts+1
                        emit("widget_text phase="..phase.." kind="..class.." owner="..owner:GetClass():GetFName():ToString().." name="..t:GetFName():ToString().." text="..s:gsub("[\r\n]+"," / "))
                    end
                end
            end
        end
    end
    emit("widget_text_count phase="..phase.." readable="..texts.." unreadable="..unreadable)
end
return M
