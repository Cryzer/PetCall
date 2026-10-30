local W = dofile("tests/wowstub.lua")

describe("Exceptions", function()
    local ns, E
    local function byId(id)
        for _, exc in ipairs(E:List()) do if exc.id == id then return exc end end
    end
    local function enter(instanceType)
        W.world.instanceType, W.world.resting = instanceType, instanceType == "none"
        W.fire("ZONE_CHANGED_NEW_AREA")
    end

    before_each(function()
        W.reset()
        ns = W.load()
        W.login()
        E = ns.Exceptions
    end)

    it("lists the eight built-ins first with fresh-install choices", function()
        local ids = {}
        for _, exc in ipairs(E:List()) do ids[#ids + 1] = exc.id end
        assert.same({ "mounted", "bg", "arena", "dungeon", "raid", "scenario", "hidden", "outsideCities" }, ids)
        assert.equal("alone", byId("mounted"):GetChoice())
        for i = 2, 8 do assert.is_false(E:List()[i]:GetChoice()) end
        assert.is_true(byId("bg").builtin)
        assert.equal("Battlegrounds", byId("bg"):DisplayName())
        assert.equal("Stealth or invisibility", byId("hidden"):DisplayName())
        assert.same({ false, "alone", "away" }, byId("bg"):Choices())
        assert.same({ false, "away" }, byId("hidden"):Choices())
        assert.same({ { "specialLocation", locs = { "city" }, negate = true } }, byId("outsideCities").trigger)
    end)

    it("As usual has no watcher", function()
        local bg = byId("bg")
        assert.is_nil(bg.watcher)
        assert.is_not_nil(byId("mounted").watcher)
        bg:SetChoice("away")
        local w = bg.watcher
        assert.is_not_nil(w)
        assert.equal("away", ns.db.profile.exceptions.builtin.bg)
        bg:SetChoice(false)
        assert.is_nil(bg.watcher)
        assert.is_true(w.freed)
        assert.is_false(ns.db.profile.exceptions.builtin.bg)
    end)

    it("the strongest fitting exception wins", function()
        local bg, mounted = byId("bg"), byId("mounted")
        bg:SetChoice("away")
        assert.is_nil(E:Strongest())
        W.world.mounted = true
        W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        local choice, exc = E:Strongest()
        assert.equal("alone", choice)
        assert.equal(mounted, exc)
        enter("pvp")
        choice, exc = E:Strongest()
        assert.equal("away", choice)
        assert.equal(bg, exc)
        local inForce = E:InForce()
        assert.same({ bg, mounted }, { inForce[1], inForce[2] })
        assert.equal(inForce, E:InForce())                    -- cached until something changes
        bg:SetChoice("alone")
        choice, exc = E:Strongest()
        assert.equal("alone", choice)
        assert.equal(mounted, exc)                            -- same strength: the first in the list
        enter("none")
        W.world.mounted = false
        W.fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        assert.is_nil(E:Strongest())
    end)

    it("fires ExceptionStarted on entering, not while inside", function()
        local started, changed = {}, 0
        ns:RegisterCallback({}, "ExceptionStarted", function(_, exc) started[#started + 1] = exc end)
        ns:RegisterCallback({}, "ExceptionsChanged", function() changed = changed + 1 end)
        local dungeon = byId("dungeon")
        dungeon:SetChoice("away")
        assert.is_true(changed > 0)
        enter("party")
        assert.same({ dungeon }, started)
        W.fire("ZONE_CHANGED")
        W.fire("PLAYER_ENTERING_WORLD", false, false)         -- a loading screen inside
        assert.equal(1, #started)
        enter("none")
        enter("party")
        assert.equal(2, #started)
    end)

    it("fires ExceptionStarted at login inside the condition", function()
        W.reset()
        PetCall3DB = { profiles = { Default = { exceptions = { builtin = { bg = "away" } } } } }
        W.world.instanceType, W.world.resting = "pvp", false
        ns = W.load()
        local started = {}
        ns:RegisterCallback({}, "ExceptionStarted", function(_, exc) started[#started + 1] = exc.id end)
        W.login()
        assert.same({ "bg" }, started)
        W.fire("PLAYER_ENTERING_WORLD", false, false)
        assert.same({ "bg" }, started)
    end)

    it("raids count solo by default", function()
        local raid = byId("raid")
        raid:SetChoice("away")
        assert.is_true(raid:GetSolo())
        enter("raid")
        assert.equal("away", (E:Strongest()))
    end)

    it("with Also when solo cleared, a raid fits only in a group", function()
        local raid = byId("raid")
        raid:SetChoice("away")
        local changed = 0
        ns:RegisterCallback({}, "ExceptionsChanged", function() changed = changed + 1 end)
        raid:SetSolo(false)
        assert.is_true(changed > 0)
        assert.is_false(raid:GetSolo())
        assert.is_false(ns.db.profile.exceptions.solo.raid)
        enter("raid")
        assert.is_nil(E:Strongest())
        W.world.inRaid = true
        W.fire("GROUP_ROSTER_UPDATE")
        assert.equal(raid, select(2, E:Strongest()))
        raid:SetSolo(true)
        W.world.inRaid = false
        W.fire("GROUP_ROSTER_UPDATE")
        assert.equal(raid, select(2, E:Strongest()))
    end)

    it("only the three PvE built-ins have the solo option", function()
        local with = {}
        for _, exc in ipairs(E:List()) do if exc:HasSolo() then with[#with + 1] = exc.id end end
        assert.same({ "dungeon", "raid", "scenario" }, with)
        local bg = byId("bg")
        bg:SetSolo(false)
        assert.equal(1, #bg.trigger)
        assert.is_false(E:Add({ { "groupType", party = true } }, "away"):HasSolo())
    end)

    it("own exceptions: add, name falls back to the condition, delete", function()
        local a = E:Add({ { "zone", zoneName = "Dornogal" } }, "away")
        local b = E:Add({ { "zone", zoneName = "Valdrakken" } }, false, "Hub")
        assert.equal("own:1", a.id)
        assert.equal("own:2", b.id)
        assert.is_false(a.builtin)
        local list = E:List()
        assert.equal(10, #list)
        assert.equal(a, list[9])
        assert.equal("Place: Dornogal", a:DisplayName())
        assert.equal("Hub", b:DisplayName())
        assert.is_not_nil(a.watcher)
        assert.is_nil(b.watcher)
        local own = ns.db.profile.exceptions.own
        assert.equal(2, #own)
        assert.equal("away", own[1].choice)
        assert.equal("Hub", own[2].name)
        W.world.zone = "Dornogal"
        W.fire("ZONE_CHANGED_NEW_AREA")
        assert.equal(a, select(2, E:Strongest()))
        assert.is_false((byId("bg"):Delete()))
        a:Delete()
        assert.equal(9, #E:List())
        assert.equal(1, #own)
        assert.is_nil(E:Strongest())
        assert.equal("own:3", E:Add({ { "zone", zoneName = "Oribos" } }, "alone").id)
    end)
end)
