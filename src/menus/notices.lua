-- Passive startup/episode notices, from Steam build 11330282's cooked widgets.
-- SplashScreenController's native array is logos, Disclaimer, Middleware,
-- HealthSafety, SaveGameIcon, then three logos (indices0..7). ChangeSplash has
-- latent delays: observe the current index AND visible panel, not SplashDone
-- (which refers to the outgoing screen). Never change timers or call Skip.
local M={}
M.log=function(_)end
local clean=require('core.text').clean
local join=require('core.text').join
local pages={
    [1]={panel='Disclaimer',fields={'DisclaimerText','CopyrightText'}},
    [2]={panel='Middleware',fields={'MiddlewareText'}},
    [3]={panel='HealthSafety',fields={'WarningText'}},
    [4]={panel='SaveGameIcon',fields={'AutosaveText'}},
}
local active,generation=nil,0 -- scalar identity only; never retain game objects
local errors={}
local function valid(o)
    if not o or not o:IsValid() then return false end
    local f=EObjectFlags
    return not o:HasAnyFlags(f.RF_BeginDestroyed|f.RF_FinishDestroyed|
        (f.RF_ClassDefaultObject or 0)|(f.RF_ArchetypeObject or 0))
end
local function opacity(o)
    local alpha=1
    -- IsVisible is local to the widget; a hidden/transparent parent also hides
    -- its children. These shipped trees are shallow; bound malformed chains.
    for _=1,32 do
        if not valid(o) or not o:IsVisible() then return 0 end
        local a=o:GetRenderOpacity()
        if type(a)~='number' or a~=a or a<=0 then return 0 end
        alpha=alpha*math.min(a,1)
        local parent=o:GetParent()
        if not parent or not parent:IsValid() then return alpha end
        o=parent
    end
    return 0
end
local function text_of(w)
    if not valid(w) or opacity(w)<=0 then return nil end
    -- ChoiceDisclaimer fades ColorAndOpacity, NOT RenderOpacity. Its authored
    -- text is initially alpha0 even though the TextBlock is marked Visible.
    local alpha=w.ColorAndOpacity.SpecifiedColor.A
    if type(alpha)~='number' or not (alpha>0) then return nil end
    local raw=w:GetText():ToString()
    if type(raw)~='string' or raw:find('$GT_',1,true) then return nil end
    local s=clean(raw)
    if s~='' then return s end
end
local function find(class)
    for _,w in ipairs(FindAllOf(class) or {}) do
        if valid(w) and w:IsInViewport() and w:IsVisible() then return w end
    end
end
local function observe(key)
    if key~=active then active=key;generation=generation+1 end
    return 'notice#'..generation
end
local function read()
    local w=find('ChoiceDisclaimer_Widget_C')
    local kind='story'
    if not w then w=find('SplashScreenController_C');kind='splash' end
    if not w then active=nil;return nil end
    local index=kind=='splash' and w.SplashIndex or 0
    if type(index)~='number' or index%1~=0 then index=-1 end
    local screen=observe(kind..'@'..w:GetAddress()..':'..w:GetFullName()..':'..index)
    local detail='screen=notice kind='..kind..' index='..index
    -- Logos, fade gaps and not-yet-localized text still cover the menu below.
    -- Keep that context silent, rather than announcing underlying title/menu
    -- controls between notices. A pending key cannot consume the once receipt.
    local quiet={screen=screen,index=0,key=screen..':pending',label='',silent=true,once=true,interrupt=false}
    if opacity(w)<=0 then return quiet,detail end
    local label
    if kind=='story' then
        label=text_of(w.DisclaimerText)
    else
        local page=pages[index]
        if not page or opacity(w[page.panel])<=0 then return quiet,detail end
        local cover=w.FGImage_1
        if not valid(cover) then return quiet,detail end
        -- The shipped overlay brush is solid black, alpha1. Its own tint and
        -- render opacity determine whether it still completely covers the text.
        local cover_alpha=cover.ColorAndOpacity.A
        if type(cover_alpha)~='number' or cover_alpha~=cover_alpha then return quiet,detail end
        if opacity(cover)*cover_alpha>=1 then return quiet,detail end
        for _,field in ipairs(page.fields) do
            local s=text_of(w[field])
            if not s then return quiet,detail end -- wait for BOTH disclaimer/copyright
            label=join(label,s)
        end
    end
    if not label then return quiet,detail end
    return {screen=screen,index=0,key=screen,label=label,once=true,interrupt=false},
        detail
end
function M.snapshot()
    local ok,s,detail=pcall(read)
    if ok then return s,detail end
    local err=tostring(s)
    if not errors[err] then errors[err]=true;M.log('notice_error='..err) end
    return nil
end
return M
