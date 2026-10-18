local W = dofile("tests/wowstub.lua")

local function fixture()
    return {
        profileKeys = { ["Tester - Realm"] = "Default", ["Alt - Realm"] = "Alt" },
        profiles = {
            Default = {
                waitTimer = 5,
                sets = {
                    ["$Default"] = { pets = { ["BattlePet-0-1"] = 8 } },
                    ["City"] = { name = "City", trigger = { { "specialLocation", loc = "city" } } },
                },
                autoSwitch = { onZone = true },
            },
            Alt = { enable = false },
        },
        namespaces = { SpecialItems = { profiles = { Default = { enable = false } }, global = { localeCache = { enUS = { ["item:1"] = "X" } } } } },
        _petleashMigrated = true,
        _futureField = { x = 1 },
    }
end

describe("DB", function()
    local ns
    before_each(function()
        W.reset()
        PetCall3DB = fixture()
        ns = W.load()
        W.login()
    end)

    it("selects the character profile and fills defaults", function()
        assert.equal("Default", ns.DB:Current())
        assert.equal(5, ns.db.profile.waitTimer)
        assert.equal(true, ns.db.profile.enable)
        assert.equal(true, ns.db.profile.autoSwitch.onZone)
        assert.equal(false, ns.db.profile.autoSwitch.timer)
        assert.equal(30 * 60, ns.db.profile.autoSwitch.timerValue)
    end)

    it("wildcard defaults: sets stripped by AceDB behave like 1.0.x", function()
        local city = ns.db.profile.sets.City
        assert.equal(true, city.enabled)
        assert.equal(1, city.priority)
        assert.equal(0, city.defaultValue)
        assert.same({}, city.pets)
        local def = ns.db.profile.sets["$Default"]
        assert.equal(1, def.defaultValue)
        assert.equal(-1, def.priority)
        assert.equal(8, def.pets["BattlePet-0-1"])
    end)

    it("keeps unknown top-level keys", function()
        assert.same({ x = 1 }, PetCall3DB._futureField)
    end)

    it("namespaces follow the profile", function()
        local si = ns.DB:Namespace("SpecialItems", { profile = { enable = true, items = { ["*"] = true } } })
        assert.equal(false, si.profile.enable)
        assert.equal(true, si.profile.items["item:5"])
        assert.equal("X", si.global.localeCache.enUS["item:1"])
        ns.DB:Set("Fresh")
        assert.equal(true, si.profile.enable)
    end)

    it("profile operations", function()
        local fired = 0
        ns:RegisterCallback({}, "ProfileChanged", function() fired = fired + 1 end)
        assert.same({ "Alt", "Default" }, ns.DB:List())
        assert.is_true((ns.DB:Set("Alt")))
        assert.equal(false, ns.db.profile.enable)
        assert.equal("Alt", PetCall3DB.profileKeys["Tester - Realm"])
        assert.is_true((ns.DB:Copy("Default")))
        assert.equal(5, ns.db.profile.waitTimer)
        ns.DB:Reset()
        assert.equal(3, ns.db.profile.waitTimer)
        assert.is_false(ns.db.profile.minimap.hide)   -- a reset brings the minimap button back
        local ok = ns.DB:Delete("Alt")
        assert.is_false(ok)                       -- cannot delete the current profile
        ns.DB:Set("Default")
        assert.is_true((ns.DB:Delete("Alt")))
        assert.is_nil(PetCall3DB.profiles.Alt)
        assert.equal(5, fired)
    end)

    it("creates a fresh database", function()
        W.reset()
        local ns2 = W.load()
        W.login()
        assert.equal("Default", ns2.DB:Current())
        assert.equal(true, ns2.db.profile.sets["$Default"].enabled)
        assert.is_not_nil(PetCall3DB.profiles.Default)
    end)
end)
