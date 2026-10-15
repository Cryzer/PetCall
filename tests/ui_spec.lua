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
    it("pets tab builds, rebuilds and survives resizing", function()
        assert.has_no_error(function()
            ns.UI.Main:Show()
            ns.UI.Main:SelectTab("pets")
            local set = ns.Sets:Get("$Default")
            set:SetPetWeight("a", 0)
            W.advance(1)
            ns:Fire("WindowResized", 700, 500)
            ns:Fire("WindowResized", 900, 600)
            ns.UI.Preview:SetHover("a")
            ns.UI.Preview:SetSelected("a")
            ns.UI.Preview:SetHover(nil)
        end)
    end)
    it("auto rule chips render, open the editor and edit", function()
        assert.has_no_error(function()
            ns.UI.Main:Show()
            ns.UI.Main:SelectTab("pets")
            local set = ns.Sets:Get("$Default")
            set.settings.filter = { { "favorites", 64 }, { "AND", items = { { "OR", items = { { "favorites" } } } }, 1 } }
            ns.UI.AutoRulesBar:Refresh(set)
            local chips = ns.UI.AutoRulesBar._chips
            assert.is_true(chips[1]:IsShown())
            chips[1]:Click()      -- editor for a simple chip
            chips[2]:Click()      -- editor for a legacy chip
            chips[1]:Click()
            chips[1].remove:Click()
            assert.equal(1, #set.settings.filter)
        end)
    end)
end)
