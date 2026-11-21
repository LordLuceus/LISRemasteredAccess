-- Descriptions live in the mod, never beside or inside the game's movies.
-- Optional overrides (including an empty file) take precedence over bundled
-- tracks. English timing is not silently used over another language's dialogue.
local Track=require('cutscenes.track')
local M={};M.__index=M
-- English dialogue spans from the two shipped movie subtitle tracks, padded
-- for the game-thread poll. Merge short gaps where a line cannot fit.
local dialogue={
    ['en/episode01/bik_e1_7a_snowing.mp4']={{0,74.55},{80.5,97.2}},
    ['en/episode01/bik_e1_6a_dialend.mp4']={{17.75,23.3},{28.9,36.45}},
}
function M.in_dialogue(track,time)
    for _,span in ipairs(track.dialogue or {})do
        if time>=span[1] and time<span[2] then return true end
    end
    return false
end
function M.movie_id(url)
    if type(url)~='string' or #url>4096 then return end
    local path=url:gsub('\\','/'):lower()
    if path:find('%z') then return end
    if path:match('^%a[%w+.-]*://') and not path:match('^file://') then return end
    -- Only this validated suffix becomes a mod-relative path. Native URLs may
    -- legitimately have parent segments or escaped spaces in their game prefix.
    local episode,name=('/'..path):match('/movies/(episode0[1-5])/([%w_%-]+%.mp4)$')
    if not episode then return end
    return episode..'/'..name
end
local function read_file(path)
    local f,why,code=io.open(path,'rb')
    if not f then return nil,code==2 and 'missing' or tostring(why)end
    local text=f:read(262145) or '';f:close();return text
end
function M.new(root,read)
    return setmetatable({root=root:gsub('[/\\]+$',''),read=read or read_file,cache={}},M)
end
function M:load(url,language)
    local id=M.movie_id(url)
    if not id then return nil,'not a supported story movie path' end
    if type(language)~='string' or not language:match('^[a-z][a-z]$') then return nil,'unsupported language code' end
    local key=language..'/'..id
    if self.cache[key] then return self.cache[key].track,self.cache[key].why end
    local relative=key..'.ad.srt'
    local path=self.root..'/overrides/'..relative
    local text,why=self.read(path)
    local protection
    if text==nil and why=='missing' then
        path=self.root..'/tracks/'..relative;text,why=self.read(path)
        protection=dialogue[key]
    end
    local value
    if text~=nil then
        local cues; cues,why=Track.parse(text)
        if cues then value={id=id,language=language,key=key,cues=cues,path=path,dialogue=protection}end
    end
    self.cache[key]={track=value,why=why}
    return value,why
end
return M
