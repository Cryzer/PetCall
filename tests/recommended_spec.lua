local W = dofile("tests/wowstub.lua")

describe("Recommended", function()
    local ns, R
    local function row(key)
        for _, r in ipairs(R:Rows()) do if r.key == key then return r end end
    end
    local function exc(id)
        for _, e in ipairs(ns.Exceptions:List()) do if e.id == id then return e end end
    end
    local function default() return ns.Sets:Get(ns.Sets.DEFAULT) end
    local function switch(set)
        local minutes, cities = set:GetSwitch()
        return { minutes, cities }
    end

    before_each(function()
        W.reset()
        ns = W.load()
        W.login()
        R = ns.Recommended
    end)

    it("rows compare yours with recommended", function()
        local r = row("enable")
        assert.same({ "enable", "Auto-summon", "On", "On", true }, { r.key, r.label, r.yours, r.recommended, r.same })
        r = row("bringOut")
        assert.equal("When I stand still, 3 s", r.yours)
        assert.is_true(r.same)
        r = row("newMap")
        assert.same({ "No", "No", true }, { r.yours, r.recommended, r.same })
        r = row("petBattle")
        assert.same({ "Keep the game's pick", "Bring back my pet", false }, { r.yours, r.recommended, r.same })
        r = row("defaultSwitch")
        assert.same({ "Off", "30 minutes", false }, { r.yours, r.recommended, r.same })
        r = row("defaultAnnounce")
        assert.same({ "Always", "Never", false }, { r.yours, r.recommended, r.same })
        r = row("mounted")
        assert.same({ "While mounted", "Leave the pet alone", "Leave the pet alone", true }, { r.label, r.yours, r.recommended, r.same })
        r = row("raid")
        assert.same({ "As usual", "Put the pet away", false }, { r.yours, r.recommended, r.same })
        r = row("solo")
        assert.same({ "Also when solo", "Dungeons, Raids, Scenarios and delves", true }, { r.label, r.yours, r.same })
        ns:SetAutoSummon(false)
        ns:SetProfileValue("nearPEWOnly", true)
        exc("raid"):SetSolo(false)
        exc("dungeon"):SetSolo(false)
        exc("scenario"):SetSolo(false)
        assert.same({ "Off", "On", false }, { row("enable").yours, row("enable").recommended, row("enable").same })
        assert.same({ "Only after a loading screen", false }, { row("bringOut").yours, row("bringOut").same })
        assert.same({ "None", false }, { row("solo").yours, row("solo").same })
        exc("raid"):SetSolo(true)
        assert.equal("Raids", row("solo").yours)
        default():SetSwitch(15, true)
        assert.equal("15 minutes, only in cities", row("defaultSwitch").yours)
    end)

    it("apply changes only the listed settings", function()
        local x = ns.Sets:Create("X")
        x:SetSwitch(5, true)
        x:SetAnnounce(true)
        local own = ns.Exceptions:Add({ { "activity", mounted = true } }, "alone", "Mine")
        local fired = 0
        ns:RegisterCallback({}, "RecommendedApplied", function() fired = fired + 1 end)
        R:Apply()
        assert.equal(1, fired)
        local p = ns.db.profile
        assert.same({ true, false, 3, false, true }, { p.enable, p.nearPEWOnly, p.waitTimer, p.switchOnNewMap, p.overrideSetLoadout })
        assert.same({ 30, false }, switch(default()))
        assert.is_false((default():GetAnnounce()))
        assert.equal("alone", exc("mounted"):GetChoice())
        assert.equal("away", exc("bg"):GetChoice())
        assert.equal("away", exc("hidden"):GetChoice())
        assert.is_false(exc("scenario"):GetChoice())
        assert.is_false(exc("outsideCities"):GetChoice())
        assert.same({ 5, true }, switch(x))
        assert.is_true((x:GetAnnounce()))
        assert.equal("alone", own:GetChoice())
        assert.equal(1, #ns.db.profile.exceptions.own)
        for _, r in ipairs(R:Rows()) do assert.is_true(r.same, r.key) end
    end)

    it("undo restores the previous values", function()
        assert.is_false(R:CanUndo())
        ns:SetAutoSummon(false)
        ns:SetProfileValue("waitTimer", 7)
        ns:SetProfileValue("nearPEWOnly", true)
        default():SetSwitch(10, true)
        default():SetAnnounce(true)
        exc("raid"):SetChoice("alone")
        exc("raid"):SetSolo(false)
        R:Apply()
        assert.is_true(R:CanUndo())
        assert.is_true(ns:IsAutoSummon())
        assert.equal("away", exc("raid"):GetChoice())
        R:Undo()
        local p = ns.db.profile
        assert.same({ false, true, 7, false, false }, { p.enable, p.nearPEWOnly, p.waitTimer, p.switchOnNewMap, p.overrideSetLoadout })
        assert.same({ 10, true }, switch(default()))
        assert.is_true((default():GetAnnounce()))
        assert.equal("alone", exc("raid"):GetChoice())
        assert.is_false(exc("raid"):GetSolo())
        assert.equal("alone", exc("mounted"):GetChoice())
        assert.is_false(exc("bg"):GetChoice())
        assert.is_false(R:CanUndo())
    end)

    it("undo is gone after a change by hand", function()
        local changes = {
            function() ns:SetAutoSummon(false) end,
            function() ns:SetProfileValue("overrideSetLoadout", false) end,
            function() ns:SetProfileValue("waitTimer", 5) end,
            function() default():SetSwitch(20, false) end,
            function() default():SetAnnounce(true) end,
            function() exc("bg"):SetChoice("alone") end,
            function() exc("raid"):SetSolo(false) end,
        }
        for i, change in ipairs(changes) do
            R:Apply()
            assert.is_true(R:CanUndo(), i)
            change()
            assert.is_false(R:CanUndo(), i)
            R:Undo()                                        -- nothing left to undo
            W.reset()
            ns = W.load()
            W.login()
            R = ns.Recommended
        end
    end)

    it("undo survives a change that is not a setting", function()
        R:Apply()
        local x = ns.Sets:Create("X")
        x:SetSwitch(5, false)
        ns.Exceptions:Add({}, "away")
        ns:Fire("ExceptionsChanged")
        assert.is_true(R:CanUndo())
    end)

    it("converted exceptions show as kept", function()
        ns.Exceptions:Add({ { "activity", mounted = true } }, "away", nil, "Quiet raid")
        ns.Exceptions:Add({ { "activity", mounted = true } }, "alone", "Hand made")
        local rows = R:Rows()
        local last = rows[#rows]
        assert.equal("kept", last.recommended)
        assert.equal("Put the pet away", last.yours)
        assert.is_true(last.same)
        assert.is_true(last.label ~= "Hand made")
        local n = 0
        for _, r in ipairs(rows) do if r.recommended == "kept" then n = n + 1 end end
        assert.equal(1, n)
        R:Apply()
        assert.equal("away", ns.Exceptions:List()[#ns.Exceptions:List() - 1]:GetChoice())
    end)
end)
