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
local AUTO_PAUSED = { level = "auto", key = "paused", label = L["Paused until you change zone"] }

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
    local state = ns:GetAutoState()
    if state == "off" then return AUTO_OFF end
    if state == "paused" then return AUTO_PAUSED end
end

-- action: "summon" or "switch"; source: "explicit" or "auto". Returns ok, cause.
function Gate:Check(action, source)
    local key = ns.Ready:FirstBlocker()
    if key then return false, gameCause(key) end
    if source ~= "auto" then return true end
    local auto = self:AutoCause()
    if auto then return false, auto end
    local choice, exc = ns.Exceptions:Strongest()
    if choice then return false, exceptionCause(exc) end
    return true
end

-- Why nothing happens, or what happens next, as one record: { kind = "game" | "off" | "paused" |
-- "exception" | "next" | "idle", label, exc, set, seconds, due (instead of seconds: "afk" or
-- "city", what the new pet waits for), minutes, waiting (a request waits to run) }. pastGame: leave the game level out (it holds back
-- nothing while a pet is out and nothing waits). Allocates: call it from refreshes, not from
-- event handlers.
function Gate:Explain(pastGame)
    local waiting = ns.Ready.pending ~= nil
    local ok, cause
    if pastGame then
        cause = self:AutoCause()
        local choice, exc = ns.Exceptions:Strongest()
        if not cause and choice then cause = exceptionCause(exc) end
        ok = cause == nil
    else
        ok, cause = self:Check("summon", "auto")
    end
    if not ok then
        local kind = cause.level == "auto" and cause.key or cause.level
        return { kind = kind, label = cause.label, exc = cause.exc, waiting = waiting }
    end
    local set = ns.Sets:GetCurrent()
    local seconds = set and ns.SwitchTimer:Remaining()
    local due = set and ns.SwitchTimer.due
    if seconds or due then
        return { kind = "next", set = set, seconds = seconds, due = due, minutes = (set:GetSwitch()), waiting = waiting }
    end
    return { kind = "idle", waiting = waiting }
end

local function awayInForce()
    return ns.Exceptions:Strongest() == "away"
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
        ns.Summon:Dismiss(true)
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
