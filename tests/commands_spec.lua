local W = dofile("tests/wowstub.lua")
describe("Commands", function()
    it("dispatches 1.x subcommands case-insensitively", function()
        W.reset()
        W.world.pets = { a = { species = 1, name = "A" } }
        local ns = W.load()
        W.login()
        W.advance(1)
        ns.OpenWindow = function() W.world.opened = true end
        SlashCmdList.PETCALL("")
        assert.is_true(W.world.opened)
        SlashCmdList.PETCALL("ENABLE")
        assert.is_false(ns:IsAutoSummon())
        SlashCmdList.PETCALL("dismissWhenStealthed")
        assert.is_true(ns.db.profile.dismissWhenStealthed)
        local before = #W.world.printed
        SlashCmdList.PETCALL("debugstate")
        SlashCmdList.PETCALL("holidays")
        assert.is_true(#W.world.printed - before >= 5)
        SlashCmdList.PETCALL("nope")
        assert.is_true(W.world.printed[#W.world.printed]:find("Unknown command") ~= nil)
    end)

    it("pseudo saves longer test texts for the next load, which lengthens texts files keep from loading", function()
        W.reset()
        local ns = W.load()
        W.login()
        local reloads = 0
        ReloadUI = function() reloads = reloads + 1 end
        SlashCmdList.PETCALL("pseudo")
        assert.is_true(PetCall3DB.global.pseudo)
        assert.equal(1, reloads)
        assert.equal("Often", ns.Weights.Label(8))
        local saved = PetCall3DB
        W.reset()
        PetCall3DB = saved                     -- LoadSavedVariablesFirst: there before the files
        ns = W.load()
        W.login()
        assert.equal(ns.Pseudo("Often"), ns.Weights.Label(8))
        assert.equal(ns.Pseudo("Not in the locale file"), ns.L["Not in the locale file"])
        SlashCmdList.PETCALL("pseudo")
        assert.is_nil(PetCall3DB.global.pseudo)
        ReloadUI = nil
    end)
end)
