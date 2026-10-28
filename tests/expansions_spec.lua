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
    it("without the client's expansion level the data's newest is used", function()
        local f = GetServerExpansionLevel
        GetServerExpansionLevel = nil
        assert.equal(11, ns.Expansions.Newest())
        GetServerExpansionLevel = f
    end)
    it("never older than the data, whatever the client says", function()
        W.world.expansionLevel = 3
        assert.equal(11, ns.Expansions.Newest())
    end)
    it("names expansions as the game does, and an unknown one by its number", function()
        assert.equal("Legion", ns.Expansions.Name(6))
        assert.equal("12", ns.Expansions.Name(12))
    end)
end)
