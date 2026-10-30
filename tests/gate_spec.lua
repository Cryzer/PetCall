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
