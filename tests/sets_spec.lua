local W = dofile("tests/wowstub.lua")
local F = dofile("tests/fixtures/PetCall3DB_1_0.lua")

local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local c = {} for k, v in pairs(t) do c[k] = deepcopy(v) end return c
end

describe("Sets", function()
    local ns
    before_each(function()
        W.reset()
        for id, p in pairs(F.pets) do W.world.pets[id] = p end
        PetCall3DB = deepcopy(F.db)
        ns = W.load()
        W.login()
        W.advance(1)
    end)

    it("orders 1.x sets by their old priority and name, the default set last", function()
        local names = {}
        for _, s in ipairs(ns.Sets:List()) do names[#names + 1] = s.name end
        assert.same({ "RaidOrZone", "City", "Deep", "Disabled", "NoTrigger", "$Default" }, names)
        assert.equal(1, ns.Sets:Get("RaidOrZone").settings.order)      -- numbered on load
    end)

    it("moves sets up and down; new sets start at the top; the default set stays last", function()
        local function names()
            local out = {}
            for _, s in ipairs(ns.Sets:List()) do out[#out + 1] = s.name end
            return out
        end
        assert.is_true(ns.Sets:Move(ns.Sets:Get("City"), -1))
        assert.equal("City", names()[1])
        assert.is_false(ns.Sets:Move(ns.Sets:Get("NoTrigger"), 1))      -- never below Default
        assert.is_false(ns.Sets:Move(ns.Sets:Get("$Default"), -1))
        ns.Sets:Create("Fresh")
        assert.equal("Fresh", names()[1])
        ns.Sets:MoveToBottom(ns.Sets:Get("Fresh"))
        local list = names()
        assert.equal("Fresh", list[#list - 1])
        assert.equal(1, ns.Sets:Get("City"):GetRank())
        ns.Sets:MoveTo(ns.Sets:Get("City"), 3)                      -- dropped between the 3rd and 4th
        assert.equal(2, ns.Sets:Get("City"):GetRank())
        ns.Sets:MoveTo(ns.Sets:Get("City"), 99)                     -- below everything: still above Default
        list = names()
        assert.equal("City", list[#list - 1])
    end)

    it("when two sets fit, the one higher in the list is used; the other says it is outranked", function()
        local a, b = ns.Sets:Create("A"), ns.Sets:Create("B")       -- B is created last: on top
        a:SetPetWeight("BattlePet-0-0001", 1)
        b:SetPetWeight("BattlePet-0-0001", 1)
        W.advance(1)
        assert.equal(b, ns.Sets:GetCurrent())
        assert.equal("outranked", a:GetStatus())
        ns.Sets:Move(a, -1)
        assert.equal(a, ns.Sets:GetCurrent())
    end)

    it("pauses any set: until resumed, for an hour, until logout", function()
        local d = ns.Sets:Get("$Default")
        local a = ns.Sets:Create("A")
        a:SetPetWeight("BattlePet-0-0001", 1)
        W.advance(1)
        assert.equal(a, ns.Sets:GetCurrent())
        a:Pause("hour")
        local paused, kind, left = a:IsPaused()
        assert.is_true(paused)
        assert.equal("timed", kind)
        assert.is_true(left > 3500)
        assert.is_false(ns.Sets:GetCurrent() == a)
        W.advance(3602)
        assert.is_false((a:IsPaused()))
        assert.equal(a, ns.Sets:GetCurrent())                      -- back by itself
        a:Pause("session")
        assert.equal("paused", a:GetStatus())
        a:Resume()
        assert.is_false((a:IsPaused()))
        d:Pause()                                                   -- the default set too
        assert.equal("paused", d:GetStatus())
        assert.is_false(d.settings.enabled)
    end)

    it("validates names", function()
        assert.is_false((ns.Sets:ValidateName("")))
        assert.is_false((ns.Sets:ValidateName("$x")))
        assert.is_false((ns.Sets:ValidateName("City")))
        assert.is_true((ns.Sets:ValidateName("City", "City")))
        local set, ok = ns.Sets:Create("  New  ")
        assert.is_true(ok)
        assert.equal("New", set.name)
        assert.equal(true, set.settings.enabled)
        assert.equal(1, set.settings.priority)
    end)

    it("renames without leaving stale entries and refuses duplicates", function()
        local city = ns.Sets:Get("City")
        assert.is_false((city:Rename("Deep")))
        assert.is_true((city:Rename("Town")))
        assert.equal(city, ns.Sets:Get("Town"))
        assert.is_nil(ns.Sets:Get("City"))
        assert.is_nil(rawget(ns.db.profile.sets, "City"))
        assert.equal("Town", ns.db.profile.sets.Town.name)
    end)

    it("default set cannot be renamed or deleted", function()
        local d = ns.Sets:Get("$Default")
        assert.is_false((d:Rename("X")))
        assert.is_false((d:Delete()))
    end)

    it("weights and chance", function()
        local d = ns.Sets:Get("$Default")
        d:SetPetWeight("BattlePet-0-0005", 64)
        assert.equal(64, d:GetPetWeight("BattlePet-0-0005"))
        assert.is_true(d:HasManualWeight("BattlePet-0-0005"))
        local c = ns.Weights.Chance(d:GetWeightTable(), "BattlePet-0-0005")
        assert.is_true(c > 0 and c < 1)
        d:ClearPetWeights()
        assert.is_false(d:HasManualWeight("BattlePet-0-0005"))
        W.world.cooldowns["BattlePet-0-0001"] = 30
        assert.equal("On cooldown", d:Unavailable("BattlePet-0-0001"))
    end)

    it("fires SetsChanged on edits", function()
        local got = {}
        ns:RegisterCallback({}, "SetsChanged", function(_, n) got[#got + 1] = n end)
        ns.Sets:Get("City"):SetDefaultWeight(8)
        assert.same({ "City" }, got)
    end)

    it("status reflects enabled/empty/noConditions", function()
        assert.equal("paused", ns.Sets:Get("Disabled"):GetStatus())
        local nt = ns.Sets:Get("NoTrigger")
        assert.is_true(nt:GetStatus() == "active" or nt:GetStatus() == "outranked")
        local e = ns.Sets:Create("Empty")
        assert.equal("empty", e:GetStatus())
    end)

    it("reloads on profile change", function()
        ns.DB:Set("Other")
        assert.is_nil(ns.Sets:Get("City"))
        assert.is_not_nil(ns.Sets:Get("$Default"))
    end)
    it("normalizes triggers on load and keeps meaning", function()
        local raid = ns.Sets:Get("RaidOrZone")
        local m = raid:GetConditionModel()
        assert.equal(2, #m.groups)
    end)

    it("matches 1.0.x current set across worlds", function()
        local REF = dofile("tests/fixtures/reference_1_0.lua")
        for wi, state in ipairs(F.worlds) do
            W.reset()
            for id, p in pairs(F.pets) do W.world.pets[id] = p end
            for id in pairs(F.favorites) do W.world.favorites[id] = true end
            for k, v in pairs(state) do W.world[k] = v end
            PetCall3DB = deepcopy(F.db)
            local ns2 = W.load()
            W.login()
            W.advance(1)
            local cur = ns2.Sets:GetCurrent()
            assert.equal(REF[wi].current, cur and cur.name or "", "world " .. wi)
        end
    end)

    it("edits through the model and fires ConditionStateChanged", function()
        local city = ns.Sets:Get("City")
        local fired = 0
        ns:RegisterCallback({}, "ConditionStateChanged", function() fired = fired + 1 end)
        local m = city:GetConditionModel()
        table.insert(m.groups[1].rows, { "groupType", party = true, raid = true })
        city:SetConditionModel(m)
        assert.equal(2, #city.settings.trigger)
        assert.is_true(fired >= 1)
        assert.is_false(city:ConditionsMet())     -- solo in world 1
    end)

    it("templates", function()
        local s = ns.Sets:Create("T")
        s:ApplyTemplate("city")
        assert.equal("specialLocation", s.settings.trigger[1][1])
        assert.is_true(s:ConditionsMet())
    end)

    it("profile switch frees watchers", function()
        local old = ns.Sets:Get("City").watcher
        assert.is_not_nil(old)
        ns.DB:Set("Other")
        assert.is_true(old.freed)
    end)
    it("set objects from a previous profile cannot edit the new one", function()
        local old = ns.Sets:Get("City")
        local oldWatcher = old.watcher
        ns.DB:Set("Other")
        ns.Sets:Create("City")
        assert.is_false((old:Delete()))
        assert.is_false((old:Rename("Town")))
        old:SetDefaultWeight(8)
        old:ConditionsChanged()
        assert.is_not_nil(ns.Sets:Get("City"))
        assert.is_nil(rawget(ns.db.profile.sets, "Town"))
        assert.equal(0, ns.Sets:Get("City").settings.defaultValue)
        assert.is_true(oldWatcher.freed)
        local refreshed = 0
        oldWatcher.Refresh = function() refreshed = refreshed + 1 end
        W.fire("ZONE_CHANGED_NEW_AREA")
        assert.equal(0, refreshed)
    end)
    it("on start: keep, new unless it fits, always new", function()
        local s = ns.Sets:Create("S")
        assert.equal("keep", s:GetOnActivate())
        s:SetOnActivate("new")
        assert.is_true(s.settings.immediate and s.settings.alwaysNew)
        s:SetOnActivate("fits")
        assert.equal("fits", s:GetOnActivate())
        assert.is_nil(s.settings.alwaysNew)
        W.world.summoned = "BattlePet-0-0001"
        s:SetPetWeight("BattlePet-0-0001", 1)
        local queued = 0
        local orig = ns.Ready.Request
        ns.Ready.Request = function(_, action, source)
            assert.equal("switch", action)
            assert.equal("auto", source)
            queued = queued + 1
        end
        ns.Summon:OnImmediateSet(s)
        assert.equal(0, queued)                                     -- the pet out fits: kept
        s:SetOnActivate("new")
        ns.Summon:OnImmediateSet(s)
        assert.equal(1, queued)
        ns.Ready.Request = orig
    end)

    it("a set's own switch interval wins over the setting", function()
        local s = ns.Sets:Create("Quick")
        s:SetPetWeight("BattlePet-0-0001", 1)
        s:SetSwitch(5)
        W.advance(1)
        assert.equal(s, ns.Sets:GetCurrent())
        W.world.summoned = "BattlePet-0-0001"
        ns.SwitchTimer:Start()
        assert.equal(300, ns.SwitchTimer.interval)
    end)

    it("a set without its own timer uses Default's", function()
        local d = ns.Sets:Get("$Default")
        local x = ns.Sets:Create("X")
        d:SetSwitch(30, true)
        assert.same({ 30, true, true }, { x:GetSwitch() })
        x:SetSwitch(5)
        assert.same({ 5, false, false }, { x:GetSwitch() })
        x:SetSwitch(nil)
        assert.same({ 30, true, true }, { x:GetSwitch() })
    end)

    it("a deleted set's timer and message setters do nothing", function()
        local x = ns.Sets:Create("X")
        x:Delete()
        x:SetSwitch(5, true)
        x:SetAnnounce(false)
        assert.is_nil(x.settings.switchMinutes)
        assert.is_nil(x.settings.announce)
    end)

    it("Default's timer off is 0, not nil", function()
        assert.same({ 0, false, false }, { ns.Sets:Get("$Default"):GetSwitch() })
        ns.Sets:Get("$Default"):SetSwitch(nil)                      -- Default has no "like Default"
        assert.same({ 0, false, false }, { ns.Sets:Get("$Default"):GetSwitch() })
    end)

    it("keeps a timer value that is not a dropdown choice", function()
        local x = ns.Sets:Create("X")
        x.settings.switchMinutes = 7
        assert.equal(7, (x:GetSwitch()))
    end)

    it("announce follows Default unless set", function()
        local d, x = ns.Sets:Get("$Default"), ns.Sets:Create("X")
        assert.same({ true, true }, { x:GetAnnounce() })
        d:SetAnnounce(false)
        assert.same({ false, true }, { x:GetAnnounce() })
        x:SetAnnounce(true)
        assert.same({ true, false }, { x:GetAnnounce() })
        assert.equal("on", x.settings.announce)
        x:SetAnnounce(nil)
        assert.is_nil(x.settings.announce)
        d:SetAnnounce(nil)
        assert.same({ false, false }, { d:GetAnnounce() })
    end)

    it("duplicates a set right below it with all its settings", function()
        local city = ns.Sets:Get("City")
        city:SetSwitch(15)
        local copy = ns.Sets:Duplicate(city)
        assert.equal("City copy", copy.name)
        assert.equal(15, copy.settings.switchMinutes)
        assert.same(city.settings.trigger, copy.settings.trigger)
        assert.is_false(copy.settings.trigger == city.settings.trigger)
        assert.equal(city:GetRank() + 1, copy:GetRank())
        assert.equal("City copy 2", ns.Sets:Duplicate(city).name)
        local d = ns.Sets:Duplicate(ns.Sets:Get("$Default"))
        assert.equal("Default copy", d.name)
        assert.is_nil(d.settings.priority)
        assert.same({ 0, false, false }, { ns.Sets:Get("$Default"):GetSwitch() })
        assert.same({ 0, false, true }, { d:GetSwitch() })          -- follows Default, not pinned off
        assert.same({ true, true }, { d:GetAnnounce() })
    end)

    it("a set's chat-message choice wins over the setting", function()
        local s = ns.Sets:Create("Loud")
        s:SetPetWeight("BattlePet-0-0001", 1)
        s:SetAnnounce(true)
        ns.Sets:Get("$Default"):SetAnnounce(false)
        W.advance(1)
        W.world.summoned = nil
        local before = #W.world.printed
        assert.is_true(ns.Summon:SummonRandom())
        assert.is_true(#W.world.printed > before)
        s:SetAnnounce(false)
        ns.Sets:Get("$Default"):SetAnnounce(true)
        before = #W.world.printed
        W.world.summoned = nil
        ns.Summon:SummonRandom()
        assert.equal(before, #W.world.printed)
    end)
end)
