-- Lists every layout problem the checker finds, screen by screen, at the smallest and
-- the default window size, in English and in the pseudo-locale.
-- Usage: lua5.1 tests/layout_report.lua [screen name]   or   python tools/lua.py tests/layout_report.lua
package.path = "./?.lua;" .. package.path
local Layout = dofile("tests/layout.lua")
local Screens = dofile("tests/layout_screens.lua")

local SIZES = { { 640, 440 }, { 940, 640 } }
local total = 0
local seen = {}         -- a problem shows under the first screen it appears on
for _, screen in ipairs(Screens.list) do
    if not (arg and arg[1]) or screen.name == arg[1] then
        local found, order, placed = {}, {}, 0
        for _, pseudo in ipairs({ false, true }) do
            for _, size in ipairs(SIZES) do
                local ns, U = Layout.load({ pseudo = pseudo })
                Screens.World(U.W)
                U.W.login()
                local ok, err = pcall(function()
                    screen.open(ns, U)
                    Layout.SetWindowSize(ns, U, size[1], size[2])
                end)
                local tag = size[1] .. "x" .. size[2] .. (pseudo and " pseudo" or "")
                local problems, checked
                if ok then
                    problems, checked = Layout.Check(U, UIParent)
                    placed = math.max(placed, checked)
                else
                    problems = { "could not open: " .. tostring(err) }
                end
                for _, p in ipairs(problems) do
                    if not seen[p] or seen[p] == screen then
                        seen[p] = screen
                        if not found[p] then found[p] = {} order[#order + 1] = p end
                        table.insert(found[p], tag)
                    end
                end
            end
        end
        print(string.format("== %s: %d problems (%d objects placed)", screen.name, #order, placed))
        for _, p in ipairs(order) do print("  " .. p .. "   [" .. table.concat(found[p], ", ") .. "]") end
        total = total + #order
    end
end
print(string.format("%d problems", total))
return 0
