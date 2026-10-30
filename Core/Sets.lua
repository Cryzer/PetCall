local _, ns = ...

local L = ns.L
local pairs, ipairs, rawget, wipe, sort, strfind, strtrim = pairs, ipairs, rawget, wipe, table.sort, strfind, strtrim

local Sets = ns:NewModule("Sets")
ns.Sets = Sets
Sets.DEFAULT = "$Default"

local cache = {}          -- name -> set object
local current
local sessionPaused = {}  -- name -> true: paused until logout (not saved)
local pauseTimers = {}    -- name -> timer that ends a timed pause

local SetMixin = {}
SetMixin.__index = SetMixin

local function changed(set)
    set.dirty = true
    ns:Fire("SetsChanged", set and set.name)
    Sets:Update()
end

function SetMixin:IsDefault() return self.name == Sets.DEFAULT end
function SetMixin:DisplayName() return self:IsDefault() and L["Default"] or self.name end

function SetMixin:Rename(name)
    if self:IsDefault() then return false, L["The default set cannot be renamed."] end
    local ok, err = Sets:ValidateName(name, self.name)
    if not ok then return false, err end
    name = strtrim(name)
    if name == self.name then return true end
    local sets = ns.db.profile.sets
    sets[name] = self.settings
    sets[self.name] = nil
    cache[self.name] = nil
    cache[name] = self
    sessionPaused[name], sessionPaused[self.name] = sessionPaused[self.name], nil
    self.name = name
    self.settings.name = name
    changed(self)
    return true
end

function SetMixin:Delete()
    if self:IsDefault() then return false, L["The default set cannot be deleted."] end
    ns.db.profile.sets[self.name] = nil
    cache[self.name] = nil
    sessionPaused[self.name] = nil
    if pauseTimers[self.name] then pauseTimers[self.name]:Cancel() pauseTimers[self.name] = nil end
    if self.watcher then self.watcher:Free() self.watcher = nil end
    self.deleted = true
    ns:Fire("SetsChanged", self.name)
    Sets:Update()
    return true
end

function SetMixin:SetEnabled(v)
    self.settings.enabled = v and true or false
    if v then self.settings.pausedUntil, sessionPaused[self.name] = nil, nil end
    changed(self)
end

-- Pausing: "forever" is the 1.x "enabled = false" (saved), "hour" ends by itself
-- (saved as server time), "session" lasts until logout or /reload.
local function schedulePauseEnd(set)
    local name = set.name
    if pauseTimers[name] then pauseTimers[name]:Cancel() pauseTimers[name] = nil end
    local untilTime = set.settings.pausedUntil
    if not untilTime then return end
    local left = untilTime - GetServerTime()
    if left <= 0 then set.settings.pausedUntil = nil return end
    pauseTimers[name] = ns:After(left + 1, function()
        pauseTimers[name] = nil
        local s = cache[name]
        if s and not s.deleted then changed(s) end
    end)
end

function SetMixin:Pause(kind)
    if kind == "hour" then
        self.settings.pausedUntil = GetServerTime() + 3600
        schedulePauseEnd(self)
    elseif kind == "session" then
        sessionPaused[self.name] = true
    else
        self.settings.enabled = false
    end
    changed(self)
end

function SetMixin:Resume()
    self.settings.enabled = true
    self.settings.pausedUntil = nil
    sessionPaused[self.name] = nil
    schedulePauseEnd(self)
    changed(self)
end

-- paused?, how ("forever" | "session" | "timed"), seconds left for a timed pause
function SetMixin:IsPaused()
    if not self.settings.enabled then return true, "forever" end
    if sessionPaused[self.name] then return true, "session" end
    local untilTime = self.settings.pausedUntil
    if untilTime then
        local left = untilTime - GetServerTime()
        if left > 0 then return true, "timed", left end
    end
    return false
end

function SetMixin:SetImmediate(v) self.settings.immediate = v and true or nil changed(self) end

-- what happens when the set starts being used: "keep" the pet that is out, a new pet
-- unless the one out "fits", or always a "new" one
function SetMixin:GetOnActivate()
    if not self.settings.immediate then return "keep" end
    return self.settings.alwaysNew and "new" or "fits"
end
function SetMixin:SetOnActivate(mode)
    self.settings.immediate = mode ~= "keep" or nil
    self.settings.alwaysNew = mode == "new" or nil
    changed(self)
end

-- a set that keeps the pet away (raids, arenas...): it dismisses instead of summoning
function SetMixin:SetNoPet(v) self.settings.noPet = v and true or nil changed(self) end
function SetMixin:IsNoPet() return self.settings.noPet == true end

-- A set's own value wins; without one it reads Default's (fromDefault). Default always has one.
-- New pet every: minutes (0 = off), only in cities, fromDefault
function SetMixin:GetSwitch()
    local own = self.settings.switchMinutes
    if own == nil and not self:IsDefault() then
        local d = Sets:Get(Sets.DEFAULT).settings
        return d.switchMinutes or 0, d.switchCitiesOnly == true, true
    end
    return own or 0, self.settings.switchCitiesOnly == true, false
end
-- nil minutes = like Default (a no-op on Default)
function SetMixin:SetSwitch(minutes, citiesOnly)
    if minutes == nil and self:IsDefault() then return end
    self.settings.switchMinutes = minutes
    self.settings.switchCitiesOnly = minutes ~= nil and citiesOnly or nil
    changed(self)
end

-- Message on summon: on?, fromDefault
function SetMixin:GetAnnounce()
    local own = self.settings.announce
    if own == nil and not self:IsDefault() then
        return Sets:Get(Sets.DEFAULT).settings.announce ~= "off", true
    end
    return own ~= "off", false
end
-- nil = like Default (a no-op on Default)
function SetMixin:SetAnnounce(on)
    if on == nil and self:IsDefault() then return end
    if on == nil then self.settings.announce = nil else self.settings.announce = on and "on" or "off" end
    changed(self)
end
function SetMixin:SetDefaultWeight(w) self.settings.defaultValue = w changed(self) end

function SetMixin:GetPetWeight(petID) return ns.Weights.PetWeight(self.settings, petID) end
function SetMixin:HasManualWeight(petID) return rawget(self.settings.pets, petID) ~= nil end
function SetMixin:SetPetWeight(petID, w) self.settings.pets[petID] = w changed(self) end
function SetMixin:SetPetWeights(petIDs, w)
    for _, id in ipairs(petIDs) do self.settings.pets[id] = w end
    changed(self)
end
function SetMixin:ClearPetWeights() wipe(self.settings.pets) changed(self) end

-- the weight the set's strongest rule for a pet gives it, worked out with the draw table
function SetMixin:GetAutoWeight(petID)
    return self:GetWeightTable().auto[petID] or 0
end

-- how often the pet comes out in this set and why: "hand", "rule" or "default"
function SetMixin:GetLevel(petID)
    return ns.Weights.Effective(self.settings, petID, self:GetWeightTable().auto[petID])
end

-- drop the pets' own setting: they come out as their rules or the set's default say
function SetMixin:UseRule(petIDs)
    for _, id in ipairs(petIDs) do self.settings.pets[id] = nil end
    changed(self)
end

function SetMixin:FiltersChanged() changed(self) end

-- Before 2.2 a pet's own weight and its rules' weights added up; now its own setting
-- wins. An own setting that only repeated the set's default (ticking a pet stored
-- Normal) would now shut its rules out, so those go, once per set.
local function ownSettingsWin(settings)
    if settings.ownWins then return end
    local same = {}
    for id, w in pairs(settings.pets) do
        if w == ns.Weights.Effective({ pets = {}, defaultValue = settings.defaultValue }, id) then same[#same + 1] = id end
    end
    for _, id in ipairs(same) do settings.pets[id] = nil end
    settings.ownWins = true
end

function SetMixin:GetWeightTable()
    if self.dirty or not self.weights then
        ownSettingsWin(self.settings)
        self.weights = ns.Weights.Build(self.settings, self.weights)
        -- rules about where you are: the place this draw was made for
        self.weights.place = ns.AutoRules.PlaceKey(self.settings.filter)
        self.dirty = false
    end
    return self.weights
end

-- why the pet would not come out right now, or nil
function SetMixin:Unavailable(petID)
    if ns.PetCache:OnCooldown(petID) then return L["On cooldown"] end
    if not C_PetJournal.PetIsSummonable(petID) then return L["Cannot be summoned"] end
end

-- tickets per tile (copies add up on their primary) and the tile that has the most,
-- added up once per draw table: hovering the grid only reads them
function SetMixin:GetTileSums()
    local tbl = self:GetWeightTable()
    if not tbl.tiles then
        local sums, top, best = {}, 0, nil
        for i = 1, #tbl, 2 do
            local primary = ns.PetCache:GetCopies(tbl[i + 1])[1]
            sums[primary] = (sums[primary] or 0) + tbl[i]
            if sums[primary] > top then top, best = sums[primary], primary end
        end
        tbl.tiles = { sums = sums, best = best }
    end
    return tbl.tiles.sums, tbl.tiles.best
end

function SetMixin:PickPet(exclude) return ns.Weights.Pick(self:GetWeightTable(), fastrandom(), exclude) end
function SetMixin:Contains(petID) return ns.Weights.Sum(self:GetWeightTable(), petID) > 0 end

function SetMixin:HasConditions()
    return not self:IsDefault() and self.settings.trigger ~= nil and #self.settings.trigger > 0
end

function SetMixin:ConditionsMet()
    if self:IsDefault() or not self.watcher then return true end
    return self.watcher.value
end

function SetMixin:IsActive()
    if self.deleted or self:IsPaused() then return false end
    if not self:ConditionsMet() then return false end
    if self:IsNoPet() then return true end
    return self:GetWeightTable().total > 0
end

function SetMixin:GetPriority()
    return self:IsDefault() and -1 or (self.settings.priority or 1)
end

-- "outranked": the set could be used right now, but a set above it in the list is
function SetMixin:GetStatus()
    if self:IsPaused() then return "paused" end
    if not self:IsNoPet() and self:GetWeightTable().total <= 0 then return "empty" end
    if current == self then return "active" end
    if self:ConditionsMet() then return "outranked" end
    return "waiting"
end

-- place in the list (1 = first) and how many sets take part in the order
function SetMixin:GetRank()
    local list = Sets:List()
    for i, s in ipairs(list) do if s == self then return i, #list end end
end

function SetMixin:GetConditionModel() return ns.Conditions.ToModel(self.settings.trigger) end

function SetMixin:SetConditionModel(model)
    local list = ns.Conditions.FromModel(model)
    local t = self.settings.trigger
    wipe(t)
    for i, e in ipairs(list) do t[i] = e end
    self:ConditionsChanged()
end

function SetMixin:ConditionsChanged()
    if self.watcher then self.watcher:Rebuild() end
    ns:Fire("ConditionStateChanged", self.name)
    changed(self)
end

function SetMixin:GetConditionStates() return self.watcher and self.watcher.states or {} end

local TEMPLATES = {
    city = function() return { { "specialLocation", locs = { "city" } } } end,
    instance = function() return { { "specialLocation", locs = { "dungeon", "raid" } } } end,
    here = function() return { { "zone", mapIDs = { C_Map.GetBestMapForUnit("player") } } } end,
    spec = function()
        local _, class = UnitClass("player")
        return { { "specialization", class = class, spec = C_SpecializationInfo.GetSpecialization() or -1 } }
    end,
    group = function() return { { "groupType", party = true, raid = true } } end,
    home = function() return { { "housing", ownHome = true } } end,
    holiday = function() return { { "holiday", holidayIDs = { 0 } } } end,
}

function SetMixin:ApplyTemplate(key)
    local t = self.settings.trigger
    for _, e in ipairs(TEMPLATES[key]()) do t[#t + 1] = e end
    self:ConditionsChanged()
end

-- A set object outlives its data when it is deleted or the profile changes; its
-- mutators must not touch the (new) profile's tables or revive its freed watcher.
for _, method in ipairs({ "Rename", "Delete", "SetEnabled", "Pause", "Resume", "SetImmediate", "SetDefaultWeight",
    "SetOnActivate", "SetNoPet", "SetSwitch", "SetAnnounce",
    "SetPetWeight", "SetPetWeights", "ClearPetWeights", "FiltersChanged", "SetConditionModel", "ConditionsChanged",
    "ApplyTemplate" }) do
    local original = SetMixin[method]
    SetMixin[method] = function(self, ...)
        if self.deleted then return false, L["This set no longer exists."] end
        return original(self, ...)
    end
end

--
-- Collection
--

local function newSet(name)
    local set = setmetatable({ name = name, settings = ns.db.profile.sets[name], dirty = true }, SetMixin)
    cache[name] = set
    if not set:IsDefault() then
        set.settings.trigger = set.settings.trigger or {}
        ns.Conditions.Normalize(set.settings.trigger)
        set.watcher = ns.Conditions.NewWatcher(set.settings.trigger, function()
            ns:Fire("ConditionStateChanged", set.name)
            Sets:Update()
        end)
    end
    return set
end

function Sets:Get(name)
    if cache[name] then return cache[name] end
    if rawget(ns.db.profile.sets, name) then return newSet(name) end
end

-- The list is the order: when several sets fit, the first one is used. The default
-- set is always last. Sets from 1.x (or imports) without a place are put in by their
-- old priority, then by name.
function Sets:List()
    local out = {}
    for name in pairs(ns.db.profile.sets) do
        out[#out + 1] = self:Get(name)
    end
    local huge = math.huge
    sort(out, function(a, b)
        if a:IsDefault() ~= b:IsDefault() then return b:IsDefault() end
        local oa, ob = a.settings.order or huge, b.settings.order or huge
        if oa ~= ob then return oa < ob end
        if a:GetPriority() ~= b:GetPriority() then return a:GetPriority() > b:GetPriority() end
        return a.name < b.name
    end)
    return out
end

-- numbers the sets 1..n in list order, so every set has its own place
function Sets:Renumber()
    for i, s in ipairs(self:List()) do
        if not s:IsDefault() then s.settings.order = i end
    end
end

-- moves a set up (delta -1) or down (+1); the default set stays last
function Sets:Move(set, delta)
    if set:IsDefault() or set.deleted then return false end
    local list = self:List()
    local i
    for k, s in ipairs(list) do if s == set then i = k end end
    local j = i + delta
    if not list[j] or list[j]:IsDefault() then return false end
    list[i], list[j] = list[j], list[i]
    for k, s in ipairs(list) do if not s:IsDefault() then s.settings.order = k end end
    ns:Fire("SetsChanged", set.name)
    self:Update()
    return true
end

-- puts a set at a place in the list (1 = first), as a drag and drop does
function Sets:MoveTo(set, slot)
    if set:IsDefault() or set.deleted then return false end
    local list = {}
    for _, s in ipairs(self:List()) do if not s:IsDefault() then list[#list + 1] = s end end
    local from
    for k, s in ipairs(list) do if s == set then from = k end end
    table.remove(list, from)
    if slot > from then slot = slot - 1 end
    slot = math.max(1, math.min(#list + 1, slot))
    table.insert(list, slot, set)
    for k, s in ipairs(list) do s.settings.order = k end
    ns:Fire("SetsChanged", set.name)
    self:Update()
    return true
end

-- just above the default set: for sets meant as a better Default
function Sets:MoveToBottom(set)
    set.settings.order = math.huge
    self:Renumber()
    ns:Fire("SetsChanged", set.name)
    self:Update()
end

function Sets:ValidateName(name, except)
    name = name and strtrim(name) or ""
    if name == "" or strfind(name, "^%$") then
        return false, L["Set name cannot be empty or begin with '$'."]
    end
    if name ~= except and rawget(ns.db.profile.sets, name) then
        return false, L["A set with this name already exists."]
    end
    return true
end

function Sets:Create(name)
    local ok, err = self:ValidateName(name)
    if not ok then return nil, false, err end
    name = strtrim(name)
    local settings = ns.db.profile.sets[name]   -- wildcard defaults create it
    settings.name = name
    settings.order = 0                            -- a new set goes to the top of the list
    local set = newSet(name)
    self:Renumber()
    ns:Fire("SetsChanged", name)
    self:Update()
    return set, true
end

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = deepCopy(x) end
    return c
end

-- a copy right below the original, named "<name> copy" (then "<name> copy 2"...)
function Sets:Duplicate(set)
    if set.deleted then return nil end
    local base = format(L["%s copy"], set:DisplayName())
    local name, i = base, 2
    while rawget(ns.db.profile.sets, name) do name, i = base .. " " .. i, i + 1 end
    local new = self:Create(name)
    local st = new.settings
    for k, v in pairs(set.settings) do
        if k ~= "name" and k ~= "order" and k ~= "trigger" then st[k] = deepCopy(v) end
    end
    if set:IsDefault() then
        -- the copy follows Default rather than pinning its timer and message
        st.priority, st.switchMinutes, st.switchCitiesOnly, st.announce = nil, nil, nil, nil
    end
    for _, e in ipairs(set.settings.trigger or {}) do st.trigger[#st.trigger + 1] = deepCopy(e) end
    st.order = (set:IsDefault() and math.huge) or ((set.settings.order or 0) + 0.5)
    self:Renumber()
    new:ConditionsChanged()
    return new
end

function Sets:Reload()
    for _, set in pairs(cache) do
        if set.watcher then set.watcher:Free() end
        set.deleted = true
    end
    wipe(cache)
    for _, t in pairs(pauseTimers) do t:Cancel() end
    wipe(pauseTimers)
    current = nil
    rawget(ns.db.profile.sets, Sets.DEFAULT)
    -- give 1.x sets (priority only) their place in the order; restart timed pauses
    self:Renumber()
    for _, set in ipairs(self:List()) do schedulePauseEnd(set) end
    ns:Fire("SetsChanged", nil)
    self:Update()
end

function Sets:GetCurrent() return current end

function Sets:Update()
    local best
    for _, set in ipairs(self:List()) do
        if set:IsActive() then best = set break end
    end
    if best ~= current then
        current = best
        ns:Fire("CurrentSetChanged", current)
        if current and current.settings.immediate and ns.Summon then
            ns.Summon:OnImmediateSet(current)
        end
    end
end

function Sets:OnInitialize()
    ns:RegisterCallback(self, "ProfileChanged", function() Sets:Reload() end)
    ns:RegisterCallback(self, "PetsChanged", function()
        for _, set in pairs(cache) do set.dirty = true end
        Sets:Update()
    end)
end

function Sets:OnEnable() self:Reload() end
