local _, ns = ...

local L = ns.L
local ipairs, pairs, type, tinsert, loadstring, pcall, setmetatable = ipairs, pairs, type, tinsert, loadstring, pcall, setmetatable

local C = {}
ns.Conditions = C

local types, order = {}, {}

function C.RegisterType(def)
    assert(not types[def.key], "condition type exists: " .. def.key)
    types[def.key] = def
    order[#order + 1] = def
end

function C.Types() return order end
function C.GetType(key) return types[key] end

local function isNode(e) return e[1] == "AND" or e[1] == "OR" end
function C.IsLegacyNode(e) return isNode(e) end

--
-- Context
--

-- field -> the function that reads it from the game, together with its neighbours
local FILL = {}
local function fills(names, fill) for _, n in ipairs(names) do FILL[n] = fill end end

fills({ "zone", "subzone" }, function(ctx) ctx.zone, ctx.subzone = GetZoneText(), GetSubZoneText() end)
fills({ "mapChain" }, function(ctx)
    ctx.mapChain = {}
    local mapID = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while mapID and mapID ~= 0 and guard < 20 do
        ctx.mapChain[mapID] = true
        local info = C_Map.GetMapInfo(mapID)
        mapID = info and info.parentMapID
        guard = guard + 1
    end
end)
fills({ "inInstance", "instanceType" }, function(ctx) ctx.inInstance, ctx.instanceType = IsInInstance() end)
fills({ "delve" }, function(ctx)
    ctx.delve = C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress() or false
end)
fills({ "resting" }, function(ctx) ctx.resting = IsResting() end)
fills({ "inRaid", "inGroup" }, function(ctx) ctx.inRaid, ctx.inGroup = IsInRaid(), IsInGroup() end)
fills({ "class", "name" }, function(ctx)
    local _, class = UnitClass("player")
    ctx.class, ctx.name = class, UnitName("player")
end)
fills({ "spec" }, function(ctx) ctx.spec = C_SpecializationInfo.GetSpecialization() end)
fills({ "minutes" }, function(ctx)
    local h, m = GetGameTime()
    ctx.minutes = h * 60 + m
end)
fills({ "mounted", "afk", "swimming", "indoors", "outdoors", "form" }, function(ctx)
    ctx.mounted, ctx.afk = IsMounted() and true or false, UnitIsAFK("player") and true or false
    ctx.swimming = (IsSwimming() or IsSubmerged()) and true or false
    ctx.indoors, ctx.outdoors = IsIndoors() and true or false, IsOutdoors() and true or false
    ctx.form = GetShapeshiftFormID() ~= nil
end)
fills({ "ownHome", "anyHome", "inHouse" }, function(ctx)
    local H = C_Housing
    ctx.ownHome = H and H.IsInsideOwnedHouseOrPlot and H.IsInsideOwnedHouseOrPlot() or false
    ctx.anyHome = H and H.IsInsideHouseOrPlot and H.IsInsideHouseOrPlot() or false
    ctx.inHouse = H and H.IsInsideHouse and H.IsInsideHouse() or false
end)
-- The journal marks the mount you ride as active. Looking through the whole journal is
-- a thousand calls, and a set that also checks Activity asks every second: the mount
-- found last is checked first (one call), and a ride the journal does not know (a quest
-- mount) is not looked for again for a few seconds.
local lastMount, unknownAt
fills({ "mountID" }, function(ctx)
    ctx.mountID = false
    if not (IsMounted() and C_MountJournal) then unknownAt = nil return end
    if lastMount and select(4, C_MountJournal.GetMountInfoByID(lastMount)) then ctx.mountID = lastMount return end
    if unknownAt and GetTime() - unknownAt < 5 then return end
    for _, id in ipairs(C_MountJournal.GetMountIDs()) do
        local _, _, _, active = C_MountJournal.GetMountInfoByID(id)
        if active then
            lastMount, unknownAt, ctx.mountID = id, nil, id
            return
        end
    end
    unknownAt = GetTime()
end)
fills({ "holidays" }, function(ctx) ctx.holidays = C.ActiveHolidays and C.ActiveHolidays() or {} end)

local Lazy = { __index = function(ctx, key)
    local fill = FILL[key]
    if fill then fill(ctx) return rawget(ctx, key) end
end }

-- The player's state as the conditions see it. Each field is read from the game the
-- first time a condition asks for it, so a tick of "Activity" never reads the map
-- chain or the calendar.
function C.Context() return setmetatable({}, Lazy) end

--
-- Evaluation
--

function C.Eval(e, ctx)
    local result, reason
    if isNode(e) then
        if e[1] == "AND" then
            result = true
            for _, sub in ipairs(e.items or {}) do
                if not C.Eval(sub, ctx) then result = false break end
            end
        else
            result = false
            for _, sub in ipairs(e.items or {}) do
                if C.Eval(sub, ctx) then result = true break end
            end
        end
    else
        local def = types[e[1]]
        if not def then return false, L["Unknown condition"] end
        result = def.check(e, ctx) and true or false
        reason = def.reason and def.reason(e, ctx)
    end
    if e.negate then result = not result end
    return result, reason
end

function C.EvalList(list, ctx)
    for _, e in ipairs(list or {}) do
        if not C.Eval(e, ctx) then return false end
    end
    return true
end

function C.Describe(e)
    local text
    if isNode(e) then
        local parts = {}
        for _, sub in ipairs(e.items or {}) do parts[#parts + 1] = C.Describe(sub) end
        text = "(" .. table.concat(parts, e[1] == "AND" and (" " .. L["and"] .. " ") or (" " .. L["or"] .. " ")) .. ")"
    else
        local def = types[e[1]]
        text = def and def.describe(e) or L["Unknown condition"]
    end
    if e.negate then text = L["not"] .. " " .. text end
    return text
end

-- a shorter wording where a type has one (narrow places such as the set cards)
function C.DescribeShort(e)
    if isNode(e) then return C.Describe(e) end
    local def = types[e[1]]
    local text = def and (def.short or def.describe)(e) or L["Unknown condition"]
    if e.negate then text = L["not"] .. " " .. text end
    return text
end

--
-- Model
--

function C.ToModel(list)
    list = list or {}
    local groups = {}
    local only = list[1]
    if #list == 1 and only[1] == "OR" and not only.negate then
        for _, item in ipairs(only.items or {}) do
            if item[1] == "AND" and not item.negate then
                groups[#groups + 1] = { rows = item.items or {} }
            else
                groups[#groups + 1] = { rows = { item } }
            end
        end
    else
        groups[1] = { rows = list }
    end
    return { groups = groups }
end

function C.FromModel(model)
    -- an empty group would evaluate to true and make the set always active
    local groups = {}
    for _, g in ipairs(model.groups) do
        if #g.rows > 0 then groups[#groups + 1] = g end
    end
    if #groups <= 1 then
        local out = {}
        for _, r in ipairs(groups[1] and groups[1].rows or {}) do out[#out + 1] = r end
        return out
    end
    local items = {}
    for _, g in ipairs(groups) do
        local rows = {}
        for _, r in ipairs(g.rows) do rows[#rows + 1] = r end
        items[#items + 1] = { "AND", items = rows }
    end
    return { { "OR", items = items } }
end

local function mergeLeaves(items)
    local first = items[1]
    local def = first and not isNode(first) and types[first[1]]
    if not def or not def.merge then return nil end
    local acc = first
    for i = 2, #items do
        local e = items[i]
        if isNode(e) or e[1] ~= first[1] or e.negate or acc.negate then return nil end
        acc = def.merge(acc, e)
        if not acc then return nil end
    end
    return acc
end

function C.Simplify(node)
    if not isNode(node) or node.negate then return nil end
    local items = node.items or {}
    if #items == 1 then return { items[1] } end
    if node[1] == "AND" then
        -- splicing an AND into an AND context never changes the meaning
        local out = {}
        for _, e in ipairs(items) do out[#out + 1] = e end
        return out
    end
    local merged = mergeLeaves(items)
    return merged and { merged } or nil
end

-- Rewrites only where the meaning stays identical: splices AND into the AND
-- context, merges same-type OR leaves, unwraps single-child nodes. A single
-- top-level OR of AND groups is the multi-group shape and stays; its groups
-- are normalized in turn.
function C.Normalize(list)
    local i = 1
    while i <= #list do
        local e = list[i]
        local replacement = isNode(e) and C.Simplify(e)
        if replacement then
            table.remove(list, i)
            for k = #replacement, 1, -1 do tinsert(list, i, replacement[k]) end
        else
            i = i + 1
        end
    end
    local only = list[1]
    if #list == 1 and only[1] == "OR" and not only.negate then
        for _, item in ipairs(only.items or {}) do
            if item[1] == "AND" and not item.negate then C.Normalize(item.items) end
        end
    end
    return list
end

--
-- Lua code
--

local compiled = setmetatable({}, { __mode = "k" })   -- entry -> { code, fn, err, obj }

local function compile(entry)
    local c = compiled[entry]
    if c and c.code == entry.code then return c end
    c = { code = entry.code, events = {} }
    compiled[entry] = c
    local code = entry.code or ""
    if code == "" then c.err = L["No code"] return c end
    local chunk, err = loadstring("return function(self) " .. code .. "\nend", "PetCall condition")
    if not chunk then c.err = err return c end
    local okSetup, setup = pcall(chunk)
    if not okSetup then c.err = setup return c end
    local seen = {}
    c.obj = { RegisterEvent = function(_, event)
        if not seen[event] then seen[event] = true c.events[#c.events + 1] = event end
    end }
    local okFn, fn = pcall(setup, c.obj)
    if not okFn then c.err = fn return c end
    if type(fn) == "function" then
        c.fn = fn
    else
        -- 1.x style: the code itself is the check and runs on every evaluation
        c.fn = setup
    end
    return c
end

function C.Compile(entry)
    local c = compile(entry)
    return c.fn, c.err, c
end

function C.CheckLua(code)
    local c = compile({ code = code })
    if not c.fn then return false, c.err end
    local ok, res = pcall(c.fn, c.obj)
    if not ok then return false, res end
    return true, res
end

--
-- Watchers
--

local tickers = {}   -- seconds -> { ticker, watchers = {} }
local listeners = {} -- event -> { [watcher] = true }
local dispatcher = {}

-- every watcher woken together looks at one context: one look at the world per event
local function refreshAll(watchers)
    local list = {}
    for w in pairs(watchers) do list[#list + 1] = w end   -- a change may add or free watchers
    local ctx = C.Context()
    for _, w in ipairs(list) do w:Refresh(nil, ctx) end
end

local function subscribeTick(w, seconds)
    local t = tickers[seconds]
    if not t then
        t = { watchers = {} }
        t.ticker = ns:NewTicker(seconds, function() refreshAll(t.watchers) end)
        tickers[seconds] = t
    end
    t.watchers[w] = true
end

local function listen(w, event)
    local set = listeners[event]
    if not set then
        set = {}
        listeners[event] = set
        ns.Events.Register(dispatcher, event, function(_, _, unit)
            -- fires for every group member; only our own flags matter
            if event == "PLAYER_FLAGS_CHANGED" and unit ~= "player" then return end
            refreshAll(set)
        end)
    end
    set[w] = true
end

local function stopListening(w)
    for event, set in pairs(listeners) do
        set[w] = nil
        if not next(set) then
            ns.Events.Unregister(dispatcher, event)
            listeners[event] = nil
        end
    end
end

local function unsubscribeTicks(w)
    for seconds, t in pairs(tickers) do
        t.watchers[w] = nil
        if not next(t.watchers) then
            t.ticker:Cancel()
            tickers[seconds] = nil
        end
    end
end

local Watcher = {}
Watcher.__index = Watcher

local function collect(list, out)
    for _, e in ipairs(list) do
        if isNode(e) then collect(e.items or {}, out)
        else out[#out + 1] = e end
    end
    return out
end

function Watcher:Rebuild()
    if self.freed then return end
    stopListening(self)
    unsubscribeTicks(self)
    local events = {}
    for _, e in ipairs(collect(self.list, {})) do
        local def = types[e[1]]
        if def then
            for _, ev in ipairs(def.events or {}) do events[ev] = true end
            if def.tick then subscribeTick(self, def.tick) end
            -- compiling runs the code's setup part; imported code must not run before review
            if e[1] == "luacode" and not e.disabledByImport then
                local _, _, c = C.Compile(e)
                for _, ev in ipairs(c.events) do events[ev] = true end
            end
        end
    end
    for ev in pairs(events) do listen(self, ev) end
    self:Refresh(true)
end

-- ctx: shared by the watchers woken by one event or tick
function Watcher:Refresh(silent, ctx)
    if self.freed then return end
    ctx = ctx or C.Context()
    local changed = false
    local states = {}
    for _, e in ipairs(collect(self.list, {})) do
        local v, reason = C.Eval(e, ctx)
        states[e] = { value = v, reason = reason }
        local old = self.states[e]
        if not old or old.value ~= v or old.reason ~= reason then changed = true end
    end
    -- the set's value from the top-level states: leaves are not judged twice
    local value = true
    for _, e in ipairs(self.list) do
        if isNode(e) then states[e] = { value = (C.Eval(e, ctx)) } end
        if not states[e].value then value = false end
    end
    self.states = states
    if value ~= self.value then changed = true end
    self.value = value
    if changed and not silent then self.onChange(self) end
end

function Watcher:Free()
    stopListening(self)
    unsubscribeTicks(self)
    self.freed = true
end

function C.NewWatcher(list, onChange)
    local w = setmetatable({ list = list, onChange = onChange, states = {}, value = true }, Watcher)
    w:Rebuild()
    return w
end
