-- Permissive Blizzard UI stub for smoke-testing UI/ files: unknown frame methods and
-- capitalized globals resolve to inert objects, so the test exercises our own logic
-- (nil indexes, wrong arguments, ordering) without emulating Blizzard templates.
-- Global names are checked separately by luacheck against .luacheckrc.
local W = dofile("tests/wowstub.lua")
local U = {}

local NUMERIC = { "Width", "Height", "Scale", "ID", "Left", "Right", "Top", "Bottom", "Value", "Alpha",
    "NumPoints", "StringWidth", "StringHeight", "EffectiveScale", "FrameLevel", "Extent", "ScrollPercentage",
    "VerticalScroll", "Facing", "CursorPosition", "NumLetters", "Number" }
local STRING = { "Text", "Name", "Title", "ObjectType", "Atlas", "Texture" }

local Universal
local function universal() return setmetatable({ _events = {}, _scripts = {}, _shown = false }, Universal) end

local function defaultFor(name)
    for _, n in ipairs(NUMERIC) do
        if name == "Get" .. n then return function() return 0 end end
    end
    for _, n in ipairs(STRING) do
        if name == "Get" .. n then return function(self) return type(self) == "table" and rawget(self, "_text") or "" end end
    end
    if name:match("^Is") or name:match("^Has") or name:match("^Can") then
        return function() return false end
    end
    if name:match("^Get") or name:match("^Create") or name:match("^New") then
        return function() return universal() end
    end
    return function() end
end

-- A capitalized member is both callable (a method with a sensible default result)
-- and indexable (a nested table such as Mixin.Event.OnValueChanged).
local Member = {}
Member.__call = function(self, ...) return defaultFor(rawget(self, "_name"))(...) end
Member.__index = function(_, k)
    if type(k) == "string" and k:match("^[A-Z]") then return setmetatable({ _name = k }, Member) end
end
local function smart(name) return setmetatable({ _name = name }, Member) end

Universal = {}
Universal.__index = function(t, k)
    local m = rawget(Universal, k)
    if m then return m end
    if type(k) ~= "string" then return nil end
    if k:match("^[a-z]") then return nil end   -- plain fields are ours to set
    return smart(k)
end
Universal.__call = function() return universal() end
function Universal:RegisterEvent(e) self._events[e] = true end
function Universal:RegisterUnitEvent(e, ...) self._events[e] = { ... } end
function Universal:UnregisterEvent(e) self._events[e] = nil end
function Universal:UnregisterAllEvents() self._events = {} end
function Universal:SetScript(n, f) self._scripts[n] = f end
function Universal:GetScript(n) return self._scripts[n] end
function Universal:HookScript(n, f)
    local old = self._scripts[n]
    self._scripts[n] = function(...) if old then old(...) end f(...) end
end
function Universal:IsShown() return self._shown end
function Universal:IsVisible() return self._shown end
function Universal:Show()
    if self._shown then return end
    self._shown = true
    if self._scripts.OnShow then self._scripts.OnShow(self) end
end
function Universal:Hide()
    if not self._shown then return end
    self._shown = false
    if self._scripts.OnHide then self._scripts.OnHide(self) end
end
function Universal:SetShown(v) if v then self:Show() else self:Hide() end end
function Universal:SetText(t) self._text = t end
function Universal:GetChecked() return self._checked or false end
function Universal:SetChecked(v) self._checked = v end
function Universal:Click(button)
    if self._scripts.OnClick then self._scripts.OnClick(self, button or "LeftButton") end
end

U.universal = universal

-- Globals that must stay nil (optional addons) even though they are capitalized.
local ABSENT = { EllesmereUI = true, ElvUI = true }

function U.install()
    local createFrame = function(_, name, parent, template)
        local f = universal()
        f._shown = true
        f._template = template
        if name then rawset(_G, name, f) end
        W.track(f)
        return f
    end
    CreateFrame = createFrame
    UIParent = universal()
    UIParent._shown = true
    GameTooltip = universal()
    setmetatable(_G, {
        __index = function(_, k)
            if type(k) ~= "string" or ABSENT[k] then return nil end
            if k:match("^[A-Z][A-Z0-9_]*$") then return k end   -- GlobalStrings such as BATTLE_PET_NAME_8
            if k:match("^[A-Z]") then return universal() end
        end,
    })
end

function U.uninstall()
    setmetatable(_G, nil)
end

-- Every UI file listed in PetCall.toc, in load order.
function U.uiFiles()
    local list = {}
    for line in io.lines("PetCall.toc") do
        line = line:gsub("\r", ""):gsub("\\", "/")
        if line:match("^UI/") then list[#list + 1] = line end
    end
    return list
end

function U.load()
    W.reset()
    U.install()
    return W.load({ ui = U.uiFiles() })
end

U.W = W
return U
