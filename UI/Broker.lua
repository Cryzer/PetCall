local _, ns = ...

local L = ns.L
ns.UI = ns.UI or {}
local Broker = {}
ns.UI.Broker = Broker

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")
local ICON = "Interface\\AddOns\\PetCall\\Media\\icon"
local obj

function Broker:FillTooltip(tt)
    tt:AddLine("PetCall")
    tt:AddDoubleLine(L["Auto-summon"], ns:IsAutoSummon() and ("|cff40ff40" .. L["On"] .. "|r") or ("|cffff4040" .. L["Off"] .. "|r"))
    local set = ns.Sets:GetCurrent()
    tt:AddDoubleLine(L["Active set"], set and set:DisplayName() or NONE, nil, nil, nil, 1, 1, 1)
    local pet = ns:GetCurrentPet()
    local info = pet and ns.PetCache:GetInfo(pet)
    tt:AddDoubleLine(L["Pet"], info and (info.customName or info.name) or L["none"], nil, nil, nil, 1, 1, 1)
    local blockers = ns.Ready:GetBlockers()
    if #blockers > 0 then
        local labels = {}
        for _, b in ipairs(blockers) do labels[#labels + 1] = b.label end
        tt:AddLine(L["Paused by"] .. ": " .. table.concat(labels, ", "), 1, 0.7, 0.25, true)
    end
    tt:AddLine(format(L["You have %d pets"], ns.PetCache:NumPets()), 0.6, 0.6, 0.6)
    tt:AddLine(" ")
    tt:AddLine("|cff69b950" .. L["Left-Click:"] .. "|r " .. L["Toggle Non-Combat Pet"], 1, 1, 1)
    tt:AddLine("|cff69b950" .. L["Right-Click:"] .. "|r " .. L["Pet Menu"], 1, 1, 1)
    tt:AddLine("|cff69b950" .. L["Ctrl + Click:"] .. "|r " .. L["Open PetCall"], 1, 1, 1)
end

function Broker:OnClick(frame, button)
    if IsControlKeyDown() then
        ns:OpenWindow()
    elseif button == "RightButton" then
        ns.UI.Menu:Open()
    else
        ns:TogglePet()
    end
end

local function update()
    if not obj then return end
    local pet = ns:GetCurrentPet()
    local info = pet and ns.PetCache:GetInfo(pet)
    obj.text = info and (info.customName or info.name) or "PetCall"
    local on = ns:IsAutoSummon()
    obj.iconR, obj.iconG, obj.iconB = 1, on and 1 or 0.3, on and 1 or 0.3
end

function Broker:SetMinimapShown(v)
    if v then LDBIcon:Show("PetCall") else LDBIcon:Hide("PetCall") end
end

local loader = {}
ns.Events.Register(loader, "PLAYER_LOGIN", function()
    ns.Events.Unregister(loader, "PLAYER_LOGIN")
    obj = LDB:NewDataObject("PetCall", {
        type = "data source", label = "PetCall", text = "PetCall", icon = ICON,
        OnClick = function(frame, button) Broker:OnClick(frame, button) end,
        OnTooltipShow = function(tt) Broker:FillTooltip(tt) end,
    })
    LDBIcon:Register("PetCall", obj, ns.db.profile.minimap)
    update()
end)

for _, cb in ipairs({ "SummonedPetChanged", "AutoSummonChanged", "PetsChanged", "CurrentSetChanged" }) do
    ns:RegisterCallback(Broker, cb, update)
end
ns:RegisterCallback(Broker, "ProfileChanged", function()
    LDBIcon:Refresh("PetCall", ns.db.profile.minimap)
    update()
end)

function PetCall_OnAddonCompartmentClick(_, button) Broker:OnClick(AddonCompartmentFrame, button) end
function PetCall_OnAddonCompartmentEnter(_, frame)
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    Broker:FillTooltip(GameTooltip)
    GameTooltip:Show()
end
function PetCall_OnAddonCompartmentLeave() GameTooltip:Hide() end
