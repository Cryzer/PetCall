local _, ns = ...

local L = ns.L
local GetTime, InCombatLockdown, wipe = GetTime, InCombatLockdown, wipe

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

-- The last thing PetCall did by itself, for "Because:". Memory only; one record is reused.
local NEWS_SECONDS = 600
local lastEvent, lastData = nil, { at = 0 }

-- events: set_kept, set_replaced, timer, new_map, put_away, paused, came_back, explicit (yours)
-- data (optional): set, reason ("fits" | "always" | "not_in_set"), pick (a pet you chose), exc;
-- the pet out at the time is kept with it
function Gate:Note(event, data)
    lastEvent = event
    lastData.at = GetTime()
    lastData.pet = ns:GetCurrentPet()
    lastData.set = data and data.set
    lastData.reason = data and data.reason
    lastData.pick = data and data.pick
    lastData.exc = data and data.exc
end

function Gate:LastEvent() return lastEvent, lastData end

-- A set start is about the pet out: the one it kept, or the new one that replaced the old.
-- A pet out since then (yours, or another) makes it old news.
local function setNews()
    if lastEvent ~= "set_kept" and lastEvent ~= "set_replaced" then return false end
    if GetTime() - lastData.at >= NEWS_SECONDS then return false end
    local cur = ns:GetCurrentPet()
    if lastEvent == "set_kept" then return cur ~= nil and cur == lastData.pet end
    return cur ~= nil and cur ~= lastData.pet and cur ~= ns.Summon.manualPick
end

-- Why nothing happens, or what happens next, as one record: { kind = "game" | "off" | "paused" |
-- "exception" | "set" | "next" | "idle", label, exc, set, reason, pick, replaced, seconds, minutes,
-- next (the set whose timer runs, with a "set" record), waiting (a request waits to run) }. pastGame: leave the game level out (it holds back
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
    local minutes = seconds and (set:GetSwitch())
    -- the news of a set that started says when the next pet comes too
    if setNews() then
        return { kind = "set", set = lastData.set, reason = lastData.reason, pick = lastData.pick,
            replaced = lastEvent == "set_replaced", waiting = waiting, seconds = seconds, minutes = minutes, next = set }
    end
    if seconds then
        return { kind = "next", set = set, seconds = seconds, minutes = minutes, waiting = waiting }
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
        self:Note("put_away", { exc = select(2, ns.Exceptions:Strongest()) })
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
