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
    it("every recipe has conditions or the lowest priority", function()
        for _, r in ipairs(R.List()) do
            assert.is_true(#r.conditions > 0 or r.priority == ns.Weights.LEVELS[2].value, r.key)
        end
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
end)
