-- WoW API stub for Core/ unit tests. Not loaded in game.
local W = {}

local function noop() end

-- ------------------------------------------------------------------ frames
local frames, timers
local FrameMT = {}
FrameMT.__index = function(t, k) return FrameMT[k] or noop end
function FrameMT:RegisterEvent(e) self._events[e] = true end
function FrameMT:RegisterUnitEvent(e, ...) self._events[e] = { ... } end
function FrameMT:UnregisterEvent(e) self._events[e] = nil end
function FrameMT:UnregisterAllEvents() self._events = {} end
function FrameMT:IsEventRegistered(e) return self._events[e] ~= nil end
function FrameMT:SetScript(n, f) self._scripts[n] = f end
function FrameMT:GetScript(n) return self._scripts[n] end
function FrameMT:HookScript(n, f)
    local old = self._scripts[n]
    self._scripts[n] = function(...) if old then old(...) end f(...) end
end
function FrameMT:IsShown() return self._shown end
function FrameMT:Show() self._shown = true end
function FrameMT:Hide() self._shown = false end
function FrameMT:CreateTexture() return W.newFrame() end
function FrameMT:CreateFontString() return W.newFrame() end

function W.newFrame()
    local f = setmetatable({ _events = {}, _scripts = {}, _shown = true }, FrameMT)
    frames[#frames + 1] = f
    return f
end

-- lets tests/uistub.lua route events to its own frame objects
function W.track(f) frames[#frames + 1] = f end

function W.fire(event, ...)
    local unit = ...
    for _, f in ipairs(frames) do
        local reg = f._events[event]
        if reg and f._scripts.OnEvent then
            if reg == true or reg[1] == unit or reg[2] == unit then
                f._scripts.OnEvent(f, event, ...)
            end
        end
    end
end

-- ------------------------------------------------------------------ world
local function defaultWorld()
    return {
        time = 1000, gameHour = 12, gameMinute = 0,
        zone = "Stormwind City", subzone = "Trade District", mapID = 84, mapParents = { [84] = 37, [37] = 13 },
        resting = true, instanceType = "none", inGroup = false, inRaid = false, delve = false,
        class = "HUNTER", className = "Hunter", spec = 1, playerName = "Tester", realm = "Realm",
        combat = false, flying = false, falling = false, mounted = false, stealthed = false, dead = false,
        vehicle = false, afk = false, casting = false, fullControl = true,
        auras = {}, items = {}, equipped = {}, quests = {}, pastCooldowns = {},
        pets = {}, summoned = nil, cooldowns = {}, favorites = {},
        macroResult = nil, locale = "enUS",
        swimming = false, indoors = false, formID = nil,
        home = { own = false, any = false, inside = false },
        outfits = {}, activeOutfit = 0, gearDisplayed = false,   -- transmog outfits: { outfitID, name, icon }
        mounts = {},          -- { id, name, active, collected, types = { journal type filter indices } }
        -- the journal's filters as the player left them: types/sources by index, collected 1-3, search
        mountFilters = { types = { true, true, true, true, true }, sources = { true, true, true }, collected = { true, true, true }, search = "" },
        -- calendar: the month it shows, today, and events keyed by offset * 100 + day
        calShown = { year = 2026, month = 10 }, now = { year = 2026, month = 10, monthDay = 16, hour = 12, minute = 0 },
        calEvents = {},
        sources = {},
        printed = {},
    }
end

-- ------------------------------------------------------------------ install
function W.reset()
    setmetatable(_G, nil)   -- drop tests/uistub.lua's permissive globals
    frames, timers = {}, {}
    W.world = defaultWorld()
    local w = W.world
    -- WoW Lua extensions
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    tinsert, tremove, tconcat = table.insert, table.remove, table.concat
    format, strfind, strlower, strupper, strsub, strmatch, gsub, strsplit =
        string.format, string.find, string.lower, string.upper, string.sub, string.match, string.gsub,
        function(sep, s)
            local out = {}
            for piece in string.gmatch(s, "([^" .. sep .. "]+)") do out[#out + 1] = piece end
            return unpack(out)
        end
    strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    string.trim = strtrim
    floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs
    fastrandom = function() return W.random and W.random() or math.random() end
    CopyTable = function(t)
        local c = {}
        for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end
        return c
    end
    securecallfunction = function(f, ...) return f(...) end
    -- WoW's xpcall forwards extra args
    local xp = xpcall
    xpcall = function(f, h, ...)
        local n, a = select("#", ...), { ... }
        return xp(function() return f(unpack(a, 1, n)) end, h)
    end
    geterrorhandler = function() return function(e) error(e, 0) end end
    hooksecurefunc = function(t, k, f)
        if type(t) == "string" then t, k, f = _G, t, k end
        assert(type(t[k]) == "function", "hooksecurefunc: " .. tostring(k) .. " is not a function")
        local orig = t[k]
        t[k] = function(...) local r = { orig(...) } f(...) return unpack(r) end
    end
    CreateFrame = function() return W.newFrame() end
    UIParent = W.newFrame()
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) w.printed[#w.printed + 1] = m end }
    StaticPopupDialogs = {}
    StaticPopup_Show = function(name) w.popup = name end
    SlashCmdList = {}
    UISpecialFrames = {}
    -- game state
    GetTime = function() return w.time end
    GetServerTime = function() return 1700000000 + math.floor(w.time) end
    GetGameTime = function() return w.gameHour, w.gameMinute end
    GetLocale = function() return w.locale end
    GetBuildInfo = function() return "12.1.5", "70100", "Oct 13 2026", 120105 end
    IsLoggedIn = function() return true end
    UnitName = function() return w.playerName end
    GetRealmName = function() return w.realm end
    UnitClass = function() return w.className, w.class end
    UnitFactionGroup = function() return "Alliance" end
    GetCurrentRegion = function() return 3 end
    GetZoneText = function() return w.zone end
    GetSubZoneText = function() return w.subzone end
    GetRealZoneText = function() return w.zone end
    IsResting = function() return w.resting end
    IsInInstance = function() return w.instanceType ~= "none", w.instanceType end
    IsInGroup = function() return w.inGroup or w.inRaid end
    IsInRaid = function() return w.inRaid end
    InCombatLockdown = function() return w.combat end
    IsFlying = function() return w.flying end
    IsFalling = function() return w.falling end
    IsMounted = function() return w.mounted end
    IsStealthed = function() return w.stealthed end
    HasFullControl = function() return w.fullControl end
    UnitIsDeadOrGhost = function() return w.dead end
    UnitInVehicle = function() return w.vehicle end
    UnitIsAFK = function() return w.afk end
    IsSwimming = function() return w.swimming end
    IsSubmerged = function() return false end
    IsIndoors = function() return w.indoors end
    IsOutdoors = function() return not w.indoors end
    GetShapeshiftFormID = function() return w.formID end
    UnitCastingInfo = function() return w.casting and "Spell" or nil end
    UnitChannelInfo = function() return nil end
    SecureCmdOptionParse = function() return w.macroResult end
    JumpOrAscendStart, SitStandOrDescendStart = noop, noop
    GetBindingKey = function() return nil end
    -- only the sounds the client has: a missing SOUNDKIT name is nil, and the game errors on PlaySound(nil)
    SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_MAINMENU_OPTION_CHECKBOX_OFF = 857,
        IG_CHARACTER_INFO_OPEN = 839, IG_CHARACTER_INFO_CLOSE = 840, IG_QUEST_LOG_ABANDON_QUEST = 846 }
    PlaySound = function(id) assert(type(id) == "number", "PlaySound needs a sound id") end
    ReloadUI = function() w.reloaded = true end
    ERR_MUST_BE_STANDING = "You must be standing to do that"
    SPELL_FAILED_NOT_STANDING = "You must be standing to do that"
    DEFAULT, ZONE, PARTY, RAID, CLASS = "Default", "Zone", "Party", "Raid", "Class"
    CLASS_SORT_ORDER = { "HUNTER", "WARRIOR" }
    LOCALIZED_CLASS_NAMES_MALE = { HUNTER = "Hunter", WARRIOR = "Warrior" }
    local classFiles = { "WARRIOR", "HUNTER" }
    GetNumClasses = function() return #classFiles end
    GetClassInfo = function(id) return LOCALIZED_CLASS_NAMES_MALE[classFiles[id]], classFiles[id], id end
    GetSpecializationInfoForClassID = function(id, i)
        local specs = ({ { "Arms", "Fury", "Protection" }, { "Beast Mastery", "Marksmanship", "Survival" } })[id]
        if specs and specs[i] then return id * 100 + i, specs[i] end
    end
    Enum = { PetJournalFilter = {}, MountType = { Ground = 0, Flying = 1, Aquatic = 2, Dragonriding = 3, RideAlong = 4 } }
    C_Timer = {
        After = function(sec, fn) timers[#timers + 1] = { at = w.time + sec, fn = fn } end,
        NewTimer = function(sec, fn)
            local t = { at = w.time + sec, fn = fn }
            t.Cancel = function() t.cancelled = true end
            t.IsCancelled = function() return t.cancelled end
            timers[#timers + 1] = t
            return t
        end,
        NewTicker = function(sec, fn)
            local t = { at = w.time + sec, fn = fn, every = sec }
            t.Cancel = function() t.cancelled = true end
            t.IsCancelled = function() return t.cancelled end
            timers[#timers + 1] = t
            return t
        end,
    }
    C_PetJournal = {
        GetNumPetSources = function() return 3 end,
        GetOwnedPetIDs = function()
            local r = {}
            for id in pairs(w.pets) do r[#r + 1] = id end
            table.sort(r)
            return r
        end,
        GetPetInfoByPetID = function(id)
            local p = w.pets[id]
            if not p then return nil end
            return p.species, p.custom, p.level or 1, 0, 0, p.display or 0, w.favorites[id] or false,
                p.name, "icon" .. p.species, p.type or 1, p.creature or (1000 + p.species)
        end,
        GetPetStats = function(id) local p = w.pets[id] return 100, 100, 10, 10, p and (p.quality or 2) end,
        PetIsSummonable = function(id) local p = w.pets[id] return p ~= nil and not p.unsummonable end,
        PetNeedsFanfare = function(id) local p = w.pets[id] return p ~= nil and p.fanfare == true end,
        GetSummonedPetGUID = function() return w.summoned end,
        SummonPetByGUID = function(id)
            if w.summoned == id then w.summoned = nil else w.summoned = id end
            w.summonCalls = (w.summonCalls or 0) + 1
        end,
        -- real API: start, duration, isEnabled; cooldowns[id] = seconds left, pastCooldowns[id] = expired one
        GetPetCooldownByGUID = function(id)
            if w.cooldowns[id] then return w.time - 1, w.cooldowns[id] + 1, 1 end
            if w.pastCooldowns[id] then return w.time - 100, 30, 1 end
            return 0, 0, 1
        end,
        SetPetLoadOutInfo = noop,
        SetCustomName = noop,
        SetFavorite = function(id, v) w.favorites[id] = v == 1 end,
        GetNumPetTypes = function() return 10 end,
        -- name, icon, type, creatureID, source, description, isWild, canBattle, isTradeable, isUnique, obtainable, displayID
        GetPetModelSceneInfoBySpeciesID = function() return 718, 718 end,
        GetPetInfoBySpeciesID = function(s)
            return "Species" .. s, "icon", 1, 1000 + s, w.sources[s] or ("Source " .. s), "", false, true, true, false, true, 5000 + s
        end,
    }
    C_Item = {
        GetItemCount = function(id) return w.items[id] or 0 end,
        GetItemInfo = function(id) return "Item" .. id end,
        IsEquippedItem = function(id) return w.equipped[id] == true end,
        RequestLoadItemDataByID = noop,
        GetItemQualityColor = function() return 1, 1, 1 end,
    }
    C_ChatInfo = { SendChatMessage = noop }
    C_SpecializationInfo = {
        GetSpecialization = function() return w.spec end,
        GetSpecializationInfo = function(i) return i, "Spec" .. i end,
    }
    C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return w.auras[id] and { spellId = id } or nil end }
    C_Map = {
        GetBestMapForUnit = function() return w.mapID end,
        GetMapInfo = function(id) return { mapID = id, name = "Map" .. id, parentMapID = w.mapParents[id] or 0 } end,
    }
    C_PartyInfo = { IsDelveInProgress = function() return w.delve end }
    C_Housing = {
        IsInsideOwnedHouseOrPlot = function() return w.home.own end,
        IsInsideHouseOrPlot = function() return w.home.any or w.home.own end,
        IsInsideHouse = function() return w.home.inside end,
    }
    C_TransmogOutfitInfo = {
        GetOutfitsInfo = function() return w.outfits end,
        GetActiveOutfitID = function() return w.activeOutfit end,
        IsEquippedGearOutfitDisplayed = function() return w.gearDisplayed end,
        GetOutfitInfo = function(id) for _, o in ipairs(w.outfits) do if o.outfitID == id then return o end end end,
    }
    C_MountJournal = {
        GetMountIDs = function()
            local ids = {}
            for i, m in ipairs(w.mounts) do ids[i] = m.id end
            return ids
        end,
        GetMountInfoByID = function(id)
            w.mountLookups = (w.mountLookups or 0) + 1
            for _, m in ipairs(w.mounts) do
                if m.id == id then
                    return m.name, 1, m.icon or 1, m.active, m.usable ~= false, m.source or 1, m.favorite or false, false, nil, m.hidden or false, m.collected, id
                end
            end
        end,
        IsValidTypeFilter = function(i) return i >= 1 and i <= 5 end,
        IsTypeChecked = function(i) return w.mountFilters.types[i] end,
        SetTypeFilter = function(i, on) w.mountFilters.types[i] = on w.filterSets = (w.filterSets or 0) + 1 end,
        IsValidSourceFilter = function(i) return w.mountFilters.sources[i] ~= nil end,
        IsSourceChecked = function(i) return w.mountFilters.sources[i] end,
        SetSourceFilter = function(i, on) w.mountFilters.sources[i] = on end,
        SetAllSourceFilters = function(on) for i in pairs(w.mountFilters.sources) do w.mountFilters.sources[i] = on end end,
        GetCollectedFilterSetting = function(i) return w.mountFilters.collected[i] end,
        SetCollectedFilterSetting = function(i, on) w.mountFilters.collected[i] = on end,
        SetSearch = function(text) w.mountFilters.search = text end,
        -- what the journal lists under the filters: collected mounts of a ticked type, if the search is empty
        GetNumDisplayedMounts = function()
            local f, n = w.mountFilters, 0
            w.displayedMounts = {}
            if f.search ~= "" or not f.collected[1] then return 0 end
            for _, m in ipairs(w.mounts) do
                local shown = false
                for _, t in ipairs(m.types or {}) do if f.types[t] then shown = true end end
                if m.collected and shown and f.sources[m.source or 1] ~= false then n = n + 1 w.displayedMounts[n] = m.id end
            end
            return n
        end,
        GetDisplayedMountID = function(n) return w.displayedMounts[n] end,
        GetMountInfoExtraByID = function(id)
            for _, m in ipairs(w.mounts) do
                if m.id == id then return m.display or 100 + id, "", m.sourceText or "", false, m.typeID or 230, 1 end
            end
        end,
    }
    C_DateAndTime = { GetCurrentCalendarTime = function() return w.now end }
    C_Calendar = {
        OpenCalendar = function() w.calendarOpened = true end,
        GetMonthInfo = function(off)
            local m = w.calShown.month - 1 + off
            return { year = w.calShown.year + math.floor(m / 12), month = m % 12 + 1, numDays = 31 }
        end,
        GetNumDayEvents = function(off, day) return #(w.calEvents[off * 100 + day] or {}) end,
        GetDayEvent = function(off, day, i) return (w.calEvents[off * 100 + day] or {})[i] end,
    }
    C_QuestLog = {
        GetNumQuestLogEntries = function() return #w.quests end,
        GetInfo = function(i) return w.quests[i] and { questID = w.quests[i], isHeader = false } or nil end,
        IsOnQuest = function(id)
            for _, q in ipairs(w.quests) do if q == id then return true end end
            return false
        end,
        GetTitleForQuestID = function(q) return "Quest" .. q end,
    }
    C_Spell = { GetSpellInfo = function(id) return { name = "Spell" .. id } end }
    C_AddOns = { GetAddOnMetadata = function(_, k) return k == "Version" and "2.0.0-test" or nil end }
    C_EncodingUtil = {
        SerializeCBOR = function(v) W._cbor = W._cbor or {} W._cbor[#W._cbor + 1] = v return "CBOR" .. #W._cbor end,
        DeserializeCBOR = function(s) local i = tonumber(s:match("^CBOR(%d+)$")) return i and W._cbor[i] end,
        CompressString = function(s) return "Z" .. s end,
        DecompressString = function(s) return s:match("^Z(.*)$") end,
        EncodeBase64 = function(s) return "B" .. s end,
        DecodeBase64 = function(s) return s:match("^B(.*)$") end,
    }
    PetCall3DB, PetLeash3DB, PetCall = nil, nil, nil
    LibStub = nil   -- libraries register afresh on every load
end

function W.advance(seconds)
    local w = W.world
    local target = w.time + seconds
    while true do
        table.sort(timers, function(a, b) return a.at < b.at end)
        local t = timers[1]
        if not t or t.at > target then break end
        table.remove(timers, 1)
        w.time = t.at
        if not t.cancelled then
            t.fn(t)
            if t.every and not t.cancelled then
                t.at = w.time + t.every
                timers[#timers + 1] = t
            end
        end
    end
    w.time = target
end

-- Reads PetCall.toc and returns the addon files in load order.
function W.tocFiles(opts)
    opts = opts or {}
    local uiAllowed = {}
    for _, f in ipairs(opts.ui or {}) do uiAllowed[f] = true end
    local list = {}
    for line in io.lines("PetCall.toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then
            local path = line:gsub("\\", "/")
            -- the minimap/LDB libraries need real UI frames; tests/uistub.lua registers stand-ins
            local skip = path:match("^Libs/LibDBIcon") or path:match("^Libs/LibDataBroker")
                or (path:match("^UI/") and not uiAllowed[path])
                or (path:match("^Locales/") and path ~= "Locales/enUS.lua")
            if not skip then list[#list + 1] = path end
        end
    end
    return list
end

function W.load(opts)
    local ns = {}
    for _, path in ipairs(W.tocFiles(opts)) do
        local chunk = assert(loadfile(path))
        chunk("PetCall", ns)
    end
    return ns
end

function W.login()
    W.fire("ADDON_LOADED", "PetCall")
    W.fire("PLAYER_LOGIN")
    W.fire("PLAYER_ENTERING_WORLD", true, false)
    W.advance(1)
end

W.reset()
return W
