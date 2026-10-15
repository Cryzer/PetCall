local W = dofile("tests/wowstub.lua")
local F = dofile("tests/fixtures/PetCall3DB_1_0.lua")

local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local c = {} for k, v in pairs(t) do c[k] = deepcopy(v) end return c
end

describe("Sets", function()
    local ns
    before_each(function()
        W.reset()
        for id, p in pairs(F.pets) do W.world.pets[id] = p end
        PetCall3DB = deepcopy(F.db)
        ns = W.load()
        W.login()
        W.advance(1)
    end)

    it("lists Default first, then by priority and name", function()
        local names = {}
        for _, s in ipairs(ns.Sets:List()) do names[#names + 1] = s.name end
        assert.same({ "$Default", "RaidOrZone", "City", "Deep", "Disabled", "NoTrigger" }, names)
    end)

    it("validates names", function()
        assert.is_false((ns.Sets:ValidateName("")))
        assert.is_false((ns.Sets:ValidateName("$x")))
        assert.is_false((ns.Sets:ValidateName("City")))
        assert.is_true((ns.Sets:ValidateName("City", "City")))
        local set, ok = ns.Sets:Create("  New  ")
        assert.is_true(ok)
        assert.equal("New", set.name)
        assert.equal(true, set.settings.enabled)
        assert.equal(1, set.settings.priority)
    end)

    it("renames without leaving stale entries and refuses duplicates", function()
        local city = ns.Sets:Get("City")
        assert.is_false((city:Rename("Deep")))
        assert.is_true((city:Rename("Town")))
        assert.equal(city, ns.Sets:Get("Town"))
        assert.is_nil(ns.Sets:Get("City"))
        assert.is_nil(rawget(ns.db.profile.sets, "City"))
        assert.equal("Town", ns.db.profile.sets.Town.name)
    end)

    it("default set cannot be renamed, deleted or disabled", function()
        local d = ns.Sets:Get("$Default")
        assert.is_false((d:Rename("X")))
        assert.is_false((d:Delete()))
        d:SetEnabled(false)
        assert.equal(true, d.settings.enabled)
    end)

    it("weights and chance", function()
        local d = ns.Sets:Get("$Default")
        d:SetPetWeight("BattlePet-0-0005", 64)
        assert.equal(64, d:GetPetWeight("BattlePet-0-0005"))
        assert.is_true(d:HasManualWeight("BattlePet-0-0005"))
        local c = d:GetChance("BattlePet-0-0005")
        assert.is_true(c > 0 and c < 1)
        d:ClearPetWeights()
        assert.is_false(d:HasManualWeight("BattlePet-0-0005"))
        W.world.cooldowns["BattlePet-0-0001"] = 30
        local _, reason = d:GetChance("BattlePet-0-0001")
        assert.equal("On cooldown", reason)
    end)

    it("fires SetsChanged on edits", function()
        local got = {}
        ns:RegisterCallback({}, "SetsChanged", function(_, n) got[#got + 1] = n end)
        ns.Sets:Get("City"):SetPriority(64)
        assert.same({ "City" }, got)
    end)

    it("status reflects enabled/empty/noConditions", function()
        assert.equal("disabled", ns.Sets:Get("Disabled"):GetStatus())
        assert.equal("noConditions", ns.Sets:Get("NoTrigger"):GetStatus())
        local e = ns.Sets:Create("Empty")
        assert.equal("empty", e:GetStatus())
    end)

    it("reloads on profile change", function()
        ns.DB:Set("Other")
        assert.is_nil(ns.Sets:Get("City"))
        assert.is_not_nil(ns.Sets:Get("$Default"))
    end)
    it("normalizes triggers on load and keeps meaning", function()
        local raid = ns.Sets:Get("RaidOrZone")
        local m = raid:GetConditionModel()
        assert.equal(2, #m.groups)
    end)

    it("matches 1.0.x current set across worlds", function()
        local REF = dofile("tests/fixtures/reference_1_0.lua")
        for wi, state in ipairs(F.worlds) do
            W.reset()
            for id, p in pairs(F.pets) do W.world.pets[id] = p end
            for id in pairs(F.favorites) do W.world.favorites[id] = true end
            for k, v in pairs(state) do W.world[k] = v end
            PetCall3DB = deepcopy(F.db)
            local ns2 = W.load()
            W.login()
            W.advance(1)
            local cur = ns2.Sets:GetCurrent()
            assert.equal(REF[wi].current, cur and cur.name or "", "world " .. wi)
        end
    end)

    it("edits through the model and fires ConditionStateChanged", function()
        local city = ns.Sets:Get("City")
        local fired = 0
        ns:RegisterCallback({}, "ConditionStateChanged", function() fired = fired + 1 end)
        local m = city:GetConditionModel()
        table.insert(m.groups[1].rows, { "groupType", party = true, raid = true })
        city:SetConditionModel(m)
        assert.equal(2, #city.settings.trigger)
        assert.is_true(fired >= 1)
        assert.is_false(city:ConditionsMet())     -- solo in world 1
    end)

    it("templates", function()
        local s = ns.Sets:Create("T")
        s:ApplyTemplate("city")
        assert.equal("specialLocation", s.settings.trigger[1][1])
        assert.is_true(s:ConditionsMet())
    end)

    it("profile switch frees watchers", function()
        local old = ns.Sets:Get("City").watcher
        assert.is_not_nil(old)
        ns.DB:Set("Other")
        assert.is_true(old.freed)
    end)
end)
