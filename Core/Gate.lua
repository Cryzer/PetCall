local _, ns = ...

local L = ns.L
local InCombatLockdown, wipe = InCombatLockdown, wipe

-- The order of decisions: the game, then Auto-summon, then exceptions. The set and the pet
-- come after, in Summon. What you do yourself ("explicit") waits only for the game.
local Gate = ns:NewModule("Gate")
ns.Gate = Gate

-- causes are shared tables: checking allocates nothing
local gameCauses = {}
local AUTO_OFF = { level = "auto", key = "off", label = L["Auto-summon is off"] }
local NO_PET_SET = { level = "exception", key = "noPetSet", label = L["This set keeps the pet away"] }

local function gameCause(key)
    local c = gameCauses[key]
    if not c then
        c = { level = "game", key = key, label = ns.Ready:BlockerLabel(key) }
        gameCauses[key] = c
    end
    return c
end

local function exceptionCause(exc)
    local c = exc.cause
    if not c then
        c = { level = "exception", key = exc.id, exc = exc }
        exc.cause = c
    end
    -- the name changes only with a new name or new conditions
    local name, rev = exc.entry and exc.entry.name, exc.rev or 0
    if not c.label or c.rev ~= rev or c.name ~= name then c.label, c.rev, c.name = exc:DisplayName(), rev, name end
    return c
end

-- the Auto-summon level: nil while PetCall may act by itself
function Gate:AutoCause()
    if not ns:IsAutoSummon() then return AUTO_OFF end
end

-- action: "summon" or "switch"; source: "explicit" or "auto". Returns ok, cause.
function Gate:Check(action, source)
    local key = ns.Ready:FirstBlocker()
    if key then return false, gameCause(key) end
    if source ~= "auto" then return true end
    local auto = self:AutoCause()
    if auto then return false, auto end
    local set = ns.Sets:GetCurrent()
    if set and set:IsNoPet() then return false, NO_PET_SET end
    local choice, exc = ns.Exceptions:Strongest()
    if choice then return false, exceptionCause(exc) end
    return true
end

local function awayInForce()
    local set = ns.Sets:GetCurrent()
    return ns.Exceptions:Strongest() == "away" or (set and set:IsNoPet())
end

-- "Put the pet away" acts as it starts to fit; in combat, once combat ends
function Gate:PutAway()
    if self:AutoCause() then return end
    if InCombatLockdown() then
        self.awayAfterCombat = true
        return
    end
    if ns:GetCurrentPet() then
        ns.Ready.comeback = true
        ns.Summon:Dismiss(false, true)
    end
end

function Gate:PLAYER_REGEN_ENABLED()
    if not self.awayAfterCombat then return end
    self.awayAfterCombat = nil
    if awayInForce() then self:PutAway() end
end

function Gate:OnInitialize()
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    ns:RegisterCallback(self, "ExceptionStarted", function(_, exc)
        if exc:GetChoice() == "away" then Gate:PutAway() end
    end)
    ns:RegisterCallback(self, "SpecialItemsChanged", function() wipe(gameCauses) end)
end
