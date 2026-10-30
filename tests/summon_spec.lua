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

    it("the Summon Another Pet key binding summons at once, without the idle wait", function()
        local xml = assert(io.open("Bindings.xml")):read("*a")
        local body = xml:match('name="PETCALL_SUMMON"[^>]*>%s*(.-)%s*</Binding>')
        W.world.summoned = "a"
        assert(loadstring(body))()
        assert.equal("b", W.world.summoned)            -- no W.advance: immediate
    end)

    it("a set's own timer only in cities waits outside a city", function()
        local s = ns.Sets:Create("Quick")
        s:SetPetWeight("a", 1)
        s:SetSwitch(5, true)
        W.advance(1)
        W.world.summoned = "a"
        local resummons = 0
        local orig = ns.Ready.Request
        ns.Ready.Request = function() resummons = resummons + 1 end
        W.world.resting = false
        ns.SwitchTimer:Start()
        W.advance(301)
        assert.equal(0, resummons)
        assert.is_not_nil(ns.SwitchTimer.timer)                     -- waiting for the next round
        W.world.resting = true
        W.advance(300)
        assert.equal(1, resummons)
        ns.Ready.Request = orig
    end)
    it("a new map asks for a new pet when that is on", function()
        local requests = {}
        local orig = ns.Ready.Request
        ns.Ready.Request = function(_, action, source) requests[#requests + 1] = action .. " " .. source end
        W.world.zone = "Westfall"
        W.fire("ZONE_CHANGED_NEW_AREA")
        W.advance(2)
        assert.equal(0, #requests)
        ns.db.profile.switchOnNewMap = true
        W.world.zone = "Duskwood"
        W.fire("ZONE_CHANGED_NEW_AREA")
        W.advance(2)
        assert.same({ "switch auto" }, requests)
        ns.Ready.Request = orig
    end)
    it("verbose message", function()
        ns.Summon:SummonRandom()
        assert.is_true(W.world.printed[#W.world.printed]:find("Summoning") ~= nil)
    end)
end)
