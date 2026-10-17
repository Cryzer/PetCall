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
    if name:match("^Get") then return function() return universal() end end
    -- factories may return several objects (e.g. Settings.RegisterVerticalLayoutCategory)
    if name:match("^Create") or name:match("^New") or name:match("^Register") then
        return function() return universal(), universal() end
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
    if k:match("^[a-z_]") then return nil end   -- plain and stub fields are ours to set
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
function Universal:GetParent() return self._parent end
function Universal:GetTop() return self._top or 500 end
function Universal:GetEffectiveScale() return 1 end
function Universal:SetParent(p) self._parent = p end
function Universal:CreateTexture() local t = universal() t._parent = self t._shown = true return t end
function Universal:CreateFontString() local t = universal() t._parent = self t._shown = true return t end
function Universal:CreateAnimationGroup() local t = universal() t._parent = self return t end
-- CallbackRegistry-style widgets (MinimalSliderWithSteppers) notify on every SetValue, user or not
function Universal:RegisterCallback(event, fn, owner)
    self._callbacks = self._callbacks or {}
    self._callbacks[#self._callbacks + 1] = { fn = fn, owner = owner }
end
function Universal:SetValue(v)
    self._value = v
    for _, c in ipairs(self._callbacks or {}) do c.fn(c.owner, v) end
end
function Universal:GetValue() return self._value or 0 end
function Universal:SetTexture(t) self._texture = t end
function Universal:SetColorTexture(r, g, b, a) self._color = { r, g, b, a } end
function Universal:SetTexCoord(...) self._texCoord = { ... } end
function Universal:LockHighlight() self._highlightLocked = true end
function Universal:UnlockHighlight() self._highlightLocked = false end
-- anchors are recorded so layout tests can check them
function Universal:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, point, rel, relPoint end
    self._points = self._points or {}
    self._points[point] = { rel = rel, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end
function Universal:ClearAllPoints() self._points = {} end
function Universal:SetEnabled(v) self._enabled = v and true or false end
function Universal:IsEnabled() return self._enabled ~= false end
function Universal:SetAllPoints(rel) self._points = { ALL = { rel = rel } } end
-- linear ScrollBox: SetDataProvider initialises one row frame per element
function Universal:SetElementInitializer(_, fn) self._init = fn end
function Universal:SetDataProvider(dp)
    self._rowFrames = {}
    local view = self._view
    if not (view and view._init and type(dp) == "table" and dp._elements) then return end
    for _, data in ipairs(dp._elements) do
        local row = universal()
        row._shown, row._parent = true, self
        view._init(row, data)
        self._rowFrames[#self._rowFrames + 1] = row
    end
end
function Universal:SetCreature(id) self._creature = id U.modelLoads = (U.modelLoads or 0) + 1 end
function Universal:SetDisplayInfo(id) self._display = id U.modelLoads = (U.modelLoads or 0) + 1 end
function Universal:ClearModel() self._creature, self._display = nil, nil end
function Universal:SetFacing(a) self._facing = a end
function Universal:SetYaw(a) self._yaw = a end
function Universal:SetModelByCreatureDisplayID(id) self._display = id U.modelLoads = (U.modelLoads or 0) + 1 end
function Universal:GetObjectType() return self._type or "Frame" end
-- one actor per scene, like a real ModelScene with a single tagged actor
-- an actor is not a frame: no scripts (SetScript/HookScript), only what ModelSceneActor has
local ACTOR_METHODS = { "SetModelByCreatureDisplayID", "SetAnimationBlendOperation", "ClearModel", "GetModelFileID",
    "SetYaw", "GetYaw", "GetActiveBoundingBox", "GetScale", "SetScale", "GetPosition", "SetPosition", "IsLoaded",
    "SetAnimation", "Show", "Hide", "IsShown" }
local function strictActor()
    local inner = universal()
    local a = {}
    for _, m in ipairs(ACTOR_METHODS) do a[m] = function(self, ...) return inner[m](inner, ...) end end
    a.SetModelByCreatureDisplayID = function(self, id) inner._display = id U.modelLoads = (U.modelLoads or 0) + 1 end
    a.GetModelFileID = function() return inner._display end
    a.ClearModel = function() inner._display = nil end
    a.IsLoaded = function() return true end
    a.GetPosition = function() return 0, 0, 0 end
    a.GetScale = function() return 1 end
    a.GetActiveBoundingBox = function() return -0.5, -0.5, 0, 0.5, 0.5, 1 end
    return setmetatable(a, { __index = function(_, k) error("ModelSceneActor has no method " .. tostring(k), 2) end })
end
function Universal:GetActorByTag() self._actor = self._actor or strictActor() return self._actor end
function Universal:SetFrameLevel(l) self._level = l end
function Universal:GetFrameLevel() return self._level or 0 end
function Universal:GetChildren() return unpack(self._children or {}) end
function Universal:GetModelFileID() return self._display or self._creature end
function Universal:Click(button)
    if self._scripts.OnClick then self._scripts.OnClick(self, button or "LeftButton") end
end

U.universal = universal

-- Records a Blizzard menu description tree; items can be found by text and clicked.
local MenuMT = {}
MenuMT.__index = MenuMT
function U.newMenu() return setmetatable({ items = {} }, MenuMT) end
local function add(self, kind, text, a, b)
    local item = setmetatable({ items = {}, kind = kind, text = text, a = a, b = b }, MenuMT)
    self.items[#self.items + 1] = item
    return item
end
function MenuMT:CreateTitle(text) return add(self, "title", text) end
function MenuMT:CreateDivider() return add(self, "divider") end
function MenuMT:CreateButton(text, onClick) return add(self, "button", text, onClick) end
function MenuMT:CreateCheckbox(text, isSelected, onToggle) return add(self, "checkbox", text, isSelected, onToggle) end
function MenuMT:CreateRadio(text, isSelected, onSelect) return add(self, "radio", text, isSelected, onSelect) end
function MenuMT:SetScrollMode() end
function MenuMT:SetTooltip(fn) self.tooltip = fn end
function MenuMT:SetOnEnter(fn) self.onEnter = fn end
function MenuMT:SetOnLeave(fn) self.onLeave = fn end
function MenuMT:Find(prefix)
    for _, item in ipairs(self.items) do
        if item.text and item.text:sub(1, #prefix) == prefix then return item end
    end
end
-- runs the item's action the way the menu would
function MenuMT:Click()
    if self.kind == "button" and self.a then return self.a() end
    if self.kind == "checkbox" or self.kind == "radio" then return self.b() end
end

-- Globals that must stay nil (optional addons) even though they are capitalized.
local ABSENT = { EllesmereUI = true, ElvUI = true, LibStub = true, QUI = true }

function U.install()
    U.created = {}
    local createFrame = function(frameType, name, parent, template)
        local f = universal()
        f._shown = true
        f._template = template
        f._parent = parent
        f._type = frameType
        U.created[#U.created + 1] = f
        -- template child keys our code reads
        if template and template:find("CheckButton") then f.text = universal() end
        if template == "ButtonFrameTemplate" then
            f.Inset, f.CloseButton = universal(), universal()
            f.Inset._shown, f.CloseButton._shown = true, true
        end
        if name then rawset(_G, name, f) end
        W.track(f)
        return f
    end
    CreateFrame = createFrame
    CreateDataProvider = function(elements) return { _elements = elements } end
    MenuUtil = { CreateContextMenu = function(owner, builder)
        local root = U.newMenu()
        builder(owner, root)
        U.lastMenu, U.lastMenuOwner = root, owner
        return root
    end }
    ScrollUtil = { InitScrollBoxListWithScrollBar = function(box, _, view) box._view = view end }
    UIParent = universal()
    UIParent._shown = true
    GameTooltip = universal()
    GetCursorPosition = function() return U.cursorX or 0, U.cursorY or 0 end
    setmetatable(_G, {
        __index = function(_, k)
            if type(k) ~= "string" or ABSENT[k] then return nil end
            if k:match("^[A-Z][A-Z0-9_]*$") then return k end   -- GlobalStrings such as BATTLE_PET_NAME_8
            if k:match("^Is[A-Z]") or k:match("^Has[A-Z]") then return function() return false end end   -- IsControlKeyDown…
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

-- Stand-ins for LibDataBroker-1.1 and LibDBIcon-1.0 that record what the addon asks for.
local function registerLibStandIns()
    assert(loadfile("Libs/LibStub/LibStub.lua"))()
    local ldb = LibStub:NewLibrary("LibDataBroker-1.1", 999)
    ldb.objects = {}
    function ldb:NewDataObject(name, obj)
        if self.objects[name] then return nil end
        self.objects[name] = obj
        return obj
    end
    local icon = LibStub:NewLibrary("LibDBIcon-1.0", 999)
    icon.registered, icon.shown = {}, {}
    function icon:Register(name, obj, db)
        assert(obj and obj.icon, "LibDBIcon needs an object with an icon")
        assert(not self.registered[name], "already registered: " .. name)
        self.registered[name] = db
        self.shown[name] = not (db and db.hide)
    end
    function icon:Show(name) self.shown[name] = true end
    function icon:Hide(name) self.shown[name] = false end
    function icon:Refresh(name, db) self.registered[name] = db self.shown[name] = not (db and db.hide) end
    function icon:GetMinimapButton(name) return self.buttons and self.buttons[name] end
    U.ldb, U.icon = ldb, icon
end

function U.load()
    W.reset()
    U.install()
    registerLibStandIns()
    return W.load({ ui = U.uiFiles() })
end

U.W = W
return U
