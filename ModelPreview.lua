
local _, addon = ...

local C_Timer, CreateFrame, UIParent =
    C_Timer, CreateFrame, UIParent

local ROT_SPEED = math.pi / 4  -- 45°/s — full rotation in 8 s

-- Creature IDs whose skeleton root is significantly offset from their visual
-- centre; SetFacing() rotates around the root so they orbit instead of
-- spinning in place.  List the creatureID (not speciesID) here to show a
-- static pose instead.
-- Find a creature ID: /run print(select(11, C_PetJournal.GetPetInfoByPetID(petGUID)))
local STATIC_PREVIEW_CREATURES = {
    [181535] = true,  -- Murkastrasza
}

-- Creates and returns an independent 3-D model-preview object.
--   frameName  unique string used as the container frame name (/fstack debugging).
--
-- Returned object:
--   obj:ShowForCreature(creatureID, point, anchor, relPoint, xOff, yOff)
--       Show and position the preview.  No-ops if creatureID is already
--       loaded or loading — safe to call on every OnEnter.
--   obj:ScheduleHide()
--       Deferred hide (one frame).  Call from OnLeave; a rapid OnLeave→OnEnter
--       pair within the same frame cancels the hide without flickering.
--   obj:Hide()
--       Immediate hide.  Use when the owning panel closes or the list scrolls.
--   obj.frame
--       The underlying container Frame, for parenting or layout queries.
function addon:CreateModelPreview(frameName)
    local generation    = 0   -- bumped on each new ShowForCreature request
    local angle         = 0
    local hideScheduled = false

    -- Container: plain Frame + BackdropTemplate.
    -- Mixing PlayerModel with BackdropTemplate on the same frame breaks model
    -- methods in some WoW versions, so model and backdrop live on separate frames.
    local container = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    container:SetSize(200, 200)
    container:SetFrameStrata("TOOLTIP")
    container:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 32, edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    container:SetBackdropColor(0, 0, 0, 0.9)
    container:Hide()

    -- PlayerModel exposes SetCreature/SetDisplayInfo/SetFacing on all retail
    -- builds.  Plain Model lost SetCreature in TWW 11.0+.
    local model = CreateFrame("PlayerModel", nil, container)
    model:SetPoint("TOPLEFT",     container, "TOPLEFT",      4, -4)
    model:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -4,  4)

    model:SetScript("OnUpdate", function(self, elapsed)
        if not container.isStatic then
            angle = (angle + ROT_SPEED * elapsed) % (2 * math.pi)
            self:SetFacing(angle)
        end
    end)
    -- OnModelLoaded is registered per-request inside ShowForCreature so that
    -- each callback closure captures the generation value at call time.

    local obj = {}
    obj.frame = container

    function obj:ShowForCreature(creatureID, point, anchor, relPoint, xOff, yOff)
        hideScheduled = false
        obj.hoverFrame = anchor      -- track anchor so OnLeave can detect scroll-driven updates
        container:ClearAllPoints()
        container:SetPoint(point, anchor, relPoint, xOff, yOff)
        container:Show()

        if container.currentCreatureID == creatureID then return end  -- already correct

        container.currentCreatureID = creatureID
        angle = 0

        -- Capture the generation for this specific request.  If generation
        -- advances (a newer ShowForCreature arrived) before this load
        -- completes, the callback will see myGen ~= generation and bail.
        generation = generation + 1
        local myGen = generation

        model:SetScript("OnModelLoaded", function(self)
            if myGen ~= generation then return end  -- stale load; discard
            container.isStatic =
                STATIC_PREVIEW_CREATURES[container.currentCreatureID] or false
            self:SetFacing(0)
            angle = 0
        end)

        model:ClearModel()           -- remove stale geometry before the new load
        model:SetPosition(0, 0, 0)   -- reset any per-species model position offset
        model:SetCreature(creatureID)
    end

    function obj:ScheduleHide()
        hideScheduled = true
        C_Timer.After(0, function()
            if not hideScheduled then return end
            -- Invalidate any in-flight load so its OnModelLoaded is discarded.
            generation = generation + 1
            model:SetScript("OnModelLoaded", nil)
            container.currentCreatureID = nil  -- reset same-creature guard
            model:ClearModel()
            container:Hide()
            hideScheduled = false
        end)
    end

    function obj:Hide()
        hideScheduled = false
        generation = generation + 1
        model:SetScript("OnModelLoaded", nil)
        container.currentCreatureID = nil
        model:ClearModel()
        container:Hide()
    end

    return obj
end
