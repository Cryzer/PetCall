local W = dofile("tests/wowstub.lua")
describe("AutoRules", function()
    local ns, AR
    before_each(function()
        W.reset()
        W.world.pets = {
            a = { species = 1, name = "A", level = 25, type = 8 },
            b = { species = 2, name = "B", level = 3, type = 10 },
        }
        W.world.favorites.b = true
        ns = W.load()
        W.login()
        W.advance(1)
        AR = ns.AutoRules
    end)
    it("matches legacy leaves", function()
        assert.is_true(AR.Match({ "favorites", 8 }, "b"))
        assert.is_false(AR.Match({ "favorites", 8 }, "a"))
        assert.is_true(AR.Match({ "petType", petType = "8" }, "a"))
        assert.is_true(AR.Match({ "level", operator = ">=", level = "25" }, "a"))
        assert.is_false(AR.Match({ "level", operator = ">=", level = "25" }, "b"))
    end)
    it("matches new multi petTypes and nodes", function()
        assert.is_true(AR.Match({ "petType", petTypes = { 9, 10 } }, "b"))
        assert.is_true(AR.Match({ "OR", items = { { "favorites" }, { "petType", petType = "8" } } }, "a"))
        assert.is_false(AR.Match({ "AND", items = { { "favorites" }, { "petType", petType = "8" } } }, "a"))
    end)
    it("a rule is the filters it was made from, and back", function()
        local f = { favorites = true, types = { [10] = true, [8] = true }, level = { operator = "==", level = 25 } }
        local rule = AR.FromFilters(f)
        assert.same({ "AND", items = { { "favorites" }, { "petType", petTypes = { 8, 10 } },
            { "level", operator = "==", level = "25" } } }, rule)
        assert.same(f, AR.ToFilters(rule))
        assert.same({ "rare" }, AR.FromFilters({ rare = true }), "one group: a plain rule")
        assert.is_nil(AR.FromFilters({}))
        -- older rules: one pet type, a source text, a lone condition in OR
        assert.same({ types = { [8] = true } }, AR.ToFilters({ "petType", 8, petType = "8" }))
        assert.same({ sourceText = "Trading Post" }, AR.ToFilters({ "source", 8, text = "Trading Post" }))
        assert.same({ favorites = true }, AR.ToFilters({ "OR", items = { { "favorites" } }, 8 }))
    end)
    it("rules the filters cannot show are left as they are", function()
        assert.is_nil(AR.ToFilters({ "OR", items = { { "favorites" }, { "rare" } }, 8 }))
        assert.is_nil(AR.ToFilters({ "AND", items = { { "rare" }, { "rare" } }, 8 }), "the same condition twice")
        assert.is_nil(AR.ToFilters({ "favorites", 8, negate = true }))
        assert.is_nil(AR.ToFilters({ "AND", items = { { "OR", items = { { "favorites" } } } }, 1 }))
    end)
    it("picks pets by the expansion they were added in", function()
        local e = ns.Expansions.Of(ns.PetCache:GetSpeciesID("a"))
        assert.is_true(AR.Match({ "expansion", expansions = { e } }, "a"))
        assert.is_false(AR.Match({ "expansion", expansions = { (e + 1) % 12 } }, "a"))
    end)
    it("an expansion filter is a rule and back, named as the game names it", function()
        local f = { rare = true, expansions = { [9] = true, [6] = true } }
        local rule = AR.FromFilters(f)
        assert.same({ "AND", items = { { "rare" }, { "expansion", expansions = { 6, 9 } } } }, rule)
        assert.same(f, AR.ToFilters(rule))
        assert.equal("Rare or better and Legion or Dragonflight", AR.Sentence(f))
        assert.equal("12", AR.Describe({ "expansion", expansions = { 12 } }))
    end)
    it("names each filter choice and tells rules apart by what they pick", function()
        _G.BATTLE_PET_NAME_8 = "Beast"
        local labels = {}
        for _, t in ipairs(AR.Tokens({ types = { [8] = true }, level = { operator = "<", level = 25 }, nativeZone = true })) do
            labels[#labels + 1] = t.label
        end
        assert.same({ "Beast", "Level 1–24", "From this zone" }, labels)
        assert.equal(AR.Key({ "petType", 8, petType = "8" }), AR.Key({ "petType", 64, petTypes = { 8 } }))
        assert.is_true(AR.Key({ "rare", 8 }) ~= AR.Key({ "favorites", 8 }))
        _G.BATTLE_PET_NAME_8 = nil
    end)
    it("source, native zone and rare rules", function()
        W.world.sources[1] = "|cFFFFD200World Event:|r Hallow's End"
        W.world.sources[2] = "|cFFFFD200Pet Battle:|r Elwynn Forest, Stormwind City"
        W.world.pets.a.quality = 4
        ns.PetCache:Rescan()
        assert.equal("world event: hallow's end", ns.PetCache:GetSourceText("a"))
        assert.is_true(AR.Match({ "source", 1, text = "Hallow's End" }, "a"))
        assert.is_false(AR.Match({ "source", 1, text = "Hallow's End" }, "b"))
        assert.is_true(AR.Match({ "nativeZone", 1 }, "b"))        -- stub zone: Stormwind City
        W.world.zone = "Durotar"
        assert.is_false(AR.Match({ "nativeZone", 1 }, "b"))
        assert.is_true(AR.Match({ "rare", 1 }, "a"))
        assert.is_false(AR.Match({ "rare", 1 }, "b"))
        assert.equal("Source: Hallow's End", AR.Describe({ "source", 1, text = "Hallow's End" }))
        -- journal sources by number match their name in the where-from text
        _G.BATTLE_PET_SOURCE_7 = "World Event"
        assert.is_true(AR.Match({ "source", 1, sources = { 3, 7 } }, "a"))
        assert.is_false(AR.Match({ "source", 1, sources = { 7 } }, "b"))
        _G.BATTLE_PET_SOURCE_7 = nil
    end)
    it("from this expansion matches pets of the place's expansion only", function()
        local mine = ns.Expansions.Of(ns.PetCache:GetSpeciesID("b"))
        W.world.mapID = ns.ZoneExpansionData[mine][1]
        assert.is_true(AR.Match({ "expansionHere", 1 }, "b"))
        W.world.mapID = ns.ZoneExpansionData[(mine + 1) % 12][1]
        assert.is_false(AR.Match({ "expansionHere", 1 }, "b"))
        W.world.mapID = nil
        assert.is_false(AR.Match({ "expansionHere", 1 }, "b"), "a loading screen is nowhere")
        assert.equal("From this expansion", AR.Describe({ "expansionHere" }))
    end)
    it("the filters round-trip from this expansion", function()
        local e = AR.FromFilters({ expansionHere = true })
        assert.same({ "expansionHere" }, e)
        assert.same({ expansionHere = true }, AR.ToFilters(e))
        assert.equal("From this expansion", AR.Tokens({ expansionHere = true })[1].label)
    end)
    it("a set with a native-zone rule is rebuilt after a zone change, others are not", function()
        W.world.sources[2] = "Pet Battle: Durotar"
        ns.PetCache:Rescan()
        local zoneSet = ns.Sets:Create("Zone")
        zoneSet.settings.defaultValue = 0
        zoneSet.settings.filter = { { "nativeZone", 1 } }
        zoneSet:FiltersChanged()
        local other = ns.Sets:Create("Other")
        assert.is_false(zoneSet:Contains("b"))
        local before = other:GetWeightTable()
        W.world.zone = "Durotar"
        W.fire("ZONE_CHANGED_NEW_AREA")
        assert.is_true(zoneSet:Contains("b"))
        assert.is_true(other:GetWeightTable() == before and not other.dirty)
    end)
end)
