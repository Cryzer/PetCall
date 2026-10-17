local W = dofile("tests/wowstub.lua")
local F = dofile("tests/fixtures/PetCall3DB_1_0.lua")
local REF = dofile("tests/fixtures/reference_1_0.lua")

local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local c = {} for k, v in pairs(t) do c[k] = deepcopy(v) end return c
end

describe("Conditions", function()
    local ns, C
    before_each(function()
        W.reset()
        ns = W.load()
        W.login()
        C = ns.Conditions
    end)

    local function eval(e) return (C.Eval(e, C.Context())) end

    it("zone by name, list and map ancestry", function()
        assert.is_true(eval({ "zone", zoneName = "Stormwind City" }))
        assert.is_true(eval({ "zone", zoneName = "Trade District" }))
        assert.is_true(eval({ "zone", zoneNames = { "X", "Stormwind City" } }))
        assert.is_true(eval({ "zone", mapIDs = { 13 } }))           -- continent ancestor of 84
        assert.is_false(eval({ "zone", mapIDs = { 85 } }))
    end)

    it("character conditions name the specialization; the short form drops the type name", function()
        local e = { "specialization", class = "HUNTER", spec = 2 }
        assert.equal("Character: Hunter, Marksmanship", C.Describe(e))
        assert.equal("Hunter, Marksmanship", C.DescribeShort(e))
        assert.equal("Hunter", C.DescribeShort({ "specialization", class = "HUNTER", spec = -1 }))
        assert.equal("not Hunter", C.DescribeShort({ "specialization", class = "HUNTER", spec = -1, negate = true }))
        -- a type without a short form keeps its usual wording
        local zone = { "zone", zoneName = "Stormwind City" }
        assert.equal(C.Describe(zone), C.DescribeShort(zone))
    end)

    it("location types incl. legacy values", function()
        assert.is_true(eval({ "specialLocation", loc = "city" }))
        W.world.instanceType, W.world.resting = "party", false
        assert.is_true(eval({ "specialLocation", loc = "instance" }))
        assert.is_true(eval({ "specialLocation", locs = { "dungeon" } }))
        assert.is_false(eval({ "specialLocation", locs = { "world" } }))
        W.world.instanceType, W.world.delve = "scenario", true
        assert.is_true(eval({ "specialLocation", locs = { "delve" } }))
        assert.is_false(eval({ "specialLocation", locs = { "scenario" } }))
    end)

    it("group honours party/raid/solo", function()
        local e = { "groupType", party = false, raid = true }
        assert.is_false(eval(e))
        W.world.inGroup = true
        assert.is_false(eval(e))
        W.world.inRaid = true
        assert.is_true(eval(e))
        W.world.inGroup, W.world.inRaid = false, false
        assert.is_true(eval({ "groupType", solo = true }))
    end)

    it("specialization with any class and name", function()
        assert.is_true(eval({ "specialization", class = "", spec = -1 }))
        assert.is_true(eval({ "specialization", class = "HUNTER", spec = 1 }))
        assert.is_false(eval({ "specialization", class = "WARRIOR", spec = -1 }))
        assert.is_false(eval({ "specialization", spec = -1, name = "Someone" }))
    end)

    it("time of day across midnight", function()
        W.world.gameHour, W.world.gameMinute = 23, 30
        assert.is_true(eval({ "timeOfDay", from = 22 * 60, to = 6 * 60 }))
        W.world.gameHour = 12
        assert.is_false(eval({ "timeOfDay", from = 22 * 60, to = 6 * 60 }))
    end)

    it("negate and nodes", function()
        assert.is_false(eval({ "zone", zoneName = "Stormwind City", negate = true }))
        assert.is_true(eval({ "OR", items = { { "zone", zoneName = "X" }, { "specialLocation", loc = "city" } } }))
        assert.is_false(eval({ "AND", items = { { "zone", zoneName = "X" }, { "specialLocation", loc = "city" } } }))
        assert.is_true(C.EvalList({}, C.Context()))
    end)

    it("luacode returns the function result, runs setup once, disabled when imported", function()
        local runs = 0
        _G.PC_TEST_COUNT = function() runs = runs + 1 end
        local e = { "luacode", code = "PC_TEST_COUNT()\nreturn function() return false end" }
        assert.is_false(eval(e))
        assert.is_false(eval(e))
        assert.equal(1, runs)
        local ok = C.CheckLua("return function() return true end")
        assert.is_true(ok)
        assert.is_false((C.CheckLua("this is not lua")))
        assert.is_false(eval({ "luacode", code = "return function() return true end", disabledByImport = true }))
    end)

    it("model round trip: one group and OR-of-AND groups", function()
        local list = { { "zone", zoneName = "A" }, { "groupType", party = true, raid = true } }
        local m = C.ToModel(list)
        assert.equal(1, #m.groups)
        assert.same(list, C.FromModel(m))
        local multi = { { "OR", items = { { "AND", items = { { "zone", zoneName = "A" } } }, { "zone", zoneName = "B" } } } }
        local m2 = C.ToModel(multi)
        assert.equal(2, #m2.groups)
        local back = C.FromModel(m2)
        assert.equal("OR", back[1][1])
        assert.equal(2, #back[1].items)
    end)

    it("normalize merges same-type OR and flattens AND", function()
        local list = {
            { "OR", items = { { "zone", zoneName = "A" }, { "zone", zoneName = "B" } } },
            { "AND", items = { { "specialLocation", loc = "city" } } },
        }
        C.Normalize(list)
        assert.equal(2, #list)
        assert.equal("zone", list[1][1])
        assert.same({ "A", "B" }, list[1].zoneNames)
        assert.equal("specialLocation", list[2][1])
    end)

    it("FromModel drops empty groups", function()
        local list = C.FromModel({ groups = { { rows = { { "zone", zoneName = "A" } } }, { rows = {} } } })
        assert.same({ { "zone", zoneName = "A" } }, list)
    end)

    it("simplify refuses meaning-changing rewrites", function()
        assert.is_nil(C.Simplify({ "OR", items = { { "zone", zoneName = "A" }, { "groupType", party = true } } }))
        assert.is_not_nil(C.Simplify({ "AND", items = { { "zone", zoneName = "A" } } }))
    end)

    it("equivalence with 1.0.x over all world states (normalized trees)", function()
        for wi, state in ipairs(F.worlds) do
            W.reset()
            for id, p in pairs(F.pets) do W.world.pets[id] = p end
            for k, v in pairs(state) do W.world[k] = v end
            local ns2 = W.load()
            PetCall3DB = deepcopy(F.db)
            W.login()
            for name, ref in pairs(REF[wi].sets) do
                if name ~= "$Default" then
                    local list = deepcopy(F.db.profiles.Default.sets[name].trigger or {})
                    ns2.Conditions.Normalize(list)
                    assert.equal(ref.value, ns2.Conditions.EvalList(list, ns2.Conditions.Context()), "world " .. wi .. " set " .. name)
                end
            end
        end
    end)

    it("watcher fires onChange on relevant events only", function()
        local list = { { "zone", zoneName = "Dornogal" } }
        local n = 0
        local w = C.NewWatcher(list, function() n = n + 1 end)
        assert.is_false(w.value)
        W.world.zone = "Dornogal"
        W.fire("ZONE_CHANGED_NEW_AREA")
        assert.is_true(w.value)
        assert.equal(1, n)
        W.fire("GROUP_ROSTER_UPDATE")
        assert.equal(1, n)
        w:Free()
        W.world.zone = "X"
        W.fire("ZONE_CHANGED_NEW_AREA")
        assert.equal(1, n)
    end)
    it("1.x direct-expression Lua code is evaluated on every check", function()
        local e = { "luacode", code = 'self:RegisterEvent("PLAYER_UPDATE_RESTING") return IsResting()' }
        W.world.resting = true
        assert.is_true(eval(e))
        W.world.resting = false
        assert.is_false(eval(e))
        local _, _, c = C.Compile(e)
        assert.same({ "PLAYER_UPDATE_RESTING" }, c.events)
        local ok, res = C.CheckLua("return 1 + 1 == 2")
        assert.is_true(ok)
        assert.is_true(res)
    end)
    it("adding the current place twice keeps one entry; the description lists each place once", function()
        local e = { "zone", mapIDs = { 84 } }
        assert.is_true(C.HasCurrentPlace(e))
        assert.is_false(C.AddCurrentPlace(e))
        assert.same({ 84 }, e.mapIDs)
        local named = { "zone", zoneName = "Map84" }
        assert.is_true(C.HasCurrentPlace(named))          -- same place, saved by name
        local other = { "zone", mapIDs = { 13 } }
        assert.is_true(C.AddCurrentPlace(other))
        assert.same({ 13, 84 }, other.mapIDs)
        assert.equal("Place: Map84", C.Describe({ "zone", zoneName = "Map84", mapIDs = { 84, 84 } }))
        assert.equal("Place: none chosen yet", C.Describe({ "zone", mapIDs = {} }))
    end)
    it("activity: any ticked activity is enough", function()
        assert.is_false(eval({ "activity", swimming = true, afk = true }))
        W.world.swimming = true
        assert.is_true(eval({ "activity", swimming = true, afk = true }))
        W.world.swimming = false
        W.world.formID = 3
        assert.is_true(eval({ "activity", form = true }))
        W.world.mounted = true
        assert.is_true(eval({ "activity", mounted = true }))
        assert.equal("Activity: Mounted or AFK", C.Describe({ "activity", mounted = true, afk = true }))
    end)
    it("home: own plot, someone else's plot, inside a house", function()
        assert.is_false(eval({ "housing", ownHome = true }))
        W.world.home.any = true
        assert.is_false(eval({ "housing", ownHome = true }))
        assert.is_true(eval({ "housing", otherHome = true }))
        W.world.home.own = true
        assert.is_true(eval({ "housing", ownHome = true }))
        assert.is_false(eval({ "housing", otherHome = true }))      -- my own plot is not a visit
        W.world.home.inside = true
        assert.is_true(eval({ "housing", inHouse = true }))
    end)
    it("holiday: a running holiday from the calendar, by id or any", function()
        local hallows = { eventID = 324, title = "Hallow's End", calendarType = "HOLIDAY", sequenceType = "ONGOING",
            startTime = { year = 2026, month = 10, monthDay = 10, hour = 10, minute = 0 },
            endTime = { year = 2026, month = 11, monthDay = 1, hour = 11, minute = 0 } }
        local raidReset = { eventID = 9, title = "Raid reset", calendarType = "RAID_RESET" }
        W.world.calEvents[16] = { raidReset, hallows }
        assert.is_true(eval({ "holiday", holidayIDs = { 324 } }))
        assert.is_true(eval({ "holiday", holidayIDs = { 0 } }))
        assert.is_false(eval({ "holiday", holidayIDs = { 141 } }))
        assert.is_true(W.world.calendarOpened)
        assert.equal("Holiday: Hallow's End", C.Describe({ "holiday", holidayIDs = { 324 } }))
    end)
    it("holiday: not before it starts, and the calendar showing another month still finds today", function()
        local fair = { eventID = 479, title = "Darkmoon Faire", calendarType = "HOLIDAY",
            startTime = { year = 2026, month = 10, monthDay = 16, hour = 13, minute = 0 },
            endTime = { year = 2026, month = 10, monthDay = 22, hour = 23, minute = 59 } }
        W.world.calShown = { year = 2026, month = 8 }        -- the player left the calendar on August
        W.world.calEvents[2 * 100 + 16] = { fair }
        assert.is_false(eval({ "holiday", holidayIDs = { 479 } }))   -- 12:00, it opens at 13:00
        W.world.now = { year = 2026, month = 10, monthDay = 16, hour = 14, minute = 0 }
        W.advance(2)                                          -- past the short cache
        assert.is_true(eval({ "holiday", holidayIDs = { 479 } }))
        local known = C.KnownHolidays()
        assert.equal(479, known[1].value)
        assert.equal("Darkmoon Faire", known[1].label)
    end)
    it("holiday names and start-day pictures come from the calendar", function()
        local start = { eventID = 372, title = "Brewfest", calendarType = "HOLIDAY", sequenceType = "START", iconTexture = 111 }
        local ending = { eventID = 372, title = "Brewfest", calendarType = "HOLIDAY", sequenceType = "END", iconTexture = 222 }
        W.world.calEvents[6] = { ending }
        W.world.calEvents[11 * 100 + 20] = { start }        -- next year's start, eleven months on
        assert.equal("Holiday: Brewfest", C.Describe({ "holiday", holidayIDs = { 372 } }))
        W.advance(31)
        local known = C.KnownHolidays()
        assert.equal(111, known[1].icon)
    end)
    it("watchers woken by the same event share one look at the world", function()
        local ws = {}
        for i = 1, 3 do ws[i] = C.NewWatcher({ { "zone", zoneName = "Ironforge" } }, function() end) end
        local reads = 0
        local zoneText = _G.GetZoneText
        _G.GetZoneText = function(...) reads = reads + 1 return zoneText(...) end
        W.world.zone = "Ironforge"
        W.fire("ZONE_CHANGED_NEW_AREA")
        _G.GetZoneText = zoneText
        assert.equal(1, reads)
        for i = 1, 3 do assert.is_true(ws[i].value) end
        ws[2]:Free()
        W.world.zone = "Stormwind City"
        W.fire("ZONE_CHANGED_NEW_AREA")
        assert.is_false(ws[1].value)
        assert.is_true(ws[2].value, "a freed watcher is left alone")
        ws[1]:Free() ws[3]:Free()
    end)
    it("a tick reads only what its conditions need", function()
        local w = C.NewWatcher({ { "activity", mounted = true } }, function() end)
        assert.is_false(w.value)
        local looked = 0
        local holidays, best = C.ActiveHolidays, C_Map.GetBestMapForUnit
        C.ActiveHolidays = function(...) looked = looked + 1 return holidays(...) end
        rawset(C_Map, "GetBestMapForUnit", function(...) looked = looked + 1 return best(...) end)
        W.world.mounted = true
        W.advance(1.1)
        C.ActiveHolidays = holidays
        rawset(C_Map, "GetBestMapForUnit", best)
        assert.equal(0, looked)
        assert.is_true(w.value)
        w:Free()
    end)
end)
