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
    dialog:SetSize(520, 300)
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

    dialog.hint = ns.Widgets.Label(dialog.Inset, "")
    dialog.hint:SetPoint("TOPLEFT", 8, -8)
    dialog.hint:SetPoint("RIGHT", -8, 0)

    local sf = CreateFrame("ScrollFrame", nil, dialog.Inset, "ScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -28)
    sf:SetPoint("RIGHT", -28, 0)
    sf:SetHeight(140)
    dialog.text = CreateFrame("EditBox", nil, sf)
    dialog.text:SetMultiLine(true)
    dialog.text:SetFontObject("ChatFontNormal")
    dialog.text:SetWidth(460)
    dialog.text:SetAutoFocus(false)
    dialog.text:SetScript("OnEscapePressed", function() dialog:Hide() end)
    sf:SetScrollChild(dialog.text)

    dialog.nameLabel = ns.Widgets.Label(dialog.Inset, L["Set name:"])
    dialog.nameLabel:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -12)
    dialog.name = CreateFrame("EditBox", nil, dialog.Inset, "InputBoxTemplate")
    dialog.name:SetSize(220, 20)
    dialog.name:SetAutoFocus(false)
    dialog.name:SetPoint("LEFT", dialog.nameLabel, "RIGHT", 10, 0)
    ns.Skin:Apply("EditBox", dialog.name)

    dialog.status = ns.Widgets.Label(dialog.Inset, "", "GameFontHighlightSmall")
    dialog.status:SetPoint("TOPLEFT", dialog.nameLabel, "BOTTOMLEFT", 0, -10)
    dialog.status:SetPoint("RIGHT", -8, 0)
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
