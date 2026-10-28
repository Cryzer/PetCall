local W = dofile("tests/wowstub.lua")
-- Real AceSerializer-3.0 output (generated with the v1.0.15 library) for:
-- { enabled=true, priority=8, defaultValue=0, pets={[39]=64,[40]=0.125},
--   trigger={ {"specialLocation", loc="city"}, {"luacode", code="return function() return true end"}, {"bogus"} },
--   filter={ {"favorites", 8} } }
local V1 = "PetCall:1:^1^T^Senabled^B^Sfilter^T^N1^T^N1^Sfavorites^N2^N8^t^t"
    .. "^Strigger^T^N1^T^N1^SspecialLocation^Sloc^Scity^t"
    .. "^N2^T^N1^Sluacode^Scode^Sreturn~`function()~`return~`true~`end^t"
    .. "^N3^T^N1^Sbogus^t^t^Spriority^N8^SdefaultValue^N0"
    .. "^Spets^T^N39^N64^N40^N0.125^t^t^^"

describe("Share", function()
    local ns
    before_each(function()
        W.reset()
        W.world.pets = { a = { species = 39, name = "Squirrel" }, b = { species = 40, name = "Cat" } }
        ns = W.load()
        W.login()
        W.advance(1)
    end)

    it("decodes AceSerializer data", function()
        local ok, v = ns.LegacyDeserialize("^1^T^Sa^N1^Sb^F1^f-3^Sc^b^t^^")
        assert.is_true(ok)
        assert.same({ a = 1, b = 0.125, c = false }, v)
        assert.is_false((ns.LegacyDeserialize("garbage")))
    end)

    it("imports a 1.0 string with sanitising", function()
        local ok, name, info = ns.Share:Import(V1, "Imported")
        assert.is_true(ok)
        assert.equal("Imported", name)
        local s = ns.Sets:Get("Imported")
        assert.equal(8, s.settings.priority)
        assert.equal(64, s:GetPetWeight("a"))
        assert.equal(0.125, s:GetPetWeight("b"))
        assert.equal(2, #s.settings.trigger)              -- "bogus" dropped
        assert.is_true(s.settings.trigger[2].disabledByImport)
        assert.is_true(info.hasLuaCode)
        assert.equal(1, info.dropped)
        assert.same({ { "favorites", 8 } }, s.settings.filter)
    end)

    it("round-trips the new format", function()
        local set = ns.Sets:Create("Src")
        set:SetPetWeight("a", 8)
        set:ApplyTemplate("city")
        local str = ns.Share:Export("Src")
        assert.equal("PetCall:2:", str:sub(1, 10))
        local ok = ns.Share:Import(str, "Copy")
        assert.is_true(ok)
        local copy = ns.Sets:Get("Copy")
        assert.equal(8, copy:GetPetWeight("a"))
        assert.equal("specialLocation", copy.settings.trigger[1][1])
    end)

    it("rejects bad input and duplicate names", function()
        assert.is_false((ns.Share:Import("hello", "X")))
        assert.is_false((ns.Share:Import(V1, "")))
        ns.Sets:Create("Taken")
        assert.is_false((ns.Share:Import(V1, "Taken")))
    end)

    it("drops fields of the wrong type so damaged strings cannot break the addon", function()
        local data = {
            enabled = true, priority = -1, defaultValue = "x",
            pets = { [39] = "big", [40] = 8 },
            filter = { { "favorites", "x" }, { "petType", petTypes = 5, 8 }, { "level", operator = ">=", level = 25, -3 } },
            trigger = { { "zone", mapIDs = "a", zoneNames = { "Dornogal", 7 } }, { "specialLocation", locs = { "city", false } } },
        }
        local str = "PetCall:2:" .. C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(data)))
        local ok = ns.Share:Import(str, "Damaged")
        assert.is_true(ok)
        local s = ns.Sets:Get("Damaged")
        assert.equal(1, s.settings.priority)            -- an imported Default (-1) would never win
        assert.equal(0, s.settings.defaultValue)
        assert.is_false(s:HasManualWeight("a"))
        assert.equal(8, s:GetPetWeight("b"))
        assert.has_no_error(function()
            s:GetWeightTable()
            ns.Sets:Update()
            W.fire("ZONE_CHANGED_NEW_AREA")
        end)
        for _, e in ipairs(s.settings.filter) do assert.is_true(type(e[2]) == "number" and e[2] > 0) end
        assert.is_nil(s.settings.filter[2] and s.settings.filter[2].petTypes ~= nil and type(s.settings.filter[2].petTypes) ~= "table" or nil)
        assert.same({ "Dornogal" }, s.settings.trigger[1].zoneNames)
        assert.is_nil(s.settings.trigger[1].mapIDs)
    end)

    it("never executes imported code during import", function()
        _G.PC_IMPORT_RAN = false
        local evil = V1:gsub("return~`function%(%)~`return~`true~`end", "PC_IMPORT_RAN=true~`return~`function()~`return~`true~`end")
        ns.Share:Import(evil, "Evil")
        W.advance(5)
        assert.is_false(_G.PC_IMPORT_RAN)
    end)
    it("keeps the fields of the new conditions through export and import", function()
        local set = ns.Sets:Create("Src")
        table.insert(set.settings.trigger, { "holiday", holidayIDs = { 324 } })
        table.insert(set.settings.trigger, { "activity", swimming = true, afk = true })
        table.insert(set.settings.trigger, { "housing", ownHome = true })
        table.insert(set.settings.trigger, { "outfit", outfitNames = { "Necromancer" } })
        assert.is_true((ns.Share:Import(ns.Share:Export("Src"), "Copy")))
        local t = ns.Sets:Get("Copy").settings.trigger
        assert.same({ 324 }, t[1].holidayIDs)
        assert.is_true(t[2].swimming and t[2].afk)
        assert.is_true(t[3].ownHome)
        assert.same({ "Necromancer" }, t[4].outfitNames)
    end)
    it("keeps the rules' pet types and sources through export and import", function()
        local set = ns.Sets:Create("Src3")
        set.settings.filter = { { "AND", ns.Weights.NORMAL, items = {
            { "petType", petTypes = { 2, 5 } }, { "source", sources = { 3, 7 } } } } }
        assert.is_true((ns.Share:Import(ns.Share:Export("Src3"), "Copy3")))
        local items = ns.Sets:Get("Copy3").settings.filter[1].items
        assert.same({ 2, 5 }, items[1].petTypes)
        assert.same({ 3, 7 }, items[2].sources)
    end)
    it("keeps the per-set choices through export and import", function()
        local set = ns.Sets:Create("Src2")
        set:SetNoPet(true)
        set:SetSwitchMinutes(15)
        set:SetAnnounce("off")
        set:SetOnActivate("new")
        assert.is_true((ns.Share:Import(ns.Share:Export("Src2"), "Copy2")))
        local c = ns.Sets:Get("Copy2")
        assert.is_true(c:IsNoPet())
        assert.equal(15, c.settings.switchMinutes)
        assert.equal("off", c.settings.announce)
        assert.equal("new", c:GetOnActivate())
    end)
end)
