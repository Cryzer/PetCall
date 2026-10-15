local _, ns = ...

local Skin = {}
ns.Skin = Skin

local S                 -- EllesmereUI skin API once available
local pending = {}      -- { kind, frame, args } registered before EUI's callback
local accentListeners = {}

function Skin:Apply(kind, frame, ...)
    if not frame then return end
    if S then
        if S[kind] then S[kind](frame, ...) end
    else
        pending[#pending + 1] = { kind, frame, { ... } }
    end
end

function Skin:SetTabSelected(tab, selected)
    if S and S.SetTabSelection then S.SetTabSelection(tab, selected) end
end

function Skin:Accent()
    if S and S.GetAccentColor then return S.GetAccentColor() end
    return 1, 0.82, 0
end

function Skin:IsActive() return S ~= nil end

function Skin:OnLooksChanged(fn) accentListeners[#accentListeners + 1] = fn end

if EllesmereUI and EllesmereUI.RegisterSkin then
    EllesmereUI.RegisterSkin("PetCall", function(api)
        S = api
        for _, p in ipairs(pending) do
            if S[p[1]] then S[p[1]](p[2], unpack(p[3])) end
        end
        pending = nil
        if S.OnLooksChanged then
            S.OnLooksChanged(function()
                for _, fn in ipairs(accentListeners) do fn() end
            end)
        end
    end)
else
    -- No EllesmereUI: keep nothing queued.
    Skin.Apply = function() end
end
