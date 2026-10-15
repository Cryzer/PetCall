local _, ns = ...

local L = ns.L
local pairs, ipairs, rawget, wipe, sort, strfind, strtrim = pairs, ipairs, rawget, wipe, table.sort, strfind, strtrim

local Sets = ns:NewModule("Sets")
ns.Sets = Sets
Sets.DEFAULT = "$Default"

local cache = {}          -- name -> set object
local current

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
    self.name = name
    self.settings.name = name
    changed(self)
    return true
end

function SetMixin:Delete()
    if self:IsDefault() then return false, L["The default set cannot be deleted."] end
    ns.db.profile.sets[self.name] = nil
    cache[self.name] = nil
    if self.watcher then self.watcher:Free() self.watcher = nil end
    self.deleted = true
    ns:Fire("SetsChanged", self.name)
    Sets:Update()
    return true
end

function SetMixin:SetEnabled(v)
    if self:IsDefault() then return end
    self.settings.enabled = v and true or false
    changed(self)
end

function SetMixin:SetPriority(w) if not self:IsDefault() then self.settings.priority = w changed(self) end end
function SetMixin:SetImmediate(v) self.settings.immediate = v and true or nil changed(self) end
function SetMixin:SetDefaultWeight(w) self.settings.defaultValue = w changed(self) end

function SetMixin:GetPetWeight(petID) return ns.Weights.PetWeight(self.settings, petID) end
function SetMixin:HasManualWeight(petID) return rawget(self.settings.pets, petID) ~= nil end
function SetMixin:SetPetWeight(petID, w) self.settings.pets[petID] = w changed(self) end
function SetMixin:SetPetWeights(petIDs, w)
    for _, id in ipairs(petIDs) do self.settings.pets[id] = w end
    changed(self)
end
function SetMixin:ClearPetWeights() wipe(self.settings.pets) changed(self) end

function SetMixin:GetAutoWeight(petID)
    local sum = 0
    for _, e in ipairs(self.settings.filter or {}) do
        if ns.AutoRules.Match(e, petID) then sum = sum + ns.AutoRules.Weight(e) end
    end
    return sum
end

function SetMixin:GetAutoRules() return ns.AutoRules.ToChips(self.settings.filter) end
function SetMixin:FiltersChanged() changed(self) end

function SetMixin:GetWeightTable()
    if self.dirty or not self.weights then
        self.weights = ns.Weights.Build(self.settings, self.weights)
        self.dirty = false
    end
    return self.weights
end

function SetMixin:GetChance(petID)
    local chance = ns.Weights.Chance(self:GetWeightTable(), petID)
    local reason
    if (C_PetJournal.GetPetCooldownByGUID(petID) or 0) > 0 then
        reason = L["On cooldown"]
    elseif not C_PetJournal.PetIsSummonable(petID) then
        reason = L["Cannot be summoned"]
    end
    return chance, reason
end

function SetMixin:PickPet() return ns.Weights.Pick(self:GetWeightTable(), fastrandom()) end
function SetMixin:Contains(petID) return ns.Weights.Sum(self:GetWeightTable(), petID) > 0 end

function SetMixin:HasConditions()
    return not self:IsDefault() and self.settings.trigger ~= nil and #self.settings.trigger > 0
end

function SetMixin:ConditionsMet()
    if self:IsDefault() or not self.watcher then return true end
    return self.watcher.value
end

function SetMixin:IsActive()
    if self.deleted or not self.settings.enabled then return false end
    if not self:ConditionsMet() then return false end
    return self:GetWeightTable().total > 0
end

function SetMixin:GetPriority()
    return self:IsDefault() and -1 or (self.settings.priority or 1)
end

function SetMixin:GetStatus()
    if not self.settings.enabled then return "disabled" end
    if self:GetWeightTable().total <= 0 then return "empty" end
    if current == self then return "active" end
    if not self:IsDefault() and not self:HasConditions() then return "noConditions" end
    return "waiting"
end

--
-- Collection
--

local function newSet(name)
    local set = setmetatable({ name = name, settings = ns.db.profile.sets[name], dirty = true }, SetMixin)
    cache[name] = set
    if ns.Conditions and not set:IsDefault() then
        set.watcher = ns.Conditions.NewWatcher(set.settings.trigger, function() Sets:Update() end)
    end
    return set
end

function Sets:Get(name)
    if cache[name] then return cache[name] end
    if rawget(ns.db.profile.sets, name) then return newSet(name) end
end

function Sets:List()
    local out = {}
    for name in pairs(ns.db.profile.sets) do
        out[#out + 1] = self:Get(name)
    end
    sort(out, function(a, b)
        if a:IsDefault() ~= b:IsDefault() then return a:IsDefault() end
        if a:GetPriority() ~= b:GetPriority() then return a:GetPriority() > b:GetPriority() end
        return a.name < b.name
    end)
    return out
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
    local set = newSet(name)
    ns:Fire("SetsChanged", name)
    self:Update()
    return set, true
end

function Sets:Reload()
    for _, set in pairs(cache) do
        if set.watcher then set.watcher:Free() end
    end
    wipe(cache)
    current = nil
    rawget(ns.db.profile.sets, Sets.DEFAULT)
    ns:Fire("SetsChanged", nil)
    self:Update()
end

function Sets:GetCurrent() return current end

function Sets:Update()
    local best
    for _, set in ipairs(self:List()) do
        if set:IsActive() and (not best or set:GetPriority() > best:GetPriority()) then
            best = set
        end
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
