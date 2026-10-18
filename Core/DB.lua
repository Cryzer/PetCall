local _, ns = ...

local pairs, type, next, sort = pairs, type, next, table.sort

local DB = {}
ns.DB, ns.Profiles = DB, DB
ns.db = {}

DB.defaults = {
    enable = true,
    enableInBattleground = true,
    dismissInBattleground = false,
    disableOutsideCities = false,
    dismissWhenStealthed = false,
    noSummonMounted = true,               -- a summon on a mount takes the GCD from Skyriding abilities
    disableForQuestItems = true,          -- unused since 1.x; kept so old data round-trips
    enableInPVE = true,
    dismissInPVE = false,
    nearPEWOnly = false,
    overrideSetLoadout = false,
    waitTimer = 3,
    verbose = true,
    autoSwitch = { timer = false, timerValue = 30 * 60, citiesOnly = false, onZone = false },
    minimap = { hide = false },
    sets = {
        ["$Default"] = { name = DEFAULT, enabled = true, defaultValue = 1, priority = -1, pets = {}, filter = {} },
        ["*"] = { enabled = true, defaultValue = 0, priority = 1, pets = {}, filter = {}, trigger = {} },
    },
}

DB.globalDefaults = {
    -- room for the sets list, three columns of pets and the preview at first open
    window = { scale = 1, width = 940, height = 640, setsCollapsed = nil },
    look = "auto",          -- window look: auto, flat (PetCall dark) or blizzard; see UI/Skin.lua
    recentPets = {},
}

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

function DB.ApplyDefaults(tbl, defaults)
    local wildcard = defaults["*"]
    for k, v in pairs(defaults) do
        if k ~= "*" then
            if type(v) == "table" then
                if type(tbl[k]) ~= "table" then tbl[k] = {} end
                DB.ApplyDefaults(tbl[k], v)
            elseif tbl[k] == nil then
                tbl[k] = v
            end
        end
    end
    if wildcard then
        for k, v in pairs(tbl) do
            if defaults[k] == nil and type(v) == "table" and type(wildcard) == "table" then
                DB.ApplyDefaults(v, wildcard)
            end
        end
        -- new keys created later get the wildcard too
        setmetatable(tbl, {
            __index = function(t, k)
                if type(k) ~= "string" then return nil end
                local new = copy(wildcard)
                rawset(t, k, new)
                return new
            end,
        })
    end
end

local namespaces = {}

local function profileName(sv)
    sv.profileKeys = sv.profileKeys or {}
    local name = sv.profileKeys[DB.charKey] or "Default"
    sv.profileKeys[DB.charKey] = name
    return name
end

local function bindProfile()
    local sv = ns.db.sv
    local name = profileName(sv)
    sv.profiles[name] = sv.profiles[name] or {}
    DB.ApplyDefaults(sv.profiles[name], DB.defaults)
    ns.db.profile = sv.profiles[name]
    for nsName, n in pairs(namespaces) do
        local nsv = sv.namespaces[nsName]
        nsv.profiles = nsv.profiles or {}
        nsv.profiles[name] = nsv.profiles[name] or {}
        if n.defaults.profile then DB.ApplyDefaults(nsv.profiles[name], n.defaults.profile) end
        n.profile = nsv.profiles[name]
    end
end

function DB:Load()
    DB.charKey = UnitName("player") .. " - " .. GetRealmName()
    PetCall3DB = PetCall3DB or {}
    local sv = PetCall3DB
    sv.profiles = sv.profiles or {}
    sv.namespaces = sv.namespaces or {}
    sv.global = sv.global or {}
    sv.char = sv.char or {}
    sv.char[DB.charKey] = sv.char[DB.charKey] or {}
    DB.ApplyDefaults(sv.global, DB.globalDefaults)
    ns.db.sv, ns.db.global, ns.db.char = sv, sv.global, sv.char[DB.charKey]
    bindProfile()
end

function DB:Namespace(name, defaults)
    local sv = ns.db.sv
    sv.namespaces[name] = sv.namespaces[name] or {}
    local nsv = sv.namespaces[name]
    nsv.global = nsv.global or {}
    if defaults.global then DB.ApplyDefaults(nsv.global, defaults.global) end
    local n = { defaults = defaults, global = nsv.global }
    namespaces[name] = n
    bindProfile()
    return n
end

function DB:Current()
    return profileName(ns.db.sv)
end

function DB:List()
    local out, seen = {}, {}
    for name in pairs(ns.db.sv.profiles) do
        out[#out + 1], seen[name] = name, true
    end
    local cur = self:Current()
    if not seen[cur] then out[#out + 1] = cur end
    sort(out)
    return out
end

local function changed()
    bindProfile()
    ns:Fire("ProfileChanged")
end

function DB:Set(name)
    if type(name) ~= "string" or name == "" then return false, ns.L["Profile name cannot be empty."] end
    ns.db.sv.profileKeys[DB.charKey] = name
    changed()
    return true
end

function DB:Copy(from)
    local src = ns.db.sv.profiles[from]
    if not src or from == self:Current() then return false, ns.L["Unknown profile."] end
    local cur = self:Current()
    ns.db.sv.profiles[cur] = copy(src)
    for _, nsv in pairs(ns.db.sv.namespaces) do
        if nsv.profiles and nsv.profiles[from] then
            nsv.profiles[cur] = copy(nsv.profiles[from])
        end
    end
    changed()
    return true
end

function DB:Reset()
    local cur = self:Current()
    ns.db.sv.profiles[cur] = {}
    for _, nsv in pairs(ns.db.sv.namespaces) do
        if nsv.profiles then nsv.profiles[cur] = {} end
    end
    changed()
end

function DB:Delete(name)
    if name == self:Current() then return false, ns.L["Cannot delete the active profile."] end
    if not ns.db.sv.profiles[name] then return false, ns.L["Unknown profile."] end
    ns.db.sv.profiles[name] = nil
    for _, nsv in pairs(ns.db.sv.namespaces) do
        if nsv.profiles then nsv.profiles[name] = nil end
    end
    for key, prof in pairs(ns.db.sv.profileKeys) do
        if prof == name then ns.db.sv.profileKeys[key] = nil end
    end
    ns:Fire("ProfileChanged")
    return true
end
