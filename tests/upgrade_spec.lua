local W = dofile("tests/wowstub.lua")

describe("Upgrade", function()
    local ns, global
    local function up(profile)
        ns.Upgrade.Profile(profile, global)
        return profile
    end
    local function own(p) return p.exceptions.own end
    local function fact(p, name)
        for _, f in ipairs(p.upgradeFacts.converted) do if f.set == name then return f end end
    end
    local RAID = { { "specialLocation", locs = { "raid" } } }
    local CITY = { { "specialLocation", locs = { "city" } } }

    before_each(function()
        W.reset()
        ns = W.load()
        global = {}
    end)

    it("verbose goes to Default's message on summon", function()
        assert.equal("off", up({ verbose = false }).sets["$Default"].announce)
        assert.equal("on", up({ verbose = true }).sets["$Default"].announce)
        assert.is_nil(up({ verbose = false }).verbose)
    end)

    it("the timed switch goes to Default's new pet every", function()
        local p = up({ autoSwitch = { timer = true, timerValue = 15 * 60 } })
        assert.equal(15, p.sets["$Default"].switchMinutes)
        assert.equal(0, up({ autoSwitch = { timer = false, timerValue = 15 * 60 } }).sets["$Default"].switchMinutes)
        assert.equal(30, up({ autoSwitch = { timer = true } }).sets["$Default"].switchMinutes)
        assert.is_nil(p.autoSwitch)
        -- whole minutes from 1 to 60; anything else is the old 30
        assert.equal(2, up({ autoSwitch = { timer = true, timerValue = 100 } }).sets["$Default"].switchMinutes)
        assert.equal(1, up({ autoSwitch = { timer = true, timerValue = 5 } }).sets["$Default"].switchMinutes)
        assert.equal(60, up({ autoSwitch = { timer = true, timerValue = 99999 } }).sets["$Default"].switchMinutes)
        assert.equal(30, up({ autoSwitch = { timer = true, timerValue = "x" } }).sets["$Default"].switchMinutes)
    end)

    it("a missing or broken autoSwitch means its old defaults", function()
        for _, value in ipairs({ "x", 5 }) do
            local p = up({ verbose = true, autoSwitch = value })
            assert.equal(0, p.sets["$Default"].switchMinutes)
            assert.is_false(p.sets["$Default"].switchCitiesOnly)
            assert.is_false(p.switchOnNewMap)
            assert.is_nil(p.autoSwitch)
        end
    end)

    it("only in cities goes to Default and to every set with its own timer", function()
        local p = up({ autoSwitch = { citiesOnly = true }, sets = {
            Own = { switchMinutes = 5 }, Like = { trigger = CITY } } })
        assert.is_true(p.sets["$Default"].switchCitiesOnly)
        assert.is_true(p.sets.Own.switchCitiesOnly)
        assert.equal(5, p.sets.Own.switchMinutes)
        assert.is_nil(p.sets.Like.switchCitiesOnly)
        assert.is_nil(p.sets.Like.switchMinutes)
    end)

    it("switching on a new map goes to switchOnNewMap", function()
        assert.is_true(up({ autoSwitch = { onZone = true } }).switchOnNewMap)
        assert.is_false(up({ autoSwitch = { onZone = false } }).switchOnNewMap)
    end)

    it("don't summon while mounted goes to While mounted", function()
        assert.equal("alone", up({ noSummonMounted = true }).exceptions.builtin.mounted)
        assert.is_false(up({ noSummonMounted = false }).exceptions.builtin.mounted)
        assert.equal("alone", up({ verbose = true }).exceptions.builtin.mounted)   -- missing means the old default
    end)

    it("dismiss when stealthed goes to Stealth or invisibility", function()
        assert.equal("away", up({ dismissWhenStealthed = true }).exceptions.builtin.hidden)
        assert.is_false(up({ dismissWhenStealthed = false }).exceptions.builtin.hidden)
    end)

    it("the battleground pair goes to Battlegrounds and Arenas", function()
        local function bg(enable, dismiss)
            local b = up({ enableInBattleground = enable, dismissInBattleground = dismiss }).exceptions.builtin
            assert.equal(b.bg, b.arena)
            return b.bg
        end
        assert.is_false(bg(true, false))
        assert.equal("alone", bg(false, false))
        assert.equal("away", bg(true, true))
        assert.equal("away", bg(false, true))
    end)

    it("the PvE pair goes to Dungeons, Raids and Scenarios", function()
        local function pve(enable, dismiss)
            local b = up({ enableInPVE = enable, dismissInPVE = dismiss }).exceptions.builtin
            assert.equal(b.dungeon, b.raid)
            assert.equal(b.dungeon, b.scenario)
            return b.dungeon
        end
        assert.is_false(pve(true, false))
        assert.equal("alone", pve(false, false))
        assert.equal("away", pve(true, true))
    end)

    it("the old dungeons setting keeps needing a group", function()
        local p = up({ enableInPVE = false })
        assert.same({ dungeon = false, raid = false, scenario = false }, p.exceptions.solo)
        assert.same({}, up({ enableInPVE = true, dismissInPVE = false }).exceptions.solo)
    end)

    it("only enable in cities goes to Outside cities", function()
        assert.equal("alone", up({ disableOutsideCities = true }).exceptions.builtin.outsideCities)
        assert.is_false(up({ disableOutsideCities = false }).exceptions.builtin.outsideCities)
    end)

    it("removes every old key", function()
        local p = up({ enableInBattleground = true, dismissInBattleground = false, disableOutsideCities = false,
            dismissWhenStealthed = false, noSummonMounted = true, disableForQuestItems = true, enableInPVE = true,
            dismissInPVE = false, verbose = true, autoSwitch = {}, waitTimer = 5, nearPEWOnly = true })
        for _, key in ipairs({ "enableInBattleground", "dismissInBattleground", "disableOutsideCities",
            "dismissWhenStealthed", "noSummonMounted", "disableForQuestItems", "enableInPVE", "dismissInPVE",
            "verbose", "autoSwitch" }) do
            assert.is_nil(p[key])
        end
        assert.equal(5, p.waitTimer)
        assert.is_true(p.nearPEWOnly)
        assert.same({ converted = {} }, p.upgradeFacts)
        assert.is_true(global.welcomePending)
    end)

    it("a fresh profile gets no facts and no welcome", function()
        local p = up({})
        assert.equal(2, p.upgraded)
        assert.is_nil(p.upgradeFacts)
        assert.is_nil(p.sets)
        assert.is_nil(p.exceptions)
        assert.is_nil(global.welcomePending)
    end)

    it("runs once", function()
        local p = up({ verbose = false })
        p.sets["$Default"].announce = "on"
        p.verbose = false
        up(p)
        assert.equal("on", p.sets["$Default"].announce)
        assert.is_false(p.verbose)
    end)

    it("a quiet raid set folds into Raids", function()
        local p = up({ sets = { ["Quiet raid"] = { noPet = true, trigger = RAID } } })
        assert.equal("away", p.exceptions.builtin.raid)
        assert.is_false(p.exceptions.builtin.dungeon)
        assert.same({}, own(p))
        assert.is_nil(p.sets["Quiet raid"])
        assert.same({ set = "Quiet raid", outcome = "folded", into = { "raid" } }, fact(p, "Quiet raid"))
        assert.is_true(global.welcomePending)
    end)

    it("a quiet PvP set folds into Battlegrounds and Arenas", function()
        local p = up({ enableInBattleground = false, sets = {
            ["Quiet PvP"] = { noPet = true, trigger = { { "specialLocation", locs = { "pvp" } } } } } })
        assert.equal("away", p.exceptions.builtin.bg)
        assert.equal("away", p.exceptions.builtin.arena)
        assert.same({ "bg", "arena" }, fact(p, "Quiet PvP").into)
        -- the old 1.x value stands for both as well
        p = up({ sets = { Old = { noPet = true, trigger = { { "specialLocation", loc = "battleground" } } } } })
        assert.equal("away", p.exceptions.builtin.bg)
        assert.equal("away", p.exceptions.builtin.arena)
    end)

    it("a folded quiet dungeon set applies solo", function()
        local p = up({ enableInPVE = false, sets = {
            Quiet = { noPet = true, trigger = { { "specialLocation", locs = { "dungeon", "raid" } } } } } })
        assert.equal("away", p.exceptions.builtin.dungeon)
        assert.equal("away", p.exceptions.builtin.raid)
        assert.equal("alone", p.exceptions.builtin.scenario)
        assert.same({ dungeon = true, raid = true, scenario = false }, p.exceptions.solo)
    end)

    it("a no-pet set that is not one place type becomes an own exception", function()
        local trigger = { { "specialLocation", locs = { "raid", "city" } } }
        local p = up({ sets = { Mixed = { noPet = true, trigger = trigger, order = 1 },
            Negated = { noPet = true, trigger = { { "specialLocation", locs = { "raid" }, negate = true } }, order = 2 } } })
        assert.equal(2, #own(p))
        assert.same({ id = 1, trigger = trigger, choice = "away", from = "Mixed" }, own(p)[1])
        assert.equal("Negated", own(p)[2].from)
        assert.equal(2, own(p)[2].id)
        assert.is_nil(p.sets.Mixed)
        assert.equal("deleted", fact(p, "Mixed").outcome)
        assert.is_nil(fact(p, "Mixed").into)
    end)

    it("a no-pet set below a set with pets becomes an own exception with AND NOT", function()
        local group = { { "groupType", party = true }, { "zone", mapIDs = { 7 } } }
        local p = up({ sets = {
            Raiders = { trigger = CITY, pets = { a = 3 }, order = 1 },
            Group = { trigger = group, filter = { { weight = 3 } }, order = 2 },
            Off = { trigger = RAID, pets = { b = 3 }, enabled = false, order = 3 },     -- paused for good: not in the way
            Empty = { trigger = RAID, order = 4 },                                     -- no pets: not in the way
            Quiet = { noPet = true, trigger = RAID, order = 5 },
        } })
        assert.is_false(p.exceptions.builtin.raid)
        assert.same({ { "specialLocation", locs = { "raid" } },
            { "OR", negate = true, items = { CITY[1], { "AND", items = group } } } }, own(p)[1].trigger)
        assert.equal("away", own(p)[1].choice)
        assert.equal("deleted", fact(p, "Quiet").outcome)
    end)

    it("a no-pet set below a set without conditions becomes As usual", function()
        local p = up({ sets = {
            Always = { defaultValue = 1, order = 1 },
            Quiet = { noPet = true, trigger = RAID, order = 2 },
        } })
        assert.is_false(own(p)[1].choice)
        assert.same(RAID, own(p)[1].trigger)
        assert.equal("disabled", fact(p, "Quiet").outcome)
    end)

    it("a no-pet set without conditions and nothing above it turns Auto-summon off", function()
        local p = up({ sets = {
            Never = { noPet = true, order = 2 },
            Empty = { trigger = CITY, pets = { a = 0 }, filter = { { "family", 0 } }, order = 1 },   -- weight 0: no pets
        } })
        assert.is_false(p.enable)
        assert.same({}, own(p))
        assert.same({ set = "Never", outcome = "off" }, fact(p, "Never"))
        assert.is_nil(p.sets.Never)
        assert.is_nil(p.sets.Empty.noPet)
        assert.is_not_nil(p.sets.Empty)
        -- kept when it has pets of its own
        p = up({ sets = { Never = { noPet = true, pets = { a = 3 } } } })
        assert.is_false(p.enable)
        assert.is_false(p.sets.Never.enabled)
        assert.equal("off", fact(p, "Never").outcome)
        -- paused for good: Auto-summon stays as it was
        p = up({ sets = { Never = { noPet = true, enabled = false } } })
        assert.is_nil(p.enable)
        assert.equal("disabled", fact(p, "Never").outcome)
    end)

    it("a no-pet set without conditions below a set with pets puts the pet away outside that set", function()
        local p = up({ sets = {
            City = { trigger = CITY, pets = { a = 3 }, order = 1 },
            Raid = { trigger = RAID, filter = { { "family", 2 } }, order = 2 },
            Never = { noPet = true, order = 3 },
        } })
        assert.is_nil(p.enable)
        assert.same({ { "OR", negate = true, items = { CITY[1], RAID[1] } } }, own(p)[1].trigger)
        assert.equal("away", own(p)[1].choice)
        assert.equal("deleted", fact(p, "Never").outcome)
    end)

    it("a no-pet set paused for good becomes a disabled exception and never folds", function()
        local p = up({ sets = { Quiet = { noPet = true, trigger = RAID, enabled = false } } })
        assert.is_false(p.exceptions.builtin.raid)
        assert.same({ id = 1, trigger = RAID, choice = false, from = "Quiet" }, own(p)[1])
        assert.equal("disabled", fact(p, "Quiet").outcome)
        assert.is_nil(p.sets.Quiet)
    end)

    it("a no-pet set paused for a while becomes an enabled exception", function()
        local p = up({ sets = { Quiet = { noPet = true, trigger = CITY, pausedUntil = 100 } } })
        assert.equal("away", own(p)[1].choice)
    end)

    it("a no-pet set with pets of its own stays, paused", function()
        local p = up({ sets = {
            Quiet = { noPet = true, trigger = CITY, pets = { a = 3 }, pausedUntil = 100 },
            Ruled = { noPet = true, trigger = RAID, filter = { { weight = 3 } } },
        } })
        assert.is_nil(p.sets.Quiet.noPet)
        assert.is_false(p.sets.Quiet.enabled)
        assert.is_nil(p.sets.Quiet.pausedUntil)
        assert.same({ a = 3 }, p.sets.Quiet.pets)
        assert.equal("paused", fact(p, "Quiet").outcome)
        -- folded, and kept too
        assert.equal("away", p.exceptions.builtin.raid)
        assert.is_false(p.sets.Ruled.enabled)
        assert.equal("folded", fact(p, "Ruled").outcome)
    end)

    it("keeps own exceptions already there and numbers after them", function()
        local p = up({ exceptions = { own = { { id = 4, trigger = {}, choice = false } } },
            sets = { Quiet = { noPet = true, trigger = CITY } } })
        assert.equal(5, own(p)[2].id)
    end)

    it("upgrades a profile switched to later", function()
        PetCall3DB = { profileKeys = { ["Tester - Realm"] = "Default" }, profiles = {
            Default = {},
            Alt = { verbose = false, enableInBattleground = false, autoSwitch = { onZone = true },
                sets = { Quiet = { noPet = true, trigger = RAID } } },
        } }
        ns = W.load()
        W.login()
        assert.is_nil(PetCall3DB.global.welcomePending)
        assert.is_nil(ns.db.profile.upgradeFacts)
        ns.DB:Set("Alt")
        local p = ns.db.profile
        assert.equal(2, p.upgraded)
        assert.is_nil(p.verbose)
        assert.equal("off", p.sets["$Default"].announce)
        assert.equal(0, p.sets["$Default"].switchMinutes)
        assert.equal("alone", p.exceptions.builtin.bg)
        assert.equal("away", p.exceptions.builtin.raid)
        assert.equal("alone", p.exceptions.builtin.mounted)
        assert.is_false(p.exceptions.builtin.hidden)
        assert.is_true(p.switchOnNewMap)
        assert.equal("folded", fact(p, "Quiet").outcome)
        assert.is_true(PetCall3DB.global.welcomePending)
        assert.is_false(ns.Sets:Get("$Default"):GetAnnounce())
    end)

    it("a later profile upgrade after the welcome was seen leaves welcomePending unset", function()
        global.welcomeSeen = true
        local p = up({ verbose = false })
        assert.is_not_nil(p.upgradeFacts)
        assert.is_nil(global.welcomePending)
    end)
end)
