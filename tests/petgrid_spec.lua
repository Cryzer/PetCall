local W = dofile("tests/wowstub.lua")
describe("PetGridModel", function()
    local ns, set
    before_each(function()
        W.reset()
        W.world.pets = {
            a = { species = 1, name = "Alpha", level = 25, type = 8, quality = 4 },
            b = { species = 2, name = "Beta", custom = "Kitty", level = 3, type = 10, quality = 2 },
            c = { species = 3, name = "Gamma", level = 10, type = 8, quality = 3 },
        }
        W.world.favorites.c = true
        ns = W.load({ ui = { "UI/PetGridModel.lua" } })
        W.login()
        W.advance(1)
        set = ns.Sets:Get("$Default")
        set:SetPetWeight("b", 0)
    end)
    it("searches name and custom name", function()
        assert.same({ "b" }, ns.PetGridModel.Filter(set, { search = "kit" }))
        assert.same({ "a" }, ns.PetGridModel.Filter(set, { search = "ALP" }))
    end)
    it("filters selected/unselected/types/favorites", function()
        assert.same({ "a", "c" }, ns.PetGridModel.Filter(set, { show = "selected" }))
        assert.same({ "b" }, ns.PetGridModel.Filter(set, { show = "unselected" }))
        assert.same({ "a", "c" }, ns.PetGridModel.Filter(set, { types = { [8] = true } }))
        assert.same({ "c" }, ns.PetGridModel.Filter(set, { favoritesOnly = true }))
    end)
    it("counts auto-rule pets as selected", function()
        set:SetDefaultWeight(0)
        ns.AutoRules.AddChip(set.settings.filter, "favorites", 1)
        set:FiltersChanged()
        assert.same({ "c" }, ns.PetGridModel.Filter(set, { show = "selected" }))
        local text, kind = ns.PetGridModel.Badge(set, "c")
        assert.equal("auto", kind)
    end)
    it("sorts", function()
        assert.same({ "a", "c", "b" }, ns.PetGridModel.Filter(set, { sort = "level" }))
        assert.same({ "a", "c", "b" }, ns.PetGridModel.Filter(set, { sort = "rarity" }))
    end)
    it("sorts by chance with one pass over the weight table", function()
        set:SetPetWeight("a", 64)
        local sums = 0
        local origSum, origChance = ns.Weights.Sum, ns.Weights.Chance
        ns.Weights.Sum = function(...) sums = sums + 1 return origSum(...) end
        ns.Weights.Chance = function(...) sums = sums + 1 return origChance(...) end
        local ids = ns.PetGridModel.Filter(set, { sort = "chance" })
        ns.Weights.Sum, ns.Weights.Chance = origSum, origChance
        assert.same({ "a", "c", "b" }, ids)
        assert.equal(0, sums)
    end)

    it("shows one tile per pet; a copy's weight counts for the tile", function()
        W.world.pets.a2 = { species = 1, name = "Alpha", level = 1 }
        ns.PetCache:Rescan()
        assert.same({ "a", "b", "c" }, ns.PetGridModel.Filter(set, {}))
        set:SetPetWeight("a", 0)
        assert.same({ "a", "c" }, ns.PetGridModel.Filter(set, { show = "selected" }))   -- a2 still Normal
    end)

    it("chunks rows", function()
        assert.same({ { "a", "b" }, { "c" } }, ns.PetGridModel.Rows({ "a", "b", "c" }, 2))
    end)
    it("empty collection", function()
        W.world.pets = {}
        ns.PetCache:Rescan()
        assert.same({}, ns.PetGridModel.Filter(set, {}))
    end)
end)
