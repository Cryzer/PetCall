local _, ns = ...

local L = ns.L
local C_PetJournal, GetTime, InCombatLockdown, tinsert = C_PetJournal, GetTime, InCombatLockdown, tinsert
local UIErrorsFrame = UIErrorsFrame

local Summon = ns:NewModule("Summon")
ns.Summon = Summon

local RECENT_MAX = 5

function ns:GetCurrentPet() return C_PetJournal.GetSummonedPetGUID() end
function ns:IsAutoSummon() return ns.db.profile.enable end

local paused = false

function ns:SetAutoSummon(v)
    v = v and true or false
    if ns.db.profile.enable == v then return end
    ns.db.profile.enable, paused = v, false
    ns:Fire("AutoSummonChanged", v)
end

-- On, Off (the saved switch), or Paused until you change zone (your own dismissal; not saved)
function ns:GetAutoState()
    if not ns:IsAutoSummon() then return "off" end
    return paused and "paused" or "on"
end

function ns:PauseAuto()
    if paused or not ns:IsAutoSummon() then return end
    paused = true
    ns:Fire("AutoSummonChanged", true)
end

function ns:ResumeAuto()
    if not paused then return end
    paused = false
    ns:Fire("AutoSummonChanged", ns:IsAutoSummon())
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

local function announce()
    local set = ns.Sets:GetCurrent()
    return set and (set:GetAnnounce())
end

-- what PetCall expects out after its own call (false: no pet), so Ready can tell your own
-- summons and dismissals outside PetCall from PetCall's
local function summonByGUID(guid, outcome)
    Summon.expect = { pet = outcome, at = GetTime() }
    -- the game's red "must be standing" error is no use when PetCall tries by itself (out of
    -- combat, when nothing says you sit); Ready learns of it from its own listener
    if not InCombatLockdown() and not ns.Ready.is_false.sitting then
        UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
        ns:After(0, function() UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE") end)
    end
    C_PetJournal.SummonPetByGUID(guid)
end

-- pick: you chose this pet yourself, so a set that starts keeps it
local function doSummon(petID, pick)
    if announce() then
        local info = ns.PetCache:GetInfo(petID)
        ns:Printf(L["SUMMONING_MSG"], info and (info.customName or info.name) or "?")
    end
    summonByGUID(petID, petID)
    Summon.manualPick = pick and petID or nil
    remember(petID)
    ns.SwitchTimer:Start()
end

function Summon:SummonRandom()
    local set = ns.Sets:GetCurrent()
    -- never "summon" the pet that is already out: that would dismiss it
    local petID = set and set:PickPet(ns:GetCurrentPet())
    if not petID then return false end
    if ns.PetCache:OnCooldown(petID) then return false end
    doSummon(petID)
    return true
end

-- a pick that waited for the game
function Summon:SummonPick(petID)
    if ns:GetCurrentPet() == petID or ns.PetCache:OnCooldown(petID) then return false end
    doSummon(petID, true)
    return true
end

-- explicit summon: ends a pause, says once what it waits for or goes past, then asks Ready
local function summonExplicit(petID)
    ns:ResumeAuto()
    local ok, cause = ns.Gate:Check("summon", "explicit")
    if not ok then
        if cause.key == "sitting" then
            ns:Printf(L["Stand up and your pet comes out."])
        else
            ns:Printf(L["Your pet comes out when this ends: %s."], cause.label)
        end
    end
    local choice, exc = ns.Exceptions:Strongest()
    if choice == "away" then
        ns:Printf(L["%s usually puts your pet away."], exc:DisplayName())
    elseif choice == "alone" then
        ns:Printf(L["%s usually leaves your pet alone."], exc:DisplayName())
    end
    ns.Ready:Request("summon", "explicit", petID)
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
    summonExplicit(petID)
end

function Summon:Dismiss(verify)
    local cur = ns:GetCurrentPet()
    if not cur then return end
    summonByGUID(cur, false)
    if verify then
        if self.verify then self.verify:Cancel() end
        self.verify = ns:NewTicker(0.3, function()
            if ns:GetCurrentPet() == cur then
                if not InCombatLockdown() then summonByGUID(cur, false) end
            else
                Summon.verify:Cancel()
                Summon.verify = nil
            end
        end)
    end
end

-- a pet you picked yourself stays; the set's timer and a new map still replace it
function Summon:OnImmediateSet(set)
    local cur = ns:GetCurrentPet()
    if cur and cur == self.manualPick then return end
    if set.settings.alwaysNew or not set:Contains(cur) then ns.Ready:Request("switch", "auto") end
end

-- Compatibility API (Bindings.xml and 1.x macros call these on the global)
function ns:ResummonPet() summonExplicit() end
-- your dismissal pauses Auto-summon until you change zone; Off stays Off
local function dismissExplicit()
    ns.Ready:CancelRequest()
    Summon:Dismiss()
    ns:PauseAuto()
end
function ns:DismissPet() dismissExplicit() end
function ns:TogglePet()
    if ns:GetCurrentPet() then dismissExplicit() else summonExplicit() end
end
function ns:OpenOptions() ns:OpenWindow() end

-- explicit request (button, menu, key binding): say why nothing happens instead of failing silently
function ns:SummonAnother()
    local set = ns.Sets:GetCurrent()
    if set and not set:PickPet(ns:GetCurrentPet()) then
        ns:ResumeAuto()
        ns:Printf(L["No other pet to choose from in %s."], set:DisplayName())
        return
    end
    summonExplicit()
end
function ns:Dismiss() dismissExplicit() end
function ns:Toggle() ns:TogglePet() end

function Summon:ZONE_CHANGED_NEW_AREA() ns:ResumeAuto() end
function Summon:PLAYER_ENTERING_WORLD() ns:ResumeAuto() end

function Summon:OnInitialize()
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    hooksecurefunc(C_PetJournal, "SetPetLoadOutInfo", function(slot)
        if ns.db.profile.overrideSetLoadout and slot == 1 then ns.Ready:Request("summon", "auto") end
    end)
end
