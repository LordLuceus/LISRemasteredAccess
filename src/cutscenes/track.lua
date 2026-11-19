-- Plain UTF-8 SRT descriptions. Reject the whole track on malformed timing;
-- never speak timestamps, partial tracks or overlapping description windows.
local M={}
local function trim(s)return(s:gsub('^%s+',''):gsub('%s+$',''))end
local function timestamp(s)
    local h,m,sec,ms=s:match('^(%d%d):(%d%d):(%d%d),(%d%d%d)$')
    if not h then return end
    h,m,sec,ms=tonumber(h),tonumber(m),tonumber(sec),tonumber(ms)
    if m>59 or sec>59 then return end
    return h*3600+m*60+sec+ms/1000
end
function M.parse(text)
    if type(text)~='string' then return nil,'not text' end
    if #text>262144 then return nil,'track too large' end
    if text:sub(1,3)=='\239\187\191' then text=text:sub(4) end
    if not utf8.len(text) or text:find('%z') then return nil,'invalid UTF-8 text' end
    text=text:gsub('\r\n','\n'):gsub('\r','\n')
    local lines={};for line in (text..'\n'):gmatch('(.-)\n')do lines[#lines+1]=trim(line)end
    local cues,i={},1
    while i<=#lines do
        if lines[i]=='' then i=i+1
        else
            local number=tonumber(lines[i])
            if not lines[i]:match('^%d+$') or number~=#cues+1 then return nil,'expected cue '..(#cues+1)end
            i=i+1
            local a,b=(lines[i] or ''):match('^(%S+)%s+%-%->%s+(%S+)$')
            local start,finish=a and timestamp(a),b and timestamp(b)
            if not start or not finish or finish<=start then return nil,'invalid time for cue '..number end
            if #cues>0 and start<cues[#cues].finish then return nil,'overlapping cue '..number end
            i=i+1;local body={}
            while i<=#lines and lines[i]~='' do body[#body+1]=lines[i];i=i+1 end
            if #body==0 then return nil,'empty cue '..number end
            local value=table.concat(body,' ')
            if value:find('%-%->') or value:find('<[^>]+>') then return nil,'non-plain cue '..number end
            cues[#cues+1]={start=start,finish=finish,text=value}
        end
    end
    return cues
end
return M
