local _, ns = ...

local L = ns.L
local GetTime, HasFullControl, InCombatLockdown, IsFalling, IsFlying, IsStealthed,
    UnitCastingInfo, UnitChannelInfo, UnitIsDeadOrGhost, UnitInVehicle, IsMounted, UnitIsAFK =
    GetTime, HasFullControl, InCombatLockdown, IsFalling, IsFlying, IsStealthed,
    UnitCastingInfo, UnitChannelInfo, UnitIsDeadOrGhost, UnitInVehicle, IsMounted, UnitIsAFK
local pairs, ipairs, next, sort, tconcat = pairs, ipairs, next, table.sort, table.concat

local Ready = ns:NewModule("Ready")
ns.Ready = Ready

local INVIS_SPELLS = { 66, 11392, 3680 }
local CAMO_SPELLS = { 198783, 199483 }
local FOOD_SPELLS = { 430, 433, 167152, 160598, 160599 }

-- blockers that take the pet away (unlike sitting or casting); seconds that tie a pet
-- that went to one starting, and to PetCall's own call
local TAKES_PET = { alive = true, vehicle = true, pet_battle = true }
local TAKEN_WINDOW, EXPECT_WINDOW = 1.5, 3

-- game blockers only: what the game itself does not allow, or a summon would break
local BLOCKER_ORDER = {
    "have_pets", "combat", "alive", "flying", "vehicle", "stealthed", "invisible", "camo",
    "feigned", "sitting", "casting", "looting", "barbar", "thunderisle_saurok", "pet_battle", "addon_ready",
}
local LABELS = {
    have_pets = L["No pets"], combat = L["In combat"],
    alive = L["Dead"], flying = L["Flying"], vehicle = L["In a vehicle"], stealthed = L["Stealthed"],
    invisible = L["Invisible"], camo = L["Camouflaged"], feigned = L["Feigning death"], sitting = L["Sitting"],
    casting = L["Casting"], looting = L["Looting"], barbar = L["At the barber"], thunderisle_saurok = L["Transformed"],
    pet_battle = L["In a pet battle"], addon_ready = L["Loading"],
}

-- 12.x hides some values from addons in combat ("secret" values): any test on one
-- is an error, so they are checked first and treated as unknown
local function isSecret(v) return issecretvalue ~= nil and issecretvalue(v) end

local function PlayerHasAura(id)
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if isSecret(aura) then return false end
    return aura ~= nil
end
local function PlayerHasAuraInList(list)
    for _, id in ipairs(list) do if PlayerHasAura(id) then return true end end
    return false
end

function Ready:OnInitialize()
    self.is_true, self.is_false, self.is_irrelevant = {}, { addon_ready = true }, {}
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
    self:RegisterEvent("PET_BATTLE_OPENING_START")
    self:RegisterEvent("PET_BATTLE_CLOSE")
    self:RegisterUnitEvent("UNIT_AURA", "player")
    self:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
    for _, e in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED" }) do
        self:RegisterUnitEvent(e, "player", "SpellCastUpdate")
    end
    self:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
    self:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")

    self:UpdateChecks()
    ns:RegisterCallback(self, "ProfileChanged", function() Ready:UpdateChecks() end)
    ns:RegisterCallback(self, "PetsChanged", function() Ready:PetListUpdated() end)
    -- the later levels of the order of decisions may have let go
    ns:RegisterCallback(self, "AutoSummonChanged", function()
        if ns:GetAutoState() ~= "on" then Ready.comeback = nil end
        Ready:_CheckSummon()
    end)
    ns:RegisterCallback(self, "ExceptionsChanged", function() Ready:_CheckSummon() end)
end

function Ready:OnEnable()
    self:PetListUpdated()
    self._petOut = ns:GetCurrentPet()
    self.ticker = ns:NewTicker(0.5, function() Ready:FrequentCheck() end)
    self:SetReady("combat", not InCombatLockdown())
    self:SetReady("alive", not UnitIsDeadOrGhost("player"))
    self:SetReady("vehicle", not UnitInVehicle("player"))
    self:SetReady("flying", not IsFlying())
    self:SetReady("pet_battle", not C_PetBattles.IsInBattle())
    self:UNIT_AURA(nil, "player")
    self:UPDATE_STEALTH()
    self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", "CheckFlying")
    self:SetReady("addon_ready", true)
    self:PLAYER_ENTERING_WORLD()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")

    hooksecurefunc("JumpOrAscendStart", function() Ready:SetReady("sitting", true) end)
    -- the key does both, so it toggles; the emotes say which way
    local function lockSitting() Ready._sit_move_lock = Ready.is_false.sitting and (GetTime() + 3) or nil end
    hooksecurefunc("SitStandOrDescendStart", function()
        if not IsFlying() and not IsMounted() then
            Ready:ToggleReady("sitting")
            lockSitting()
        end
    end)
    local function onEmote(token)
        if type(token) ~= "string" or IsFlying() or IsMounted() then return end
        token = token:upper()
        if token == "SIT" then
            Ready:SetReady("sitting", false)
            lockSitting()
        elseif token == "STAND" then
            Ready:SetReady("sitting", true)
        end
    end
    -- /sit typed in chat goes straight to C_ChatInfo.PerformEmote; addons may still call DoEmote
    hooksecurefunc("DoEmote", onEmote)
    if C_ChatInfo and C_ChatInfo.PerformEmote then hooksecurefunc(C_ChatInfo, "PerformEmote", onEmote) end
    local function onSendChat(msg, chatType)
        if chatType == "AFK" then Ready.afk_message = msg end
    end
    if C_ChatInfo and C_ChatInfo.SendChatMessage then hooksecurefunc(C_ChatInfo, "SendChatMessage", onSendChat) end
    if type(SendChatMessage) == "function" then hooksecurefunc("SendChatMessage", onSendChat) end
end

function Ready:UpdateChecks()
    for _, key in ipairs(BLOCKER_ORDER) do self:EnableCheck(key, true) end
    if ns.SpecialItems then ns.SpecialItems:UpdateReadyEnabled() end
    self:_Changed()
    self:_CheckSummon()
end

function Ready:EnableCheck(name, enabled)
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
    else
        self.is_irrelevant[name] = v
    end
end

function Ready:_Changed() ns:Fire("ReadyChanged") end

function Ready:SetReady(name, value)
    if isSecret(value) then return end
    -- for /pcall debugstate: what last said you sit or stand, and where from
    if name == "sitting" then
        self._sitLast = { at = GetTime(), value = value, from = debugstack and debugstack(2, 1, 0) or "?" }
    end
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

function Ready:LastCheck()
    return not IsFalling() and HasFullControl() and GetTime() - self.last_spell_sent > 1.5
end

-- runs the pending request, or brings out a pet when none is out, once the order of
-- decisions (Gate) lets it and the player stood still long enough
function Ready:_CheckSummon(waitFinished)
    local source = self.pending
    if not source then
        if ns:GetCurrentPet() then return end
        -- "Only after a loading screen": by itself a pet comes out only for a few seconds
        -- after one, or once to bring back a pet that PetCall or the game took away
        if ns.db.profile.nearPEWOnly and not self.zoning and not self.comeback then return end
    end
    local ok, cause = ns.Gate:Check("summon", source or "auto")
    if not ok then
        -- only the game and exceptions keep an automatic request waiting
        if source == "auto" and cause.level == "auto" then self.pending = nil end
        return
    end
    if waitFinished then
        if self:LastCheck() then
            local pick = self.pendingPet
            self._ranExplicit, self._ranPick = source == "explicit", pick
            if self.comeback then self._takenPet, self._takenPick = nil, nil end
            self.pending, self.pendingPet, self.comeback = nil, nil, nil
            if self.wait_timer then self.wait_timer:Cancel() self.wait_timer = nil end
            self._last_summon_time = GetTime()
            if pick then ns.Summon:SummonPick(pick) else ns.Summon:SummonRandom() end
            ns:After(2, function() Ready:_CheckSummon() end)
            return
        end
    elseif self.wait_timer then
        return
    end
    self.wait_counter = 0
    if self.wait_timer then self.wait_timer:Cancel() end   -- an explicit request may arrive while one is waiting
    self.wait_timer = ns:NewTicker(0.5, function() Ready:WaitTimerProgress() end)
end

function Ready:_CheckUn(name)
    if TAKES_PET[name] then self:_GameTook() end
    if self.wait_timer then
        self.wait_timer:Cancel()
        self.wait_timer = nil
    end
end

-- an explicit request does not wait for the player to stand still
function Ready:WaitTimerProgress()
    self.wait_counter = self.wait_counter + 0.5
    if self.wait_counter >= ns.db.profile.waitTimer or (self.pending == "explicit" and self:LastCheck()) then
        self.wait_timer:Cancel()
        self.wait_timer = nil
        self:_CheckSummon(true)
    elseif not self:LastCheck() then
        self.wait_counter = 0
    end
end

-- action: "summon" or "switch"; source: "explicit" (you) or "auto" (PetCall); petID: the pet
-- you picked, else one is drawn. At most one request waits, and yours replaces PetCall's own.
function Ready:Request(action, source, petID)
    if source == "explicit" then
        self.pending, self.pendingPet = source, petID
    elseif self.pending ~= "explicit" then
        self.pending = source
    end
    self:_CheckSummon(source == "explicit")
end

-- you dismissed: a request still waiting would go against that
function Ready:CancelRequest() self.pending, self.pendingPet = nil, nil end

function Ready:PetListUpdated() self:SetReady("have_pets", ns.PetCache:NumPets() > 0) end
function Ready:CheckFlying() self:SetReady("flying", not IsFlying()) end

function Ready:FrequentCheck()
    self:SetReady("flying", not IsFlying())
    local petID = ns:GetCurrentPet()
    if not petID and petID ~= self._lastPet then self:_CheckSummon() end
    self._lastPet = petID
end

function Ready:PLAYER_ENTERING_WORLD()
    self:_GameTook()
    self:OpenZoningWindow()
end

-- "Only after a loading screen": a few seconds after a loading screen or a new zone
function Ready:OpenZoningWindow()
    if self.zoning_handle then return end
    self.zoning = true
    self.zoning_handle = ns:After(6 + (ns.db.profile.waitTimer or 1), function()
        Ready.zoning, Ready.zoning_handle = false, nil
    end)
    self:_CheckSummon()
end

-- the game takes the pet on death, in a vehicle and on a loading screen: it comes back after.
-- A pet that went just before counts too, whichever event the game sends first.
function Ready:_GameTook()
    local now = GetTime()
    self._takenAt = now
    if self._vanishedAt and now - self._vanishedAt < TAKEN_WINDOW then
        self._vanishedAt = nil
        self._takenPet, self._takenPick = self._vanishedPet, self._vanishedPick
        ns:ResumeAuto()
        self.comeback = true
    end
end

local function gameTakes(self)
    if GetTime() - (self._takenAt or -TAKEN_WINDOW) < TAKEN_WINDOW then return true end
    for key in pairs(TAKES_PET) do
        if self.is_false[key] then return true end
    end
    return false
end

-- a change PetCall did not ask for is yours (Pet Journal, pet frame) or the game's
function Ready:_PetChanged(pet)
    local expect = ns.Summon.expect
    if expect and GetTime() - expect.at < EXPECT_WINDOW then
        local out = pet or false
        if out == expect.pet then
            ns.Summon.expect = nil
            self._takenPet, self._takenPick = nil, nil      -- PetCall's own call replaced it
            return
        end
        if not out then return end          -- no pet in between: a switch
    end
    if pet then
        if pet == self._takenPet then
            ns.Summon.manualPick = self._takenPick and pet or nil     -- the game put it back
        else
            ns.Summon.manualPick = pet
            ns:ResumeAuto()
        end
        self._takenPet = nil
        return
    end
    local gone = self._petOut
    local wasPick = gone ~= nil and ns.Summon.manualPick == gone
    if gameTakes(self) then
        self._takenPet, self._takenPick = gone, wasPick
        if ns:GetAutoState() == "on" then self.comeback = true end
    elseif ns:GetAutoState() == "on" then
        self._vanishedAt, self._vanishedPet, self._vanishedPick = GetTime(), gone, wasPick
        ns:PauseAuto()
    end
end

function Ready:COMPANION_UPDATE(_, ctype)
    if ctype ~= "CRITTER" then return end
    local pet = ns:GetCurrentPet()
    if pet then self.comeback = nil end
    if pet ~= self._petOut then self:_PetChanged(pet) end
    self._petOut = pet
    ns:Fire("SummonedPetChanged")
    self:_CheckSummon()
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
function Ready:PLAYER_REGEN_ENABLED()
    self:SetReady("combat", true)
    self:CheckAuras()       -- aura updates during combat may have been unreadable
end
function Ready:ZONE_CHANGED_NEW_AREA() self:OpenZoningWindow() end
function Ready:UNIT_ENTERED_VEHICLE() self:SetReady("vehicle", false) end
function Ready:UNIT_EXITED_VEHICLE() self:SetReady("vehicle", true) end

-- stealth, invisibility, camouflage and feign death for the "Hidden" condition
local hidden = { stealth = false, invisible = false, camo = false, feign = false }

local function setHidden(stealth, invisible, camo, feign)
    stealth, invisible, camo, feign = stealth and true or false, invisible and true or false, camo and true or false, feign and true or false
    if stealth == hidden.stealth and invisible == hidden.invisible and camo == hidden.camo and feign == hidden.feign then return end
    hidden.stealth, hidden.invisible, hidden.camo, hidden.feign = stealth, invisible, camo, feign
    ns:Fire("HiddenChanged")
end

function Ready:HiddenState() return hidden.stealth, hidden.invisible, hidden.camo, hidden.feign end

function Ready:UPDATE_STEALTH()
    local stealth = IsStealthed() and not PlayerHasAuraInList(CAMO_SPELLS)
    self:SetReady("stealthed", not stealth)
    setHidden(stealth, hidden.invisible, hidden.camo, hidden.feign)
end

function Ready:UNIT_AURA(_, unit, info)
    if unit ~= "player" then return end
    if info then
        -- a hidden payload (combat): leave it, combat blocks summoning and the auras
        -- are read again when it ends
        if isSecret(info.isFullUpdate) or isSecret(info.addedAuras) or isSecret(info.removedAuraInstanceIDs) then return end
        if not info.isFullUpdate and not info.addedAuras and not info.removedAuraInstanceIDs then return end
    end
    self:CheckAuras()
end

function Ready:CheckAuras()
    local invisible, camo, feign = PlayerHasAuraInList(INVIS_SPELLS), PlayerHasAuraInList(CAMO_SPELLS), PlayerHasAura(5384)
    self:SetReady("invisible", not invisible)
    self:SetReady("camo", not camo)
    self:SetReady("thunderisle_saurok", not PlayerHasAura(136461))
    if PlayerHasAuraInList(FOOD_SPELLS) then self:SetReady("sitting", false) end
    self:SetReady("feigned", not feign)
    setHidden(hidden.stealth, invisible, camo, feign)
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
        -- a request of yours that failed this way waits until you stand
        if self._ranExplicit and not self.pending then
            self._ranExplicit = nil
            self.pending, self.pendingPet = "explicit", self._ranPick
            ns:Printf(L["Stand up and your pet comes out."])
        end
    end
end

function Ready:PET_BATTLE_OPENING_START() self:SetReady("pet_battle", false) end
function Ready:PET_BATTLE_CLOSE() self:SetReady("pet_battle", true) end

function Ready:PLAYER_FLAGS_CHANGED(_, unit)
    if unit and unit ~= "player" then return end
    local afk = UnitIsAFK("player")
    self._flagsLast = { at = GetTime(), unit = tostring(unit), afk = tostring(afk), typed = self.afk_message ~= nil }
    if not isSecret(afk) and afk and self.afk_message == nil then self:SetReady("sitting", false) end
    self.afk_message = nil
end

function Ready:BlockerLabel(key)
    if LABELS[key] then return LABELS[key] end
    local name = ns.SpecialItems and ns.SpecialItems:LocalizeString(key) or key
    return format(L["Using %s"], name)
end

-- the first game blocker in force, or nil; allocates nothing
function Ready:FirstBlocker()
    local is_false = self.is_false
    if not next(is_false) then return end
    for i = 1, #BLOCKER_ORDER do
        if is_false[BLOCKER_ORDER[i]] then return BLOCKER_ORDER[i] end
    end
    return (next(is_false))
end

function Ready:GetBlockers()
    local out = {}
    for _, key in ipairs(BLOCKER_ORDER) do
        if self.is_false[key] then out[#out + 1] = { key = key, label = LABELS[key] } end
    end
    for key in pairs(self.is_false) do
        if not LABELS[key] then out[#out + 1] = { key = key, label = self:BlockerLabel(key) } end
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
    ns:Printf("Falling %s, full control %s, since last cast %.1f s, waiting %s, request %s", tostring(IsFalling()), tostring(HasFullControl()),
        GetTime() - self.last_spell_sent, tostring(self.wait_timer ~= nil), tostring(self.pending))
    local f, sit = self._flagsLast, self._sitLast
    ns:Printf("AFK now %s; last flags event: %s", tostring(UnitIsAFK("player")),
        f and format("%.0f s ago, unit %s, afk %s, typed /afk %s", GetTime() - f.at, f.unit, f.afk, tostring(f.typed)) or "none")
    ns:Printf("Sitting last set: %s", sit and format("%s, %.0f s ago, from %s", sit.value and "standing" or "sitting",
        GetTime() - sit.at, (tostring(sit.from):gsub("%s+$", ""))) or "never")
end
