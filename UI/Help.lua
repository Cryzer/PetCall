local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame

ns.UI = ns.UI or {}
local Help = {}
ns.UI.Help = Help

-- The game's own help system (the "i" in Blizzard windows): yellow boxes over the
-- parts of the window, each with a tooltip. The boxes are measured from the window
-- as it is when the help opens, so they fit any size and either tab.

local TEXT = {
    sets = L["HELP_SETS"],
    header = L["HELP_HEADER"],
    tabs = L["HELP_TABS"],
    toolbar = L["HELP_TOOLBAR"],
    rules = L["HELP_RULES"],
    grid = L["HELP_GRID"],
    preview = L["HELP_PREVIEW"],
    when = L["HELP_WHEN"],
    settings = L["HELP_SETTINGS"],
    gallery = L["HELP_GALLERY"],
    status = L["HELP_STATUS"],
}

local plate = {}     -- the help shown now; HelpPlate tells it apart by identity
local button

local function available()
    if not HelpPlate and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_HelpPlate") end
    return HelpPlate ~= nil and HelpPlate.Show ~= nil
end

local function box(region)
    if not region or not region:IsVisible() then return nil end
    local s = region:GetEffectiveScale()
    local l, t, r, b = region:GetLeft(), region:GetTop(), region:GetRight(), region:GetBottom()
    if not (l and t and r and b) then return nil end
    return { l = l * s, t = t * s, r = r * s, b = b * s }    -- screen pixels
end

local function union(regions)
    local u
    for _, region in ipairs(regions) do
        local x = box(region)
        if x then
            u = u or { l = x.l, t = x.t, r = x.r, b = x.b }
            u.l, u.t, u.r, u.b = math.min(u.l, x.l), math.max(u.t, x.t), math.max(u.r, x.r), math.min(u.b, x.b)
        end
    end
    return u
end

-- the boxes for what the window shows now, in screen pixels
function Help.Areas()
    local Main = ns.UI.Main
    local f = Main.GetFrameRaw()
    if not f then return {} end
    local out = {}
    local function add(key, rect, dir, outside)
        if rect and rect.r - rect.l > 4 and rect.t - rect.b > 4 then
            out[#out + 1] = { key = key, rect = rect, dir = dir, text = TEXT[key], outside = outside }
        end
    end
    add("sets", box(f.left), "RIGHT")
    local gallery = ns.UI.RecipeGallery
    if gallery and gallery:IsShown() then
        add("gallery", box(gallery:GetFrame()), "LEFT")
    else
        add("header", box(f.header), "DOWN")
        add("tabs", union(Main:GetTabButtons()), "DOWN", true)    -- its "i" past the names, not over one
        local tab = Main:GetSelectedTab()
        local content = box(f.content)
        if tab == "pets" and content then
            local page = ns.UI.PetsTabPage
            local rules = box(ns.UI.PetsTabRulesBar)
            if rules then add("toolbar", { l = content.l, t = content.t, r = content.r, b = rules.t }, "DOWN") end
            add("rules", rules, "DOWN")
            add("grid", box(page and page.grid), "RIGHT")
            add("preview", box(ns.UI.Preview:GetPanel()), "LEFT")
        elseif tab == "when" or tab == "settings" then
            add(tab, content, "RIGHT")
        end
    end
    add("status", box(f.status), "UP")
    return out
end

-- HelpPlate's table: the canvas covers the window below its title bar, so the "i",
-- the gear and the close button stay clickable; boxes are placed from its top left
local function fill()
    local f = ns.UI.Main.GetFrameRaw()
    wipe(plate)
    local scale = HelpPlate.GetEffectiveScale and HelpPlate.GetEffectiveScale() or UIParent:GetEffectiveScale()
    local win, inset = box(f), box(f.Inset)
    if not (win and inset) then return false end
    local ox, oy = win.l, inset.t
    plate.FramePos = { x = 0, y = (oy - win.t) / scale }
    plate.FrameSize = { width = (win.r - win.l) / scale, height = (oy - win.b) / scale }
    for _, a in ipairs(Help.Areas()) do
        local x, y = (a.rect.l - ox) / scale, (a.rect.t - oy) / scale
        local w, h = (a.rect.r - a.rect.l) / scale, (a.rect.t - a.rect.b) / scale
        plate[#plate + 1] = {
            ButtonPos = { x = a.outside and x + w + 2 or x + w / 2 - 23, y = y - h / 2 + 23 },
            HighLightBox = { x = x, y = y, width = w, height = h },
            ToolTipDir = a.dir,
            ToolTipText = a.text,
        }
    end
    return #plate > 0
end

function Help:IsShown() return available() and HelpPlate.IsShowingHelpInfo(plate) end

function Help:Show()
    if not available() or not fill() then return end
    HelpPlate.Show(plate, ns.UI.Main.GetFrameRaw(), button)
    ns.db.global.helpSeen = true
end

function Help:Hide(fromUser)
    if self:IsShown() then HelpPlate.Hide(fromUser) end
end

function Help:Toggle()
    if self:IsShown() then self:Hide(true) else self:Show() end
end

function Help.GetButton() return button end

ns:RegisterCallback(Help, "WindowBuilt", function(_, f)
    button = CreateFrame("Button", nil, f)
    -- Blizzard's size, on the title bar's line just right of the logo, like the "i"
    -- in their windows: the texture fills its frame, so smaller reads as a dot
    button:SetSize(36, 36)
    button:SetPoint("CENTER", f.badge or f, f.badge and "TOPRIGHT" or "TOPLEFT", 16, f.badge and -21 or -11)
    button:SetFrameLevel((f.badge and f.badge:GetFrameLevel() or f:GetFrameLevel()) + 1)
    button:SetNormalTexture("Interface\\common\\help-i")
    button:SetHighlightTexture("Interface\\common\\help-i", "ADD")
    button:GetHighlightTexture():SetAlpha(0.3)
    button.mainHelpPlateButtonTooltipText = MAIN_HELP_BUTTON_TOOLTIP
    button:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        Help:Toggle()
    end)
    button:SetScript("OnEnter", function(self)
        if available() and HelpPlateTooltip then HelpPlateTooltip:Init(self, MAIN_HELP_BUTTON_TOOLTIP, "RIGHT") end
    end)
    button:SetScript("OnLeave", function() if HelpPlateTooltip then HelpPlateTooltip:Hide() end end)
end)

-- the first time the window opens, the "i" points itself out
ns:RegisterCallback(Help, "WindowShown", function()
    if ns.db.global.helpSeen or not button or not available() or not HelpPlate.ShowTutorialTooltip then return end
    ns.db.global.helpSeen = true
    HelpPlate.ShowTutorialTooltip(plate, button)
end)

-- the boxes belong to one size and one page of the window
ns:RegisterCallback(Help, "WindowHidden", function() Help:Hide(false) end)
ns:RegisterCallback(Help, "WindowResized", function() Help:Hide(false) end)
ns:RegisterCallback(Help, "SelectedSetChanged", function() if Help:IsShown() then Help:Show() end end)
