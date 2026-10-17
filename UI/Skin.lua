local _, ns = ...

local Skin = {}
ns.Skin = Skin

-- Three looks:
--   eui       EllesmereUI's skin API styles every frame (needs EllesmereUI)
--   flat      PetCall's own flat dark style below; colours from QUI when it is installed
--   blizzard  the stock frames, untouched
-- The choice is read once, on the first frame styled: frames are styled as they are
-- built, so a new choice takes a reload.

local S                 -- EllesmereUI skin API once available
local pending = {}      -- { kind, frame, args } registered before EUI's callback
local accentListeners = {}
local look              -- resolved look, fixed for the session
local Flat = {}
Skin.Flat = Flat

local function hasEUI() return EllesmereUI ~= nil and EllesmereUI.RegisterSkin ~= nil end
local function hasQUI() return type(QUI) == "table" and type(QUI.GetSkinColor) == "function" end
Skin.HasQUI = hasQUI

-- what the player picked in the settings: auto, flat or blizzard
function Skin:GetChoice()
    return ns.db and ns.db.global and ns.db.global.look or "auto"
end

function Skin.Resolve(choice, eui, qui)
    if choice == "flat" then return "flat" end
    if choice == "blizzard" then return "blizzard" end
    if eui then return "eui" end
    if qui then return "flat" end
    return "blizzard"
end

function Skin:Look()
    if look then return look end
    local resolved = Skin.Resolve(self:GetChoice(), hasEUI(), hasQUI())
    -- before the saved variables are read the choice is not known yet: do not fix it
    if ns.db and ns.db.global then look = resolved end
    return resolved
end
function Skin._Forget() look = nil end      -- for tests

function Skin:Apply(kind, frame, ...)
    if not frame then return end
    local l = self:Look()
    if l == "flat" then
        if Flat[kind] then Flat[kind](frame, ...) end
    elseif l == "eui" then
        if S then
            if S[kind] then S[kind](frame, ...) end
        elseif pending then
            pending[#pending + 1] = { kind, frame, { ... } }
        end
    end
end

function Skin:SetTabSelected(tab, selected)
    local l = self:Look()
    if l == "flat" then Flat.SetTabSelection(tab, selected)
    elseif l == "eui" and S and S.SetTabSelection then S.SetTabSelection(tab, selected) end
end

function Skin:Accent()
    local l = self:Look()
    if l == "flat" then return Flat.Accent() end
    if l == "eui" and S and S.GetAccentColor then return S.GetAccentColor() end
    return 1, 0.82, 0
end

-- a dark look is in use (EllesmereUI's or PetCall's own)
function Skin:IsActive()
    local l = self:Look()
    return l == "flat" or (l == "eui" and S ~= nil)
end

function Skin:OnLooksChanged(fn) accentListeners[#accentListeners + 1] = fn end

if hasEUI() then
    EllesmereUI.RegisterSkin("PetCall", function(api)
        S = api
        if Skin:Look() == "eui" then
            for _, p in ipairs(pending or {}) do
                if S[p[1]] then S[p[1]](p[2], unpack(p[3])) end
            end
        end
        pending = nil
        if S.OnLooksChanged then
            S.OnLooksChanged(function()
                if Skin:Look() ~= "eui" then return end
                for _, fn in ipairs(accentListeners) do fn() end
            end)
        end
    end)
end

--
-- Flat dark style: one background colour, 1-px borders, accent for the picked things.
--

local DEFAULT_BG = { 0.05, 0.05, 0.06, 0.95 }
local DEFAULT_ACCENT = { 0.98, 0.76, 0.26 }
local BORDER = { 1, 1, 1, 0.12 }

function Flat.Accent()
    if hasQUI() then
        local ok, r, g, b = pcall(QUI.GetSkinColor, QUI)
        if ok and type(r) == "number" then return r, g, b end
    end
    return DEFAULT_ACCENT[1], DEFAULT_ACCENT[2], DEFAULT_ACCENT[3]
end

function Flat.Background()
    if hasQUI() and type(QUI.GetSkinBgColor) == "function" then
        local ok, r, g, b, a = pcall(QUI.GetSkinBgColor, QUI)
        if ok and type(r) == "number" then return r, g, b, a or 0.95 end
    end
    return DEFAULT_BG[1], DEFAULT_BG[2], DEFAULT_BG[3], DEFAULT_BG[4]
end

local function hide(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

-- every texture the template drew, except the ones we keep (icons, arrows)
local function hideTextures(frame, keep)
    if not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and not (keep and keep[region]) then
            region:SetAlpha(0)
        end
    end
end

-- background and a 1-px border drawn on our own textures, so the template cannot undo them
local function fill(frame, r, g, b, a, border)
    local f = frame.pcFlat
    if not f then
        f = {}
        f.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        f.bg:SetAllPoints()
        for _, side in ipairs({ "top", "bottom", "left", "right" }) do
            f[side] = frame:CreateTexture(nil, "BORDER", nil, 7)
        end
        f.top:SetPoint("TOPLEFT") f.top:SetPoint("TOPRIGHT") f.top:SetHeight(1)
        f.bottom:SetPoint("BOTTOMLEFT") f.bottom:SetPoint("BOTTOMRIGHT") f.bottom:SetHeight(1)
        f.left:SetPoint("TOPLEFT") f.left:SetPoint("BOTTOMLEFT") f.left:SetWidth(1)
        f.right:SetPoint("TOPRIGHT") f.right:SetPoint("BOTTOMRIGHT") f.right:SetWidth(1)
        frame.pcFlat = f
    end
    f.bg:SetColorTexture(r, g, b, a)
    border = border or BORDER
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        f[side]:SetColorTexture(border[1], border[2], border[3], border[4] or 1)
        f[side]:SetShown(border[4] ~= 0)
    end
    return f
end
Flat.Fill = fill

local function lighter(amount)
    local r, g, b = Flat.Background()
    return math.min(1, r + amount), math.min(1, g + amount), math.min(1, b + amount)
end

local function dropNineSlice(frame)
    if frame.NineSlice then frame.NineSlice:Hide() end
    if frame.SetBackdrop and frame.backdropInfo then frame:SetBackdrop(nil) end
end

-- a framed window (ButtonFrameTemplate): flat body, a title strip, an optional bottom bar
function Flat.Shell(frame, opts)
    dropNineSlice(frame)
    hide(frame.Bg)
    hide(frame.TopTileStreaks)
    if frame.PortraitContainer and frame.PortraitContainer.CircleMask then
        -- the round portrait keeps its look; only its golden ring goes
        hide(frame.PortraitFrame)
    end
    local r, g, b, a = Flat.Background()
    fill(frame, r, g, b, a)
    frame.pcTitle = frame.pcTitle or frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    frame.pcTitle:SetPoint("TOPLEFT", 1, -1)
    frame.pcTitle:SetPoint("TOPRIGHT", -1, -1)
    frame.pcTitle:SetHeight(22)
    local lr, lg, lb = lighter(0.05)
    frame.pcTitle:SetColorTexture(lr, lg, lb, 1)
    if opts and opts.bottomBar then
        frame.pcBottom = frame.pcBottom or frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        frame.pcBottom:SetPoint("BOTTOMLEFT", 1, 1)
        frame.pcBottom:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.pcBottom:SetHeight(opts.bottomBar)
        frame.pcBottom:SetColorTexture(lr, lg, lb, 1)
    end
end

-- a sunken area inside a window
function Flat.Inset(frame)
    dropNineSlice(frame)
    hide(frame.Bg)
    fill(frame, 0, 0, 0, 0.25)
end

-- a floating panel (popovers) or, with inset, a block inside the window (the preview)
function Flat.Panel(frame, opts)
    dropNineSlice(frame)
    if opts and opts.inset then
        fill(frame, 0, 0, 0, 0.25)
    else
        local r, g, b = lighter(0.03)
        fill(frame, r, g, b, 0.98, { 1, 1, 1, 0.2 })
    end
end

function Flat.Button(b)
    hideTextures(b)
    hide(b.Left) hide(b.Middle) hide(b.Right)
    local r, g, bl = lighter(0.09)
    fill(b, r, g, bl, 1)
    if not b.pcHover then
        b.pcHover = b:CreateTexture(nil, "HIGHLIGHT")
        b.pcHover:SetAllPoints()
        b.pcHover:SetColorTexture(1, 1, 1, 0.08)
    end
end

function Flat.Tab(tab)
    hideTextures(tab)
    local r, g, b = lighter(0.04)
    fill(tab, r, g, b, 1)
    if not tab.pcLine then
        tab.pcLine = tab:CreateTexture(nil, "OVERLAY")
        tab.pcLine:SetPoint("BOTTOMLEFT", 1, 1)
        tab.pcLine:SetPoint("BOTTOMRIGHT", -1, 1)
        tab.pcLine:SetHeight(2)
        tab.pcLine:Hide()
        tab.pcHover = tab:CreateTexture(nil, "HIGHLIGHT")
        tab.pcHover:SetAllPoints()
        tab.pcHover:SetColorTexture(1, 1, 1, 0.06)
    end
end

function Flat.SetTabSelection(tab, selected)
    if not tab.pcLine then return end
    hideTextures(tab, { [tab.pcLine] = true, [tab.pcHover] = true,
        [tab.pcFlat.bg] = true, [tab.pcFlat.top] = true, [tab.pcFlat.bottom] = true,
        [tab.pcFlat.left] = true, [tab.pcFlat.right] = true })
    local r, g, b = Flat.Accent()
    tab.pcLine:SetColorTexture(r, g, b, 1)
    tab.pcLine:SetShown(selected)
    local lr, lg, lb = lighter(selected and 0.1 or 0.04)
    tab.pcFlat.bg:SetColorTexture(lr, lg, lb, 1)
end

function Flat.CloseButton(button)
    hideTextures(button)
    if not button.pcX then
        button.pcX = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        button.pcX:SetPoint("CENTER", 0, 1)
        button.pcX:SetText("×")
        button.pcHover = button:CreateTexture(nil, "HIGHLIGHT")
        button.pcHover:SetAllPoints()
        button.pcHover:SetColorTexture(1, 0.3, 0.3, 0.25)
    end
end

-- input boxes and the search box: the side pieces go, the search icon stays
function Flat.EditBox(eb)
    hide(eb.Left) hide(eb.Middle) hide(eb.Right)
    fill(eb, 0, 0, 0, 0.45)
end

function Flat.Dropdown(dd)
    hide(dd.Background)
    local r, g, b = lighter(0.07)
    fill(dd, r, g, b, 1)
end
