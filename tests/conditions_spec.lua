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
end)
