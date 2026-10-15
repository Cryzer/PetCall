local _, ns = ...

local L = ns.L
ns.UI = ns.UI or {}
local P = {}
ns.UI.Profiles = P

local frame

local function refresh()
    if not frame then return end
    frame.current:GenerateMenu()
    frame.copy:GenerateMenu()
    frame.delete:GenerateMenu()
end

local function profileMenu(onPick, skipCurrent)
    return function(owner, root)
        for _, name in ipairs(ns.DB:List()) do
            if not (skipCurrent and name == ns.DB:Current()) then
                root:CreateRadio(name, function() return not skipCurrent and name == ns.DB:Current() end, function() onPick(name) end)
            end
        end
    end
end

local function report(ok, err) if not ok and err then UIErrorsFrame:AddMessage(err, 1, 0.3, 0.3) end refresh() end

function P:Register(parent)
    frame = CreateFrame("Frame")
    frame:Hide()
    local y = -16
    local function row(label, control)
        local l = ns.Widgets.Label(frame, label)
        l:SetPoint("TOPLEFT", 16, y)
        l:SetWidth(180)
        control:SetPoint("LEFT", l, "RIGHT", 10, 0)
        y = y - 36
        return control
    end
    frame.current = row(L["Current profile"], ns.Widgets.Dropdown(frame, 220, profileMenu(function(n) report(ns.DB:Set(n)) end)))
    local new = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    new:SetSize(200, 20)
    new:SetAutoFocus(false)
    new:SetScript("OnEnterPressed", function(self) report(ns.DB:Set(self:GetText())) self:SetText("") self:ClearFocus() end)
    row(L["New profile (Enter)"], new)
    frame.copy = row(L["Copy from"], ns.Widgets.Dropdown(frame, 220, profileMenu(function(n)
        StaticPopup_Show("PETCALL_CONFIRM", format(L["Overwrite the current profile with \"%s\"?"], n), nil, { onAccept = function() report(ns.DB:Copy(n)) end })
    end, true)))
    frame.delete = row(L["Delete profile"], ns.Widgets.Dropdown(frame, 220, profileMenu(function(n)
        StaticPopup_Show("PETCALL_CONFIRM", format(L["Delete profile \"%s\"?"], n), nil, { onAccept = function() report(ns.DB:Delete(n)) end })
    end, true)))
    local reset = ns.Widgets.Button(frame, L["Reset current profile"], function()
        StaticPopup_Show("PETCALL_CONFIRM", L["Reset the current profile to defaults?"], nil, { onAccept = function() ns.DB:Reset() refresh() end })
    end)
    reset:SetPoint("TOPLEFT", 16, y)
    frame:SetScript("OnShow", refresh)
    Settings.RegisterCanvasLayoutSubcategory(parent, frame, L["Profiles"])
end

ns:RegisterCallback(P, "ProfileChanged", refresh)
