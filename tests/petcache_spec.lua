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
        W.world.pets.c.level = 2
        W.fire("PET_JOURNAL_LIST_UPDATE")
        W.advance(1)
        assert.same({ true, false }, events)
    end)
    it("a journal update that changes nothing sends no PetsChanged and keeps the pets' tables", function()
        local n = 0
        ns:RegisterCallback({}, "PetsChanged", function() n = n + 1 end)
        local a = ns.PetCache:GetInfo("a")
        W.fire("PET_JOURNAL_LIST_UPDATE")       -- the game sends it on a summon, a journal search...
        W.advance(1)
        assert.equal(0, n)
        assert.equal(a, ns.PetCache:GetInfo("a"))
    end)
    it("a new favourite, level, name or a pet that can no longer be summoned is a change", function()
        local events = {}
        ns:RegisterCallback({}, "PetsChanged", function(_, changed) events[#events + 1] = changed end)
        W.world.favorites.a = true
        ns.PetCache:Rescan()
        assert.is_true(ns.PetCache:GetInfo("a").isFavorite)
        W.world.pets.a.level = 6
        ns.PetCache:Rescan()
        W.world.pets.a.custom = "Squeak"
        ns.PetCache:Rescan()
        assert.is_true(ns.PetCache:GetInfo("a").summonable)
        W.world.pets.a.unsummonable = true
        ns.PetCache:Rescan()
        assert.is_false(ns.PetCache:GetInfo("a").summonable)
        assert.same({ false, false, false, false }, events)
    end)
    it("groups copies of the same pet and picks the favorite or best copy as primary", function()
        W.world.pets.c1 = { species = 50, name = "Bouncer", level = 3 }
        W.world.pets.c2 = { species = 50, name = "Bouncer", level = 25 }
        W.world.pets.c3 = { species = 50, name = "Bouncer", level = 10 }
        W.world.pets.c4 = { species = 50, name = "Bouncer", custom = "Boing" }
        W.world.favorites.c3 = true
        ns.PetCache:Rescan()
        assert.same({ "c3", "c1", "c2" }, ns.PetCache:GetCopies("c1"))
        assert.is_true(ns.PetCache:IsPrimary("c3"))
        assert.is_false(ns.PetCache:IsPrimary("c2"))
        assert.same({ "c4" }, ns.PetCache:GetCopies("c4"))
        assert.is_true(ns.PetCache:IsPrimary("c4"))
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
