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
    local function binding(name)
        local xml = assert(io.open("Bindings.xml")):read("*a")
        return assert(loadstring(xml:match('name="' .. name .. '"[^>]*>%s*(.-)%s*</Binding>')))
    end
    local function petChanged(pet)
        W.world.summoned = pet
        W.fire("COMPANION_UPDATE", "CRITTER")
    end
    local function printedSince(n, text)
        for i = n + 1, #W.world.printed do
            if W.world.printed[i]:find(text, 1, true) then return true end
        end
        return false
    end

    it("toggle dismisses and pauses, then summons and resumes, never touching the switch", function()
        petChanged("a")
        ns:TogglePet()
        assert.is_nil(W.world.summoned)
        assert.equal("paused", ns:GetAutoState())
        assert.is_true(ns:IsAutoSummon())
        ns:TogglePet()
        assert.is_not_nil(W.world.summoned)
        assert.equal("on", ns:GetAutoState())
    end)

    it("the Dismiss key pauses until the next zone change", function()
        local changes = 0
        ns:RegisterCallback({}, "AutoSummonChanged", function() changes = changes + 1 end)
        petChanged("a")
        binding("PETCALL_DESUMMON")()
        W.fire("COMPANION_UPDATE", "CRITTER")
        assert.is_nil(W.world.summoned)
        assert.equal("paused", ns:GetAutoState())
        assert.equal(1, changes)
        W.advance(30)
        assert.is_nil(W.world.summoned, "nothing comes back while paused")
        W.world.zone = "Westfall"
        W.fire("ZONE_CHANGED_NEW_AREA")
        assert.equal("on", ns:GetAutoState())
        assert.equal(2, changes)
        W.advance(ns.db.profile.waitTimer + 2)
        assert.is_not_nil(W.world.summoned)
    end)

    it("a loading screen and Resume end the pause too", function()
        ns:PauseAuto()
        W.fire("PLAYER_ENTERING_WORLD", false, false)
        assert.equal("on", ns:GetAutoState())
        ns:PauseAuto()
        ns:ResumeAuto()
        assert.equal("on", ns:GetAutoState())
    end)

    it("dismissing outside PetCall pauses", function()
        petChanged("a")
        petChanged(nil)                                  -- the Pet Journal or the pet frame
        assert.equal("paused", ns:GetAutoState())
        W.advance(30)
        assert.is_nil(W.world.summoned, "it does not come back")
        petChanged("b")                                  -- a summon in the Pet Journal resumes
        assert.equal("on", ns:GetAutoState())
        assert.equal("b", ns.Summon.manualPick)
    end)

    it("PetCall's own summons and dismissals do not pause", function()
        petChanged("a")
        ns:SummonAnother()
        W.fire("COMPANION_UPDATE", "CRITTER")
        assert.equal("b", W.world.summoned)
        assert.equal("on", ns:GetAutoState())
        assert.is_nil(ns.Summon.manualPick)
        ns.Summon:Dismiss()
        W.fire("COMPANION_UPDATE", "CRITTER")
        assert.equal("on", ns:GetAutoState())
    end)

    it("the game taking the pet on a loading screen or death does not pause", function()
        ns.db.profile.nearPEWOnly = true
        petChanged("a")
        W.world.dead = true
        W.fire("PLAYER_DEAD")
        petChanged(nil)                                  -- death first, then the pet goes
        assert.equal("on", ns:GetAutoState())
        assert.is_true(ns.Ready.comeback)
        W.world.dead = false
        W.fire("PLAYER_UNGHOST")
        W.advance(ns.db.profile.waitTimer + 2)
        assert.is_not_nil(W.world.summoned, "it comes back")

        W.advance(30)
        petChanged("a")
        petChanged(nil)                                  -- the pet goes first, then the vehicle
        W.advance(1)
        W.world.vehicle = true
        W.fire("UNIT_ENTERED_VEHICLE", "player")
        assert.equal("on", ns:GetAutoState())
        assert.is_true(ns.Ready.comeback)
        W.world.vehicle = false
        W.fire("UNIT_EXITED_VEHICLE", "player")

        W.advance(30)
        petChanged("a")
        petChanged(nil)                                  -- a loading screen
        W.fire("PLAYER_ENTERING_WORLD", false, false)
        assert.equal("on", ns:GetAutoState())
        assert.is_true(ns.Ready.comeback)
    end)

    it("casting when the pet goes is still your own dismissal", function()
        petChanged("a")
        W.world.casting = true
        W.fire("UNIT_SPELLCAST_START", "player")
        petChanged(nil)
        assert.equal("paused", ns:GetAutoState())
        assert.is_nil(ns.Ready.comeback)
    end)

    it("the game taking the pet while Auto-summon is off leaves no comeback behind", function()
        ns:SetAutoSummon(false)
        petChanged("a")
        W.world.dead = true
        W.fire("PLAYER_DEAD")
        petChanged(nil)
        assert.is_nil(ns.Ready.comeback)
        assert.equal("off", ns:GetAutoState())
    end)

    it("a pet picked in the Pet Journal is not replaced when a set starts", function()
        local s = ns.Sets:Create("S")
        s:SetPetWeight("a", 1)
        s:SetPetWeight("b", 1)
        s:SetOnActivate("new")
        local requests = 0
        local orig = ns.Ready.Request
        local function count() requests = requests + 1 end
        petChanged("b")
        ns.Ready.Request = count
        ns.Summon:OnImmediateSet(s)
        assert.equal(0, requests, "your pick stays")
        ns.Ready.Request = orig
        ns:SummonPet("a")                                -- a grid pick is yours too
        ns.Ready.Request = count
        ns.Summon:OnImmediateSet(s)
        assert.equal(0, requests)
        ns.Ready.Request = orig
        ns.Summon:SummonRandom()                         -- PetCall's own draw is not
        ns.Ready.Request = count
        ns.Summon:OnImmediateSet(s)
        assert.equal(1, requests)
        ns.Ready.Request = orig
    end)

    it("a grid pick waits while sitting", function()
        petChanged("a")
        ns.Ready:SetReady("sitting", false)
        local n = #W.world.printed
        ns:SummonPet("b")
        W.advance(5)
        assert.equal("a", W.world.summoned)
        assert.is_true(printedSince(n, "Sitting"))
        n = #W.world.printed
        W.fire("PLAYER_STARTED_MOVING")                  -- stands up
        W.advance(1)
        assert.equal("b", W.world.summoned)
        assert.equal("b", ns.Summon.manualPick)
        assert.is_false(printedSince(n, "Sitting"), "said once")
    end)

    it("an explicit summon while Off summons and leaves Off", function()
        ns:SetAutoSummon(false)
        ns:SummonAnother()
        assert.is_not_nil(W.world.summoned)
        assert.equal("off", ns:GetAutoState())
        binding("PETCALL_TOGGLE")()
        assert.is_nil(W.world.summoned)
        assert.equal("off", ns:GetAutoState(), "a dismiss does not turn Off into Paused")
        binding("PETCALL_TOGGLE")()
        assert.is_not_nil(W.world.summoned)
        assert.is_false(ns:IsAutoSummon())
        ns:SetAutoSummon(true)
        assert.equal("on", ns:GetAutoState())
    end)

    it("says which exception it went past", function()
        W.world.mounted = true
        W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        local n = #W.world.printed
        ns:SummonAnother()
        assert.is_not_nil(W.world.summoned)
        assert.is_true(printedSince(n, "While mounted usually leaves your pet alone."))
        for _, exc in ipairs(ns.Exceptions:List()) do
            if exc.id == "mounted" then exc:SetChoice("away") end
        end
        n = #W.world.printed
        ns:SummonAnother()
        assert.is_true(printedSince(n, "While mounted usually puts your pet away."))
        W.world.mounted = false
        W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        n = #W.world.printed
        ns:SummonAnother()
        assert.is_false(printedSince(n, "usually"))
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
