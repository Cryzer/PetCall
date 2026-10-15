local W = dofile("tests/wowstub.lua")
describe("Summon", function()
    local ns
    before_each(function()
        W.reset()
        W.world.pets = { a = { species = 1, name = "A" }, b = { species = 2, name = "B" } }
        ns = W.load()
        W.login()
        W.advance(1)
    end)
    it("auto-summons a pet from the current set after the wait timer", function()
        W.advance(ns.db.profile.waitTimer + 2)
        assert.is_not_nil(W.world.summoned)
        assert.equal(W.world.summoned, ns:GetRecentPets()[1])
    end)
    it("toggle and auto-summon flag", function()
        W.world.summoned = "a"
        ns:TogglePet()
        assert.is_nil(W.world.summoned)
        assert.is_false(ns:IsAutoSummon())
        ns:TogglePet()
        assert.is_true(ns:IsAutoSummon())
    end)
    it("manual summon keeps history of 5", function()
        for i = 1, 7 do
            W.world.pets["p" .. i] = { species = 10 + i, name = "P" .. i }
        end
        ns.PetCache:Rescan()
        for i = 1, 7 do ns:SummonPet("p" .. i) W.world.summoned = nil end
        local r = ns:GetRecentPets()
        assert.equal(5, #r)
        assert.equal("p7", r[1])
    end)
    it("does not summon on cooldown", function()
        W.world.cooldowns.a, W.world.cooldowns.b = 10, 10
        assert.is_false(ns.Summon:SummonRandom())
    end)
    it("an expired cooldown does not block summoning", function()
        W.world.pastCooldowns.a, W.world.pastCooldowns.b = true, true
        W.world.summoned = "a"
        ns:SummonAnother()
        W.advance(1)
        assert.equal("b", W.world.summoned)
    end)

    it("verbose message", function()
        ns.Summon:SummonRandom()
        assert.is_true(W.world.printed[#W.world.printed]:find("Summoning") ~= nil)
    end)
end)
