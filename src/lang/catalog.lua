-- Merge an explicitly ordered set of language modules into a flat catalogue.
-- Each relative name is resolved beneath lang.<code>; no discovery or overrides.
local M = {}

local function fail(message)
    error("language catalogue: " .. message, 3)
end

function M.load(code, modules)
    if type(code) ~= "string" or not code:match("^[%a][%w_]*$") then
        fail("invalid language code " .. tostring(code))
    end
    if type(modules) ~= "table" or getmetatable(modules) ~= nil then
        fail("lang." .. code .. " manifest must be an ordered table")
    end
    local count = 0
    for index in pairs(modules) do
        if type(index) ~= "number" or index < 1 or index % 1 ~= 0 then
            fail("lang." .. code .. " manifest must contain only consecutive integer indices")
        end
        count = count + 1
    end
    for index = 1, count do
        if rawget(modules, index) == nil then
            fail("lang." .. code .. " manifest has a gap at index " .. index)
        end
    end
    local merged, owners = {}, {}
    for index = 1, count do
        local relative = modules[index]
        if type(relative) ~= "string" or relative == "" or
            relative:find("[^%w_.]") or relative:find("..", 1, true) or
            relative:sub(1, 1) == "." or relative:sub(-1) == "." then
            fail("lang." .. code .. " invalid module name at index " .. index)
        end
        local name = "lang." .. code .. "." .. relative
        local ok, content = pcall(require, name)
        if not ok then fail("cannot load " .. name .. ": " .. tostring(content)) end
        if type(content) ~= "table" or getmetatable(content) ~= nil then
            fail(name .. " must return a plain string table")
        end
        for key, value in pairs(content) do
            if type(key) ~= "string" or type(value) ~= "string" then
                fail(name .. " has non-string key or value at " .. tostring(key))
            end
            if owners[key] then
                fail("duplicate key " .. key .. " in " .. name .. " (already in " .. owners[key] .. ")")
            end
            owners[key], merged[key] = name, value
        end
    end
    return merged
end

return M
