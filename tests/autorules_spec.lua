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
    it("builds chips and marks deep trees legacy", function()
        local list = {
            { "favorites", 64 },
            { "OR", items = { { "petType", petType = "8" }, { "favorites" } }, 8 },
            { "AND", items = { { "OR", items = { { "favorites" } } } }, 1 },
        }
        local chips = AR.ToChips(list)
        assert.equal(3, #chips)
        assert.same({ false, "all", 1 }, { chips[1].legacy, chips[1].match, #chips[1].criteria })
        assert.same({ false, "any", 2 }, { chips[2].legacy, chips[2].match, #chips[2].criteria })
        assert.is_true(chips[3].legacy)
    end)
    it("edits chips keeping the 1.0 storage shape", function()
        local list = {}
        AR.AddChip(list, "favorites", 8)
        assert.same({ { "favorites", 8 } }, list)
        AR.AddCriterion(list, 1, "level")
        assert.equal("AND", list[1][1])
        assert.equal(8, list[1][2])
        assert.equal(2, #list[1].items)
        AR.SetMatch(list, 1, "any")
        assert.equal("OR", list[1][1])
        AR.RemoveCriterion(list, 1, 2)
        assert.same({ { "favorites", 8 } }, list)
        AR.RemoveChip(list, 1)
        assert.same({}, list)
    end)
    it("simplifies a nested single-child node", function()
        local list = { { "AND", items = { { "OR", items = { { "favorites" } } } }, 1 } }
        assert.is_true(AR.Simplify(list, 1))
        assert.same({ { "favorites", 1 } }, list)
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
