
local addon_name, addon = ...

local AceGUI        = LibStub("AceGUI-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")
local LibPetJournal = LibStub("LibPetJournal-2.0")

local C_PetJournal = C_PetJournal
local type, strfind, tinsert = type, strfind, tinsert

local EXPORT_PREFIX = "PetCall:1:"

-- ---------------------------------------------------------------------------
-- Serialization helpers
-- ---------------------------------------------------------------------------

-- Returns an export string for the named set, or nil + error.
-- The set name is intentionally excluded: the importer chooses their own name.
function addon:ExportSet(setName)
    local setData = addon.db.profile.sets[setName]
    if not setData then
        return nil, "Set not found: " .. tostring(setName)
    end

    -- Convert pets from {petGUID → weight} to {speciesID → weight} so the
    -- export string is portable across different accounts.
    local exportPets = {}
    for petGUID, weight in pairs(setData.pets) do
        if type(weight) == "number" then
            local speciesID = C_PetJournal.GetPetInfoByPetID(petGUID)
            if speciesID and speciesID > 0 then
                local cur = exportPets[speciesID]
                if cur == nil or weight > cur then
                    exportPets[speciesID] = weight
                end
            end
        end
    end

    local export = {
        enabled      = setData.enabled,
        priority     = setData.priority,
        defaultValue = setData.defaultValue,
        immediate    = setData.immediate,
        pets         = exportPets,
        filter       = setData.filter,
        trigger      = setData.trigger,
    }

    local str = AceSerializer:Serialize(export)
    if not str then return nil, "Serialization failed" end
    return EXPORT_PREFIX .. str
end

-- Imports a set from an export string using the caller-supplied name.
-- Returns true + newName on success, or nil + error message on failure.
function addon:ImportSet(str, newName)
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

    -- Validate the name supplied by the user.
    newName = newName and newName:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if #newName == 0 then
        return nil, "Please enter a name for the set"
    end
    -- Use rawget to bypass the AceDB $Default metatable: a plain table
    -- lookup would return the wildcard default for any key, making every
    -- name appear to already exist.
    if rawget(addon.db.profile.sets, newName) then
        return nil, "A set named \"" .. newName .. "\" already exists"
    end

    -- Convert pets from {speciesID → weight} to {petGUID → weight} using
    -- the importer's own pet collection. Pets whose species aren't owned
    -- are simply omitted.
    local importedPets = type(data.pets) == "table" and data.pets or {}
    local convertedPets = {}
    for _, petGUID in LibPetJournal:IteratePetIDs() do
        local speciesID = C_PetJournal.GetPetInfoByPetID(petGUID)
        if speciesID and importedPets[speciesID] ~= nil then
            convertedPets[petGUID] = importedPets[speciesID]
        end
    end

    -- Write validated data to DB.
    addon.db.profile.sets[newName] = {
        name         = newName,
        enabled      = data.enabled ~= false,
        priority     = type(data.priority)     == "number" and data.priority     or 1,
        defaultValue = type(data.defaultValue) == "number" and data.defaultValue or 0,
        immediate    = data.immediate or false,
        pets         = convertedPets,
        filter       = type(data.filter)  == "table" and data.filter  or {},
        trigger      = type(data.trigger) == "table" and data.trigger or {},
    }

    addon:ReloadSets()
    return true, newName
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
    frame:SetWidth(500)
    frame:SetHeight(185)
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)

    local hint = AceGUI:Create("Label")
    hint:SetText("All text is selected \226\128\148 press Ctrl+C to copy.")
    hint:SetFullWidth(true)
    frame:AddChild(hint)

    local eb = AceGUI:Create("MultiLineEditBox")
    eb:SetLabel("")
    eb:SetText(str)
    eb:SetFullWidth(true)
    eb:SetHeight(80)
    eb:DisableButton(true)

    -- Hook before AddChild: the editBox becomes visible when the layout engine
    -- shows it during AddChild, so OnShow fires at exactly the right moment.
    eb.editBox:HookScript("OnShow", function(self)
        self:SetFocus()
        self:HighlightText()
    end)

    frame:AddChild(eb)
end

-- ---------------------------------------------------------------------------
-- Import dialog
-- ---------------------------------------------------------------------------

function addon:ShowImportDialog(onImported)
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("PetCall \226\128\148 Import Set")
    frame:SetLayout("Flow")
    frame:SetWidth(500)
    frame:SetHeight(265)
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)

    local hint = AceGUI:Create("Label")
    hint:SetText("Paste a PetCall export string below:")
    hint:SetFullWidth(true)
    frame:AddChild(hint)

    local eb = AceGUI:Create("MultiLineEditBox")
    eb:SetLabel("")
    eb:SetFullWidth(true)
    eb:SetHeight(90)
    eb:DisableButton(true)

    eb.editBox:HookScript("OnShow", function(self)
        self:SetFocus()
    end)

    frame:AddChild(eb)

    local nameBox = AceGUI:Create("EditBox")
    nameBox:SetLabel("Set name:")
    nameBox:SetFullWidth(true)
    nameBox:DisableButton(true)
    frame:AddChild(nameBox)

    local statusLabel = AceGUI:Create("Label")
    statusLabel:SetFullWidth(true)
    frame:AddChild(statusLabel)

    local function doImport()
        local ok, result = addon:ImportSet(eb:GetText(), nameBox:GetText())
        if ok then
            if onImported then onImported() end
            AceGUI:Release(frame)
        else
            statusLabel:SetText("|cffffcc00" .. tostring(result) .. "|r")
        end
    end

    nameBox:SetCallback("OnEnterPressed", doImport)

    local importBtn = AceGUI:Create("Button")
    importBtn:SetText("Import")
    importBtn:SetFullWidth(true)
    importBtn:SetCallback("OnClick", doImport)
    frame:AddChild(importBtn)
end
