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
        local before = #W.world.printed
        SlashCmdList.PETCALL("debugstate")
        SlashCmdList.PETCALL("holidays")
        assert.is_true(#W.world.printed - before >= 5)
        SlashCmdList.PETCALL("nope")
        assert.is_true(W.world.printed[#W.world.printed]:find("Unknown command") ~= nil)
    end)

    it("help says what the pet commands do to Auto-summon", function()
        W.reset()
        local ns = W.load()
        W.login()
        local help = table.concat(ns.Commands:HelpLines(), "\n")
        assert.is_true(help:find("/pcall resummon – Summon another pet\n", 1, true) ~= nil, help)
        assert.is_true(help:find("/pcall dismiss – Dismiss your pet; Auto-summon pauses until you change zone", 1, true) ~= nil, help)
        assert.is_true(help:find("/pcall togglePet – Summon or dismiss your pet", 1, true) ~= nil, help)
        assert.is_true(help:find("/pcall enable – Toggle auto-summon", 1, true) ~= nil, help)
    end)

    it("the pet commands pause and resume; only enable turns Auto-summon off", function()
        W.reset()
        W.world.pets = { a = { species = 1, name = "A" }, b = { species = 2, name = "B" } }
        local ns = W.load()
        W.login()
        W.advance(1)
        W.world.summoned = "a"
        SlashCmdList.PETCALL("dismiss")
        assert.is_nil(W.world.summoned)
        assert.equal("paused", ns:GetAutoState())
        SlashCmdList.PETCALL("togglePet")
        assert.is_not_nil(W.world.summoned)
        assert.equal("on", ns:GetAutoState())
        SlashCmdList.PETCALL("togglePet")
        assert.equal("paused", ns:GetAutoState())
        SlashCmdList.PETCALL("resummon")
        assert.is_not_nil(W.world.summoned)
        assert.equal("on", ns:GetAutoState())
        SlashCmdList.PETCALL("enable")
        assert.equal("off", ns:GetAutoState())
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

    it("profile names every slow part of PetCall in chat, from the next load on", function()
        W.reset()
        local ns = W.load()
        W.login()
        local reloads = 0
        ReloadUI = function() reloads = reloads + 1 end
        local function slow(ms) return function() W.world.ms = (W.world.ms or 0) + ms end end
        ns.Events.Register({}, "BAG_UPDATE", slow(30))
        W.fire("BAG_UPDATE")
        for _, m in ipairs(W.world.printed) do assert.is_nil(m:find(" ms", 1, true), "off: nothing is timed") end
        SlashCmdList.PETCALL("profile")
        assert.is_true(PetCall3DB.global.profile)
        assert.equal(1, reloads)
        local saved = PetCall3DB
        W.reset()
        PetCall3DB = saved
        ns = W.load()
        W.login()
        ReloadUI = function() reloads = reloads + 1 end
        local function last() return W.world.printed[#W.world.printed] end
        local before = #W.world.printed
        ns.Events.Register({ name = "Bags" }, "BAG_UPDATE", slow(2))
        W.fire("BAG_UPDATE")
        assert.equal(before, #W.world.printed, "quick parts stay quiet")
        ns.Events.Register({ name = "Bags" }, "BAG_UPDATE", slow(30))
        W.fire("BAG_UPDATE")
        assert.is_true(last():find("30 ms", 1, true) ~= nil, last())
        assert.is_true(last():find("BAG_UPDATE", 1, true) ~= nil, last())
        assert.is_true(last():find("commands_spec.lua:%d+") ~= nil, last())
        ns:RegisterCallback({}, "SomethingChanged", slow(12))
        ns:Fire("SomethingChanged")
        assert.is_true(last():find("SomethingChanged", 1, true) ~= nil, last())
        ns:After(1, slow(40))
        W.advance(1)
        assert.is_true(last():find("40 ms", 1, true) ~= nil, last())
        local tick = ns.Debounce(0.1, slow(25))
        tick()
        W.advance(1)
        assert.is_true(last():find("25 ms", 1, true) ~= nil, last())
        SlashCmdList.PETCALL("profile")
        assert.is_nil(PetCall3DB.global.profile)
        assert.equal(2, reloads)
        ReloadUI = nil
    end)
end)
