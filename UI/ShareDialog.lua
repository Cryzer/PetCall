local _, ns = ...

local L = ns.L
ns.UI = ns.UI or {}
local Share = {}
ns.UI.Share = Share

local dialog

local function build()
    dialog = CreateFrame("Frame", "PetCallShareDialog", UIParent, "ButtonFrameTemplate")
    ButtonFrameTemplate_HidePortrait(dialog)
    ButtonFrameTemplate_HideButtonBar(dialog)
    dialog:SetSize(520, 320)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    tinsert(UISpecialFrames, "PetCallShareDialog")
    ns.Skin:Apply("Shell", dialog)
    ns.Skin:Apply("CloseButton", dialog.CloseButton)
    ns.Skin:Apply("Inset", dialog.Inset)
    -- it opens over the window: opaque and edged, so the pets under it do not show through
    ns.Widgets.Raise(dialog)

    dialog.hint = ns.Widgets.Label(dialog.Inset, "")
    dialog.hint:SetPoint("TOPLEFT", 8, -8)
    dialog.hint:SetPoint("RIGHT", -8, 0)

    -- the text sits in a box that looks like a field: clicking anywhere in it types there
    dialog.field = CreateFrame("Button", nil, dialog.Inset)
    dialog.field:SetPoint("TOPLEFT", 6, -26)
    dialog.field:SetPoint("RIGHT", -6, 0)
    dialog.field:SetHeight(148)
    dialog.field.bg = dialog.field:CreateTexture(nil, "BACKGROUND")
    dialog.field.bg:SetAllPoints()
    dialog.field.bg:SetColorTexture(0, 0, 0, 0.5)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local line = dialog.field:CreateTexture(nil, "BORDER")
        line:SetColorTexture(1, 1, 1, 0.2)
        line:SetPoint(side[1])
        line:SetPoint(side[2])
        line:SetHeight(1)
    end
    for _, side in ipairs({ { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local line = dialog.field:CreateTexture(nil, "BORDER")
        line:SetColorTexture(1, 1, 1, 0.2)
        line:SetPoint(side[1])
        line:SetPoint(side[2])
        line:SetWidth(1)
    end
    dialog.field:SetScript("OnClick", function() dialog.text:SetFocus() end)

    local sf = CreateFrame("ScrollFrame", nil, dialog.field, "ScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -4)
    sf:SetPoint("BOTTOMRIGHT", -24, 4)
    dialog.text = CreateFrame("EditBox", nil, sf)
    dialog.text:SetMultiLine(true)
    dialog.text:SetFontObject("ChatFontNormal")
    dialog.text:SetWidth(460)
    dialog.text:SetAutoFocus(false)
    dialog.text:SetScript("OnEscapePressed", function() dialog:Hide() end)
    sf:SetScrollChild(dialog.text)

    dialog.nameLabel = ns.Widgets.Label(dialog.Inset, L["Set name:"])
    dialog.nameLabel:SetPoint("TOPLEFT", dialog.field, "BOTTOMLEFT", 2, -12)
    dialog.name = CreateFrame("EditBox", nil, dialog.Inset, "InputBoxTemplate")
    dialog.name:SetSize(220, 20)
    dialog.name:SetAutoFocus(false)
    dialog.name:SetPoint("LEFT", dialog.nameLabel, "RIGHT", 10, 0)
    ns.Skin:Apply("EditBox", dialog.name)

    dialog.status = ns.Widgets.Label(dialog.Inset, "", "GameFontHighlightSmall")
    dialog.status:SetPoint("TOPLEFT", dialog.nameLabel, "BOTTOMLEFT", 0, -10)
    dialog.status:SetWordWrap(true)

    dialog.import = ns.Widgets.Button(dialog.Inset, L["Import"], function()
        local ok, result, info = ns.Share:Import(dialog.text:GetText(), dialog.name:GetText())
        if not ok then
            dialog.status:SetText("|cffff4040" .. tostring(result) .. "|r")
            return
        end
        dialog:Hide()
        ns.UI.Main:Show()
        ns.UI.Main:SelectSet(result)
        if info.hasLuaCode then
            ns:Print(L["The imported set contains Lua code. It is disabled until you review it in the When tab."])
            ns.UI.Main:SelectTab("when")
        end
    end)
    dialog.import:SetPoint("BOTTOMRIGHT", -8, 8)
    -- an error wraps beside the button, never under it
    dialog.status:SetPoint("RIGHT", dialog.import, "LEFT", -8, 0)
    dialog.name:SetScript("OnEnterPressed", function() dialog.import:Click() end)
end

function Share:ShowExport(name)
    if not dialog then build() end
    local str, err = ns.Share:Export(name)
    dialog:SetTitle(format(L["Export: %s"], ns.Sets:Get(name):DisplayName()))
    dialog.hint:SetText(L["All text is selected – press Ctrl+C to copy."])
    dialog.text:SetText(str or err)
    for _, w in ipairs({ dialog.nameLabel, dialog.name, dialog.status, dialog.import }) do w:Hide() end
    dialog:Show()
    dialog.text:SetFocus()
    dialog.text:HighlightText()
end

function Share:ShowImport()
    if not dialog then build() end
    dialog:SetTitle(L["Import set"])
    dialog.hint:SetText(L["Paste a PetCall export string below:"])
    dialog.text:SetText("")
    dialog.name:SetText("")
    dialog.status:SetText("")
    for _, w in ipairs({ dialog.nameLabel, dialog.name, dialog.status, dialog.import }) do w:Show() end
    dialog:Show()
    dialog.text:SetFocus()
end
