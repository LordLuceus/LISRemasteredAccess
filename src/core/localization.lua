-- Mod announcement text. The game's own labels arrive already translated; this
-- only covers text the mod itself adds. Catalogs are lang/<code>.lua files (lang/pt_br.lua for pt-BR).
-- Lookup: exact game language (e.g. pt-br), then its base (pt), then English.
-- A key missing even from English is a bug: it is logged and spoken as a
-- clearly marked placeholder, never silently replaced with other text.
local M={}
local english=require("lang.en")
local active,active_code=english,"en"
local reported={}
local log=function(line)print("[LISNavTick] "..line.."\n")end

local function load(code)
    if code=="en" then return english end
    local ok,catalog=pcall(require,"lang."..code)
    if ok and type(catalog)=="table" then return catalog end
    return nil
end
local function normalise(code)
    if type(code)~="string" then return nil end
    code=string.lower(code):gsub("[^%a%-_]",""):gsub("_","-")
    return code~="" and code or nil
end

function M.set_logger(fn)log=fn end
-- Follows the game's language. Returns the catalog code actually used.
function M.set_language(game_code)
    local code=normalise(game_code)
    local chosen,chosen_code=english,"en"
    if code then
        local exact=load(code:gsub("%-","_"))
        local base=code:match("^(%a+)")
        if exact then chosen,chosen_code=exact,code
        elseif base and load(base) then chosen,chosen_code=load(base),base end
    end
    if chosen_code~=active_code then log("language catalog="..chosen_code.." game="..tostring(game_code)) end
    active,active_code=chosen,chosen_code
    return active_code
end
function M.language()return active_code end

-- text(key, {name=value}) substitutes {name}. Unknown placeholders stay
-- visible and are logged, so a broken string is noticed rather than misread.
function M.text(key,params)
    local s=active[key]
    if s==nil and active~=english then s=english[key] end
    if s==nil then
        if not reported[key] then reported[key]=true;log("localization_missing key="..tostring(key)) end
        return "[missing text: "..tostring(key).."]"
    end
    if params then
        s=s:gsub("{([%w_]+)}",function(name)
            local v=params[name]
            if v==nil then
                local id=tostring(key).."."..name
                if not reported[id] then reported[id]=true;log("localization_missing_param key="..id) end
                return "{"..name.."}"
            end
            return tostring(v)
        end)
    end
    return s
end
return M
