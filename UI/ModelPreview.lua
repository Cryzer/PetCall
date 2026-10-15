local _, ns = ...

local C_Timer, CreateFrame, UIParent = C_Timer, CreateFrame, UIParent

-- Creature IDs whose skeleton root is far from their visual centre: turning them
-- makes them orbit instead of spin, so they get a static pose.
-- Find a creature ID: /run print(select(11, C_PetJournal.GetPetInfoByPetID(petGUID)))
local STATIC_PREVIEW_CREATURES = {
    [181535] = true,  -- Murkastrasza
}

local HOVER_DELAY = 0.12   -- a mouse sweep over a list only loads the pet it stops on

ns.UI = ns.UI or {}
ns.UI.previews = ns.UI.previews or {}

-- Creates a floating 3-D preview (pet menu, narrow grid) on the shared model viewer.
--   obj:ShowForPet(info, point, anchor, relPoint, xOff, yOff)
--       Show and position the preview for a PetCache info; cheap to call on every OnEnter.
--   obj:ScheduleHide()   deferred hide (one frame): an OnLeave followed by OnEnter does not flicker
--   obj:Hide()           immediate hide
--   obj.frame, obj.viewer
function ns:CreateModelPreview(frameName)
    local container = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    container:SetSize(200, 200)
    container:SetFrameStrata("TOOLTIP")
    container:SetClampedToScreen(true)
    container:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    container:SetBackdropColor(0, 0, 0, 0.9)
    container:Hide()

    local viewer = ns.UI.NewModelViewer(container, { turnSpeed = math.pi / 4 })
    viewer.frame:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -4)
    viewer.frame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4, 4)

    local obj = { frame = container, viewer = viewer }
    local current, pendingLoad, hideScheduled

    local function cancelLoad()
        if pendingLoad then pendingLoad:Cancel() pendingLoad = nil end
    end

    function obj:ShowForPet(info, point, anchor, relPoint, xOff, yOff)
        if not info then return end
        hideScheduled = false
        container:ClearAllPoints()
        container:SetPoint(point, anchor, relPoint, xOff, yOff)
        container:Show()
        -- same pet and its model is there (or on its way): nothing to do
        if current == info.creatureID and (pendingLoad or viewer:ModelID()) then return end
        current = info.creatureID
        cancelLoad()
        viewer:Clear()
        pendingLoad = C_Timer.NewTimer(HOVER_DELAY, function()
            pendingLoad = nil
            if current ~= info.creatureID then return end
            viewer:SetStatic(STATIC_PREVIEW_CREATURES[info.creatureID])
            viewer:Load(info)
        end)
    end

    function obj:Hide()
        hideScheduled = false
        cancelLoad()
        current = nil
        viewer:Clear()
        container:Hide()
    end

    function obj:ScheduleHide()
        hideScheduled = true
        C_Timer.After(0, function()
            if hideScheduled then obj:Hide() end
        end)
    end

    ns.UI.previews[frameName] = obj
    return obj
end
