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
    it("matches 1.0.x weight tables for every set", function()
        for name, ref in pairs(REF[1].sets) do
            local tbl = ns.Weights.Build(ns.db.profile.sets[name])
            assert.equal(ref.total, tbl.total, name .. " total")
            local sums = {}
            for i = 1, #tbl, 2 do sums[tbl[i + 1]] = (sums[tbl[i + 1]] or 0) + tbl[i] end
            assert.same(ref.weights, sums, name .. " weights")
        end
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

    it("names weights by how often and priorities by rank", function()
        assert.equal("Very often", ns.Weights.Label(64))
        assert.equal("Rarely", ns.Weights.Label(1 / 8))
        assert.equal("Never", ns.Weights.Label(0))
        assert.equal("Highest", ns.Weights.PriorityLabel(64))
        assert.equal("Normal", ns.Weights.PriorityLabel(1))
        assert.equal("Lowest", ns.Weights.PriorityLabel(1 / 64))
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
end)
