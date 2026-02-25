
local addon_name, addon = ...

local AceGUI      = LibStub("AceGUI-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")

local type, strfind, tinsert = type, strfind, tinsert

local EXPORT_PREFIX = "PetCall:1:"

-- ---------------------------------------------------------------------------
-- Serialization helpers
-- ---------------------------------------------------------------------------

-- Returns an export string for the named set, or nil + error.
function addon:ExportSet(setName)
    local setData = addon.db.profile.sets[setName]
    if not setData then
        return nil, "Set not found: " .. tostring(setName)
    end

    local export = {
        name         = setData.name,
        enabled      = setData.enabled,
        priority     = setData.priority,
        defaultValue = setData.defaultValue,
        immediate    = setData.immediate,
        pets         = setData.pets,
        filter       = setData.filter,
        trigger      = setData.trigger,
    }

    local ok, str = AceSerializer:Serialize(export)
    if not ok then return nil, "Serialization failed" end
    return EXPORT_PREFIX .. str
end

-- Imports a set from an export string. Returns true + new set name on
-- success, or nil + error message on failure.
function addon:ImportSet(str)
    str = str and str:gsub("^%s+", ""):gsub("%s+$", "") or ""

    if str:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
        return nil, "Invalid import string (missing PetCall prefix)"
    end

    local ok, data = AceSerializer:Deserialize(str:sub(#EXPORT_PREFIX + 1))
    if not ok then
        return nil, "Corrupt import string: " .. tostring(data)
    end
    if type(data) ~= "table" then
        return nil, "Invalid data format"
    end

    -- Determine a unique key in the sets table
    local baseName = (type(data.name) == "string" and #data.name > 0)
                     and data.name or "Imported Set"
    local setName  = baseName
    local i = 2
    while addon.db.profile.sets[setName] do
        setName = baseName .. " (" .. i .. ")"
        i = i + 1
    end

    -- Write validated data to DB
    addon.db.profile.sets[setName] = {
        name         = data.name or setName,
        enabled      = data.enabled ~= false,
        priority     = type(data.priority)     == "number" and data.priority     or 1,
        defaultValue = type(data.defaultValue) == "number" and data.defaultValue or 0,
        immediate    = data.immediate or false,
        pets         = type(data.pets)    == "table" and data.pets    or {},
        filter       = type(data.filter)  == "table" and data.filter  or {},
        trigger      = type(data.trigger) == "table" and data.trigger or {},
    }

    addon:ReloadSets()
    return true, setName
end

-- ---------------------------------------------------------------------------
-- Export dialog
-- ---------------------------------------------------------------------------

function addon:ShowExportDialog(setName)
    local str, err = self:ExportSet(setName)
    if not str then
        self:Print("Export failed: " .. tostring(err))
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("PetCall \226\128\148 Export: " .. setName)
    frame:SetLayout("Flow")
    frame:SetWidth(540)
    frame:SetHeight(270)
    frame:EnableResize(false)
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)

    local hint = AceGUI:Create("Label")
    hint:SetText("Copy the string below and share it with others:")
    hint:SetFullWidth(true)
    frame:AddChild(hint)

    local eb = AceGUI:Create("MultiLineEditBox")
    eb:SetLabel("")
    eb:SetText(str)
    eb:SetFullWidth(true)
    eb:SetHeight(160)
    eb:DisableButton(true)
    frame:AddChild(eb)

    -- Select all text so the user can immediately Ctrl+C
    C_Timer.After(0.05, function()
        if eb.editBox then
            eb.editBox:SetFocus()
            eb.editBox:HighlightText()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Import dialog
-- ---------------------------------------------------------------------------

function addon:ShowImportDialog(onImported)
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("PetCall \226\128\148 Import Set")
    frame:SetLayout("Flow")
    frame:SetWidth(540)
    frame:SetHeight(310)
    frame:EnableResize(false)
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)

    local hint = AceGUI:Create("Label")
    hint:SetText("Paste a PetCall export string below, then click Import:")
    hint:SetFullWidth(true)
    frame:AddChild(hint)

    local eb = AceGUI:Create("MultiLineEditBox")
    eb:SetLabel("")
    eb:SetFullWidth(true)
    eb:SetHeight(160)
    eb:DisableButton(true)
    frame:AddChild(eb)

    local statusLabel = AceGUI:Create("Label")
    statusLabel:SetFullWidth(true)
    frame:AddChild(statusLabel)

    local importBtn = AceGUI:Create("Button")
    importBtn:SetText("Import")
    importBtn:SetCallback("OnClick", function()
        local ok, result = addon:ImportSet(eb:GetText())
        if ok then
            statusLabel:SetText("|cff77cc77\226\156\147 Imported as: " .. result .. "|r")
            if onImported then onImported() end
        else
            statusLabel:SetText("|cffff4444\226\156\151 Error: " .. tostring(result) .. "|r")
        end
    end)
    frame:AddChild(importBtn)

    C_Timer.After(0.05, function()
        if eb.editBox then eb.editBox:SetFocus() end
    end)
end
