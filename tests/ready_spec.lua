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

    it("waits while mounted unless the option is off", function()
        W.world.mounted = true
        W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        local function blocked()
            for _, b in ipairs(ns.Ready:GetBlockers()) do if b.key == "mounted" then return true end end
            return false
        end
        assert.is_true(ns.db.profile.noSummonMounted)
        assert.is_true(blocked())
        ns.db.profile.noSummonMounted = false
        ns.Ready:UpdateChecks()
        assert.is_false(blocked())
        ns.db.profile.noSummonMounted = true
        ns.Ready:UpdateChecks()
        W.world.mounted = false
        W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        assert.is_false(blocked())
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

    it("leaves a hidden (secret) aura payload alone and reads the auras after combat", function()
        local SECRET = {}
        issecretvalue = function(v) return v == SECRET end
        local n = 0
        ns:RegisterCallback({}, "ReadyChanged", function() n = n + 1 end)
        W.world.auras[5384] = true                 -- feign death
        W.fire("PLAYER_REGEN_DISABLED")
        n = 0
        W.fire("UNIT_AURA", "player", { isFullUpdate = SECRET, addedAuras = SECRET })
        assert.equal(0, n)
        W.fire("PLAYER_REGEN_ENABLED")
        local feigned = false
        for _, b in ipairs(ns.Ready:GetBlockers()) do if b.key == "feigned" then feigned = true end end
        assert.is_true(feigned)
        issecretvalue = nil
    end)

    it("leaves hidden (secret) AFK and resting flags alone", function()
        local SECRET = {}
        issecretvalue = function(v) return v == SECRET end
        ns.db.profile.disableOutsideCities = true
        ns.Ready:UpdateChecks()
        W.world.resting = false
        W.fire("PLAYER_FLAGS_CHANGED", "player")
        assert.is_true(ns.Ready.is_false.resting)
        W.world.afk, W.world.resting = SECRET, SECRET
        W.fire("PLAYER_FLAGS_CHANGED", "player")
        assert.is_nil(ns.Ready.is_false.sitting)
        assert.is_true(ns.Ready.is_false.resting)
        local ctx = ns.Conditions.Context()
        assert.is_false(ctx.afk)
        assert.is_false(ctx.resting)
        issecretvalue = nil
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
    it("profile switch applies the new profile's auto-summon setting", function()
        PetCall3DB.profiles.Off = { enable = false }
        ns.DB:Set("Off")
        assert.is_true(ns.Ready.is_false.addon_enabled)
        ns.DB:Set("Default")
        assert.is_nil(ns.Ready.is_false.addon_enabled)
    end)

    it("ignores other players' flag changes", function()
        ns.Ready.afk_message = "brb"
        W.fire("PLAYER_FLAGS_CHANGED", "raid7")
        assert.equal("brb", ns.Ready.afk_message)
        local n = 0
        local w = ns.Conditions.NewWatcher({ { "specialLocation", locs = { "city" } } }, function() end)
        w.Refresh = function() n = n + 1 end
        W.fire("PLAYER_FLAGS_CHANGED", "raid7")
        assert.equal(0, n)
        W.fire("PLAYER_FLAGS_CHANGED", "player")
        assert.equal(1, n)
        w:Free()
    end)
end)
