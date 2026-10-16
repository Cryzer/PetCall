local _, ns = ...

local L = ns.L
local C_PetJournal, InCombatLockdown, tinsert = C_PetJournal, InCombatLockdown, tinsert

local Summon = ns:NewModule("Summon")
ns.Summon = Summon

local RECENT_MAX = 5

function ns:GetCurrentPet() return C_PetJournal.GetSummonedPetGUID() end
function ns:IsAutoSummon() return ns.db.profile.enable end

function ns:SetAutoSummon(v)
    v = v and true or false
    if ns.db.profile.enable == v then return end
    ns.db.profile.enable = v
    ns:Fire("AutoSummonChanged", v)
end

local function remember(petID)
    local r = ns.db.global.recentPets
    for i = #r, 1, -1 do if r[i] == petID then table.remove(r, i) end end
    tinsert(r, 1, petID)
    while #r > RECENT_MAX do table.remove(r) end
end

function ns:GetRecentPets()
    local out = {}
    for _, id in ipairs(ns.db.global.recentPets) do
        if ns.PetCache:Contains(id) then out[#out + 1] = id end
    end
    return out
end

-- the set's own choice wins over the setting
local function announce()
    local set = ns.Sets:GetCurrent()
    local own = set and set.settings.announce
    if own == "on" then return true end
    if own == "off" then return false end
    return ns.db.profile.verbose
end

local function doSummon(petID)
    if announce() then
        local info = ns.PetCache:GetInfo(petID)
        ns:Printf(L["SUMMONING_MSG"], info and (info.customName or info.name) or "?")
    end
    C_PetJournal.SummonPetByGUID(petID)
    remember(petID)
    ns.SwitchTimer:Start()
end

function Summon:SummonRandom()
    local set = ns.Sets:GetCurrent()
    if set and set:IsNoPet() then return false end
    -- never "summon" the pet that is already out: that would dismiss it
    local petID = set and set:PickPet(ns:GetCurrentPet())
    if not petID then return false end
    if ns.PetCache:OnCooldown(petID) then return false end
    doSummon(petID)
    return true
end

-- explicit pick (menu, preview, grid): the game would fail silently, so say why
function ns:SummonPet(petID)
    if not petID or ns:GetCurrentPet() == petID then return end
    local info = ns.PetCache:GetInfo(petID)
    local name = info and (info.customName or info.name) or "?"
    if ns.PetCache:OnCooldown(petID) then
        return ns:Printf(L["%s is on cooldown."], name)
    end
    if not C_PetJournal.PetIsSummonable(petID) then
        return ns:Printf(L["%s cannot be summoned right now."], name)
    end
    doSummon(petID)
end

function Summon:Dismiss(disable, verify)
    local cur = ns:GetCurrentPet()
    if cur then
        C_PetJournal.SummonPetByGUID(cur)
        if verify then
            if self.verify then self.verify:Cancel() end
            self.verify = ns:NewTicker(0.3, function()
                if ns:GetCurrentPet() == cur then
                    if not InCombatLockdown() then C_PetJournal.SummonPetByGUID(cur) end
                else
                    Summon.verify:Cancel()
                    Summon.verify = nil
                end
            end)
        end
    end
    if disable then ns:SetAutoSummon(false) end
end

function Summon:OnImmediateSet(set)
    if set:IsNoPet() then return end
    if set.settings.alwaysNew or not set:Contains(ns:GetCurrentPet()) then ns.Ready:QueueResummon() end
end

-- Compatibility API (Bindings.xml and 1.x macros call these on the global)
function ns:ResummonPet(enable, nowait)
    if enable then ns:SetAutoSummon(true) end
    ns.Ready:QueueResummon(nowait)
end
function ns:DismissPet(disable) Summon:Dismiss(disable) end
function ns:TogglePet()
    if ns:GetCurrentPet() then Summon:Dismiss(true) else ns:ResummonPet(true, true) end
end
function ns:OpenOptions() ns:OpenWindow() end

-- explicit request (button, menu, key binding): say why nothing happens instead of failing silently
function ns:SummonAnother()
    local set = ns.Sets:GetCurrent()
    if set and not set:PickPet(ns:GetCurrentPet()) then
        ns:Printf(L["No other pet to choose from in %s."], set:DisplayName())
        return
    end
    local blockers = ns.Ready:GetBlockers()
    if #blockers > 0 then
        local labels = {}
        for _, b in ipairs(blockers) do labels[#labels + 1] = b.label end
        ns:Printf(L["A pet will be summoned when this ends: %s."], table.concat(labels, ", "))
    end
    ns:ResummonPet(true, true)
end
function ns:Dismiss() Summon:Dismiss(true) end
function ns:Toggle() ns:TogglePet() end

function Summon:OnInitialize()
    hooksecurefunc(C_PetJournal, "SetPetLoadOutInfo", function(slot)
        if ns.db.profile.overrideSetLoadout and slot == 1 then ns:ResummonPet() end
    end)
end
