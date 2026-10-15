local _, ns = ...

local L = ns.L
local CreateFrame = CreateFrame
ns.UI = ns.UI or {}
local Preview = {}
ns.UI.Preview = Preview

local panel, model, set, hoverID, selectedID
local shownID, syncing
local loadModel        -- assigned above Preview:ShowPet
local angle, dragging, lastX = 0, false, nil
-- after a (re)load the model faces front, holds still, then eases into the idle turn
local HOLD, EASE, TURN_SPEED = 0.8, 1.0, 0.3
local holdUntil = 0

local function faceFront()
    angle, holdUntil = 0, GetTime() + HOLD
    if model then model:SetFacing(0) end
end

-- a selected pet stays in the panel; hovering only previews while nothing is selected
local function petToShow()
    return selectedID or hoverID or C_PetJournal.GetSummonedPetGUID()
end

function Preview:Attach(parent)
    panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(240)
    ns.Skin:Apply("Panel", panel, { inset = true })

    model = CreateFrame("PlayerModel", nil, panel)
    panel.model = model
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
            holdUntil = 0                       -- the player took over
        else
            local t = GetTime() - holdUntil
            if t < 0 then return end
            angle = angle + elapsed * TURN_SPEED * math.min(1, t / EASE)
        end
        self:SetFacing(angle)
    end)
    -- loads finish later than they are requested; restart the hold when the model appears
    model:SetScript("OnModelLoaded", faceFront)

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

    -- weight label above the slider: the slider's own side label does not fit the panel
    panel.weight = ns.Widgets.Label(panel, "", "GameFontNormal")
    panel.weight:SetPoint("TOPLEFT", panel.source, "BOTTOMLEFT", 0, -12)
    panel.weight:SetPoint("RIGHT", -6, 0)

    local steps = #ns.Weights.LEVELS - 1
    panel.slider = ns.Widgets.Slider(panel, 0, steps, steps, 3, function(v)
        -- the slider also reports our own SetValue calls; only user moves change weights,
        -- and only for the pet the panel is showing
        if syncing or not shownID or not set then return end
        local value = ns.Weights.LEVELS[math.floor(v + 0.5) + 1].value
        if ns.Weights.Nearest(set:GetPetWeight(shownID)) ~= value then set:SetPetWeights(ns.PetCache:GetCopies(shownID), value) end
    end)
    panel.slider:SetPoint("TOPLEFT", panel.weight, "BOTTOMLEFT", -2, -4)
    panel.slider:SetPoint("RIGHT", -6, 0)

    panel.chance = ns.Widgets.Label(panel, "", "GameFontHighlight")
    panel.chance:SetPoint("TOPLEFT", panel.slider, "BOTTOMLEFT", 2, -8)
    panel.chance:SetPoint("RIGHT", -6, 0)

    panel.summon = ns.Widgets.Button(panel, L["Summon"], function()
        if shownID then ns:SummonPet(shownID) end
    end)
    panel.summon:SetPoint("BOTTOMLEFT", 6, 6)
    panel.fav = CreateFrame("Button", nil, panel)
    panel.fav:SetSize(22, 22)
    panel.fav:SetPoint("LEFT", panel.summon, "RIGHT", 6, 0)
    panel.fav:SetNormalTexture("Interface\\COMMON\\FavoritesIcon")
    panel.fav:SetHighlightTexture("Interface\\COMMON\\FavoritesIcon", "ADD")
    panel.fav:SetScript("OnClick", function()
        if not shownID then return end
        local info = ns.PetCache:GetInfo(shownID)
        C_PetJournal.SetFavorite(shownID, info.isFavorite and 0 or 1)
    end)
    ns.Widgets.Tooltip(panel.fav, function()
        local info = shownID and ns.PetCache:GetInfo(shownID)
        return info and info.isFavorite and L["Remove favorite"] or L["Set favorite"]
    end)
    return panel
end

-- Model loads are asynchronous and the client drops some when flooded, so a mouse
-- sweep over the grid only loads the pet it stops on. The species' display ID is
-- more reliable than SetCreature, which needs the creature in the client cache.
local HOVER_DELAY = 0.12
local pendingLoad

function loadModel(info, fromHover)
    if pendingLoad then pendingLoad:Cancel() pendingLoad = nil end
    local function load()
        pendingLoad = nil
        if model.creatureID ~= info.creatureID then return end   -- moved on meanwhile
        model:ClearModel()
        faceFront()
        local displayID = select(12, C_PetJournal.GetPetInfoBySpeciesID(info.speciesID))
        if displayID and displayID > 0 then model:SetDisplayInfo(displayID) else model:SetCreature(info.creatureID) end
    end
    if fromHover then pendingLoad = C_Timer.NewTimer(HOVER_DELAY, load) else load() end
end

function Preview:ShowPet(petID, forSet)
    set = forSet or set
    if not panel then return end
    local info = petID and ns.PetCache:GetInfo(petID)
    shownID = info and petID or nil
    if not info then
        panel.name:SetText(L["No pet selected"])
        panel.sub:SetText("") panel.source:SetText("") panel.chance:SetText("") panel.weight:SetText("")
        model:ClearModel()
        model.creatureID = nil      -- forget it, or the same pet would not be loaded again
        return
    end
    -- (re)load when the pet changed or the client dropped the previous load
    if model.creatureID ~= info.creatureID or not model:GetModelFileID() then
        model.creatureID = info.creatureID
        loadModel(info, petID ~= selectedID)
    end
    local r, g, b = C_Item.GetItemQualityColor((info.quality or 2) - 1)
    panel.name:SetText(info.name)
    panel.name:SetTextColor(r, g, b)
    panel.sub:SetText(format("%s%s · %s %d · %s", info.customName and ("«" .. info.customName .. "» ") or "",
        _G["BATTLE_PET_NAME_" .. (info.petType or 0)] or "", L["Level"], info.level, _G["BATTLE_PET_BREED_QUALITY" .. (info.quality or 2)] or ""))
    local copies = ns.PetCache:GetCopies(petID)
    if #copies > 1 then panel.sub:SetText(panel.sub:GetText() .. " · " .. format(L["%d copies"], #copies)) end
    local _, _, _, _, source = C_PetJournal.GetPetInfoBySpeciesID(info.speciesID)
    panel.source:SetText(source or "")
    if set then
        local w = set:GetPetWeight(petID)
        panel.weight:SetText(L["Weight"] .. ": |cffffffff" .. ns.Weights.Label(w) .. "|r")
        syncing = true
        for i, lvl in ipairs(ns.Weights.LEVELS) do
            if lvl.value == ns.Weights.Nearest(w) then panel.slider:SetValue(i - 1) end
        end
        syncing = false
        -- every copy of the pet is a separate ticket in the draw
        local chance, reason = 0, nil
        for _, id in ipairs(copies) do
            local c, r = set:GetChance(id)
            chance, reason = chance + c, reason or r
        end
        panel.chance:SetText(format(L["Chance in this set: %.1f%%"], chance * 100) .. (reason and ("\n|cffff8040" .. reason .. "|r") or ""))
    end
    panel.fav:GetNormalTexture():SetDesaturated(not info.isFavorite)
    panel.fav:GetNormalTexture():SetAlpha(info.isFavorite and 1 or 0.4)
end

function Preview:SetHover(petID) hoverID = petID self:ShowPet(petToShow()) end
function Preview:SetSelected(petID) selectedID = petID self:ShowPet(petToShow()) end
function Preview:Refresh() self:ShowPet(petToShow()) end
function Preview:GetPanel() return panel end
function Preview:GetSelected() return selectedID end
function Preview:GetShown() return shownID end
