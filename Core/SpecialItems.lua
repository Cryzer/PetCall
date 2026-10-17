local _, ns = ...

local L = ns.L
local GetItemCount, GetItemInfo, IsEquippedItem = C_Item.GetItemCount, C_Item.GetItemInfo, C_Item.IsEquippedItem
local GetZoneText, ipairs, pairs, tonumber, strsub, setmetatable, rawset, sort =
    GetZoneText, ipairs, pairs, tonumber, strsub, setmetatable, rawset, table.sort

local SI = ns:NewModule("SpecialItems")
ns.SpecialItems = SI

local MAP_NAME = setmetatable({}, { __index = function(t, id)
    local info = C_Map.GetMapInfo(id)
    rawset(t, id, info and info.name)
    return info and info.name
end })

local ENTRIES = {}
local function bagItem(id) ENTRIES["item:" .. id] = { events = { "BAG_UPDATE_DELAYED" }, check = function() return GetItemCount(id) > 0 end } end
for _, id in ipairs({ 18597, 18598, 30803, 31815, 31880, 31881, 32834, 34971, 36936, 46396, 46397, 46831 }) do bagItem(id) end
ENTRIES["item:12185"] = { events = { "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SWAP_FINISHED" }, check = function() return IsEquippedItem(12185) end }
ENTRIES["item:46362"] = { events = { "BAG_UPDATE_DELAYED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA" }, check = function()
    local z = GetZoneText()
    return GetItemCount(46362) > 0 and (z == MAP_NAME[201] or z == MAP_NAME[161] or z == MAP_NAME[261])
end }
ENTRIES["item:68646"] = { events = { "BAG_UPDATE_DELAYED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA" }, check = function()
    return GetItemCount(68646) > 0 and GetZoneText() == MAP_NAME[281]
end }
ENTRIES["item:71137"] = { unitEvents = { "UNIT_SPELLCAST_SUCCEEDED" }, check = function(self, event, unit, castGUID, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and spellID == 100959 then
        if self.timer then self.timer:Cancel() end
        self.timer = ns:After(180, function()
            self.timer = nil
            SI:Update("item:71137", false)
        end)
        return true
    end
    return self.timer ~= nil
end }
local function questEntry(...)
    local ids = { ... }
    return { quest = true, check = function()
        for _, q in ipairs(ids) do if SI.quests[q] then return true end end
        return false
    end }
end
ENTRIES["quest:11878"] = questEntry(11878)
ENTRIES["quest:26831"] = questEntry(26831)
ENTRIES["quest:25371"] = questEntry(25371)
ENTRIES["quest:35396"] = questEntry(25371, 35317, 35331, 34965)

local defaults = { profile = { enable = true, items = { ["*"] = true } }, global = { localeCache = { ["*"] = {} } } }

function SI:OnInitialize()
    self.db = ns.DB:Namespace("SpecialItems", defaults)
    self.quests = {}
    self.byEvent = {}
    -- comes with every bit of quest progress: read the log once the burst settles
    self.QueueQuestList = ns.Debounce(0.5, function() SI:UpdateQuestList() end)
    self:RegisterEvent("QUEST_LOG_UPDATE", "QueueQuestList")
    self:RegisterEvent("QUEST_ACCEPTED", "UpdateQuestList")
    self:RegisterEvent("QUEST_REMOVED", "UpdateQuestList")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckAll")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    for key, e in pairs(ENTRIES) do
        e.key = key
        for _, ev in ipairs(e.events or {}) do self:Subscribe(ev, e, false) end
        for _, ev in ipairs(e.unitEvents or {}) do self:Subscribe(ev, e, true) end
        local id = key:match("^item:(%d+)$")
        if id and not GetItemInfo(tonumber(id)) then C_Item.RequestLoadItemDataByID(tonumber(id)) end
    end
    ns:RegisterCallback(self, "ProfileChanged", function() SI:UpdateReadyEnabled() end)
end

function SI:Subscribe(event, entry, unit)
    if not self.byEvent[event] then
        self.byEvent[event] = {}
        local handler = function(_, ev, ...) for _, x in ipairs(SI.byEvent[ev]) do SI:Update(x.key, x.check(x, ev, ...)) end end
        if unit then self:RegisterUnitEvent(event, "player", handler) else self:RegisterEvent(event, handler) end
    end
    tinsert(self.byEvent[event], entry)
end

function SI:OnEnable()
    self:UpdateQuestList()
    self:UpdateReadyEnabled()
    self:CheckAll()
end

function SI:Update(key, value) ns.Ready:SetReady(key, not value) end

function SI:CheckAll()
    for key, e in pairs(ENTRIES) do self:Update(key, e.check(e, "Init")) end
end

function SI:UpdateQuestList()
    wipe(self.quests)
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader then self.quests[info.questID] = true end
    end
    for key, e in pairs(ENTRIES) do
        if e.quest then self:Update(key, e.check(e)) end
    end
end

function SI:IsEnabled() return self.db.profile.enable end
function SI:SetEnabled(v) self.db.profile.enable = v and true or false self:UpdateReadyEnabled() end
function SI:SetItemEnabled(key, v) self.db.profile.items[key] = v and true or false self:UpdateReadyEnabled() end

function SI:UpdateReadyEnabled()
    if not self.db then return end
    for key in pairs(ENTRIES) do
        ns.Ready:EnableCheck(key, self.db.profile.enable and self.db.profile.items[key])
    end
    ns.Ready:_Changed()
end

function SI:LocalizeString(key)
    local cache = self.db.global.localeCache[GetLocale()]
    if cache[key] then return cache[key] end
    local name
    local kind, id = key:match("^(%a+):(%d+)$")
    id = tonumber(id)
    if kind == "item" then
        name = GetItemInfo(id)
        if not name then C_Item.RequestLoadItemDataByID(id) end
    elseif kind == "quest" then
        name = C_QuestLog.GetTitleForQuestID(id)
    end
    if name then cache[key] = name return name end
    return key
end

function SI:GET_ITEM_INFO_RECEIVED(_, itemID, success)
    if success and ENTRIES["item:" .. tostring(itemID)] then ns:Fire("SpecialItemsChanged") end
end

function SI:List()
    local out = {}
    for key in pairs(ENTRIES) do
        out[#out + 1] = { key = key, name = self:LocalizeString(key), enabled = self.db.profile.items[key] and true or false }
    end
    sort(out, function(a, b) return a.name < b.name end)
    return out
end
