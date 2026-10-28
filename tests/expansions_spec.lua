local W = dofile("tests/wowstub.lua")

describe("Expansions", function()
    local ns
    before_each(function()
        W.reset()
        ns = W.load()
        W.login()
    end)
    it("knows the expansion of real species", function()
        assert.equal(0, ns.Expansions.Of(39))      -- Mechanical Squirrel: Classic
        assert.equal(5, ns.Expansions.Of(115))     -- an old number handed out in WoD
        assert.equal(11, ns.Expansions.Of(3277))   -- an old number handed out in Midnight
    end)
    it("every range edge maps to its own expansion", function()
        local d = ns.ExpansionData
        for i, start in ipairs(d.starts) do
            assert.equal(d.expansions[i], ns.Expansions.Of(start))
            if i > 1 then assert.equal(d.expansions[i - 1], ns.Expansions.Of(start - 1)) end
        end
        assert.equal(d.expansions[1], ns.Expansions.Of(1))
    end)
    it("a species newer than the data belongs to the newest expansion the client knows", function()
        W.world.expansionLevel = 12
        assert.equal(12, ns.Expansions.Of(ns.ExpansionData.maxSpecies + 1))
        assert.equal(13, #ns.Expansions.All())
        assert.equal(0, ns.Expansions.All()[1])
    end)
    it("in a pre-patch the client's next expansion counts, though the server still runs the old one", function()
        W.world.expansionLevel, W.world.clientExpansionLevel = 11, 12
        assert.equal(12, ns.Expansions.Newest())
        assert.equal(12, ns.Expansions.Of(ns.ExpansionData.maxSpecies + 1))
    end)
    it("without the client's expansion level the data's newest is used", function()
        local server, client = GetServerExpansionLevel, GetClientDisplayExpansionLevel
        GetServerExpansionLevel, GetClientDisplayExpansionLevel = nil, nil
        assert.equal(11, ns.Expansions.Newest())
        GetServerExpansionLevel, GetClientDisplayExpansionLevel = server, client
    end)
    it("never older than the data, whatever the client says", function()
        W.world.expansionLevel = 3
        assert.equal(11, ns.Expansions.Newest())
    end)
    it("the zone data covers every expansion and lists each map once", function()
        local seen = {}
        for e = 0, 11 do
            local list = ns.ZoneExpansionData[e]
            assert.is_true(list ~= nil and #list > 0)
            for _, id in ipairs(list) do
                assert.is_nil(seen[id])
                seen[id] = e
            end
        end
        assert.equal(0, seen[84])      -- Stormwind City
        assert.equal(3, seen[249])     -- Uldum, on Kalimdor but from Cataclysm
        assert.equal(10, seen[2339])   -- Dornogal
    end)
    it("a map is found directly, through its parents, or not at all", function()
        assert.equal(0, ns.Expansions.OfMap(84))
        W.world.mapParents[99999] = 2339                      -- a sub-map newer than the data
        assert.equal(10, ns.Expansions.OfMap(99999))
        W.world.mapParents[88888], W.world.mapParents[88887] = 88887, 88888   -- a loop
        assert.is_nil(ns.Expansions.OfMap(88888))
        assert.is_nil(ns.Expansions.OfMap(77777))             -- no data, no parent
        assert.is_nil(ns.Expansions.OfMap(nil))
    end)
    it("here is the player's map; a loading screen is nowhere; a house counts as Midnight", function()
        W.world.mapID = 249
        assert.equal(3, ns.Expansions.Here())
        W.world.mapID = nil
        assert.is_nil(ns.Expansions.Here())
        W.world.home.any = true
        assert.equal(11, ns.Expansions.Here())
    end)
    it("a map's parents are walked once, however many pets ask", function()
        W.world.mapParents[99999] = 2339
        W.world.mapID = 99999
        local walks, getMapInfo = 0, C_Map.GetMapInfo
        C_Map.GetMapInfo = function(id) walks = walks + 1 return getMapInfo(id) end
        for _ = 1, 50 do assert.equal(10, ns.Expansions.Here()) end
        C_Map.GetMapInfo = getMapInfo
        assert.equal(1, walks)
    end)
    it("a client without the housing call is nowhere during a loading screen", function()
        W.world.mapID = nil
        local inside = C_Housing.IsInsideHouseOrPlot
        C_Housing.IsInsideHouseOrPlot = nil
        assert.is_nil(ns.Expansions.Here())
        C_Housing.IsInsideHouseOrPlot = inside
    end)
    it("names expansions as the game does, and an unknown one by its number", function()
        assert.equal("Legion", ns.Expansions.Name(6))
        assert.equal("12", ns.Expansions.Name(12))
    end)
end)
