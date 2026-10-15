local _, ns = ...

local CreateFrame, GetTime = CreateFrame, GetTime
ns.UI = ns.UI or {}

-- 3-D pet model used by the preview panel and the floating previews.
-- Uses the Pet Journal's ModelScene (camera framed per species) when the client has
-- it, else a plain PlayerModel. After every (re)load the model faces front, holds
-- still, then eases into an idle turn, so a reload never makes it jump.
--
--   local v = ns.UI.NewModelViewer(parent, { mouse = true, turnSpeed = 0.3 })
--   v.frame                   the ModelScene / PlayerModel to anchor
--   v:Load(info)              PetCache info; resets the facing
--   v:Clear()  v:ModelID()    nil while nothing is loaded (or a load was dropped)
--   v:SetStatic(b)            no idle turn (models that orbit their root)
--   v:GetYaw()

local SCENE_TEMPLATE = "WrappedAndUnwrappedModelScene"
local HOLD, EASE = 0.8, 1.0

local function sceneAvailable()
    return C_PetJournal.GetPetModelSceneInfoBySpeciesID ~= nil and C_XMLUtil ~= nil
        and C_XMLUtil.GetTemplateInfo ~= nil and C_XMLUtil.GetTemplateInfo(SCENE_TEMPLATE) ~= nil
end

function ns.UI.NewModelViewer(parent, opts)
    opts = opts or {}
    local v = { angle = 0, holdUntil = 0, turnSpeed = opts.turnSpeed or 0.3 }
    local useScene = sceneAvailable()
    local dragging, lastX = false, nil

    if useScene then
        v.frame = CreateFrame("ModelScene", nil, parent, SCENE_TEMPLATE)
        if not opts.mouse then v.frame:EnableMouse(false) v.frame:EnableMouseWheel(false) end
    else
        v.frame = CreateFrame("PlayerModel", nil, parent)
        if opts.mouse then
            v.frame:EnableMouse(true)
            v.frame:EnableMouseWheel(true)
            v.frame:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then dragging, lastX = true, GetCursorPosition() end end)
            v.frame:SetScript("OnMouseUp", function() dragging = false end)
            v.frame:SetScript("OnMouseWheel", function(self, delta)
                self.zoom = math.max(-0.5, math.min(0.7, (self.zoom or 0) + delta * 0.1))
                self:SetPortraitZoom(self.zoom)
            end)
        end
    end

    function v:SetYaw(a)
        if useScene then
            if self.actor then self.actor:SetYaw(a) end
        else
            self.frame:SetFacing(a)
        end
    end

    function v:FaceFront()
        self.angle, self.holdUntil = 0, GetTime() + HOLD
        self:SetYaw(0)
    end

    function v:Load(info)
        local displayID = select(12, C_PetJournal.GetPetInfoBySpeciesID(info.speciesID))
        if useScene then
            local sceneID = C_PetJournal.GetPetModelSceneInfoBySpeciesID(info.speciesID)
            self.frame:TransitionToModelSceneID(sceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
            self.actor = self.frame:GetActorByTag("unwrapped")
            if self.actor then
                self.actor:SetModelByCreatureDisplayID(displayID)
                if Enum.ModelBlendOperation then self.actor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None) end
            end
        else
            self.frame:ClearModel()
            if displayID and displayID > 0 then self.frame:SetDisplayInfo(displayID) else self.frame:SetCreature(info.creatureID) end
        end
        self:FaceFront()
    end

    function v:Clear()
        if useScene then
            if self.actor then self.actor:ClearModel() end
        else
            self.frame:ClearModel()
        end
    end

    function v:ModelID()
        if useScene then return self.actor and self.actor:GetModelFileID() end
        return self.frame:GetModelFileID()
    end

    function v:SetStatic(b) self.static = b and true or false end
    function v:GetYaw() return self.angle end

    -- the scene rotates its own camera on drag; the idle turn pauses meanwhile
    local function dragDelta()
        if useScene then
            return (opts.mouse and v.frame:IsMouseOver() and IsMouseButtonDown("LeftButton")) and 0 or nil
        end
        if not dragging then return nil end
        local x = GetCursorPosition()
        local dx = x - lastX
        lastX = x
        return dx
    end

    v.frame:HookScript("OnUpdate", function(_, elapsed)
        local dx = dragDelta()
        if dx then
            v.angle = v.angle + dx * 0.02
            v.holdUntil = 0                       -- the player took over
        else
            local t = GetTime() - v.holdUntil
            if t < 0 or v.static then return end
            v.angle = v.angle + elapsed * v.turnSpeed * math.min(1, t / EASE)
        end
        v:SetYaw(v.angle)
    end)
    -- a PlayerModel load finishes later than requested; restart the hold when it appears
    if not useScene then v.frame:SetScript("OnModelLoaded", function() v:FaceFront() end) end
    return v
end
