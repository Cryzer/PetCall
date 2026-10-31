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

    it("only after a loading screen: walking into a new zone counts, like a loading screen", function()
        ns.db.profile.nearPEWOnly = true
        W.advance(20)                            -- the login's window has closed
        summons = 0
        W.advance(5)
        assert.equal(0, summons, "outside the window no pet comes by itself")
        W.world.zone = "Westfall"
        W.fire("ZONE_CHANGED_NEW_AREA")          -- Elwynn Forest to Westfall: no loading screen
        W.advance(ns.db.profile.waitTimer + 1)
        assert.is_true(summons >= 1)
        W.advance(20)
        summons = 0
        W.advance(5)
        assert.equal(0, summons, "and the window closes again")
    end)

    it("only after a loading screen: a pet the game took comes back once", function()
        ns.db.profile.nearPEWOnly = true
        W.advance(20)
        W.world.summoned = "a"
        W.fire("COMPANION_UPDATE", "CRITTER")
        W.world.dead = true
        W.fire("PLAYER_DEAD")
        W.world.summoned = nil
        W.fire("COMPANION_UPDATE", "CRITTER")
        W.advance(20)
        summons = 0
        W.world.dead = false
        W.fire("PLAYER_UNGHOST")
        W.advance(ns.db.profile.waitTimer + 1)
        assert.equal(1, summons)
        W.advance(20)
        assert.equal(1, summons, "once")
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
        W.world.afk, W.world.resting = SECRET, SECRET
        W.fire("PLAYER_FLAGS_CHANGED", "player")
        assert.is_nil(ns.Ready.is_false.sitting)
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
        local ok, cause = ns.Gate:Check("summon", "auto")
        assert.is_false(ok)
        assert.equal("auto", cause.level)
        ns.DB:Set("Default")
        assert.is_true((ns.Gate:Check("summon", "auto")))
    end)

    it("blocks only on the game: preferences are not blockers", function()
        local p = ns.db.profile
        p.nearPEWOnly = true
        p.exceptions.builtin.outsideCities, p.exceptions.builtin.bg, p.exceptions.builtin.dungeon = "alone", "away", "alone"
        ns.Exceptions:Reload()
        ns:SetAutoSummon(false)
        ns.Ready:UpdateChecks()
        W.world.mounted, W.world.resting, W.world.instanceType, W.world.inGroup = true, false, "pvp", true
        W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        W.fire("ZONE_CHANGED_NEW_AREA")
        W.fire("PLAYER_ENTERING_WORLD")
        W.fire("PLAYER_FLAGS_CHANGED", "player")
        W.advance(20)
        assert.equal(0, #ns.Ready:GetBlockers())
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

describe("Ready: pet battles and sitting", function()
    local ns
    before_each(function()
        W.reset()
        W.world.pets = { a = { species = 1, name = "A" }, b = { species = 2, name = "B" } }
        ns = W.load()
        W.login()
        W.advance(1)
    end)
    local function printed(text)
        for _, m in ipairs(W.world.printed) do if m:find(text, 1, true) then return true end end
        return false
    end
    local function count(text)
        local n = 0
        for _, m in ipairs(W.world.printed) do if m:find(text, 1, true) then n = n + 1 end end
        return n
    end

    it("a pet battle blocks both sources", function()
        W.fire("PET_BATTLE_OPENING_START")
        for _, source in ipairs({ "auto", "explicit" }) do
            local ok, cause = ns.Gate:Check("summon", source)
            assert.is_false(ok)
            assert.equal("game", cause.level)
            assert.equal("pet_battle", cause.key)
            assert.equal("In a pet battle", cause.label)
        end
        W.fire("PET_BATTLE_CLOSE")
        assert.is_true((ns.Gate:Check("summon", "explicit")))
        assert.is_true((ns.Gate:Check("summon", "auto")))
    end)

    it("a pet the battle took is not a pet you dismissed", function()
        W.world.summoned = "a"
        W.fire("COMPANION_UPDATE", "CRITTER")
        W.fire("PET_BATTLE_OPENING_START")
        W.world.summoned = nil
        W.fire("COMPANION_UPDATE", "CRITTER")
        assert.equal("on", ns:GetAutoState())
    end)

    it("/sit and /stand are noticed", function()
        DoEmote("SIT")
        assert.is_not_nil(ns.Ready.is_false.sitting)
        DoEmote("STAND")
        assert.is_nil(ns.Ready.is_false.sitting)
        DoEmote("DANCE")
        assert.is_nil(ns.Ready.is_false.sitting)
        DoEmote("SIT")
        SitStandOrDescendStart()
        assert.is_nil(ns.Ready.is_false.sitting, "the key still toggles")
    end)

    it("/sit is noticed in any case, and not while flying or mounted", function()
        DoEmote("sit")
        assert.is_not_nil(ns.Ready.is_false.sitting)
        DoEmote("stand")
        assert.is_nil(ns.Ready.is_false.sitting)
        DoEmote(nil)
        DoEmote(12)
        W.world.mounted = true
        DoEmote("SIT")
        assert.is_nil(ns.Ready.is_false.sitting)
        W.world.mounted, W.world.flying = false, true
        DoEmote("SIT")
        assert.is_nil(ns.Ready.is_false.sitting)
    end)

    it("an explicit summon learns from the standing error and waits", function()
        ns:SummonPet("a")
        assert.equal("a", W.world.summoned)
        W.world.summoned = nil
        W.fire("UI_ERROR_MESSAGE", 999, ERR_MUST_BE_STANDING)
        assert.is_not_nil(ns.Ready.is_false.sitting)
        assert.equal(1, count("Stand up and your pet comes out."))
        W.advance(5)
        assert.is_nil(W.world.summoned, "nothing is tried while sitting")
        W.fire("PLAYER_STARTED_MOVING")
        W.advance(2)
        assert.equal("a", W.world.summoned)
        assert.equal(1, count("Stand up and your pet comes out."))
    end)

    it("an explicit summon while sitting says so once instead of naming the blocker", function()
        DoEmote("SIT")
        ns:SummonPet("a")
        assert.equal(1, count("Stand up and your pet comes out."))
        assert.is_false(printed("when this ends"))
    end)

    it("PetCall's own summon does not show the standing error", function()
        local frame = UIErrorsFrame
        local seen
        local summon = C_PetJournal.SummonPetByGUID
        C_PetJournal.SummonPetByGUID = function(id)
            seen = frame:IsEventRegistered("UI_ERROR_MESSAGE")
            summon(id)
        end
        ns.Summon:SummonPick("a")
        assert.is_false(seen, "hidden during the call")
        assert.is_false(frame:IsEventRegistered("UI_ERROR_MESSAGE"))
        W.advance(0.1)
        assert.is_true(frame:IsEventRegistered("UI_ERROR_MESSAGE"), "back on the next frame")
    end)

    it("the standing error stays visible in combat and while Ready thinks you sit", function()
        local frame = UIErrorsFrame
        local seen
        local summon = C_PetJournal.SummonPetByGUID
        C_PetJournal.SummonPetByGUID = function(id)
            seen = frame:IsEventRegistered("UI_ERROR_MESSAGE")
            summon(id)
        end
        W.world.combat = true
        ns.Summon:SummonPick("a")
        assert.is_true(seen)
        W.world.combat = false
        W.world.summoned = nil
        DoEmote("SIT")
        ns.Summon:SummonPick("a")
        assert.is_true(seen)
    end)
end)

describe("Ready: at load", function()
    it("a reload inside a pet battle knows it is in one", function()
        W.reset()
        W.world.petBattle = true
        local ns = W.load()
        W.login()
        assert.is_not_nil(ns.Ready.is_false.pet_battle)
    end)
end)
