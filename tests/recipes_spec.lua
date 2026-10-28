local W = dofile("tests/wowstub.lua")
describe("Recipes", function()
    local ns, R
    before_each(function()
        W.reset()
        W.world.pets = {
            fish = { species = 1, name = "Fish", type = 9 },
            bird = { species = 2, name = "Bird", type = 3 },
            pumpkin = { species = 3, name = "Pumpkin", type = 5 },
        }
        W.world.sources[3] = "World Event: Hallow's End"
        W.world.calEvents[16] = { { eventID = 324, title = "Hallow's End", calendarType = "HOLIDAY" },
            { eventID = 555, title = "Timewalking", calendarType = "HOLIDAY" } }
        ns = W.load()
        W.login()
        W.advance(1)
        R = ns.Recipes
    end)
    local function byKey(key) for _, r in ipairs(R.List()) do if r.key == key then return r end end end
    it("pets from this expansion: an everyday card after the zone one, a set at the bottom", function()
        local list, at = R.List(), {}
        for i, r in ipairs(list) do at[r.key] = i end
        assert.equal(at.zone + 1, at.here)
        local here = list[at.here]
        assert.equal("everyday", here.category)
        assert.equal("Pets from this expansion", here.title)
        W.world.mapID = ns.ZoneExpansionData[ns.Expansions.Of(1)][1]   -- where Fish came from
        W.fire("ZONE_CHANGED_NEW_AREA")
        assert.is_true((R.Count(here)) >= 1)
        local set = R.Create(here)
        assert.same({ { "expansionHere", ns.Weights.NORMAL } }, set.settings.filter)
        assert.equal(0, set.settings.defaultValue)
        local sets = ns.Sets:List()
        assert.equal(set, sets[#sets - 1], "just above the Default set")
    end)
    it("the expansion card counts the expansion you are in now", function()
        local here = byKey("here")
        local owned = { [ns.Expansions.Of(1)] = true, [ns.Expansions.Of(2)] = true, [ns.Expansions.Of(3)] = true }
        local none
        for e = 0, 11 do if not owned[e] then none = e break end end
        W.world.mapID = ns.ZoneExpansionData[ns.Expansions.Of(1)][1]
        assert.is_true((R.Count(here)) >= 1)
        W.world.mapID = ns.ZoneExpansionData[none][1]
        assert.equal(0, (R.Count(here)), "no pet from there")
    end)
    it("the zone card counts the zone you are in now, without waiting for the pets to change", function()
        W.world.sources[1] = "Pet Battle: Durotar"
        ns.PetCache:Rescan()
        local zone = byKey("zone")
        local before = (R.Count(zone))
        W.world.zone = "Durotar"
        W.fire("ZONE_CHANGED_NEW_AREA")
        assert.equal(before + 1, (R.Count(zone)))
    end)

    it("lists fixed recipes and one card per holiday with pets", function()
        assert.is_not_nil(byKey("swimming"))
        assert.is_not_nil(byKey("holiday:324"))
        assert.is_nil(byKey("holiday:555"))                 -- no pet mentions it: hidden
    end)
    it("counts the pets the created set really draws from", function()
        local r = byKey("swimming")
        local n, sample = R.Count(r)
        assert.equal(1, n)
        assert.same({ "fish" }, sample)
        local set = R.Create(r)
        assert.is_true(set:Contains("fish"))
        assert.is_false(set:Contains("bird"))
        assert.equal(0, set.settings.defaultValue)
        assert.is_true(#set.settings.trigger > 0)
    end)
    it("counts tiles: copies add up on the primary, most tickets first", function()
        W.world.pets.c1 = { species = 77, name = "Twin", level = 25 }
        W.world.pets.c2 = { species = 77, name = "Twin", level = 1 }
        W.world.pets.s1 = { species = 78, name = "Solo", level = 25 }
        ns.PetCache:Rescan()
        local primary = ns.PetCache:GetCopies("c1")[1]
        local n, sample = R.Count({ rules = { { "level", ns.Weights.LEVELS[3].value, operator = ">=", level = "1" } } })
        local all = 0
        for _, id in ns.PetCache:IteratePetIDs() do
            if ns.PetCache:IsPrimary(id) and C_PetJournal.PetIsSummonable(id) then all = all + 1 end
        end
        assert.equal(all, n)
        assert.equal(primary, sample[1])            -- two copies: twice the tickets
        for _, id in ipairs(sample) do assert.is_true(ns.PetCache:IsPrimary(id)) end
    end)

    it("a card shows the four likeliest pets, then by name, whatever their journal order", function()
        W.world.pets = {}
        for i, name in ipairs({ "Fig", "Bee", "Eel", "Cat", "Ant", "Dog" }) do
            W.world.pets["z" .. i] = { species = 100 + i, name = name, level = 1 }
        end
        W.world.pets.z1.level = 25
        ns.PetCache:Rescan()
        local r = { rules = { { "level", 8, operator = ">=", level = "25" } }, defaultValue = 1 }
        local n, sample = R.Count(r)
        assert.equal(6, n)
        assert.same({ "z1", "z5", "z2", "z4" }, sample)   -- Fig often, then Ant, Bee, Cat
    end)
    it("every recipe has conditions or puts its set at the bottom", function()
        local open
        for _, r in ipairs(R.List()) do
            assert.is_true(#r.conditions > 0 or r.lowest == true, r.key)
            if #r.conditions == 0 then open = r end
        end
        ns.Sets:Create("Earlier")
        local rank, count = R.Create(open):GetRank()
        assert.equal(count - 1, rank)                       -- just above the default set
    end)
    it("a taken name gets a number and the old set is untouched", function()
        local r = byKey("swimming")
        local first = R.Create(r)
        first:SetPetWeight("bird", 1)
        local second = R.Create(r)
        assert.equal(r.title .. " 2", second.name)
        assert.equal(1, ns.Sets:Get(r.title):GetPetWeight("bird"))
    end)
    it("a recipe without pets is not usable and says why", function()
        local ok, reason = R.Usable(byKey("night"))     -- no undead or magic pets
        assert.is_false(ok)
        assert.equal("string", type(reason))
    end)
    it("a created set follows its conditions: not active while they are not met", function()
        local set = R.Create(byKey("swimming"))
        W.advance(1)
        assert.equal("waiting", set:GetStatus())
        assert.is_false(ns.Sets:GetCurrent() == set)
        W.world.swimming = true
        W.advance(2)
        assert.equal("active", set:GetStatus())
    end)
    it("recipes can use either-or conditions, a default weight, immediate summons and weights per rule", function()
        W.world.pets.fish.quality = 4                       -- a rare pet for the show-off set
        ns.PetCache:Rescan()
        local showoff = R.Create(byKey("showoff"))
        assert.is_true(showoff.settings.immediate)
        assert.equal("OR", showoff.settings.trigger[1][1])
        W.world.resting = false
        W.fire("PLAYER_UPDATE_RESTING")
        W.advance(2)
        assert.equal("waiting", showoff:GetStatus())
        W.world.home.any = true                             -- visiting a friend: the second group
        W.fire("HOUSE_PLOT_ENTERED")
        W.advance(2)
        assert.equal("active", showoff:GetStatus())
        local fav = R.Create(byKey("favfirst"))
        assert.equal(ns.Weights.LEVELS[2].value, fav.settings.defaultValue)   -- every other pet: very rarely
        assert.equal(ns.Weights.LEVELS[6].value, fav.settings.filter[1][2])   -- favorites: very often
        assert.is_true(R.Count(byKey("favfirst")) == 3)
    end)
    it("every recipe has a section the gallery knows", function()
        local known = {}
        for _, s in ipairs(ns.UI and ns.UI.RecipeGallery and ns.UI.RecipeGallery.SECTIONS or {}) do known[s.key] = true end
        if not next(known) then
            known = { everyday = true, town = true, world = true, moving = true, time = true, company = true,
                families = true, sources = true, expansions = true, class = true, holiday = true }
        end
        for _, r in ipairs(R.List()) do assert.is_true(known[r.category], r.key) end
    end)
    it("one recipe per pet family and per source you have pets for", function()
        _G.BATTLE_PET_SOURCE_1 = "Drop"
        W.world.sources[1] = "Drop: Somewhere"
        W.world.pets.rock = { species = 1, name = "Rock", type = 9 }
        ns.PetCache:Rescan()
        R.ForgetCounts()
        assert.is_not_nil(byKey("family:9"))                -- aquatic: the fish
        assert.is_nil(byKey("family:2"))                    -- no dragonkin
        local drop = byKey("source:1")
        assert.is_not_nil(drop)
        assert.is_true(drop.lowest)
        assert.is_nil(byKey("source:2"))                    -- the stub has no name for it
        local set = R.Create(byKey("family:9"))
        assert.is_true(set:Contains("fish"))
        assert.is_false(set:Contains("bird"))
        _G.BATTLE_PET_SOURCE_1 = nil
    end)
    it("one recipe per expansion you have pets from", function()
        W.world.pets.rock = { species = 115, name = "Rock" }   -- Warlords of Draenor; the others are Classic
        ns.PetCache:Rescan()
        R.ForgetCounts()
        local classic, wod = byKey("expansion:0"), byKey("expansion:5")
        assert.is_not_nil(classic)
        assert.is_not_nil(wod)
        assert.is_true(wod.lowest)
        assert.equal("Warlords of Draenor pets", wod.title)
        assert.is_nil(byKey("expansion:6"))                 -- no Legion pets
        local set = R.Create(wod)
        assert.is_true(set:Contains("rock"))
        assert.is_false(set:Contains("fish"))
    end)
    it("every expansion card has a picture of its own, the BfA one by faction", function()
        local d, seen = ns.ExpansionData, {}
        for e = 0, 11 do
            for i, x in ipairs(d.expansions) do
                if x == e then W.world.pets["e" .. e] = { species = d.starts[i], name = "E" .. e } break end
            end
        end
        ns.PetCache:Rescan()
        R.ForgetCounts()
        for e = 0, 11 do
            local r = byKey("expansion:" .. e)
            assert.is_not_nil(r, e)
            assert.is_nil(r.icon:find("Token_Boost"), e .. ": " .. r.icon)
            assert.is_nil(r.icon:find("Teleport") or r.icon:find("Portal"), e .. ": a square scene, not a round portal")
            assert.is_nil(seen[r.icon], e .. " shares " .. r.icon)
            seen[r.icon] = true
        end
        assert.is_true(byKey("expansion:7").icon:find("TiragardeSound") ~= nil, "Alliance: Tiragarde Sound")
    end)
    it("a no-pet recipe is usable without pets and makes a set that summons none", function()
        local r = byKey("quietpvp")
        assert.is_true((R.Usable(r)))
        local set = R.Create(r)
        assert.is_true(set:IsNoPet())
        local zoo = R.Create(byKey("raidzoo"))
        assert.equal(5, zoo.settings.switchMinutes)
        assert.is_true(zoo:Contains("bird"))               -- every pet you own
    end)
end)
