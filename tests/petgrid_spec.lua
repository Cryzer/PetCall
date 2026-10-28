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
        assert.same({ "a", "c" }, ns.PetGridModel.Filter(set, { filters = { types = { [8] = true } } }))
        assert.same({ "c" }, ns.PetGridModel.Filter(set, { filters = { favorites = true } }))
        assert.same({ "a" }, ns.PetGridModel.Filter(set, { filters = { level = { operator = "==", level = 25 } } }))
        assert.same({ "a" }, ns.PetGridModel.Filter(set, { filters = { rare = true } }))
        -- an open rule shows exactly its pets: search and segment wait
        assert.same({ "a", "c" }, ns.PetGridModel.Filter(set,
            { search = "zzz", show = "unselected", editing = {}, filters = { types = { [8] = true } } }))
    end)
    it("filters by journal source, as the where-from text names it", function()
        _G.BATTLE_PET_SOURCE_1, _G.BATTLE_PET_SOURCE_2 = "Drop", "Pet Battle"
        W.world.sources[1] = "Drop: Hogger"
        W.world.sources[2] = "Pet Battle: Elwynn Forest"
        W.world.sources[3] = "Pet Battle: Westfall"
        assert.same({ "b", "c" }, ns.PetGridModel.Filter(set, { filters = { sources = { [2] = true } } }))
        assert.same({ "a", "b", "c" }, ns.PetGridModel.Filter(set, { filters = { sources = { [1] = true, [2] = true } } }))
        assert.same({ "c" }, ns.PetGridModel.Filter(set, { filters = { sources = { [2] = true }, types = { [8] = true } } }))
        local counts = ns.PetGridModel.SourceCounts()
        assert.equal(1, counts[1])
        assert.equal(2, counts[2])
        _G.BATTLE_PET_SOURCE_1, _G.BATTLE_PET_SOURCE_2 = nil, nil
    end)
    it("names the filters, counts the menu ones, says when the list is narrowed and clears it", function()
        _G.BATTLE_PET_SOURCE_2, _G.BATTLE_PET_NAME_8 = "Pet Battle", "Beast"
        local state = { search = "", show = "all", sort = "level", filters = {} }
        assert.is_false(ns.PetGridModel.IsNarrowed(state))
        state.filters = { favorites = true, types = { [8] = true }, sources = { [2] = true } }
        assert.is_true(ns.PetGridModel.IsNarrowed(state))
        local tokens = ns.PetGridModel.Tokens(state)
        assert.same({ "Favorites", "Beast", "Pet Battle" }, { tokens[1].label, tokens[2].label, tokens[3].label })
        tokens[2].clear()
        assert.is_nil(state.filters.types, "the last pet type gone: no type filter")
        state.search, state.show = "kit", "selected"
        ns.PetGridModel.ClearFilters(state)
        assert.same({ search = "", show = "all", sort = "level", filters = {} }, state)
        _G.BATTLE_PET_SOURCE_2, _G.BATTLE_PET_NAME_8 = nil, nil
    end)
    it("counts auto-rule pets as selected", function()
        set:SetDefaultWeight(0)
        table.insert(set.settings.filter, { "favorites", 1 })
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
