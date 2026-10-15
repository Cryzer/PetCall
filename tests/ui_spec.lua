-- Smoke tests: UI files load and the main flows run without Lua errors.
local U = dofile("tests/uistub.lua")
local W = U.W

describe("UI smoke", function()
    local ns
    before_each(function()
        ns = U.load()
        W.world.pets = { a = { species = 1, name = "A" } }
        W.login()
        W.advance(1)
    end)

    it("opens, switches tabs and closes the main window", function()
        assert.has_no_error(function()
            ns.Commands:Handle("")
            assert.is_true(ns.UI.Main:GetFrame():IsShown())
            ns.UI.Main:SelectTab("pets")
            ns.UI.Main:SelectSet("$Default")
            ns.UI.Main:Toggle()
        end)
        assert.is_false(ns.UI.Main:GetFrame():IsShown())
    end)
end)
