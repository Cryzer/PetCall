local _, ns = ...

local L = ns.L
local GetTime, HasFullControl, InCombatLockdown, IsFalling, IsFlying, IsInInstance, IsResting, IsStealthed,
    UnitCastingInfo, UnitChannelInfo, UnitIsDeadOrGhost, UnitInVehicle, IsMounted, UnitIsAFK =
    GetTime, HasFullControl, InCombatLockdown, IsFalling, IsFlying, IsInInstance, IsResting, IsStealthed,
    UnitCastingInfo, UnitChannelInfo, UnitIsDeadOrGhost, UnitInVehicle, IsMounted, UnitIsAFK
local pairs, ipairs, next, sort, tconcat, tinsert = pairs, ipairs, next, table.sort, table.concat, table.insert

local Ready = ns:NewModule("Ready")
ns.Ready = Ready

local INVIS_SPELLS = { 66, 11392, 3680 }
local CAMO_SPELLS = { 198783, 199483 }
local FOOD_SPELLS = { 430, 433, 167152, 160598, 160599 }

local BLOCKER_ORDER = {
    "addon_enabled", "have_pets", "combat", "alive", "flying", "vehicle", "stealthed", "invisible", "camo",
    "feigned", "sitting", "casting", "looting", "barbar", "thunderisle_saurok", "in_battleground", "in_pve",
    "resting", "near_pew", "addon_ready",
}
local LABELS = {
    addon_enabled = L["Auto-summon is off"], have_pets = L["No pets"], combat = L["In combat"],
    alive = L["Dead"], flying = L["Flying"], vehicle = L["In a vehicle"], stealthed = L["Stealthed"],
    invisible = L["Invisible"], camo = L["Camouflaged"], feigned = L["Feigning death"], sitting = L["Sitting"],
    casting = L["Casting"], looting = L["Looting"], barbar = L["At the barber"], thunderisle_saurok = L["Transformed"],
    in_battleground = L["In a battleground or arena"], in_pve = L["In a dungeon or raid"],
    resting = L["Outside a city"], near_pew = L["Waiting for a zone change"], addon_ready = L["Loading"],
}

local function PlayerHasAura(id) return C_UnitAuras.GetPlayerAuraBySpellID(id) ~= nil end
local function PlayerHasAuraInList(list)
    for _, id in ipairs(list) do if PlayerHasAura(id) then return true end end
    return false
end

function Ready:OnInitialize()
    self.is_true, self.is_false, self.is_irrelevant, self.dismiss_on = {}, { addon_ready = true }, {}, {}
    self.last_spell_sent = 0

    self:RegisterEvent("COMPANION_UPDATE")
    self:RegisterEvent("UPDATE_STEALTH")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("BARBER_SHOP_CLOSE")
    self:RegisterEvent("BARBER_SHOP_OPEN")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("LOOT_CLOSED")
    self:RegisterEvent("PLAYER_ALIVE")
    self:RegisterEvent("PLAYER_DEAD")
    self:RegisterEvent("PLAYER_UNGHOST")
    self:RegisterEvent("CONFIRM_XP_LOSS")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("PLAYER_STARTED_MOVING")
    self:RegisterEvent("PLAYER_FLAGS_CHANGED")
    self:RegisterEvent("UI_ERROR_MESSAGE")
    self:RegisterUnitEvent("UNIT_AURA", "player")
    self:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    for _, e in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED" }) do
        self:RegisterUnitEvent(e, "player", "SpellCastUpdate")
    end
    self:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    self:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")

    self:UpdateChecks()
    ns:RegisterCallback(self, "ProfileChanged", function()
        Ready:UpdateChecks()
        Ready:SetReady("addon_enabled", ns.db.profile.enable)
    end)
    ns:RegisterCallback(self, "PetsChanged", function() Ready:PetListUpdated() end)
    ns:RegisterCallback(self, "AutoSummonChanged", function(_, v) Ready:SetReady("addon_enabled", v) end)
end

function Ready:OnEnable()
    self:PetListUpdated()
    self.ticker = ns:NewTicker(0.5, function() Ready:FrequentCheck() end)
    self:SetReady("addon_enabled", ns.db.profile.enable)
    self:SetReady("combat", not InCombatLockdown())
    self:SetReady("resting", IsResting())
    self:SetReady("alive", not UnitIsDeadOrGhost("player"))
    self:SetReady("in_battleground", not ns.InBattlegroundOrArena())
    self:SetReady("vehicle", not UnitInVehicle("player"))
    self:SetReady("flying", not IsFlying())
    self:UNIT_AURA(nil, "player")
    self:UPDATE_STEALTH()
    self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", "CheckFlying")
    self:SetReady("addon_ready", true)
    self:PLAYER_ENTERING_WORLD()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    hooksecurefunc("JumpOrAscendStart", function() Ready:SetReady("sitting", true) end)
    hooksecurefunc("SitStandOrDescendStart", function()
        if not IsFlying() and not IsMounted() then
            Ready:ToggleReady("sitting")
            Ready._sit_move_lock = Ready.is_false.sitting and (GetTime() + 3) or nil
        end
    end)
    local function onSendChat(msg, chatType)
        if chatType == "AFK" then Ready.afk_message = msg end
    end
    if C_ChatInfo and C_ChatInfo.SendChatMessage then hooksecurefunc(C_ChatInfo, "SendChatMessage", onSendChat) end
    if type(SendChatMessage) == "function" then hooksecurefunc("SendChatMessage", onSendChat) end
end

function ns.InBattlegroundOrArena()
    local _, t = IsInInstance()
    return t == "pvp" or t == "arena"
end

function ns.InInstanceOrRaid()
    local _, t = IsInInstance()
    return t == "party" or t == "raid"
end

function Ready:UpdateChecks()
    local p = ns.db.profile
    self:EnableCheck("addon_ready", true)
    self:EnableCheck("combat", true)
    self:EnableCheck("in_battleground", p.dismissInBattleground or not p.enableInBattleground, p.dismissInBattleground)
    self:EnableCheck("in_pve", p.dismissInPVE or not p.enableInPVE, p.dismissInPVE)
    self:EnableCheck("resting", p.disableOutsideCities)
    self:EnableCheck("stealthed", true, p.dismissWhenStealthed)
    self:EnableCheck("invisible", true, p.dismissWhenStealthed)
    self:EnableCheck("flying", true)
    self:EnableCheck("near_pew", p.nearPEWOnly)
    self:EnableCheck("alive", true)
    self:EnableCheck("camo", true, p.dismissWhenStealthed)
    self:EnableCheck("casting", true)
    self:EnableCheck("have_pets", true)
    self:EnableCheck("barbar", true)
    self:EnableCheck("thunderisle_saurok", true)
    self:EnableCheck("sitting", true)
    self:EnableCheck("feigned", true, p.dismissWhenStealthed)
    self:EnableCheck("looting", true)
    self:EnableCheck("vehicle", true)
    self:EnableCheck("addon_enabled", true)
    if ns.SpecialItems then ns.SpecialItems:UpdateReadyEnabled() end
    self:_Changed()
    self:_CheckSummon()
end

function Ready:EnableCheck(name, enabled, dismiss)
    local v = true
    if self.is_irrelevant[name] ~= nil then
        v = self.is_irrelevant[name]
        self.is_irrelevant[name] = nil
    elseif self.is_true[name] then
        self.is_true[name] = nil
    elseif self.is_false[name] then
        v = false
        self.is_false[name] = nil
    end
    if enabled then
        if v then self.is_true[name] = true else self.is_false[name] = true end
        self.dismiss_on[name] = dismiss and true or nil
    else
        self.is_irrelevant[name] = v
    end
end

function Ready:_Changed() ns:Fire("ReadyChanged") end

function Ready:SetReady(name, value)
    if value then
        if self.is_false[name] then
            self.is_false[name], self.is_true[name] = nil, true
            self:_Changed()
            self:_CheckSummon()
            return
        elseif self.is_true[name] then
            return
        end
    else
        if self.is_true[name] then
            self.is_true[name], self.is_false[name] = nil, true
            self:_Changed()
            self:_CheckUn(name)
            return
        elseif self.is_false[name] then
            return
        end
    end
    self.is_irrelevant[name] = not not value
end

function Ready:ToggleReady(name) self:SetReady(name, self.is_false[name] and true or false) end

function Ready:IsReady() return next(self.is_false) == nil end

function Ready:LastCheck()
    return not IsFalling() and HasFullControl() and GetTime() - self.last_spell_sent > 1.5
end

function Ready:_CheckSummon(waitFinished)
    if next(self.is_false) then return end
    if ns:GetCurrentPet() and not self.force then return end
    if waitFinished then
        if self:LastCheck() then
            self.force = false
            self._last_summon_time = GetTime()
            if ns.Summon and ns.Summon.SummonRandom then ns.Summon:SummonRandom() end
            ns:After(2, function() Ready:_CheckSummon() end)
            return
        end
    elseif self.wait_timer then
        return
    end
    self.wait_counter = 0
    if self.wait_timer then self.wait_timer:Cancel() end   -- a forced check may arrive while one is waiting
    self.wait_timer = ns:NewTicker(0.5, function() Ready:WaitTimerProgress() end)
end

function Ready:_CheckUn(name)
    if self.dismiss_on[name] and ns.db.profile.enable and not InCombatLockdown() and ns.Summon then
        ns.Summon:Dismiss(false, true)
    end
    if self.wait_timer then
        self.wait_timer:Cancel()
        self.wait_timer = nil
    end
end

function Ready:WaitTimerProgress()
    self.wait_counter = self.wait_counter + 0.5
    if self.wait_counter >= ns.db.profile.waitTimer then
        self.wait_timer:Cancel()
        self.wait_timer = nil
        self:_CheckSummon(true)
    elseif not self:LastCheck() then
        self.wait_counter = 0
    end
end

function Ready:QueueResummon(nowait)
    self.force = true
    self:_CheckSummon(nowait)
end

function Ready:PetListUpdated() self:SetReady("have_pets", ns.PetCache:NumPets() > 0) end
function Ready:CheckFlying() self:SetReady("flying", not IsFlying()) end

function Ready:FrequentCheck()
    self:SetReady("flying", not IsFlying())
    local petID = ns:GetCurrentPet()
    if not petID and petID ~= self._lastPet then self:_CheckSummon() end
    self._lastPet = petID
end

function Ready:PLAYER_ENTERING_WORLD()
    local _, instanceType = IsInInstance()
    self:SetReady("in_pve", not (IsInGroup() and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario")))
    if not self.near_pew_handle then
        self:SetReady("near_pew", true)
        self.near_pew_handle = ns:After(6 + (ns.db.profile.waitTimer or 1), function()
            Ready:SetReady("near_pew", false)
            Ready.near_pew_handle = nil
        end)
    end
end

function Ready:COMPANION_UPDATE(_, ctype)
    if ctype == "CRITTER" then
        ns:Fire("SummonedPetChanged")
        self:_CheckSummon()
    end
end
function Ready:BARBER_SHOP_OPEN() self:SetReady("barbar", false) end
function Ready:BARBER_SHOP_CLOSE() self:SetReady("barbar", true) end
function Ready:LOOT_OPENED() self:SetReady("looting", false) end
function Ready:LOOT_CLOSED() self:SetReady("looting", true) end
function Ready:PLAYER_ALIVE() self:SetReady("alive", not UnitIsDeadOrGhost("player")) end
function Ready:PLAYER_DEAD() self:SetReady("alive", false) end
function Ready:PLAYER_UNGHOST() self:SetReady("alive", true) end
function Ready:CONFIRM_XP_LOSS() self:SetReady("alive", true) end
function Ready:PLAYER_REGEN_DISABLED() self:SetReady("combat", false) end
function Ready:PLAYER_REGEN_ENABLED() self:SetReady("combat", true) end
function Ready:ZONE_CHANGED_NEW_AREA() self:SetReady("in_battleground", not ns.InBattlegroundOrArena()) end
function Ready:UNIT_ENTERED_VEHICLE() self:SetReady("vehicle", false) end
function Ready:UNIT_EXITED_VEHICLE() self:SetReady("vehicle", true) end

function Ready:UPDATE_STEALTH()
    self:SetReady("stealthed", not (IsStealthed() and not PlayerHasAuraInList(CAMO_SPELLS)))
end

function Ready:UNIT_AURA(_, unit, info)
    if unit ~= "player" then return end
    if info and not info.isFullUpdate and not info.addedAuras and not info.removedAuraInstanceIDs then return end
    self:SetReady("invisible", not PlayerHasAuraInList(INVIS_SPELLS))
    self:SetReady("camo", not PlayerHasAuraInList(CAMO_SPELLS))
    self:SetReady("thunderisle_saurok", not PlayerHasAura(136461))
    if PlayerHasAuraInList(FOOD_SPELLS) then self:SetReady("sitting", false) end
    self:SetReady("feigned", not PlayerHasAura(5384))
end

function Ready:UNIT_SPELLCAST_SENT(event, unit)
    self.last_spell_sent = GetTime()
    self:SpellCastUpdate(event, unit)
end

function Ready:SpellCastUpdate()
    self:SetReady("casting", not (UnitCastingInfo("player") or UnitChannelInfo("player")))
end

function Ready:PLAYER_STARTED_MOVING()
    if self._sit_move_lock and GetTime() < self._sit_move_lock then return end
    self._last_summon_time = nil
    self:SetReady("sitting", true)
end

function Ready:UI_ERROR_MESSAGE(_, _, message)
    if (message == ERR_MUST_BE_STANDING or message == SPELL_FAILED_NOT_STANDING)
        and self._last_summon_time and GetTime() - self._last_summon_time < 3 then
        self:SetReady("sitting", false)
    end
end

function Ready:PLAYER_FLAGS_CHANGED(_, unit)
    if unit and unit ~= "player" then return end
    self:SetReady("resting", IsResting())
    if UnitIsAFK("player") and self.afk_message == nil then self:SetReady("sitting", false) end
    self.afk_message = nil
end

function Ready:GetBlockers()
    local out, seen = {}, {}
    for _, key in ipairs(BLOCKER_ORDER) do
        if self.is_false[key] then
            out[#out + 1] = { key = key, label = LABELS[key] }
            seen[key] = true
        end
    end
    for key in pairs(self.is_false) do
        if not seen[key] then
            local name = ns.SpecialItems and ns.SpecialItems:LocalizeString(key) or key
            out[#out + 1] = { key = key, label = format(L["Using %s"], name) }
        end
    end
    return out
end

function Ready:DumpDebugState()
    local ready, notReady = {}, {}
    for k in pairs(self.is_true) do ready[#ready + 1] = k end
    for k in pairs(self.is_false) do notReady[#notReady + 1] = k end
    sort(ready) sort(notReady)
    ns:Printf("Ready: %s", tconcat(ready, " "))
    ns:Printf("Not Ready: %s", tconcat(notReady, " "))
    -- every step "Summon another" goes through, for bug reports
    local set = ns.Sets:GetCurrent()
    local tbl = set and set:GetWeightTable()
    ns:Printf("Set: %s, draw entries %d, total %s", set and set.name or "none", tbl and #tbl / 2 or 0, tbl and tostring(tbl.total) or "-")
    local cur = ns:GetCurrentPet()
    local pick = set and set:PickPet(cur)
    ns:Printf("Pet out: %s, next pick: %s", tostring(cur), tostring(pick))
    if pick then
        local start, duration = C_PetJournal.GetPetCooldownByGUID(pick)
        ns:Printf("Pick cooldown: start %s, duration %s, now %.1f, blocked %s, summonable %s", tostring(start), tostring(duration),
            GetTime(), tostring(ns.PetCache:OnCooldown(pick)), tostring(C_PetJournal.PetIsSummonable(pick)))
    end
    ns:Printf("Falling %s, full control %s, since last cast %.1f s, waiting %s, forced %s", tostring(IsFalling()), tostring(HasFullControl()),
        GetTime() - self.last_spell_sent, tostring(self.wait_timer ~= nil), tostring(self.force))
end
