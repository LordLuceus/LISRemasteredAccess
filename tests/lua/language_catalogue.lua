-- Catalogue structure and byte-for-byte preservation, independent of game APIs.
package.path = "src/?.lua;tests/lua/?.lua;" .. package.path
local count = 0
local function check(name, condition)
    count = count + 1
    assert(condition, name)
end
local catalog = require("lang.catalog")
local baseline = require("language_catalogue_baseline")
local english = require("lang.en")
local old_count, new_count = 0, 0
for key, value in pairs(baseline) do
    old_count = old_count + 1
    check("original bytes: " .. key, english[key] == value)
end
for key in pairs(english) do
    new_count = new_count + 1
    check("no extra key: " .. key, baseline[key] ~= nil)
end
check("frozen original count", old_count == 546 and new_count == 546)

-- Execute the actual index with only its merger intercepted, capturing its
-- manifest without duplicating that manifest in a second authoring location.
local code, manifest
local indexed = assert(loadfile("src/lang/en.lua", "t", {
    require = function(name)
        assert(name == "lang.catalog")
        return {load = function(language, modules)
            code, manifest = language, modules
            return catalog.load(language, modules)
        end}
    end,
}))()
check("English manifest language", code == "en")
local union, module_count = {}, 0
for _, relative in ipairs(manifest) do
    local content = require("lang.en." .. relative)
    local size = 0
    for key, value in pairs(content) do
        check("manifest key unique: " .. key, union[key] == nil)
        union[key], size = value, size + 1
        check("manifest value reaches index: " .. key, indexed[key] == value and english[key] == value)
    end
    check("nonempty module: " .. relative, size > 0)
    module_count = module_count + 1
end
check("split into interface and scene modules", module_count > 10)
for key in pairs(baseline) do check("manifest complete: " .. key, union[key] ~= nil) end

-- Mock modules exercise the same public merger as real catalogues. Restore all
-- package state even if a check fails, so this suite cannot taint later tests.
local saved_loaded, saved_preload = {}, {}
local function mock(name, loader)
    saved_loaded[name] = {package.loaded[name]}
    saved_preload[name] = {package.preload[name]}
    package.loaded[name] = nil
    package.preload[name] = loader
end
local function rejects(name, fragment, fn)
    local ok, message = pcall(fn)
    check(name, not ok and tostring(message):find(fragment, 1, true) ~= nil)
end
local old_localization = package.loaded["core.localization"]
local ok, failure = pcall(function()
    mock("lang.zz.good", function() return {arrived = "Arrivée.", starting = "Départ {cancel_key}."} end)
    mock("lang.zz.other", function() return {stopped = "Arrêt."} end)
    mock("lang.zz.duplicate", function() return {arrived = "Different."} end)
    mock("lang.zz.number", function() return {bad = 7} end)
    mock("lang.zz.key", function() return {[1] = "bad"} end)
    mock("lang.zz.scalar", function() return "bad" end)
    mock("lang.zz.empty_return", function() end)
    mock("lang.zz.metatable", function() return setmetatable({}, {__index = {hidden = "bad"}}) end)
    mock("lang.zz.broken", function() error("broken module") end)
    mock("lang.zz.empty", function() return {} end)
    local combined = catalog.load("zz", {"good", "other", "empty"})
    check("merge disjoint modules", combined.arrived == "Arrivée." and combined.stopped == "Arrêt.")
    rejects("duplicates name both modules", "lang.zz.duplicate (already in lang.zz.good)", function()
        catalog.load("zz", {"good", "duplicate"})
    end)
    rejects("repeated module rejected", "duplicate key", function() catalog.load("zz", {"good", "good"}) end)
    for _, name in ipairs({"number", "key"}) do
        rejects("non-string " .. name, "non-string key or value", function() catalog.load("zz", {name}) end)
    end
    for _, name in ipairs({"scalar", "empty_return", "metatable"}) do
        rejects("malformed " .. name, "must return a plain string table", function() catalog.load("zz", {name}) end)
    end
    rejects("module errors contextualized", "cannot load lang.zz.broken", function() catalog.load("zz", {"broken"}) end)
    rejects("missing module contextualized", "cannot load lang.zz.absent", function() catalog.load("zz", {"absent"}) end)
    rejects("invalid code", "invalid language code", function() catalog.load("../en", {}) end)
    rejects("invalid manifest", "manifest must be an ordered table", function() catalog.load("zz", false) end)
    rejects("manifest map", "consecutive integer indices", function() catalog.load("zz", {named = "good"}) end)
    rejects("manifest gap", "manifest has a gap", function() catalog.load("zz", {[2] = "good"}) end)
    for _, name in ipairs({"", "../good", ".good", "good.", "good..bad", false}) do
        rejects("invalid relative module " .. tostring(name), "invalid module name", function() catalog.load("zz", {name}) end)
    end
    check("empty manifest permitted for partial translation", next(catalog.load("zz", {})) == nil)

    mock("lang.zz", function() return catalog.load("zz", {"good"}) end)
    mock("lang.zz_zz.interface", function() return {arrived = "Exact {name}."} end)
    mock("lang.zz_zz", function() return catalog.load("zz_zz", {"interface"}) end)
    mock("lang.yy", function() return {arrived = "Legacy flat."} end)
    package.loaded["core.localization"] = nil
    local l = require("core.localization")
    local logged = {}
    l.set_logger(function(line) logged[#logged + 1] = line end)
    check("exact modular language", l.set_language("ZZ_zz") == "zz-zz")
    check("exact modular placeholder", l.text("arrived", {name = "Max"}) == "Exact Max.")
    check("exact gaps go to English, not base", l.text("starting", {cancel_key = "F8"}) == "Starting the navigation test. F8 stops it.")
    check("absent exact uses modular base", l.set_language("zz-AA") == "zz")
    check("base translated bytes", l.text("arrived") == "Arrivée.")
    check("base placeholder", l.text("starting", {cancel_key = "F8"}) == "Départ F8.")
    check("base missing key uses English", l.text("stopped") == baseline.stopped)
    check("missing parameter stays visible", l.text("starting", {}) == "Départ {cancel_key}.")
    check("missing parameter logged", logged[#logged]:find("localization_missing_param key=starting.cancel_key", 1, true) ~= nil)
    check("missing key marked", l.text("catalogue_test_absent") == "[missing text: catalogue_test_absent]")
    check("unknown language uses English", l.set_language("qx") == "en")
    check("English placeholder unchanged", l.text("starting", {cancel_key = "F8"}) == "Starting the navigation test. F8 stops it.")
    check("legacy flat table supported", l.set_language("yy") == "yy" and l.text("arrived") == "Legacy flat.")
end)
package.loaded["core.localization"] = old_localization
for name, value in pairs(saved_loaded) do package.loaded[name] = value[1] end
for name, value in pairs(saved_preload) do package.preload[name] = value[1] end
assert(ok, failure)
return count
