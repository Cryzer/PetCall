local _, ns = ...

local C_Timer, CreateFrame, UIParent = C_Timer, CreateFrame, UIParent

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
    local current, hideScheduled

    function obj:ShowForPet(info, point, anchor, relPoint, xOff, yOff)
        if not info then return end
        hideScheduled = false
        container:ClearAllPoints()
        container:SetPoint(point, anchor, relPoint, xOff, yOff)
        container:Show()
        -- same pet and its model is there: nothing to do (a dropped load is retried)
        if current == info.creatureID and viewer:ModelID() then return end
        current = info.creatureID
        viewer:Load(info)
    end

    function obj:Hide()
        hideScheduled = false
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
