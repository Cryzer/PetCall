local _, ns = ...

local L = ns.L
local C = ns.Conditions
local ipairs, tinsert, format = ipairs, tinsert, format

local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }

local function contains(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

local function union(a, b)
    local out = {}
    for _, x in ipairs(a or {}) do if not contains(out, x) then out[#out + 1] = x end end
    for _, x in ipairs(b or {}) do if not contains(out, x) then out[#out + 1] = x end end
    return out
end

local function mapName(id)
    local info = C_Map.GetMapInfo(id)
    return info and info.name or tostring(id)
end

local function zoneNames(e)
    local names = {}
    if e.zoneName and e.zoneName ~= "" then names[1] = e.zoneName end
    for _, n in ipairs(e.zoneNames or {}) do names[#names + 1] = n end
    return names
end

C.RegisterType({
    key = "zone", label = L["Place"], group = "where", hint = L["A zone, a city or a whole continent."],
    fields = { { key = "places", kind = "multiPlace" } },
    events = ZONE_EVENTS,
    new = function() return { "zone", mapIDs = { C_Map.GetBestMapForUnit("player") } } end,
    check = function(e, ctx)
        for _, n in ipairs(zoneNames(e)) do
            if n == ctx.zone or n == ctx.subzone then return true end
        end
        for _, id in ipairs(e.mapIDs or {}) do
            if ctx.mapChain[id] then return true end
        end
        return false
    end,
    reason = function(_, ctx) return format(L["You are in: %s"], ctx.subzone ~= "" and (ctx.zone .. " – " .. ctx.subzone) or ctx.zone) end,
    describe = function(e)
        local parts = zoneNames(e)
        for _, id in ipairs(e.mapIDs or {}) do parts[#parts + 1] = mapName(id) end
        if #parts == 0 then return L["Place"] .. ": " .. L["none chosen yet"] end
        return L["Place"] .. ": " .. table.concat(union(parts), ", ")
    end,
    merge = function(a, b)
        local names = union(zoneNames(a), zoneNames(b))
        return { "zone", zoneNames = names, mapIDs = union(a.mapIDs, b.mapIDs) }
    end,
})

-- the place the player stands in is already listed, by map or by name
function C.HasCurrentPlace(e)
    local id = C_Map.GetBestMapForUnit("player")
    if not id then return false end
    return contains(e.mapIDs, id) or contains(zoneNames(e), mapName(id))
end

-- adds the current map unless it is already there; true when something was added
function C.AddCurrentPlace(e)
    local id = C_Map.GetBestMapForUnit("player")
    if not id or C.HasCurrentPlace(e) then return false end
    e.mapIDs = e.mapIDs or {}
    tinsert(e.mapIDs, id)
    return true
end

local LOC_LEGACY = { city = { "city" }, battleground = { "pvp" }, instance = { "dungeon", "raid" } }
local LOC_VALUES = {
    { value = "city", label = L["City or rest area"] }, { value = "dungeon", label = L["Dungeon"] },
    { value = "raid", label = L["Raid"] }, { value = "scenario", label = L["Scenario"] },
    { value = "delve", label = L["Delve"] }, { value = "pvp", label = L["Battleground or arena"] },
    { value = "world", label = L["Open world"] },
}
local function locs(e) return e.locs or LOC_LEGACY[e.loc] or {} end
local function locLabel(v) for _, x in ipairs(LOC_VALUES) do if x.value == v then return x.label end end return v end
local function currentLoc(ctx)
    if ctx.delve then return "delve" end
    local t = ctx.instanceType
    if t == "party" then return "dungeon" end
    if t == "raid" then return "raid" end
    if t == "scenario" then return "scenario" end
    if t == "pvp" or t == "arena" then return "pvp" end
    return "world"
end

C.RegisterType({
    key = "specialLocation", label = L["Place type"], group = "where", hint = L["Cities, dungeons, raids, delves, battlegrounds or the open world."],
    fields = { { key = "locs", kind = "multiChoice", values = function() return LOC_VALUES end } },
    events = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "PLAYER_FLAGS_CHANGED", "PLAYER_UPDATE_RESTING" },
    new = function() return { "specialLocation", locs = { "city" } } end,
    check = function(e, ctx)
        local cur = currentLoc(ctx)
        for _, v in ipairs(locs(e)) do
            if v == "city" and ctx.resting then return true end
            if v == cur then return true end
        end
        return false
    end,
    reason = function(_, ctx) return format(L["You are in: %s"], locLabel(ctx.resting and "city" or currentLoc(ctx))) end,
    describe = function(e)
        local parts = {}
        for _, v in ipairs(locs(e)) do parts[#parts + 1] = locLabel(v) end
        return L["Place type"] .. ": " .. table.concat(parts, ", ")
    end,
    merge = function(a, b) return { "specialLocation", locs = union(locs(a), locs(b)) } end,
})

local GROUP_VALUES = { { value = "solo", label = L["Solo"] }, { value = "party", label = PARTY }, { value = "raid", label = RAID } }
C.RegisterType({
    key = "groupType", label = L["Group"], group = "with", hint = L["Playing alone, in a party or in a raid."],
    fields = { { key = "group", kind = "flags", values = function() return GROUP_VALUES end } },
    events = { "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" },
    new = function() return { "groupType", party = true, raid = true } end,
    check = function(e, ctx)
        if ctx.inRaid then return e.raid == true end
        if ctx.inGroup then return e.party == true end
        return e.solo == true
    end,
    reason = function(_, ctx) return ctx.inRaid and RAID or (ctx.inGroup and PARTY or L["Solo"]) end,
    describe = function(e)
        local parts = {}
        for _, v in ipairs(GROUP_VALUES) do if e[v.value] then parts[#parts + 1] = v.label end end
        return L["Group"] .. ": " .. table.concat(parts, ", ")
    end,
    merge = function(a, b)
        return { "groupType", solo = a.solo or b.solo or nil, party = a.party or b.party or nil, raid = a.raid or b.raid or nil }
    end,
})

C.RegisterType({
    key = "specialization", label = L["Character"], group = "who", hint = L["Class, specialization or one character by name."],
    fields = { { key = "class", kind = "class" }, { key = "spec", kind = "spec" }, { key = "name", kind = "text", optional = true } },
    events = { "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ENTERING_WORLD" },
    new = function()
        local _, class = UnitClass("player")
        return { "specialization", class = class, spec = C_SpecializationInfo.GetSpecialization() or -1 }
    end,
    check = function(e, ctx)
        if e.class and e.class ~= "" and e.class ~= ctx.class then return false end
        if e.spec and e.spec ~= -1 and e.spec ~= ctx.spec then return false end
        if e.name and e.name ~= "" and e.name ~= ctx.name then return false end
        return true
    end,
    reason = function(_, ctx)
        local _, specName = C_SpecializationInfo.GetSpecializationInfo(ctx.spec or 0)
        return format("%s · %s", LOCALIZED_CLASS_NAMES_MALE[ctx.class] or ctx.class, specName or "?")
    end,
    describe = function(e)
        local class = (e.class and e.class ~= "") and (LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class) or L["Any class"]
        local spec = L["Any specialization"]
        if e.spec and e.spec ~= -1 then spec = format("#%d", e.spec) end
        local s = format("%s: %s, %s", L["Character"], class, spec)
        if e.name and e.name ~= "" then s = s .. ", " .. e.name end
        return s
    end,
})

local function fmtTime(min) return format("%02d:%02d", math.floor(min / 60), min % 60) end
C.RegisterType({
    key = "timeOfDay", label = L["Time of day"], group = "when", hint = L["Hours on the server clock, e.g. evenings only."],
    fields = { { key = "range", kind = "timeRange" } },
    tick = 30,
    new = function() return { "timeOfDay", from = 20 * 60, to = 6 * 60 } end,
    check = function(e, ctx)
        local from, to, now = e.from or 0, e.to or 0, ctx.minutes
        if from <= to then return now >= from and now < to end
        return now >= from or now < to
    end,
    reason = function(_, ctx) return format(L["Server time: %s"], fmtTime(ctx.minutes)) end,
    describe = function(e) return format("%s: %s–%s", L["Time of day"], fmtTime(e.from or 0), fmtTime(e.to or 0)) end,
})

C.RegisterType({
    key = "macro", label = L["Macro conditional"], group = "advanced", hint = L["Any macro condition, e.g. [outdoors,nomounted]."],
    fields = { { key = "macro", kind = "text", placeholder = "[outdoors,nomounted]" } },
    tick = 0.5,
    events = { "MODIFIER_STATE_CHANGED", "PLAYER_TARGET_CHANGED", "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_PAGE_CHANGED" },
    new = function() return { "macro", macro = "" } end,
    check = function(e)
        if not e.macro or e.macro == "" then return false end
        return SecureCmdOptionParse(e.macro) ~= nil
    end,
    describe = function(e) return L["Macro conditional"] .. ": " .. (e.macro or "") end,
})

local reported = setmetatable({}, { __mode = "k" })
C.RegisterType({
    key = "luacode", label = L["Lua code"], group = "advanced", hint = L["Your own Lua function that returns true or false."],
    fields = { { key = "code", kind = "code" } },
    new = function() return { "luacode", code = "-- self:RegisterEvent(\"EVENT_NAME\")\nreturn function()\n    return true\nend\n" } end,
    check = function(e)
        if e.disabledByImport then return false end
        local fn, err, c = C.Compile(e)
        if not fn then
            if reported[c] == nil then reported[c] = true ns:Printf(L["Lua condition error: %s"], tostring(err)) end
            return false
        end
        local ok, res = pcall(fn, c.obj)
        if not ok then
            if reported[c] == nil then reported[c] = true ns:Printf(L["Lua condition error: %s"], tostring(res)) end
            return false
        end
        return res and true or false
    end,
    reason = function(e)
        if e.disabledByImport then return L["Imported code is disabled until you review it."] end
        local fn, err = C.Compile(e)
        return fn and nil or tostring(err)
    end,
    describe = function() return L["Lua code"] end,
})
-- player housing: the player's own plot or house, anyone's, or indoors in a house
local HOME_VALUES = {
    { value = "ownHome", label = L["My house or plot"] },
    { value = "otherHome", label = L["Someone else's house or plot"] },
    { value = "inHouse", label = L["Inside a house"] },
}
C.RegisterType({
    key = "housing", label = L["Home"], group = "where", hint = L["Your house and plot, or a visit to someone else's."],
    fields = { { key = "home", kind = "flags", values = function() return HOME_VALUES end } },
    events = { "HOUSE_PLOT_ENTERED", "HOUSE_PLOT_EXITED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" },
    new = function() return { "housing", ownHome = true } end,
    check = function(e, ctx)
        if e.ownHome and ctx.ownHome then return true end
        if e.otherHome and ctx.anyHome and not ctx.ownHome then return true end
        if e.inHouse and ctx.inHouse then return true end
        return false
    end,
    reason = function(_, ctx)
        if ctx.ownHome then return L["You are at your home."] end
        if ctx.anyHome then return L["You are visiting someone's home."] end
        return L["You are not at a house."]
    end,
    describe = function(e)
        local parts = {}
        for _, v in ipairs(HOME_VALUES) do if e[v.value] then parts[#parts + 1] = v.label end end
        return L["Home"] .. ": " .. table.concat(parts, ", ")
    end,
})

-- what the player is doing; any ticked activity is enough
local ACTIVITY_VALUES = {
    { value = "mounted", label = L["Mounted"] }, { value = "swimming", label = L["Swimming"] },
    { value = "indoors", label = L["Indoors"] }, { value = "outdoors", label = L["Outdoors"] },
    { value = "afk", label = L["AFK"] }, { value = "form", label = L["In a shapeshift form"] },
}
C.RegisterType({
    key = "activity", label = L["Activity"], group = "doing",
    hint = L["Mounted, swimming, indoors or outdoors, AFK, or in a form like Travel Form. Any ticked one is enough."],
    fields = { { key = "activity", kind = "flags", values = function() return ACTIVITY_VALUES end } },
    -- swimming and indoors have no events of their own
    tick = 1,
    events = { "PLAYER_MOUNT_DISPLAY_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_FLAGS_CHANGED", "ZONE_CHANGED_INDOORS" },
    new = function() return { "activity", swimming = true } end,
    check = function(e, ctx)
        for _, v in ipairs(ACTIVITY_VALUES) do
            if e[v.value] and ctx[v.value] then return true end
        end
        return false
    end,
    reason = function(_, ctx)
        local parts = {}
        for _, v in ipairs(ACTIVITY_VALUES) do if ctx[v.value] then parts[#parts + 1] = v.label end end
        return format(L["Right now: %s"], #parts > 0 and table.concat(parts, ", ") or NONE)
    end,
    describe = function(e)
        local parts = {}
        for _, v in ipairs(ACTIVITY_VALUES) do if e[v.value] then parts[#parts + 1] = v.label end end
        return L["Activity"] .. ": " .. table.concat(parts, " " .. L["or"] .. " ")
    end,
})

--
-- Holidays, read from the in-game calendar
--

local holidayNames = {}          -- eventID -> title, remembered for descriptions
local calendarOpened = false
local activeCache = { at = nil, list = {} }       -- shared by the refreshes of one moment
local knownCache = { at = nil, list = {} }

local function stamp(t) return ((t.year * 100 + t.month) * 100 + t.monthDay) * 10000 + (t.hour or 0) * 100 + (t.minute or 0) end

-- the calendar counts months from the one it shows; that is not always the current one
local function monthOffset(now)
    local shown = C_Calendar.GetMonthInfo(0)
    if not shown then return 0 end
    return (now.year - shown.year) * 12 + now.month - shown.month
end

local function dayHolidays(offset, day, fn)
    for i = 1, C_Calendar.GetNumDayEvents(offset, day) or 0 do
        local ev = C_Calendar.GetDayEvent(offset, day, i)
        if ev and ev.calendarType == "HOLIDAY" and ev.eventID then
            holidayNames[ev.eventID] = ev.title
            fn(ev)
        end
    end
end

local function calendarReady()
    if not (C_Calendar and C_DateAndTime and C_Calendar.GetDayEvent) then return false end
    if not calendarOpened then
        calendarOpened = true
        C_Calendar.OpenCalendar()          -- asks the server for the month data once
    end
    return true
end

-- eventID -> title of the holidays running right now
function C.ActiveHolidays()
    if not calendarReady() then return {} end
    if activeCache.at and GetTime() - activeCache.at < 1 then return activeCache.list end
    local now = C_DateAndTime.GetCurrentCalendarTime()
    local key = stamp(now)
    local list = {}
    dayHolidays(monthOffset(now), now.monthDay, function(ev)
        local from, to = ev.startTime and stamp(ev.startTime), ev.endTime and stamp(ev.endTime)
        if (not from or from <= key) and (not to or key < to) then list[ev.eventID] = ev.title end
    end)
    activeCache.at, activeCache.list = GetTime(), list
    return list
end

-- the calendar loaded new data: holidays may have appeared for the current minute
function C.ForgetHolidays() activeCache.at, knownCache.at = nil, nil end

-- every holiday in the coming year, in the order they start, for the picker
function C.KnownHolidays()
    local out, seen = {}, {}
    if not calendarReady() then return out end
    -- a year of days: scanned again only after a while, the When tab asks on every redraw
    if knownCache.at and GetTime() - knownCache.at < 30 then return knownCache.list end
    knownCache.at, knownCache.list = GetTime(), out
    local first = monthOffset(C_DateAndTime.GetCurrentCalendarTime())
    for offset = first, first + 11 do
        local info = C_Calendar.GetMonthInfo(offset)
        for day = 1, info and info.numDays or 0 do
            dayHolidays(offset, day, function(ev)
                if not seen[ev.eventID] then
                    seen[ev.eventID] = true
                    out[#out + 1] = { value = ev.eventID, label = ev.title }
                end
            end)
        end
    end
    return out
end

local ANY_HOLIDAY = 0
local function holidayLabel(id)
    if id == ANY_HOLIDAY then return L["Any holiday"] end
    return holidayNames[id] or ("#" .. id)
end

C.RegisterType({
    key = "holiday", label = L["Holiday"], group = "when",
    hint = L["Hallow's End, Winter Veil, Darkmoon Faire and the other events in the calendar."],
    fields = { { key = "holidayIDs", kind = "multiChoice", values = function()
        local list = { { value = ANY_HOLIDAY, label = L["Any holiday"] } }
        for _, h in ipairs(C.KnownHolidays()) do list[#list + 1] = h end
        return list
    end } },
    tick = 60,
    events = { "CALENDAR_UPDATE_EVENT_LIST", "PLAYER_ENTERING_WORLD" },
    new = function()
        local id = next(C.ActiveHolidays())
        return { "holiday", holidayIDs = { id or ANY_HOLIDAY } }
    end,
    check = function(e, ctx)
        for _, id in ipairs(e.holidayIDs or {}) do
            if id == ANY_HOLIDAY and next(ctx.holidays) then return true end
            if ctx.holidays[id] then return true end
        end
        return false
    end,
    reason = function(_, ctx)
        local names = {}
        for _, title in pairs(ctx.holidays) do names[#names + 1] = title end
        table.sort(names)
        return #names > 0 and format(L["Today: %s"], table.concat(names, ", ")) or L["No holiday right now."]
    end,
    describe = function(e)
        local parts = {}
        for _, id in ipairs(e.holidayIDs or {}) do parts[#parts + 1] = holidayLabel(id) end
        return L["Holiday"] .. ": " .. (#parts > 0 and table.concat(parts, ", ") or L["none chosen yet"])
    end,
    merge = function(a, b) return { "holiday", holidayIDs = union(a.holidayIDs, b.holidayIDs) } end,
})

ns.Events.Register(C, "CALENDAR_UPDATE_EVENT_LIST", function() C.ForgetHolidays() end)
