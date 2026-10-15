local W = dofile("tests/wowstub.lua")
describe("Ready", function()
    local ns, summons
    before_each(function()
        W.reset()
        W.world.pets = { a = { species = 1, name = "A" } }
        ns = W.load()
        summons = 0
        W.login()
        W.advance(1)
        ns.Summon = ns.Summon or {}
        ns.Summon.SummonRandom = function() summons = summons + 1 return true end
    end)

    it("reports blockers with labels", function()
        W.world.combat = true
        W.fire("PLAYER_REGEN_DISABLED")
        local keys = {}
        for _, b in ipairs(ns.Ready:GetBlockers()) do keys[#keys + 1] = b.key end
        assert.is_true(table.concat(keys, ","):find("combat") ~= nil)
        assert.equal("In combat", ns.Ready:GetBlockers()[1].label)
    end)

    it("summons after the wait timer when nothing blocks", function()
        W.fire("PLAYER_REGEN_ENABLED")
        W.advance(ns.db.profile.waitTimer + 1)
        assert.is_true(summons >= 1)
    end)

    it("ignores aura updates of other units and no-op aura updates", function()
        local n = 0
        ns:RegisterCallback({}, "ReadyChanged", function() n = n + 1 end)
        W.world.auras[5384] = true                 -- feign death
        W.fire("UNIT_AURA", "party1", { isFullUpdate = true })
        assert.equal(0, n)
        W.fire("UNIT_AURA", "player", {})           -- nothing added/removed
        assert.equal(0, n)
        W.fire("UNIT_AURA", "player", { addedAuras = { {} } })
        assert.equal(1, n)
    end)

    it("detects sitting on a bench from the standing error text", function()
        ns.Ready._last_summon_time = W.world.time
        W.fire("UI_ERROR_MESSAGE", 999, ERR_MUST_BE_STANDING)
        local found = false
        for _, b in ipairs(ns.Ready:GetBlockers()) do if b.key == "sitting" then found = true end end
        assert.is_true(found)
    end)

    it("captures AFK messages through C_ChatInfo", function()
        C_ChatInfo.SendChatMessage("brb", "AFK")
        assert.equal("brb", ns.Ready.afk_message)
    end)

    it("blocks with no pets", function()
        W.world.pets = {}
        ns.PetCache:Rescan()
        local found = false
        for _, b in ipairs(ns.Ready:GetBlockers()) do if b.key == "have_pets" then found = true end end
        assert.is_true(found)
    end)
end)
