local _, ns = ...

local L = ns.L
local ipairs, pairs, type, setmetatable, wipe, tremove, tconcat = ipairs, pairs, type, setmetatable, wipe, table.remove, table.concat

local Exceptions = ns:NewModule("Exceptions")
ns.Exceptions = Exceptions

-- choices: false = As usual, "alone" = leave the pet alone, "away" = put the pet away (the stronger)
local CHOICES = { false, "alone", "away" }
local AWAY_ONLY = { false, "away" }
local STRENGTH = { "away", "alone" }
Exceptions.CHOICE_LABEL = { [false] = L["As usual"], alone = L["Leave the pet alone"], away = L["Put the pet away"] }
local IN_GROUP = { "groupType", party = true, raid = true }

-- fixed conditions; "solo" ones fit only in a group while "Also when solo" is cleared
local BUILTIN = {
    { key = "mounted", name = L["While mounted"], trigger = { { "activity", mounted = true } } },
    { key = "bg", name = L["Battlegrounds"], trigger = { { "specialLocation", locs = { "bg" } } } },
    { key = "arena", name = L["Arenas"], trigger = { { "specialLocation", locs = { "arena" } } } },
    { key = "dungeon", name = L["Dungeons"], trigger = { { "specialLocation", locs = { "dungeon" } } }, solo = true },
    { key = "raid", name = L["Raids"], trigger = { { "specialLocation", locs = { "raid" } } }, solo = true },
    { key = "scenario", name = L["Scenarios and delves"], trigger = { { "specialLocation", locs = { "scenario", "delve" } } }, solo = true },
    -- summoning while hidden is held back anyway: only putting the pet away is a choice
    { key = "hidden", name = L["Stealth or invisibility"], trigger = { { "hidden", stealth = true, invisible = true, camo = true, feign = true } },
        choices = AWAY_ONLY },
    { key = "outsideCities", name = L["Outside cities"], trigger = { { "specialLocation", locs = { "city" }, negate = true } } },
}

local all                 -- built-ins in order, then own exceptions
local inForce, inForceDirty = {}, true

local function store() return ns.db.profile.exceptions end

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

local Exc = {}
Exc.__index = Exc

function Exc:GetChoice()
    if self.builtin then return store().builtin[self.id] or false end
    return self.entry.choice or false
end

function Exc:Choices() return self.def and self.def.choices or CHOICES end

function Exc:DisplayName()
    if self.builtin then return self.def.name end
    if self.entry.name and self.entry.name ~= "" then return self.entry.name end
    if #self.trigger == 0 then return L["New exception"] end
    local parts = {}
    for _, e in ipairs(self.trigger) do parts[#parts + 1] = ns.Conditions.Describe(e) end
    return tconcat(parts, " " .. L["and"] .. " ")
end

function Exc:HasSolo() return self.builtin and self.def.solo == true end
function Exc:GetSolo() return self:HasSolo() and store().solo[self.id] ~= false end

function Exc:ConditionsMet()
    if #self.trigger == 0 then return false end
    if self.watcher then return self.watcher.value end
    local ctx = ns.Conditions.Context()
    for _, e in ipairs(self.trigger) do
        if not ns.Conditions.Eval(e, ctx) then return false end
    end
    return true
end

function Exc:GetConditionStates() return self.watcher and self.watcher.states or {} end
function Exc:GetConditionModel() return ns.Conditions.ToModel(self.trigger) end

local function changed()
    inForceDirty = true
    ns:Fire("ExceptionsChanged")
end

-- the watcher saw a change: entering the condition starts the exception
local function stateChanged(exc)
    local fits = exc:ConditionsMet()
    if fits == exc.fits then ns:Fire("ExceptionsChanged") return end
    exc.fits, exc.started = fits, fits
    changed()
    if fits then ns:Fire("ExceptionStarted", exc) end
end

-- only an exception that does something is watched
local function watch(exc)
    if exc:GetChoice() then
        if not exc.watcher then
            exc.watcher = ns.Conditions.NewWatcher(exc.trigger, function() stateChanged(exc) end)
            exc.started = false
        end
    elseif exc.watcher then
        exc.watcher:Free()
        exc.watcher = nil
    end
    exc.fits = exc.watcher ~= nil and exc:ConditionsMet()
end

-- a change of settings, not of the world: the exception does not start from it
function Exc:ConditionsChanged()
    self.rev = (self.rev or 0) + 1      -- an unnamed exception's name follows its conditions
    if self.watcher then self.watcher:Rebuild() end
    self.fits = self.watcher ~= nil and self:ConditionsMet()
    if not self.fits then self.started = false end
    changed()
end

function Exc:SetChoice(c)
    local allowed = false
    for _, x in ipairs(self:Choices()) do if x == c then allowed = true end end
    if not allowed then return false end
    if self.builtin then store().builtin[self.id] = c else self.entry.choice = c end
    watch(self)
    changed()
    return true
end

local function fillBuiltin(exc)
    wipe(exc.trigger)
    for i, e in ipairs(exc.def.trigger) do exc.trigger[i] = copy(e) end
    if exc.def.solo and not exc:GetSolo() then exc.trigger[#exc.trigger + 1] = copy(IN_GROUP) end
end

function Exc:SetSolo(on)
    if not self:HasSolo() then return false end
    store().solo[self.id] = on and true or false
    fillBuiltin(self)
    self:ConditionsChanged()
    return true
end

function Exc:SetConditionModel(model)
    if self.builtin then return end
    local list = ns.Conditions.FromModel(model)
    wipe(self.trigger)
    for i, e in ipairs(list) do self.trigger[i] = e end
    self:ConditionsChanged()
end

local function free(exc)
    if exc.watcher then exc.watcher:Free() exc.watcher = nil end
    exc.deleted, exc.fits = true, false
end

function Exc:Delete()
    if self.builtin then return false end
    local own = store().own
    for i, entry in ipairs(own) do
        if entry == self.entry then tremove(own, i) break end
    end
    for i, exc in ipairs(all) do
        if exc == self then tremove(all, i) break end
    end
    free(self)
    changed()
    return true
end

-- an object outlives its data when it is deleted or the profile changes
for _, method in ipairs({ "SetChoice", "SetSolo", "SetConditionModel", "ConditionsChanged", "Delete" }) do
    local original = Exc[method]
    Exc[method] = function(self, ...)
        if self.deleted then return false end
        return original(self, ...)
    end
end

--
-- Collection
--

local function newOwn(entry)
    entry.trigger = entry.trigger or {}
    ns.Conditions.Normalize(entry.trigger)
    local exc = setmetatable({ id = "own:" .. entry.id, builtin = false, entry = entry, trigger = entry.trigger }, Exc)
    watch(exc)
    return exc
end

local function build()
    all = {}
    for _, def in ipairs(BUILTIN) do
        local exc = setmetatable({ id = def.key, builtin = true, def = def, trigger = {} }, Exc)
        fillBuiltin(exc)
        watch(exc)
        all[#all + 1] = exc
    end
    for _, entry in ipairs(store().own) do all[#all + 1] = newOwn(entry) end
    inForceDirty = true
end

local function objects()
    if not all then build() end
    return all
end

function Exceptions:List()
    local out = {}
    for i, exc in ipairs(objects()) do out[i] = exc end
    return out
end

function Exceptions:Add(trigger, choice, name, from)
    local own = store().own
    local id = 0
    for _, entry in ipairs(own) do if entry.id > id then id = entry.id end end
    local entry = { id = id + 1, trigger = trigger or {}, choice = choice or false, name = name, from = from }
    own[#own + 1] = entry
    objects()[#all + 1] = newOwn(entry)
    changed()
    return all[#all]
end

-- the exceptions that fit right now and do something, the strongest first; shared, do not change it
function Exceptions:InForce()
    if inForceDirty then
        local list = {}
        for _, strength in ipairs(STRENGTH) do
            for _, exc in ipairs(objects()) do
                if exc.fits and exc:GetChoice() == strength then list[#list + 1] = exc end
            end
        end
        inForce, inForceDirty = list, false
    end
    return inForce
end

function Exceptions:Strongest()
    local exc = self:InForce()[1]
    if exc then return exc:GetChoice(), exc end
end

function Exceptions:Reload()
    for _, exc in ipairs(all or {}) do free(exc) end
    build()
    ns:Fire("ExceptionsChanged")
end

function Exceptions:OnInitialize()
    ns:RegisterCallback(self, "ProfileChanged", function() Exceptions:Reload() end)
end

function Exceptions:OnEnable()
    self:Reload()
    -- at login or reload, an exception already in force starts as if just entered
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function(_, _, isInitialLogin, isReloadingUi)
        if not (isInitialLogin or isReloadingUi) then return end
        for _, exc in ipairs(objects()) do
            if exc.fits and not exc.started then
                exc.started = true
                ns:Fire("ExceptionStarted", exc)
            end
        end
    end)
end
