local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Welcome = ns:NewModule("Welcome")
ns.UI.Welcome = Welcome

-- The one-time screen after the update: what changed, the comparison for this profile and
-- three ways out. A profile upgraded after the screen was seen gets one chat line instead.
-- Use recommended, from here or from the page, leaves one chat line with an Undo link.

local WIDTH, PAD, GAP, ICON = 560, 12, 10, 20
local CHROME = 86          -- the dialog's title and edges around its inset
local FOOT_ROOM = 8
local LINK = "addon:PetCall:undo"
local ICONS = { "Interface\\Icons\\INV_Misc_Book_09", "Interface\\Icons\\Spell_Nature_Sleep",
    "Interface\\Icons\\INV_Misc_Key_14", "Interface\\Icons\\INV_Misc_QuestionMark" }

local dialog

local function textHeight(fs) return math.ceil(tonumber(fs:GetStringHeight()) or 0) end

local function accent(text)
    local r, g, b = ns.Skin:Accent()
    return format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

local function points()
    return {
        format(L["%s pick which pets come out, and how often you get a new one."], accent(L["Sets"])),
        format(L["%s keep the pet away in some places: battlegrounds, while mounted, and so on."], accent(L["Exceptions"])),
        format(L["%s Dismissing your pet pauses Auto-summon until you change zone."], accent(L["Your own key presses always work."])),
        format(L["No pet, or not the one you expected? %s"], accent(L["The Out now card says why."])),
    }
end

local function markSeen()
    local global, facts = ns.db.global, ns.db.profile.upgradeFacts
    global.welcomeSeen, global.welcomePending = true, nil
    if facts then facts.announced = true end
end

local function layout()
    local inner = WIDTH - 2 * PAD - 34
    dialog.headline:SetWidth(inner)
    dialog.headline:ClearAllPoints()
    dialog.headline:SetPoint("TOPLEFT", PAD, -PAD)
    local y = PAD + textHeight(dialog.headline) + 6
    dialog.line:SetWidth(inner)
    dialog.line:ClearAllPoints()
    dialog.line:SetPoint("TOPLEFT", PAD, -y)
    y = y + textHeight(dialog.line) + GAP + 4
    local texts = points()
    for i, p in ipairs(dialog.points) do
        p.text:SetText(texts[i])
        p.text:SetWidth(inner - ICON - 8)
        local h = math.max(ICON, textHeight(p.text))
        p.icon:ClearAllPoints()
        p.icon:SetPoint("TOPLEFT", PAD, -y - (h - ICON) / 2)
        p.text:ClearAllPoints()
        p.text:SetPoint("TOPLEFT", PAD + ICON + 8, -y - (h - textHeight(p.text)) / 2)
        y = y + h + 8
    end
    y = y + GAP
    dialog.heading:SetWidth(inner)
    dialog.heading:ClearAllPoints()
    dialog.heading:SetPoint("TOPLEFT", PAD, -y)
    y = y + textHeight(dialog.heading) + 6
    dialog.table:ClearAllPoints()
    dialog.table:SetPoint("TOPLEFT", PAD, -y)
    y = y + dialog.table:Layout(inner) + PAD
    dialog.body:SetSize(inner + 2 * PAD, y)

    local foot = ns.Widgets.Flow(dialog.foot, { dialog.keep, dialog.use, dialog.open }, { width = WIDTH - 2 * PAD - 12 })
    local room = (tonumber(UIParent:GetHeight()) or 768) * 0.85 - CHROME - foot - FOOT_ROOM - PAD
    local shown = math.min(y, math.max(120, room))
    dialog.scroll:ClearAllPoints()
    dialog.scroll:SetPoint("TOPLEFT", dialog.Inset, "TOPLEFT", 0, 0)
    dialog.scroll:SetPoint("BOTTOMRIGHT", dialog.Inset, "BOTTOMRIGHT", -24, foot + FOOT_ROOM + PAD)
    dialog.foot:ClearAllPoints()
    dialog.foot:SetPoint("BOTTOMLEFT", dialog.Inset, "BOTTOMLEFT", 6, PAD / 2)
    dialog.foot:SetPoint("BOTTOMRIGHT", dialog.Inset, "BOTTOMRIGHT", -6, PAD / 2)
    dialog:SetSize(WIDTH, CHROME + shown + foot + FOOT_ROOM + PAD)
end

local function build()
    dialog = CreateFrame("Frame", "PetCallWelcome", UIParent, "ButtonFrameTemplate")
    Welcome._dialog = dialog
    ButtonFrameTemplate_HidePortrait(dialog)
    ButtonFrameTemplate_HideButtonBar(dialog)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:EnableMouse(true)
    dialog:SetTitle("PetCall")
    tinsert(UISpecialFrames, "PetCallWelcome")        -- Escape closes it, the same as Keep mine
    ns.Skin:Apply("Shell", dialog)
    ns.Skin:Apply("CloseButton", dialog.CloseButton)
    ns.Skin:Apply("Inset", dialog.Inset)
    ns.Widgets.Raise(dialog)

    dialog.scroll = CreateFrame("ScrollFrame", nil, dialog.Inset, "ScrollFrameTemplate")
    ns.Skin:Apply("ScrollBar", dialog.scroll.ScrollBar)
    dialog.body = CreateFrame("Frame", nil, dialog.scroll)
    dialog.body:SetSize(10, 10)
    dialog.scroll:SetScrollChild(dialog.body)
    local body = dialog.body
    dialog.headline = ns.Widgets.Label(body, L["PetCall works a little differently now"], "GameFontNormalLarge")
    dialog.line = ns.Widgets.Label(body, L["Everything PetCall does is now set in its own window. Your settings came along unchanged."])
    dialog.points = {}
    for i, path in ipairs(ICONS) do
        local icon = body:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(path)
        icon:SetSize(ICON, ICON)
        dialog.points[i] = { icon = icon, text = ns.Widgets.Label(body, "", "GameFontHighlight") }
    end
    dialog.heading = ns.Widgets.Label(body, L["How PetCall works for you now"], "GameFontNormal")
    dialog.table = ns.UI.Comparison.Build(body)

    dialog.foot = CreateFrame("Frame", nil, dialog.Inset)
    dialog.keep = ns.Widgets.Button(dialog.foot, L["Keep mine"], function() dialog:Hide() end)
    dialog.use = ns.Widgets.Button(dialog.foot, L["Use recommended"], function()
        if ns.UI.Comparison:HasChanges() then ns.Recommended:Apply() end
        dialog:Hide()
    end)
    dialog.open = ns.Widgets.Button(dialog.foot, L["Open PetCall"], function()
        dialog:Hide()
        ns.UI.Main:Show()
        ns.UI.Behaviour:Show()
    end)
    dialog.open:GetFontString():SetTextColor(ns.Skin:Accent())
    for _, b in ipairs({ dialog.keep, dialog.use, dialog.open }) do b.right = true end
    dialog:SetScript("OnHide", function(self) if not self.diagnostic then markSeen() end end)
end

-- diagnostic: opened by /pcall welcome, which leaves the account's "seen" mark alone
function Welcome:Show(diagnostic)
    if not dialog then build() end
    dialog.diagnostic = diagnostic == true
    dialog.table:Refresh()
    dialog:Show()
    layout()
end

local checked

local function announceLater()
    local facts = ns.db.profile.upgradeFacts
    if ns.db.global.welcomeSeen and facts and not facts.announced then
        facts.announced = true
        ns:Print(L["PetCall's settings moved into its window. Type /pcall to see them."])
    end
end

local waiting

local function showWhenFree()
    if InCombatLockdown() then
        if waiting then return end
        waiting = true
        Welcome:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            waiting = nil
            Welcome:UnregisterEvent("PLAYER_REGEN_ENABLED")
            showWhenFree()
        end)
        return
    end
    if ns.db.global.welcomePending then Welcome:Show(false) end
end

function Welcome:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        if checked then return end
        checked = true
        ns:After(2, function()
            if ns.db.global.welcomePending then showWhenFree() else announceLater() end
        end)
    end)
    -- a switch to a profile upgraded since; before the first check, login does this
    ns:RegisterCallback(self, "ProfileChanged", function()
        if checked and not ns.db.global.welcomePending then announceLater() end
    end)
end

-- the Undo link in the chat line after Use recommended
hooksecurefunc("SetItemRef", function(link)
    if link ~= LINK then return end
    if ns.Recommended:CanUndo() then
        ns.Recommended:Undo()
        ns:Print(L["Your earlier settings are back."])
    else
        ns:Print(L["Those settings can no longer be undone."])
    end
end)

ns:RegisterCallback(Welcome, "RecommendedApplied", function()
    ns:Print(format(L["Recommended settings applied. %s"], format("|cff33ff99|H%s|h[%s]|h|r", LINK, L["Undo"])))
end)
