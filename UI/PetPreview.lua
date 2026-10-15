local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Preview = {}
ns.UI.Preview = Preview

local panel, model, set, hoverID, selectedID
local shownID, syncing
local angle, dragging, lastX = 0, false, nil

local function petToShow()
    return hoverID or selectedID or C_PetJournal.GetSummonedPetGUID()
end

function Preview:Attach(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(240)
    ns.Skin:Apply("Panel", panel, { inset = true })

    model = CreateFrame("PlayerModel", nil, panel)
    model:SetPoint("TOPLEFT", 4, -4)
    model:SetPoint("TOPRIGHT", -4, -4)
    model:SetHeight(220)
    model:EnableMouse(true)
    model:EnableMouseWheel(true)
    model:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then dragging, lastX = true, GetCursorPosition() end end)
    model:SetScript("OnMouseUp", function() dragging = false end)
    model:SetScript("OnMouseWheel", function(self, delta)
        local z = (self.zoom or 0) + delta * 0.1
        self.zoom = math.max(-0.5, math.min(0.7, z))
        self:SetPortraitZoom(self.zoom)
    end)
    model:SetScript("OnUpdate", function(self, elapsed)
        if dragging then
            local x = GetCursorPosition()
            angle = angle + (x - lastX) * 0.02
            lastX = x
        else
            angle = angle + elapsed * 0.3       -- slow idle rotation
        end
        self:SetFacing(angle)
    end)

    panel.name = ns.Widgets.Label(panel, "", "GameFontNormalLarge")
    panel.name:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 4, -6)
    panel.name:SetPoint("RIGHT", -6, 0)
    panel.sub = ns.Widgets.Label(panel, "", "GameFontHighlightSmall")
    panel.sub:SetPoint("TOPLEFT", panel.name, "BOTTOMLEFT", 0, -2)
    panel.sub:SetPoint("RIGHT", -6, 0)
    panel.source = ns.Widgets.Label(panel, "", "GameFontDisableSmall")
    panel.source:SetPoint("TOPLEFT", panel.sub, "BOTTOMLEFT", 0, -4)
    panel.source:SetPoint("RIGHT", -6, 0)
    panel.source:SetWordWrap(true)

    local steps = #ns.Weights.LEVELS - 1
    panel.slider = ns.Widgets.Slider(panel, 0, steps, steps, 3, function(v)
        -- the slider also reports our own SetValue calls; only user moves change weights,
        -- and only for the pet the panel is showing
        if syncing or not shownID or not set then return end
        local value = ns.Weights.LEVELS[math.floor(v + 0.5) + 1].value
        if ns.Weights.Nearest(set:GetPetWeight(shownID)) ~= value then set:SetPetWeight(shownID, value) end
    end, function(v) return ns.Weights.LEVELS[math.floor(v + 0.5) + 1].label end)
    panel.slider:SetPoint("TOPLEFT", panel.source, "BOTTOMLEFT", -2, -10)
    panel.slider:SetPoint("RIGHT", -6, 0)

    panel.chance = ns.Widgets.Label(panel, "", "GameFontHighlight")
    panel.chance:SetPoint("TOPLEFT", panel.slider, "BOTTOMLEFT", 2, -8)
    panel.chance:SetPoint("RIGHT", -6, 0)

    panel.summon = ns.Widgets.Button(panel, L["Summon"], function()
        local id = selectedID or hoverID
        if id then ns:SummonPet(id) end
    end)
    panel.summon:SetPoint("BOTTOMLEFT", 6, 6)
    panel.fav = ns.Widgets.Button(panel, "☆", function()
        local id = selectedID or hoverID
        if not id then return end
        local info = ns.PetCache:GetInfo(id)
        C_PetJournal.SetFavorite(id, info.isFavorite and 0 or 1)
    end)
    panel.fav:SetWidth(32)
    panel.fav:SetPoint("LEFT", panel.summon, "RIGHT", 4, 0)
    return panel
end

function Preview:ShowPet(petID, forSet)
    set = forSet or set
    if not panel then return end
    local info = petID and ns.PetCache:GetInfo(petID)
    shownID = info and petID or nil
    if not info then
        panel.name:SetText(L["No pet selected"])
        panel.sub:SetText("") panel.source:SetText("") panel.chance:SetText("")
        model:ClearModel()
        return
    end
    if model.creatureID ~= info.creatureID then
        model.creatureID = info.creatureID
        model:ClearModel()
        model:SetCreature(info.creatureID)
        angle = 0
    end
    local r, g, b = C_Item.GetItemQualityColor((info.quality or 2) - 1)
    panel.name:SetText(info.name)
    panel.name:SetTextColor(r, g, b)
    panel.sub:SetText(format("%s%s · %s %d · %s", info.customName and ("«" .. info.customName .. "» ") or "",
        _G["BATTLE_PET_NAME_" .. (info.petType or 0)] or "", L["Level"], info.level, _G["BATTLE_PET_BREED_QUALITY" .. (info.quality or 2)] or ""))
    local _, _, _, _, source = C_PetJournal.GetPetInfoBySpeciesID(info.speciesID)
    panel.source:SetText(source or "")
    if set then
        local w = set:GetPetWeight(petID)
        syncing = true
        for i, lvl in ipairs(ns.Weights.LEVELS) do
            if lvl.value == ns.Weights.Nearest(w) then panel.slider:SetValue(i - 1) end
        end
        syncing = false
        local chance, reason = set:GetChance(petID)
        panel.chance:SetText(format(L["Chance in this set: %.1f%%"], chance * 100) .. (reason and ("\n|cffff8040" .. reason .. "|r") or ""))
    end
    panel.fav:SetText(info.isFavorite and "★" or "☆")
end

function Preview:SetHover(petID) hoverID = petID self:ShowPet(petToShow()) end
function Preview:SetSelected(petID) selectedID = petID self:ShowPet(petToShow()) end
function Preview:Refresh() self:ShowPet(petToShow()) end
function Preview:GetPanel() return panel end
