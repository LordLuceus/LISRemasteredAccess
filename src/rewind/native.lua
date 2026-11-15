-- Primitive, versioned snapshots from the pinned native reader. No game objects
-- retained. Nonzero status is never interpreted as a fabricated gauge position.
local M={}
local reader
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.configure(provider)
    reader=provider
    if not reader then
        local here=debug.getinfo(1,'S').source:gsub('^@',''):gsub('[^/\\]+$','')
        reader=package.loadlib(here:gsub('rewind[/\\]$','')..'lisr_reflection.dll','lisr_rewind')
    end
    return type(reader)=='function'
end
function M.parse(text)
    if type(text)~='string' then return nil,'native_unavailable' end
    local fields={};for word in text:gmatch('%S+')do fields[#fields+1]=word end
    if #fields~=16 or fields[1]~='r2' then return nil,'protocol' end
    local n={}
    for i=2,16 do n[i]=tonumber(fields[i]);if not finite(n[i])then return nil,'number' end end
    for _,i in ipairs({2,3,4,5,8,9,11,12,13,14,15,16})do
        if n[i]%1~=0 then return nil,'integer' end
    end
    -- r2: status/index/serial/state/reference/range/known/present/time/
    -- visibility_known/visible/writer_known/writer/widget/material.
    for _,i in ipairs({8,9,11,12,13,14})do if n[i]~=0 and n[i]~=1 then return nil,'boolean' end end
    local status=n[2]
    if status~=0 and status~=3 then return nil,'status_'..status end
    if n[3]<0 or n[4]<=0 or n[5]<0 or n[5]>4 then return nil,'identity_state' end
    if status==0 and (n[6]<0 or n[7]<=0)then return nil,'timeline' end
    return {manager=tostring(n[3])..':'..tostring(n[4]),state=n[5],reference=n[6],range=n[7],
        valid=status==0,marker_known=n[8]==1,marker_present=n[9]==1,marker=n[10],
        writer_gate=n[13]==1 and n[14]==1,writer_widget=n[15],writer_material=n[16]},'status_'..status
end
function M.sample()
    if type(reader)~='function' then return nil,'native_unavailable' end
    local ok,text=pcall(reader)
    if not ok then return nil,'native_error' end
    return M.parse(text)
end
return M
