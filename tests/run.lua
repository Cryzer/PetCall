-- Usage: lua5.1 tests/run.lua   or   python tools/lua.py tests/run.lua
package.path = "./?.lua;" .. package.path
local T = dofile("tests/lib/minitest.lua")
local specs = {
    "tests/smoke_spec.lua",
    "tests/addon_spec.lua",
    "tests/locale_spec.lua",
    "tests/db_spec.lua",
    "tests/upgrade_spec.lua",
    "tests/petcache_spec.lua",
    "tests/expansions_spec.lua",
    "tests/weights_spec.lua",
    "tests/autorules_spec.lua",
    "tests/sets_spec.lua",
    "tests/exceptions_spec.lua",
    "tests/recipes_spec.lua",
    "tests/ui_spec.lua",
    "tests/petgrid_spec.lua",
    "tests/ready_spec.lua",
    "tests/gate_spec.lua",
    "tests/recommended_spec.lua",
    "tests/conditions_spec.lua",
    "tests/summon_spec.lua",
    "tests/specialitems_spec.lua",
    "tests/share_spec.lua",
    "tests/migrate_spec.lua",
    "tests/localekeys_spec.lua",
    "tests/translations_spec.lua",
    "tests/commands_spec.lua",
    "tests/menu_spec.lua",
    "tests/glyphs_spec.lua",
    "tests/layout_spec.lua",      -- last: it replaces CreateFrame and a few globals for measuring
}
if arg and arg[1] then specs = { arg[1] } end
for _, file in ipairs(specs) do
    local ok, err = pcall(dofile, file)
    if not ok then
        T.results.failed = T.results.failed + 1
        T.results.errors[#T.results.errors + 1] = file .. ": " .. tostring(err)
    end
end
for _, e in ipairs(T.results.errors) do print("FAIL " .. e) end
print(string.format("%d passed, %d failed", T.results.passed, T.results.failed))
return T.results.failed == 0 and 0 or 1
