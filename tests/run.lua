-- Usage: lua5.1 tests/run.lua   or   python tools/lua.py tests/run.lua
package.path = "./?.lua;" .. package.path
local T = dofile("tests/lib/minitest.lua")
local specs = {
    "tests/smoke_spec.lua",
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
