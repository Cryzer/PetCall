local W = dofile("tests/wowstub.lua")
describe("SpecialItems", function()
    local ns
    before_each(function()
        W.reset()
        W.world.pets = { a = { species = 1, name = "A" } }
        W.world.items[18597] = 1
        ns = W.load()
        W.login()
        W.advance(1)
    end)
    it("blocks while an orphan whistle is in the bags", function()
        local keys = {}
        for _, b in ipairs(ns.Ready:GetBlockers()) do keys[b.key] = b.label end
        assert.equal("Using Item18597", keys["item:18597"])
        W.world.items[18597] = 0
        W.fire("BAG_UPDATE_DELAYED")
        keys = {}
        for _, b in ipairs(ns.Ready:GetBlockers()) do keys[b.key] = true end
        assert.is_nil(keys["item:18597"])
    end)
    it("spell 100959 activates item:71137 for 180 s, player only", function()
        W.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-1", 100959)
        assert.is_nil(ns.Ready.is_false["item:71137"])
        W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 100959)
        assert.is_true(ns.Ready.is_false["item:71137"])
        W.advance(181)
        assert.is_nil(ns.Ready.is_false["item:71137"])
    end)
    it("can be disabled per item and globally", function()
        ns.SpecialItems:SetItemEnabled("item:18597", false)
        assert.is_nil(ns.Ready.is_false["item:18597"])
        ns.SpecialItems:SetItemEnabled("item:18597", true)
        ns.SpecialItems:SetEnabled(false)
        assert.is_nil(ns.Ready.is_false["item:18597"])
    end)
    it("lists entries with names", function()
        local list = ns.SpecialItems:List()
        assert.is_true(#list >= 18)
        assert.is_not_nil(list[1].name)
    end)
    it("reads the quest log once per burst of quest updates; taking a quest counts at once", function()
        local reads = 0
        local num = C_QuestLog.GetNumQuestLogEntries
        rawset(C_QuestLog, "GetNumQuestLogEntries", function(...) reads = reads + 1 return num(...) end)
        W.world.quests = { 26831 }
        for _ = 1, 10 do W.fire("QUEST_LOG_UPDATE") end
        assert.equal(0, reads)
        W.advance(0.6)
        assert.equal(1, reads)
        assert.is_true(ns.Ready.is_false["quest:26831"])
        W.world.quests = {}
        W.fire("QUEST_REMOVED", 26831)
        assert.equal(2, reads)
        assert.is_nil(ns.Ready.is_false["quest:26831"])
        rawset(C_QuestLog, "GetNumQuestLogEntries", num)
    end)
end)
