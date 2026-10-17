local _, ns = ...

local L = ns.L
local CreateFrame, UIParent = CreateFrame, UIParent

ns.UI = ns.UI or {}
local Main = {}
ns.UI.Main = Main

local MIN_W, MIN_H = 640, 440
local frame, tabs, tabOrder, tabButtons, selectedTab, selectedSet = nil, {}, {}, {}, nil, nil
local built = false     -- the tabs and panels exist; resizes before that are not news

local function saveGeometry()
    local g = ns.db.global.window
    g.width, g.height = frame:GetSize()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    g.point, g.relPoint, g.x, g.y = point, relPoint, x, y
end

local function applyScale()
    frame:SetScale(ns.db.global.window.scale or 1)
end

local ICON = "Interface\\AddOns\\PetCall\\Media\\icon"

-- The logo as an app icon hanging over the window's corner, where Blizzard's frames
-- put their portrait: rounded corners, a ring in the look's colour and a soft shadow,
-- baked at 64 px so it shows pixel for pixel, whole, never cropped.
local MEDIA = "Interface\\AddOns\\PetCall\\Media\\"
local BADGE, HANG_X, HANG_Y = 64, -11, 10
function Main.BuildBadge(f)
    ButtonFrameTemplate_HidePortrait(f)
    local badge = CreateFrame("Frame", nil, f)
    badge:SetSize(BADGE, BADGE)
    badge:SetPoint("TOPLEFT", HANG_X, HANG_Y)
    badge:SetFrameLevel((tonumber(f:GetFrameLevel()) or 0) + 20)
    badge.shadow = badge:CreateTexture(nil, "BACKGROUND")
    badge.shadow:SetTexture(MEDIA .. "logo-shadow")
    badge.shadow:SetSize(BADGE * 2, BADGE * 2)
    badge.shadow:SetPoint("CENTER", 0, -2)
    badge.logo = badge:CreateTexture(nil, "ARTWORK")
    badge.logo:SetTexture(MEDIA .. "logo")
    badge.logo:SetAllPoints()
    badge.ring = badge:CreateTexture(nil, "OVERLAY")
    badge.ring:SetTexture(MEDIA .. "logo-ring")
    badge.ring:SetAllPoints()
    -- the screen edge keeps the whole icon in view, not only the window
    f:SetClampRectInsets(HANG_X, 0, HANG_Y, 0)
    ns.Skin:PaintBadge(badge)
    ns.Skin:OnLooksChanged(function() ns.Skin:PaintBadge(badge) end)
    f.badge = badge
    return badge
end

function Main:Build()
    if frame then return end
    local g = ns.db.global.window
    frame = CreateFrame("Frame", "PetCallMainWindow", UIParent, "ButtonFrameTemplate")
    frame:SetTitle("PetCall")
    frame:SetPortraitToAsset(ICON)
    frame:SetSize(g.width or 940, g.height or 640)
    frame:SetPoint(g.point or "CENTER", UIParent, g.relPoint or "CENTER", g.x or 0, g.y or 0)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(MIN_W, MIN_H)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() saveGeometry() end)
    frame:Hide()
    tinsert(UISpecialFrames, "PetCallMainWindow")
    ButtonFrameTemplate_HideButtonBar(frame)
    -- the status bar lives below the inset
    frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 32)
    applyScale()
    ns.Skin:Apply("Shell", frame, { bottomBar = 28 })
    ns.Skin:Apply("CloseButton", frame.CloseButton)
    ns.Skin:Apply("Inset", frame.Inset)
    Main.BuildBadge(frame)

    local resize = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
    resize:SetPoint("BOTTOMRIGHT", -4, 4)
    resize:Init(frame, MIN_W, MIN_H, GetScreenWidth(), GetScreenHeight())
    resize:SetOnResizeStoppedCallback(saveGeometry)

    local gear = CreateFrame("Button", nil, frame)
    gear:SetSize(20, 20)
    gear:SetPoint("RIGHT", frame.CloseButton, "LEFT", -2, 0)
    gear:SetNormalAtlas("mechagon-projects")
    gear:SetHighlightAtlas("mechagon-projects", "ADD")
    gear:SetScript("OnClick", function() ns:OpenSettings() end)
    ns.Widgets.Tooltip(gear, L["Settings"])

    -- Layout regions: left panel (sets), content (tabs), status bar (bottom).
    frame.left = CreateFrame("Frame", nil, frame.Inset)
    frame.left:SetPoint("TOPLEFT", 4, -4)
    frame.left:SetPoint("BOTTOMLEFT", 4, 4)
    frame.left:SetWidth(190)

    -- set header (UI/SetHeader.lua) on top, then the tab row, then the pages
    frame.header = CreateFrame("Frame", nil, frame.Inset)
    frame.header:SetPoint("TOPLEFT", frame.left, "TOPRIGHT", 6, 0)
    frame.header:SetPoint("RIGHT", -4, 0)
    frame.header:SetHeight(52)

    frame.content = CreateFrame("Frame", nil, frame.Inset)
    frame.content:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -28)
    frame.content:SetPoint("BOTTOMRIGHT", -4, 4)

    frame.status = CreateFrame("Frame", nil, frame)
    frame.status:SetPoint("BOTTOMLEFT", 8, 6)
    frame.status:SetPoint("BOTTOMRIGHT", -24, 6)
    frame.status:SetHeight(22)

    -- a menu measuring itself while the tabs are built makes the window lay out early
    frame:SetScript("OnSizeChanged", function(_, w, h)
        if built then ns:Fire("WindowResized", w, h) end
    end)
    frame:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        if not selectedSet or selectedSet.deleted then Main:SelectSet(ns.Sets.DEFAULT) end
        if not selectedTab then Main:SelectTab("pets") end
        ns:Fire("WindowShown")
    end)
    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        ns:Fire("WindowHidden")
    end)

    -- fade in
    local ag = frame:CreateAnimationGroup()
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0) a:SetToAlpha(1) a:SetDuration(0.15)
    frame:HookScript("OnShow", function() ag:Play() end)

    for _, key in ipairs(tabOrder) do Main:BuildTab(key) end
    Main:LayoutTabs()
    built = true
    ns:Fire("WindowBuilt", frame)
end

-- order: 1 = pets, 2 = when, 3 = settings (files load in a different order)
function Main:RegisterTab(key, label, factory, order)
    tabs[key] = { key = key, label = label, factory = factory, order = order or 99 }
    tabOrder[#tabOrder + 1] = key
    table.sort(tabOrder, function(a, b) return tabs[a].order < tabs[b].order end)
    assert(not frame, "register tabs at load time")
end

function Main:BuildTab(key)
    local t = tabs[key]
    if t.button then return end
    local index = #tabButtons + 1
    local b = CreateFrame("Button", nil, frame, "PanelTopTabButtonTemplate")
    b:SetID(index)
    b:SetText(t.label)
    b:SetScript("OnClick", function() Main:SelectTab(key) end)
    PanelTemplates_TabResize(b, 12)
    b:SetScript("OnShow", function() Main:LayoutTabs() end)
    b:SetScript("OnHide", function() Main:LayoutTabs() end)
    tabButtons[index], t.button = b, b
    frame.Tabs = tabButtons
    PanelTemplates_SetNumTabs(frame, #tabButtons)
    ns.Skin:Apply("Tab", b)
    t.page = CreateFrame("Frame", nil, frame.content)
    t.page:SetAllPoints()
    t.page:Hide()
    t.object = t.factory(t.page)
end

-- chains the visible tabs left to right; hidden tabs (When for the default set) leave no gap
function Main:LayoutTabs()
    local prev
    for _, b in ipairs(tabButtons) do
        b:ClearAllPoints()
        if not prev then
            b:SetPoint("BOTTOMLEFT", frame.content, "TOPLEFT", 4, 2)
        else
            b:SetPoint("LEFT", prev, "RIGHT", 2, 0)
        end
        if b:IsShown() then prev = b end
    end
end

function Main:SelectTab(key)
    local t = tabs[key]
    if not t or not t.button:IsShown() then key, t = "pets", tabs.pets end
    if not t then return end
    selectedTab = key
    for k, other in pairs(tabs) do other.page:SetShown(k == key) end
    PanelTemplates_SetTab(frame, t.button:GetID())
    -- after Blizzard's own selection, which moves the text and swaps the textures
    for k, other in pairs(tabs) do ns.Skin:SetTabSelected(other.button, k == key) end
    if t.object.Refresh then t.object:Refresh(selectedSet) end
end

function Main:SelectSet(name)
    selectedSet = ns.Sets:Get(name) or ns.Sets:Get(ns.Sets.DEFAULT)
    -- the "when" tab does not exist for the default set
    if tabs.when and tabs.when.button then
        tabs.when.button:SetShown(not selectedSet:IsDefault())
    end
    ns:Fire("SelectedSetChanged", selectedSet)
    self:SelectTab(selectedTab or "pets")
end

-- another page (the recipe gallery) takes the place of the set header, tabs and
-- pages; showing them again restores the tabs this set has
function Main:SetSetPagesShown(shown)
    frame.header:SetShown(shown)
    frame.content:SetShown(shown)
    for key, t in pairs(tabs) do
        if t.button then t.button:SetShown(shown and not (key == "when" and selectedSet and selectedSet:IsDefault())) end
    end
end

function Main:GetSelectedSet() return selectedSet end
function Main:GetSelectedTab() return selectedTab end
function Main:GetFrame() self:Build() return frame end
function Main.GetFrameRaw() return frame end      -- for tests: no build
function Main:GetContentWidth() return frame and frame.content:GetWidth() or 0 end

function Main:SetScale(scale)
    ns.db.global.window.scale = scale
    if frame then applyScale() end
end

function Main:Show() self:Build() frame:Show() end
function Main:Hide() if frame then frame:Hide() end end
function Main:Toggle()
    self:Build()
    frame:SetShown(not frame:IsShown())
end

function ns:OpenWindow() Main:Show() end

-- Deleted sets and sets of a previous profile are stale objects: pick the set
-- with the same name in the current data, or the default set.
ns:RegisterCallback(Main, "SetsChanged", function()
    if frame and selectedSet and selectedSet.deleted then
        Main:SelectSet(ns.Sets:Get(selectedSet.name) and selectedSet.name or ns.Sets.DEFAULT)
    end
end)
