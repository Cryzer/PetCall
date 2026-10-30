local W = dofile("tests/wowstub.lua")
describe("Gate", function()
    local ns, G
    local function byId(id)
        for _, exc in ipairs(ns.Exceptions:List()) do if exc.id == id then return exc end end
    end
    local function mount(on)
        W.world.mounted = on
        W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
    end
    local function enter(instanceType)
        W.world.instanceType, W.world.resting = instanceType, instanceType == "none"
        W.fire("ZONE_CHANGED_NEW_AREA")
    end

    before_each(function()
        W.reset()
        W.world.pets = { a = { species = 1, name = "A" }, b = { species = 2, name = "B" } }
        ns = W.load()
        W.login()
        W.advance(1)
        G = ns.Gate
    end)

    it("game blockers stop both sources", function()
        W.world.combat = true
        W.fire("PLAYER_REGEN_DISABLED")
        for _, source in ipairs({ "auto", "explicit" }) do
            local ok, cause = G:Check("summon", source)
            assert.is_false(ok)
            assert.equal("game", cause.level)
            assert.equal("combat", cause.key)
            assert.equal("In combat", cause.label)
        end
        W.world.combat = false
        W.fire("PLAYER_REGEN_ENABLED")
        assert.is_true((G:Check("summon", "auto")))
        assert.is_true((G:Check("summon", "explicit")))
    end)

    it("exceptions stop only automatic requests", function()
        mount(true)
        local ok, cause = G:Check("switch", "auto")
        assert.is_false(ok)
        assert.equal("exception", cause.level)
        assert.equal("mounted", cause.key)
        assert.equal("While mounted", cause.label)
        assert.equal(byId("mounted"), cause.exc)
        assert.equal(cause, select(2, G:Check("summon", "auto")))      -- one shared table
        assert.is_true((G:Check("switch", "explicit")))
        local blockers = ns.Ready:GetBlockers()
        assert.equal(0, #blockers, "mounted is no longer a game blocker")
    end)

    it("Auto-summon off stops automatic, not explicit", function()
        ns:SetAutoSummon(false)
        local ok, cause = G:Check("summon", "auto")
        assert.is_false(ok)
        assert.equal("auto", cause.level)
        assert.is_true((G:Check("summon", "explicit")))
        ns:SetAutoSummon(true)
        assert.is_true((G:Check("summon", "auto")))
    end)

    it("the key binding goes through outside the zoning window", function()
        ns.db.profile.nearPEWOnly = true
        ns.Ready:UpdateChecks()
        W.advance(20)                                    -- the login's window has closed
        W.world.summoned = "a"
        local printed = #W.world.printed
        ns:SummonAnother()
        W.advance(1)
        assert.equal("b", W.world.summoned)
        for i = printed + 1, #W.world.printed do
            assert.is_nil(W.world.printed[i]:find("when this ends"), W.world.printed[i])
        end
    end)

    it("the timer is not held back by zoning-only", function()
        ns.db.profile.nearPEWOnly = true
        ns.Ready:UpdateChecks()
        ns.Sets:Get("$Default"):SetSwitch(5)
        W.advance(20)
        W.world.summoned = "a"
        ns.SwitchTimer:Start()
        W.advance(300 + ns.db.profile.waitTimer + 2)
        assert.equal("b", W.world.summoned)
    end)

    it("an away exception that starts in combat dismisses after combat", function()
        byId("bg"):SetChoice("away")
        W.world.summoned = "a"
        W.world.combat = true
        W.fire("PLAYER_REGEN_DISABLED")
        enter("pvp")
        assert.equal("a", W.world.summoned, "not in combat")
        W.world.combat = false
        W.fire("PLAYER_REGEN_ENABLED")
        assert.is_nil(W.world.summoned)
    end)

    it("a combat-deferred dismissal is not repeated", function()
        byId("bg"):SetChoice("away")
        W.world.summoned = "a"
        W.world.combat = true
        W.fire("PLAYER_REGEN_DISABLED")
        enter("pvp")
        W.world.combat = false
        W.fire("PLAYER_REGEN_ENABLED")
        assert.is_nil(W.world.summoned)
        W.advance(1)
        ns:SummonPet("b")                                -- yours, inside the battleground
        W.world.combat = true
        W.fire("PLAYER_REGEN_DISABLED")
        W.world.combat = false
        W.fire("PLAYER_REGEN_ENABLED")
        W.advance(1)
        assert.equal("b", W.world.summoned)
    end)

    it("a dismiss cancels a summon still waiting for the game", function()
        W.world.summoned = "a"
        W.world.combat = true
        W.fire("PLAYER_REGEN_DISABLED")
        ns:SummonAnother()
        ns:DismissPet()
        assert.is_nil(ns.Ready.pending)
        W.world.combat = false
        W.fire("PLAYER_REGEN_ENABLED")
        W.advance(5)
        assert.is_nil(W.world.summoned)
    end)

    it("an own exception's name is read again only when it changes", function()
        byId("mounted"):SetChoice(false)
        local own = ns.Exceptions:Add({ { "activity", mounted = true } }, "alone")
        mount(true)
        local _, cause = G:Check("summon", "auto")
        local label = cause.label
        local calls, orig = 0, own.DisplayName
        own.DisplayName = function(self) calls = calls + 1 return orig(self) end
        W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        ns:Fire("ExceptionsChanged")
        G:Check("summon", "auto")
        assert.equal(0, calls)
        own:SetConditionModel(own:GetConditionModel())
        G:Check("summon", "auto")
        assert.equal(1, calls)
        assert.equal(label, cause.label)
    end)

    it("an away exception does nothing while Auto-summon is off", function()
        byId("bg"):SetChoice("away")
        ns:SetAutoSummon(false)
        W.world.summoned = "a"
        enter("pvp")
        assert.equal("a", W.world.summoned)
    end)

    it("a pet put away by an exception comes back when it ends, even with zoning-only", function()
        ns.db.profile.nearPEWOnly = true
        ns.Ready:UpdateChecks()
        byId("mounted"):SetChoice("away")
        W.advance(20)
        W.world.summoned = "a"
        mount(true)
        assert.is_nil(W.world.summoned)
        W.advance(20)
        assert.is_nil(W.world.summoned, "nothing while mounted")
        mount(false)
        W.advance(ns.db.profile.waitTimer + 2)
        assert.is_not_nil(W.world.summoned)
        W.world.summoned = nil                           -- once: the window rule holds again
        W.advance(20)
        assert.is_nil(W.world.summoned)
    end)

    it("an automatic request held back by an exception runs when it ends", function()
        W.world.summoned = "a"
        mount(true)
        ns.Ready:Request("switch", "auto")
        W.advance(10)
        assert.equal("a", W.world.summoned)
        mount(false)
        W.advance(ns.db.profile.waitTimer + 2)
        assert.equal("b", W.world.summoned)
    end)

    it("an explicit request waits for the game and replaces an automatic one", function()
        W.world.summoned = "a"
        W.world.combat = true
        W.fire("PLAYER_REGEN_DISABLED")
        ns.Ready:Request("switch", "auto")
        ns.Ready:Request("summon", "explicit")
        ns.Ready:Request("switch", "auto")
        assert.equal("explicit", ns.Ready.pending)
        W.world.combat = false
        W.fire("PLAYER_REGEN_ENABLED")
        W.advance(1)                                     -- no wait timer
        assert.equal("b", W.world.summoned)
        assert.is_nil(ns.Ready.pending)
    end)

    it("explains the earliest level first", function()
        mount(true)
        ns:PauseAuto()
        W.world.combat = true
        W.fire("PLAYER_REGEN_DISABLED")
        local why = G:Explain()
        assert.equal("game", why.kind)
        assert.equal("In combat", why.label)
        W.world.combat = false
        W.fire("PLAYER_REGEN_ENABLED")
        assert.equal("paused", G:Explain().kind)
        ns:ResumeAuto()
        ns:SetAutoSummon(false)
        assert.equal("off", G:Explain().kind)
        ns:SetAutoSummon(true)
        assert.equal("exception", G:Explain().kind)
    end)

    it("explains a pause", function()
        ns:PauseAuto()
        local why = G:Explain()
        assert.equal("paused", why.kind)
        assert.equal("Paused until you change zone", why.label)
    end)

    it("explains an exception by name", function()
        mount(true)
        local why = G:Explain()
        assert.equal("exception", why.kind)
        assert.equal(byId("mounted"), why.exc)
        assert.equal("While mounted", why.label)
    end)

    it("tells the next timer switch when nothing holds back", function()
        ns.Sets:Get("$Default"):SetSwitch(5)
        W.world.summoned = "a"
        W.fire("COMPANION_UPDATE", "CRITTER")
        ns.SwitchTimer:Start()
        W.advance(60)
        local why = G:Explain()
        assert.equal("next", why.kind)
        assert.equal(5, why.minutes)
        assert.equal(ns.Sets:GetCurrent(), why.set)
        assert.is_true(math.abs(why.seconds - 240) <= 1, tostring(why.seconds))
        ns.Sets:Get("$Default"):SetSwitch(0)
        ns.SwitchTimer:Start()
        assert.equal("idle", G:Explain().kind)
        assert.is_nil(ns.SwitchTimer:Remaining())
    end)

    it("explains a kept pet after a set starts", function()
        local s = ns.Sets:Create("S")
        s:SetPetWeight("a", 1)
        s:SetOnActivate("fits")
        W.world.summoned = "a"
        W.fire("COMPANION_UPDATE", "CRITTER")
        ns.Summon:OnImmediateSet(s)
        local why = G:Explain()
        assert.equal("set", why.kind)
        assert.equal(s, why.set)
        assert.equal("fits", why.reason)
        assert.equal("set_kept", (G:LastEvent()))
        assert.equal(s, select(2, G:LastEvent()).set)
        W.advance(601)
        assert.equal("idle", G:Explain().kind, "a set start is only news for ten minutes")
    end)

    it("remembers a replaced pet and the other events", function()
        local s = ns.Sets:Create("S")
        s:SetPetWeight("b", 1)
        W.world.summoned = "a"
        W.fire("COMPANION_UPDATE", "CRITTER")
        ns.Summon.manualPick = nil                       -- PetCall's own draw, not your pick
        ns.Summon:OnImmediateSet(s)
        local event, data = G:LastEvent()
        assert.equal("set_replaced", event)
        assert.equal("not_in_set", data.reason)
        ns:PauseAuto()
        assert.equal("paused", (G:LastEvent()))
        byId("bg"):SetChoice("away")
        ns:ResumeAuto()
        enter("pvp")
        event, data = G:LastEvent()
        assert.equal("put_away", event)
        assert.equal(byId("bg"), data.exc)
    end)

    it("a set note stands only while the pet it was about is out", function()
        local s = ns.Sets:Create("S")
        s:SetPetWeight("a", 1)
        s:SetPetWeight("b", 1)
        s:SetOnActivate("fits")
        W.world.summoned = "a"
        W.fire("COMPANION_UPDATE", "CRITTER")
        ns.Summon:OnImmediateSet(s)
        assert.equal("set", G:Explain().kind)
        W.world.summoned = "b"
        W.fire("COMPANION_UPDATE", "CRITTER")
        assert.is_true(G:Explain().kind ~= "set", "another pet came out since")
    end)

    it("a replaced pet is explained once the new one is out", function()
        local s = ns.Sets:Create("S")
        s:SetPetWeight("b", 1)
        W.world.summoned = "a"
        W.fire("COMPANION_UPDATE", "CRITTER")
        ns.Summon.manualPick = nil
        ns.Summon:OnImmediateSet(s)
        assert.is_true(G:Explain().kind ~= "set", "the old pet is still out")
        assert.is_true(ns.Summon:SummonRandom())
        W.advance(1)
        assert.equal("b", W.world.summoned)
        local why = G:Explain()
        assert.equal("set", why.kind)
        assert.is_true(why.replaced)
        assert.equal("not_in_set", why.reason)
    end)

    it("Summon another after a set replaced the pet ends the set note", function()
        W.world.pets.c = { species = 3, name = "C" }
        ns.PetCache:Rescan()
        local s = ns.Sets:Create("S")
        s:SetPetWeight("b", 1)
        s:SetPetWeight("c", 1)
        W.world.summoned = "a"
        W.fire("COMPANION_UPDATE", "CRITTER")
        ns.Summon.manualPick = nil
        ns.Summon:OnImmediateSet(s)
        ns.Summon:SummonRandom()
        W.advance(1)
        assert.equal("set", G:Explain().kind)
        local was = W.world.summoned
        ns:SummonAnother()
        W.advance(5)
        assert.is_true(W.world.summoned ~= was, "another pet came out")
        assert.is_true(G:Explain().kind ~= "set", "your request is not the set's doing")
    end)

    it("says whether a request is waiting", function()
        assert.is_false(G:Explain().waiting)
        W.world.combat = true
        W.fire("PLAYER_REGEN_DISABLED")
        ns.Ready:Request("summon", "auto")
        local why = G:Explain()
        assert.equal("game", why.kind)
        assert.is_true(why.waiting)
    end)

    it("noting does not allocate", function()
        collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 1000 do G:Note("timer") end
        local grew = collectgarbage("count") - before
        collectgarbage("restart")
        assert.is_true(grew < 1, "grew " .. grew .. " KB")
    end)

    it("checking does not allocate", function()
        mount(true)
        assert.equal("alone", (ns.Exceptions:Strongest()))
        collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 1000 do G:Check("summon", "auto") end
        local grew = collectgarbage("count") - before
        collectgarbage("restart")
        assert.is_true(grew < 1, "grew " .. grew .. " KB")
    end)
end)
