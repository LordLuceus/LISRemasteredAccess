-- Read-only, game-thread adapter for the player used by D9PlayGameVideo in
-- LiSPlayerController_BP. No cached Blueprint fields or retained engine objects.
-- UE4SS loses opaque Timespan return data. The pinned native helper calls the
-- actual getter into an owned eight-byte buffer and returns only scalar seconds.
local M={}
local PLAYER='/Game/Movies/D9MediaPlayer.D9MediaPlayer'
local reader,configured
local function valid(o)return o and o:IsValid()end
function M.configure(provider)
    configured=true;reader=provider
    if not reader then
        local here=debug.getinfo(1,'S').source:gsub('^@',''):gsub('[^/\\]+$','')
        reader=package.loadlib(here:gsub('cutscenes[/\\]$','')..'lisr_reflection.dll','lisr_movie_time')
    end
    return type(reader)=='function'
end
function M.parse(packet)
    if type(packet)~='string' then return nil,'native_unavailable' end
    local value=packet:match('^LISRMT1|status=ok|seconds=([^|]+)$')
    if not value then return nil,'native_'..(packet:match('^LISRMT1|status=([a-z]+)$')or'protocol')end
    local seconds=tonumber(value)
    if not seconds or seconds~=seconds or seconds<0 or seconds==math.huge then return nil,'native_clock'end
    return seconds
end
function M.read_time(player,klass)
    if not configured then M.configure()end
    if type(reader)~='function'then return nil,'native_unavailable'end
    local ok,packet=pcall(reader,player,klass)
    if not ok then return nil,'native_error'end
    return M.parse(packet)
end
function M.sample(api)
    api=api or {find=StaticFindObject,all=FindAllOf}
    local ok,result,why=pcall(function()
        local widget
        for _,w in ipairs(api.all('D9MoviePlayerWidget_C') or {})do
            if valid(w) and w:IsInViewport() and w:IsVisible() and w:GetRenderOpacity()>0 then
                if widget then return nil,'ambiguous visible movie widgets' end
                widget=w
            end
        end
        if not widget then return nil end
        local player=api.find(PLAYER)
        local klass=valid(player)and player:GetClass()
        if not klass or klass:GetFName():ToString()~='MediaPlayer' then
            return nil,'movie player unavailable'
        end
        local url=player:GetUrl()
        if type(url)=='userdata' or type(url)=='table' then url=url:ToString()end
        if type(url)~='string' or url=='' then return nil end
        local playing,paused=player:IsPlaying()==true,player:IsPaused()==true
        if not playing and not paused then return nil end
        local seconds,reason=(api.clock or M.read_time)(player:GetAddress(),klass:GetAddress())
        if not seconds then return nil,reason or 'native_clock'end
        if type(seconds)~='number' or seconds~=seconds or seconds<0 or seconds==math.huge then
            return nil,'invalid movie clock'
        end
        return {url=url,time=seconds,active=true,playing=playing,
            key=tostring(widget:GetAddress())..':'..tostring(player:GetAddress())..':'..url}
    end)
    if not ok then return nil,tostring(result)end
    return result,why
end
return M
