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

    it("never executes imported code during import", function()
        _G.PC_IMPORT_RAN = false
        local evil = V1:gsub("return~`function%(%)~`return~`true~`end", "PC_IMPORT_RAN=true~`return~`function()~`return~`true~`end")
        ns.Share:Import(evil, "Evil")
        W.advance(5)
        assert.is_false(_G.PC_IMPORT_RAN)
    end)
end)
