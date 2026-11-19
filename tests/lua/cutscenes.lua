package.path='src/?.lua;'..package.path
local Track=require('cutscenes.track')
local Policy=require('cutscenes.policy')
local Tracks=require('cutscenes.tracks')
local count=0
local function check(ok,why)count=count+1;assert(ok,why)end
local source='1\n00:00:01,000 --> 00:00:03,000\nFirst view.\n\n2\n00:00:04,000 --> 00:00:06,000\nSecond\nview.\n'
local cues,err=Track.parse(source)
check(cues and #cues==2,err or 'parse')
check(cues[2].text=='Second view.','multiline prose')
check(#assert(Track.parse(' \n\n'))==0,'empty override disables track')
check(#assert(Track.parse('\239\187\191'..source:gsub('\n','\r\n')))==2,'BOM and CRLF')
for name,text in pairs({number=source:gsub('^1','2'),time=source:gsub('00:00:01,000','00:60:01,000'),
    order=source:gsub('00:00:04,000','00:00:02,000'),duration=source:gsub('00:00:03,000','00:00:01,000'),
    body=source:gsub('First view%.',''),markup=source:gsub('First view%.','<b>First</b>'),
    invalid_utf8=source..'\255',nul=source..'\0',huge=string.rep(' ',262145)})do
    local result,why=Track.parse(text);check(not result and type(why)=='string','reject '..name)
end
local function frame(time,changes)
    local f={key='Episode01/movie.mp4:1',time=time,active=true,playing=true,focused=true,allowed=true}
    for k,v in pairs(changes or {})do f[k]=v end
    return f
end
local p=Policy.new()
check(p:update(frame(0),cues)==nil,'before first cue')
check(p:update(frame(1),cues)=='First view.','start inclusive')
check(p:update(frame(1.01),cues)==nil,'one shot')
local text,stop=p:update(frame(3),cues);check(not text and not stop,'end does not stop begun speech')
check(p:update(frame(6),cues)==nil,'end exclusive, expired cue dropped')
p:reset();check(p:update(frame(4.5),cues)=='Second view.','initial clock skips expired first cue')
text,stop=p:update(frame(1.5),cues);check(text=='First view.' and stop,'seek backwards re-arms by real clock')
text,stop=p:update(frame(0,{key='Episode01/movie.mp4:2'}),cues);check(not text and stop,'new same-file playback generation')
check(p:update(frame(1),cues)=='First view.','replay emits first cue again')
for _,blocked in ipairs({'active','playing','focused','allowed'})do
    p=Policy.new();p:update(frame(1),cues)
    text,stop=p:update(frame(4,{[blocked]=false}),cues);check(not text and stop,'stop when '..blocked..' false')
    check(p:update(frame(4.1),cues)==nil,'no stale cue on '..blocked..' resume')
end
p=Policy.new();p:update(frame(1),cues)
text,stop=p:update(nil,cues);check(not text and stop,'missing observation stops owned speech')
check(p:update(frame(4.1),cues)==nil,'unknown interval does not replay backlog')
check(p:update(frame(0/0),cues)==nil,'NaN rejected')
check(p:update(frame(math.huge),cues)==nil,'infinity rejected')
check(p:update(frame(-1),cues)==nil,'negative time rejected')
check(Policy.new():update(frame(0),{})==nil,'empty track harmless')
local url='file:///C:/Game/LIS/Content/Movies/Episode01/BIK_E1_7A_Snowing.mp4'
local id='episode01/bik_e1_7a_snowing.mp4'
check(Tracks.movie_id(url)==id,'native file URL identity')
check(Tracks.movie_id('.\\Movies\\Episode01\\BIK_E1_7A_Snowing.mp4')==id,'relative Windows file path')
check(Tracks.movie_id('../../../LIS/Content/Movies/Episode01/BIK_E1_7A_Snowing.mp4')==id,'native relative content prefix')
check(Tracks.movie_id(url:gsub('/Game/','/Game%%20Folder/'))==id,'escaped spaces outside captured suffix')
for _,bad in ipairs({'http://site/Movies/Episode01/BIK_E1_7A_Snowing.mp4',
    './Movies/BIK_Loading.mp4','./Movies/Episode01/../../secret.mp4',
    url..'?other','./Movies/Episode01/secret%2fmovie.mp4'})do
    check(not Tracks.movie_id(bad),'reject unrelated or unsafe movie URL')
end
local files={['root/tracks/en/'..id..'.ad.srt']=source};local reads=0
local function read(path)reads=reads+1;return files[path],files[path]==nil and 'missing' or nil end
local tracks=Tracks.new('root',read)
check(#assert(tracks:load(url,'en')).cues==2,'bundled track')
tracks:load(url,'en');check(reads==2,'no repeated disk reads')
check(not tracks:load(url,'fr'),'no wrong-language timing fallback')
files['root/overrides/en/'..id..'.ad.srt']=''
check(#assert(Tracks.new('root',read):load(url,'en')).cues==0,'empty user override wins')
files['root/overrides/en/'..id..'.ad.srt']='bad data'
check(not Tracks.new('root',read):load(url,'en'),'broken override does not silently use defaults')
check(not tracks:load(url,'../en'),'language path traversal rejected')
local bundled=Tracks.new('src/cutscenes')
for _,name in ipairs({'BIK_E1_6A_DialEnd','BIK_E1_7A_Snowing'})do
    local value,why=bundled:load('./Movies/Episode01/'..name..'.mp4','en')
    check(value and #value.cues>0,why or 'actual shipped SRT parsed by runtime')
end
print('Cutscene parser/scheduler: '..count..' checks passed')
return count
