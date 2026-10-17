local W = dofile("tests/wowstub.lua")

describe("Addon core", function()
    local ns
    before_each(function()
        W.reset()
        ns = W.load()
    end)

    it("exposes the global", function()
        assert.equal(ns, PetCall)
    end)

    it("runs OnInitialize then OnEnable in creation order", function()
        local log = {}
        local a = ns:NewModule("A")
        function a:OnInitialize() log[#log + 1] = "Ai" end
        function a:OnEnable() log[#log + 1] = "Ae" end
        local b = ns:NewModule("B")
        function b:OnInitialize() log[#log + 1] = "Bi" end
        W.login()
        assert.same({ "Ai", "Bi", "Ae" }, log)
        assert.equal(a, ns:GetModule("A"))
    end)

    it("dispatches events to methods and functions", function()
        local m = ns:NewModule("M")
        local got = {}
        function m:ZONE_CHANGED(event, x) got[#got + 1] = event .. x end
        m:RegisterEvent("ZONE_CHANGED")
        m:RegisterEvent("PLAYER_DEAD", function(self, event) got[#got + 1] = event end)
        W.fire("ZONE_CHANGED", "!")
        W.fire("PLAYER_DEAD")
        m:UnregisterEvent("ZONE_CHANGED")
        W.fire("ZONE_CHANGED", "?")
        assert.same({ "ZONE_CHANGED!", "PLAYER_DEAD" }, got)
    end)

    it("delivers unit events only for the player", function()
        local m = ns:NewModule("U")
        local n = 0
        m:RegisterUnitEvent("UNIT_AURA", "player", function() n = n + 1 end)
        W.fire("UNIT_AURA", "raid3")
        W.fire("UNIT_AURA", "player")
        assert.equal(1, n)
    end)

    it("fires callbacks and unregisters owners", function()
        local owner, got = {}, nil
        ns:RegisterCallback(owner, "SetsChanged", function(o, name) got = name end)
        ns:Fire("SetsChanged", "X")
        assert.equal("X", got)
        ns:UnregisterAllCallbacks(owner)
        ns:Fire("SetsChanged", "Y")
        assert.equal("X", got)
    end)

    it("debounces", function()
        local n = 0
        local trigger = ns.Debounce(0.5, function() n = n + 1 end)
        trigger() trigger() trigger()
        W.advance(0.6)
        assert.equal(1, n)
    end)
    it("callbacks may come and go while one fires, and firing makes no garbage", function()
        local a, b, got = {}, {}, {}
        ns:RegisterCallback(a, "Ping", function()
            got[#got + 1] = "a"
            ns:UnregisterCallback(b, "Ping")              -- still called this time
            ns:RegisterCallback({}, "Ping", function() got[#got + 1] = "late" end)
        end)
        ns:RegisterCallback(b, "Ping", function() got[#got + 1] = "b" end)
        ns:Fire("Ping")
        table.sort(got)
        assert.same({ "a", "b" }, got)
        ns:UnregisterAllCallbacks(a)
        local quiet = {}
        ns:RegisterCallback(quiet, "Quiet", function() end)
        collectgarbage("collect")
        collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 2000 do ns:Fire("Quiet", 1, 2) end
        local grown = collectgarbage("count") - before
        collectgarbage("restart")
        assert.is_true(grown < 4, grown .. " KB")
    end)
end)
