local W = dofile("tests/wowstub.lua")
local F = dofile("tests/fixtures/PetCall3DB_1_0.lua")
local REF = dofile("tests/fixtures/reference_1_0.lua")

local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local c = {} for k, v in pairs(t) do c[k] = deepcopy(v) end return c
end

describe("Weights", function()
    local ns
    before_each(function()
        W.reset()
        for id, p in pairs(F.pets) do W.world.pets[id] = p end
        for id in pairs(F.favorites) do W.world.favorites[id] = true end
        PetCall3DB = deepcopy(F.db)
        ns = W.load()
        W.login()
        W.advance(1)
    end)
    local function sums(tbl)
        local out = {}
        for i = 1, #tbl, 2 do out[tbl[i + 1]] = (out[tbl[i + 1]] or 0) + tbl[i] end
        return out
    end
    it("matches 1.0.x weight tables for every set without rules", function()
        for name, ref in pairs(REF[1].sets) do
            local settings = ns.db.profile.sets[name]
            if #(settings.filter or {}) == 0 then
                local tbl = ns.Weights.Build(settings)
                assert.equal(ref.total, tbl.total, name .. " total")
                assert.same(ref.weights, sums(tbl), name .. " weights")
            end
        end
    end)
    it("a pet's own setting wins over rules; without one the strongest rule decides", function()
        -- 1.x added a pet's own weight and every rule's weight up; since 2.2 they do not
        local d = ns.Weights.Build(ns.db.profile.sets["$Default"])
        assert.same({ ["BattlePet-0-0001"] = 8,           -- its own Often, though the favorites rule says 64
            ["BattlePet-0-0003"] = 0.125, ["BattlePet-0-0005"] = 1,
            ["BattlePet-0-0007"] = 64 }, sums(d))       -- no own setting: the favorites rule
        assert.equal(73.125, d.total)
        local r = ns.Weights.Build(ns.db.profile.sets["RaidOrZone"])
        assert.same({ ["BattlePet-0-0001"] = 8, ["BattlePet-0-0002"] = 8, ["BattlePet-0-0003"] = 8,
            ["BattlePet-0-0005"] = 1, ["BattlePet-0-0007"] = 8 }, sums(r), "level 25 (1) and beast or favorite (8): the stronger")
        assert.equal(8, r.auto["BattlePet-0-0001"])
    end)
    it("an own setting that only repeats the set's default leaves the rules to decide, once", function()
        local set = ns.Sets:Get("$Default")
        set.settings.ownWins = nil
        set.settings.pets["BattlePet-0-0007"] = 1           -- ticked before 2.2: Normal, the default
        set:FiltersChanged()
        assert.equal(64, (set:GetLevel("BattlePet-0-0007")))
        assert.is_nil(set.settings.pets["BattlePet-0-0007"])
        assert.equal(8, set.settings.pets["BattlePet-0-0001"], "a real choice stays")
        set:SetPetWeight("BattlePet-0-0007", 1)              -- chosen now: it wins
        assert.equal(1, (set:GetLevel("BattlePet-0-0007")))
    end)
    it("picks proportionally and reports chance", function()
        local tbl = { 1, "a", 3, "b", total = 4 }
        assert.equal("a", ns.Weights.Pick(tbl, 0.2))
        assert.equal("b", ns.Weights.Pick(tbl, 0.3))
        assert.equal(0.75, ns.Weights.Chance(tbl, "b"))
        assert.is_nil(ns.Weights.Pick({ total = 0 }, 0.5))
    end)
    it("can leave one pet out of the draw", function()
        local tbl = { 1, "a", 3, "b", 1, "a", total = 5 }
        assert.equal("b", ns.Weights.Pick(tbl, 0, "a"))
        assert.equal("b", ns.Weights.Pick(tbl, 0.99, "a"))
        assert.is_nil(ns.Weights.Pick({ 2, "a", total = 2 }, 0.5, "a"))
    end)

    it("names weights by how often", function()
        assert.equal("Very often", ns.Weights.Label(64))
        assert.equal("Rarely", ns.Weights.Label(1 / 8))
        assert.equal("Never", ns.Weights.Label(0))
    end)

    it("labels", function()
        assert.equal("+2", ns.Weights.Short(64))
        assert.is_nil(ns.Weights.Short(1))
        assert.equal(8, ns.Weights.Nearest(7.9))
    end)
    it("rules give no tickets to a pet that cannot be summoned, but still count it as theirs", function()
        W.world.pets.ghost = { species = 900, name = "Ghost", unsummonable = true }
        W.world.favorites.ghost = true
        ns.PetCache:Rescan()
        local settings = { pets = {}, defaultValue = 0, filter = { { "favorites", 8 } } }
        local tbl = ns.Weights.Build(settings)
        assert.equal(0, ns.Weights.Sum(tbl, "ghost"))
        assert.equal(8, tbl.auto.ghost)
        local others = 0
        for id in pairs(W.world.favorites) do
            if id ~= "ghost" and W.world.pets[id] then others = others + 8 end
        end
        assert.equal(others, tbl.total)
    end)
    it("asks the game whether a pet can be summoned once per journal scan, not once per draw", function()
        local calls, summonable = 0, C_PetJournal.PetIsSummonable
        C_PetJournal.PetIsSummonable = function(id) calls = calls + 1 return summonable(id) end
        for _ = 1, 5 do ns.Weights.Build({ pets = {}, defaultValue = 1, filter = {} }) end
        C_PetJournal.PetIsSummonable = summonable
        assert.equal(0, calls)
    end)
end)
