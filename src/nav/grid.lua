-- Route planning where the level has no navigation mesh (pure; offline tested).
-- Some levels' baked navigation mesh leaves most of the ground uncovered (the
-- Dormitories lawn: 72 of 625 sample points). This plans on our own grid
-- instead: cells are sampled lazily through an injected `sample` (the game's
-- ground trace plus a Max-sized collision check), searched with A*, and the
-- path is shortened with an injected `clear` (a Max-sized sweep along each kept
-- segment). Budgeted: step() does a bounded number of samples per call, so a
-- search spreads over frames instead of stalling the game.
local M={}
M.__index=M
local SQRT2=math.sqrt(2)
local DIRS={{1,0,1},{-1,0,1},{0,1,1},{0,-1,1},{1,1,SQRT2},{1,-1,SQRT2},{-1,1,SQRT2},{-1,-1,SQRT2}}

-- Binary heap of {f,i,j}.
local function push(h,n)
    h[#h+1]=n;local k=#h
    while k>1 do local p=k//2;if h[p][1]<=h[k][1] then break end;h[p],h[k]=h[k],h[p];k=p end
end
local function pop(h)
    local top=h[1];local last=table.remove(h)
    if #h>0 then
        h[1]=last;local k=1
        while true do
            local l,r,m=2*k,2*k+1,k
            if l<=#h and h[l][1]<h[m][1] then m=l end
            if r<=#h and h[r][1]<h[m][1] then m=r end
            if m==k then break end
            h[m],h[k]=h[k],h[m];k=m
        end
    end
    return top
end

-- start, target: {X,Y,Z} (start = Max's feet, target = where to end up).
-- opts: sample(x,y,zref) -> ground z or nil (no ground / Max would not fit);
--   cell (cm, default 50); maxdz (largest height change between neighbours,
--   default 45); reach (cm: end within this horizontal distance of the target,
--   default 60); reach_dz (default 150); max_samples (default 6000);
--   radius (cm from start, default 4000); corridor (cm: only cells within this
--   distance of the straight line start->target, for short guided legs);
--   corner(a,b) -> true when Max can
--   step diagonally from cell a to cell b although a side cell is refused (a
--   Max-sized sweep); without it diagonals past a refused cell are not taken.
function M.new(start,target,opts)
    local s=setmetatable({},M)
    s.o=opts;s.start=start;s.target=target
    s.cell=opts.cell or 50;s.maxdz=opts.maxdz or 45;s.reach=opts.reach or 60;s.reach_dz=opts.reach_dz or 150
    local dist=math.sqrt((target.X-start.X)^2+(target.Y-start.Y)^2)
    s.max_samples=opts.max_samples or 12000
    -- The search area always contains the target, with room to go round.
    s.radius=math.max(opts.radius or 4000,dist+2000)
    s.why={};s.blockers={};s.step_rejects=0
    s.corridor=opts.corridor
    s.best_d=math.huge -- closest reached cell to the target (cm, horizontal)
    s.samples=0;s.z={};s.g={};s.parent={};s.closed={};s.open={}
    s.ti=(target.X-start.X)/s.cell;s.tj=(target.Y-start.Y)/s.cell
    local k="0,0";s.z[k]=start.Z;s.g[k]=0
    push(s.open,{s:h(0,0),0,0})
    s.state="running"
    return s
end
-- Horizontal distance from (x,y) to the segment a-b.
function M.segment_distance(x,y,a,b)
    local dx,dy=b.X-a.X,b.Y-a.Y
    local len2=dx*dx+dy*dy
    local t=len2>0 and ((x-a.X)*dx+(y-a.Y)*dy)/len2 or 0
    t=math.max(0,math.min(1,t))
    return math.sqrt((x-a.X-dx*t)^2+(y-a.Y-dy*t)^2)
end
function M:h(i,j)
    local di,dj=math.abs(self.ti-i),math.abs(self.tj-j)
    return (math.max(di,dj)-math.min(di,dj))+SQRT2*math.min(di,dj)
end
function M:pos(i,j)return self.start.X+i*self.cell,self.start.Y+j*self.cell end
-- Ground z of a cell (sampled once), or false.
function M:ground(i,j,zref)
    local k=i..","..j
    local z=self.z[k]
    if z==nil then
        local x,y=self:pos(i,j)
        if (x-self.start.X)^2+(y-self.start.Y)^2>self.radius^2 then z=false;self.why.radius=(self.why.radius or 0)+1
        elseif self.corridor and M.segment_distance(x,y,self.start,self.target)>self.corridor then z=false;self.why.corridor=(self.why.corridor or 0)+1
        else
            self.samples=self.samples+1
            local why
            z,why=self.o.sample(x,y,zref)
            if not z then
                z=false;why=why or "refused"
                local kind,who=why:match("^(%w+):(.+)$")
                if kind then self.blockers[who]=(self.blockers[who] or 0)+1;why=kind end
                self.why[why]=(self.why[why] or 0)+1
            end
            if z==false and not why then self.why.refused=(self.why.refused or 0)+1 end
        end
        self.z[k]=z
    end
    return z
end
function M:is_goal(i,j,z)
    local x,y=self:pos(i,j)
    return (x-self.target.X)^2+(y-self.target.Y)^2<=self.reach^2 and math.abs(z-self.target.Z)<=self.reach_dz
end
-- Runs until `budget` new cells have been sampled, or the search ends.
-- Returns state: "running", "found" (self.path set) or "failed" (self.reason).
function M:step(budget)
    if self.state~="running" then return self.state end
    local stop_at=self.samples+(budget or 50)
    while self.samples<stop_at do
        if #self.open==0 then self.state="failed";self.reason="no_path";return self.state end
        if self.samples>=self.max_samples then self.state="failed";self.reason="too_far";return self.state end
        local n=pop(self.open)
        local i,j=n[2],n[3];local k=i..","..j
        if not self.closed[k] then
            self.closed[k]=true
            local z=self.z[k]
            local x,y=self:pos(i,j)
            local d=math.sqrt((x-self.target.X)^2+(y-self.target.Y)^2)
            if d<self.best_d then self.best_d=d end
            if self:is_goal(i,j,z) then self:finish(i,j);return self.state end
            for _,d in ipairs(DIRS) do
                local ni,nj=i+d[1],j+d[2]
                local nk=ni..","..nj
                if not self.closed[nk] then
                    local nz=self:ground(ni,nj,z)
                    local ok=nz and math.abs(nz-z)<=self.maxdz
                    if nz and not ok then self.step_rejects=self.step_rejects+1 end
                    -- No corner cutting: a diagonal needs both side cells open.
                    if ok and d[3]>1 then
                        local a=self:ground(i+d[1],j,z);local b=self:ground(i,j+d[2],z)
                        local sides=a and b and math.abs(a-z)<=self.maxdz and math.abs(b-z)<=self.maxdz
                        if not sides then
                            -- A refused side cell need not touch Max's actual path: ask.
                            ok=false
                            if self.o.corner then
                                local x0,y0=self:pos(i,j);local x1,y1=self:pos(ni,nj)
                                self.samples=self.samples+1
                                ok=self.o.corner({X=x0,Y=y0,Z=z},{X=x1,Y=y1,Z=nz})==true
                            end
                        end
                    end
                    if ok then
                        local g=self.g[k]+d[3]
                        if self.g[nk]==nil or g<self.g[nk] then
                            self.g[nk]=g;self.parent[nk]=k
                            push(self.open,{g+self:h(ni,nj),ni,nj})
                        end
                    end
                end
            end
        end
    end
    return self.state
end
function M:finish(i,j)
    local pts={};local k=i..","..j
    while k do
        local a,b=k:match("^(-?%d+),(-?%d+)$");a,b=tonumber(a),tonumber(b)
        local x,y=self:pos(a,b)
        table.insert(pts,1,{X=x,Y=y,Z=self.z[k]})
        k=self.parent[k]
    end
    pts[1]={X=self.start.X,Y=self.start.Y,Z=self.start.Z}
    self.path=pts;self.state="found"
end
-- Is the straight line a->b over known open cells only, with no height change
-- above maxdz between consecutive samples? (No game calls: uses the cells the
-- search already sampled; an unsampled cell counts as not open.)
function M:line_open(a,b)
    local dx,dy=b.X-a.X,b.Y-a.Y
    local n=math.max(1,math.ceil(math.sqrt(dx*dx+dy*dy)/(self.cell/2)))
    local prev=nil
    for s=0,n do
        local x,y=a.X+dx*s/n,a.Y+dy*s/n
        local i=math.floor((x-self.start.X)/self.cell+0.5);local j=math.floor((y-self.start.Y)/self.cell+0.5)
        local z=self.z[i..","..j]
        if not z then return false end
        if prev and math.abs(z-prev)>self.maxdz then return false end
        prev=z
    end
    return true
end
-- Lines describing a finished search: refusal reasons, top blockers, the
-- explored area, and a 1 m map ('#' reached, 'o' open but not reached, 'X'
-- blocked, '_' no ground, '/' too steep, 'S' start, 'T' target).
function M:report(max_cols)
    local out={}
    local w={};for k,v in pairs(self.why) do w[#w+1]=k.."="..v end;table.sort(w)
    local b={};for k,v in pairs(self.blockers) do b[#b+1]={k,v} end;table.sort(b,function(x,y)return x[2]>y[2] end)
    local bs={};for i=1,math.min(8,#b) do bs[#bs+1]=b[i][1].."="..b[i][2] end
    out[#out+1]=string.format("grid_report state=%s reason=%s cell=%d reach=%d samples=%d radius=%.0f closest=%.0f step_rejects=%d refused=%s blockers=%s",
        self.state,tostring(self.reason),self.cell,self.reach,self.samples,self.radius,self.best_d,self.step_rejects,table.concat(w,","),table.concat(bs,","))
    -- Every sampled cell within reach+100 cm of the target: distance, and its
    -- ground height relative to the target, or why it was refused.
    local near={}
    for k,z in pairs(self.z) do
        local a,c=k:match("^(-?%d+),(-?%d+)$")
        if a then
            local x,y=self:pos(tonumber(a),tonumber(c))
            local d=math.sqrt((x-self.target.X)^2+(y-self.target.Y)^2)
            if d<=self.reach+100 then near[#near+1]={d,z and string.format("%.0f:dz%+.0f%s",d,z-self.target.Z,self.closed[k] and "r" or "") or string.format("%.0f:no",d)} end
        end
    end
    table.sort(near,function(p,q)return p[1]<q[1] end)
    local ns={};for i=1,math.min(16,#near) do ns[#ns+1]=near[i][2] end
    out[#out+1]="grid_target cells="..#near.." "..table.concat(ns," ")
    local i0,i1,j0,j1=math.huge,-math.huge,math.huge,-math.huge
    local zlo,zhi=math.huge,-math.huge
    for k in pairs(self.closed) do
        local a,c=k:match("^(-?%d+),(-?%d+)$");a,c=tonumber(a),tonumber(c)
        i0=math.min(i0,a);i1=math.max(i1,a);j0=math.min(j0,c);j1=math.max(j1,c)
        local z=self.z[k];if z then zlo=math.min(zlo,z);zhi=math.max(zhi,z) end
    end
    if i0==math.huge then return out end
    local ti,tj=math.floor(self.ti+0.5),math.floor(self.tj+0.5)
    i0=math.min(i0,ti)-4;i1=math.max(i1,ti)+4;j0=math.min(j0,tj)-4;j1=math.max(j1,tj)+4
    local step=math.max(2,math.ceil((j1-j0+1)/(max_cols or 100)))
    local x0,y0=self:pos(i0,j0);local x1,y1=self:pos(i1,j1)
    out[#out+1]=string.format("grid_area x=%.0f..%.0f y=%.0f..%.0f reached_z=%.0f..%.0f map_cell=%dcm rows=north_first cols=west_to_east",x0,x1,y0,y1,zlo,zhi,step*self.cell)
    for i=i1,i0,-step do
        local row={}
        for j=j0,j1,step do
            local ch=" "
            if math.abs(i-ti)<step/2+0.5 and math.abs(j-tj)<step/2+0.5 then ch="T"
            elseif math.abs(i)<step/2+0.5 and math.abs(j)<step/2+0.5 then ch="S"
            else
                local k=i..","..j;local z=self.z[k]
                if self.closed[k] then ch="#" elseif z then ch="o" elseif z==false then ch="X" end
            end
            row[#row+1]=ch
        end
        out[#out+1]="grid_map "..table.concat(row)
    end
    return out
end
-- Shortens a path: keeps a point only where the straight walk from the last
-- kept point to the next one is not clear. clear(a,b) -> true when Max can
-- walk straight from a to b. Returns the waypoints after the start.
function M.shorten(path,clear)
    if #path<=2 then return {path[#path]} end
    local out={};local anchor=path[1];local k=2
    while k<#path do
        if clear(anchor,path[k+1]) then k=k+1
        else out[#out+1]=path[k];anchor=path[k];k=k+1 end
    end
    out[#out+1]=path[#path]
    return out
end
-- The search's own path, shortened with its cells plus an injected sweep.
function M:waypoints(sweep)
    return M.shorten(self.path,function(a,b)return self:line_open(a,b) and (not sweep or sweep(a,b)) end)
end
return M
