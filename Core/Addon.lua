local ADDON, ns = ...
_G.PetCall = ns

ns.name = ADDON
local tocVersion = C_AddOns.GetAddOnMetadata(ADDON, "Version")
ns.version = (tocVersion and not tocVersion:find("@")) and tocVersion or "dev"

local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring

--
-- Profile (/pcall profile, takes a reload): from the next load on, every event handler,
-- callback and timer PetCall sets up is timed, and one that takes 5 ms or more is named
-- in chat with where it comes from. Off, nothing is wrapped and nothing is timed.
--

local Profile = {}
ns.Profile = Profile
Profile.on = type(PetCall3DB) == "table" and type(PetCall3DB.global) == "table" and PetCall3DB.global.profile == true
local SLOW_MS = 5

-- the file and line that asked for it: the first caller outside this file
local function where()
    local stack = (debugstack(2, 8, 0) or ""):gsub("\\", "/")
    for file, line in stack:gmatch('PetCall/([^"%]:\n]+)"?%]?:(%d+)') do
        if file ~= "Core/Addon.lua" then return file .. ":" .. line end
    end
end

local function finish(label, start, ...)
    local ms = debugprofilestop() - start
    if ms >= SLOW_MS then ns:Printf("|cffffd100%.0f ms|r %s", ms, label) end
    return ...
end

function Profile.Wrap(label, fn)
    if not Profile.on then return fn end
    local site = where()
    if site then label = label .. " @ " .. site end
    return function(...) return finish(label, debugprofilestop(), fn(...)) end
end

-- an event handler as a function, timed
local function timedHandler(obj, event, handler)
    if type(handler) == "string" then
        local method = handler
        handler = function(o, ...) return o[method](o, ...) end
    end
    return Profile.Wrap(event .. (obj.name and (" " .. obj.name) or ""), handler)
end

--
-- Events
--

local Events = {}
ns.Events = Events

local handlers = {}        -- event -> { [obj] = handler }
local unitHandlers = {}    -- event -> { [obj] = handler }
local frame = CreateFrame("Frame")
local unitFrame = CreateFrame("Frame")

local function dispatch(map, event, ...)
    local list = map[event]
    if not list then return end
    for obj, handler in pairs(list) do
        if type(handler) == "string" then
            obj[handler](obj, event, ...)
        else
            handler(obj, event, ...)
        end
    end
end

frame:SetScript("OnEvent", function(_, event, ...) dispatch(handlers, event, ...) end)
unitFrame:SetScript("OnEvent", function(_, event, ...) dispatch(unitHandlers, event, ...) end)

function Events.Register(obj, event, handler)
    handlers[event] = handlers[event] or {}
    if not next(handlers[event]) then frame:RegisterEvent(event) end
    handler = handler or event
    if Profile.on then handler = timedHandler(obj, event, handler) end
    handlers[event][obj] = handler
end

function Events.RegisterUnit(obj, event, unit, handler)
    assert(unit == "player", "only player unit events are supported")
    unitHandlers[event] = unitHandlers[event] or {}
    if not next(unitHandlers[event]) then unitFrame:RegisterUnitEvent(event, "player") end
    handler = handler or event
    if Profile.on then handler = timedHandler(obj, event, handler) end
    unitHandlers[event][obj] = handler
end

function Events.Unregister(obj, event)
    for _, map in ipairs({ handlers, unitHandlers }) do
        local list = map[event]
        if list and list[obj] then
            list[obj] = nil
            if not next(list) then
                (map == handlers and frame or unitFrame):UnregisterEvent(event)
            end
        end
    end
end

function Events.UnregisterAll(obj)
    for _, map in ipairs({ handlers, unitHandlers }) do
        for event, list in pairs(map) do
            if list[obj] then Events.Unregister(obj, event) end
        end
    end
end

--
-- Callbacks
--

-- name -> { [owner] = fn }. A list is never changed in place: (un)registering puts a
-- new copy in, so Fire walks the list it started with even when a callback
-- (un)registers, without copying it on every call.
local callbacks = {}

local function withOwner(name, owner, fn)
    local list = {}
    for o, f in pairs(callbacks[name] or {}) do list[o] = f end
    list[owner] = fn
    callbacks[name] = list
end

function ns:RegisterCallback(owner, name, fn) withOwner(name, owner, Profile.Wrap(name, fn)) end

function ns:UnregisterCallback(owner, name)
    if callbacks[name] and callbacks[name][owner] then withOwner(name, owner, nil) end
end

function ns:UnregisterAllCallbacks(owner)
    for name, list in pairs(callbacks) do
        if list[owner] then withOwner(name, owner, nil) end
    end
end

function ns:Fire(name, ...)
    local list = callbacks[name]
    if not list then return end
    for owner, fn in pairs(list) do
        local ok, err = pcall(fn, owner, ...)
        if not ok then geterrorhandler()(err) end
    end
end

--
-- Timers
--

function ns:After(sec, fn)
    return C_Timer.NewTimer(sec, Profile.Wrap("timer", fn))
end

function ns:NewTicker(sec, fn)
    return C_Timer.NewTicker(sec, Profile.Wrap("ticker", fn))
end

function ns.Debounce(delay, fn)
    fn = Profile.Wrap("timer", fn)
    local pending
    return function()
        if pending then return end
        pending = C_Timer.NewTimer(delay, function()
            pending = nil
            fn()
        end)
    end
end

--
-- Output
--

function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99PetCall|r: " .. tostring(msg))
end

function ns:Printf(fmt, ...)
    self:Print(format(fmt, ...))
end

--
-- Modules
--

local ModuleMixin = {}
function ModuleMixin:RegisterEvent(event, handler) Events.Register(self, event, handler) end
function ModuleMixin:RegisterUnitEvent(event, unit, handler) Events.RegisterUnit(self, event, unit, handler) end
function ModuleMixin:UnregisterEvent(event) Events.Unregister(self, event) end
function ModuleMixin:UnregisterAllEvents() Events.UnregisterAll(self) end
ns.ModuleMixin = ModuleMixin

ns.modules, ns.moduleOrder = {}, {}

function ns:NewModule(name)
    assert(not self.modules[name], "module exists: " .. name)
    local m = { name = name }
    for k, v in pairs(ModuleMixin) do m[k] = v end
    self.modules[name] = m
    self.moduleOrder[#self.moduleOrder + 1] = m
    return m
end

function ns:GetModule(name)
    return self.modules[name]
end

local function callAll(method)
    for _, m in ipairs(ns.moduleOrder) do
        if m[method] then
            local ok, err = pcall(Profile.Wrap(method .. " " .. m.name, m[method]), m)
            if not ok then geterrorhandler()(err) end
        end
    end
end

local lifecycle = {}
Events.Register(lifecycle, "ADDON_LOADED", function(_, _, name)
    if name ~= ADDON then return end
    Events.Unregister(lifecycle, "ADDON_LOADED")
    if ns.DB then ns.DB:Load() end
    callAll("OnInitialize")
end)
Events.Register(lifecycle, "PLAYER_LOGIN", function()
    Events.Unregister(lifecycle, "PLAYER_LOGIN")
    callAll("OnEnable")
    if Profile.on then ns:Print("profile on: parts that take 5 ms or more are named here. /pcall profile turns it off.") end
end)
