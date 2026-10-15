local W = dofile("tests/wowstub.lua")
describe("PetCache", function()
    local ns
    before_each(function()
        W.reset()
        W.world.pets = {
            a = { species = 39, name = "Mechanical Squirrel", level = 5 },
            b = { species = 40, name = "Bombay Cat", custom = "Mruczek", level = 25, quality = 4 },
            f = { species = 41, name = "Box", fanfare = true },
        }
        W.world.favorites.b = true
        ns = W.load()
        W.login()
        W.advance(1)
    end)
    it("lists owned non-fanfare pets sorted by name", function()
        local ids = {}
        for _, id in ns.PetCache:IteratePetIDs() do ids[#ids + 1] = id end
        assert.same({ "b", "a" }, ids)
        assert.equal(2, ns.PetCache:NumPets())
    end)
    it("caches info", function()
        local info = ns.PetCache:GetInfo("b")
        assert.equal(40, info.speciesID)
        assert.equal("Mruczek", info.customName)
        assert.equal(true, info.isFavorite)
        assert.equal(4, info.quality)
        assert.equal(2, ns.PetCache:GetInfo("a").quality)
    end)
    it("fires PetsChanged once per burst and reports list changes", function()
        local events = {}
        ns:RegisterCallback({}, "PetsChanged", function(_, changed) events[#events + 1] = changed end)
        W.world.pets.c = { species = 50, name = "Zeppelin" }
        W.fire("PET_JOURNAL_LIST_UPDATE")
        W.fire("PET_JOURNAL_LIST_UPDATE")
        W.advance(1)
        assert.same({ true }, events)
        W.fire("PET_JOURNAL_LIST_UPDATE")
        W.advance(1)
        assert.same({ true, false }, events)
    end)
    it("handles an empty collection", function()
        W.reset()
        local ns2 = W.load()
        W.login()
        W.advance(1)
        assert.equal(0, ns2.PetCache:NumPets())
        assert.is_true(ns2.PetCache:IsLoaded())
    end)
end)
