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
--   v:GetYaw()

local SCENE_TEMPLATE = "WrappedAndUnwrappedModelScene"
local HOLD, EASE = 0.8, 1.0
local FIT_WAIT = 1.2      -- seconds a model may take to load before it shows unfitted
local FILL = 0.8          -- part of the frame a fitted model may take
-- A fit further than this times the journal's distance means the model's box is
-- mostly empty space (Murkastrasza wants about 7x: a box ten times the pet, centred
-- far to the side; Burdened Soul about 3.75x: a box three times as tall as the soul).
-- Such a model keeps the journal's framing and stands still facing front: turning it
-- could swing it around a far-away centre. Big but honest models stay under it (Willie
-- wants about 2.1x in the square menu preview).
local MAX_BACK = 3
ns.UI.FIT_MAX_BACK = MAX_BACK      -- for tests

-- A box with three equal sides is a stand-in the client gives some models (Will of
-- Remornia: 7.99 on every side), not their shape: it says nothing about their size.
function ns.UI.IsStandInBox(dx, dy, dz)
    local hi, lo = math.max(dx, dy, dz), math.min(dx, dy, dz)
    return lo > 0 and hi / lo < 1.01
end

-- How far the camera must be to see a model whole in a frame of this shape. The
-- journal's camera is set up for the journal's frame; big pets (Willie, mounts-sized
-- pets) overflow a narrower or a square frame.
function ns.UI.FitDistance(dx, dy, dz, aspect, vfov)
    local tv = math.tan((vfov or 0.9) / 2)
    local th = tv * (aspect or 1)
    local wide = math.max(dx, dy)
    return math.max(dz / 2 / tv, wide / 2 / th) / FILL + wide / 2
end

local function sceneAvailable()
    return C_PetJournal.GetPetModelSceneInfoBySpeciesID ~= nil and C_XMLUtil ~= nil
        and C_XMLUtil.GetTemplateInfo ~= nil and C_XMLUtil.GetTemplateInfo(SCENE_TEMPLATE) ~= nil
end

local viewers = setmetatable({}, { __mode = "k" })

-- /pcall model: the numbers behind the model shown last, for odd models
function ns.UI.DumpModel()
    local last
    for v in pairs(viewers) do if v.info and (not last or v.loadedAt > last.loadedAt) then last = v end end
    if not last then return ns:Print("no model shown yet") end
    local info = last.info
    ns:Printf("%s: species %s, display %s", info.name or "?", tostring(info.speciesID), tostring(last.displayID))
    local actor = last.actor
    if actor and actor.GetActiveBoundingBox then
        local x1, y1, z1, x2, y2, z2 = actor:GetActiveBoundingBox()
        if x1 then
            ns:Printf("box %.2f x %.2f x %.2f, centre %.2f, %.2f, %.2f", x2 - x1, y2 - y1, z2 - z1,
                (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
        end
        local px, py, pz = actor:GetPosition()
        if type(px) == "number" then ns:Printf("actor position %.2f, %.2f, %.2f", px, py, pz) end
        local scale = actor:GetScale()
        if type(scale) == "number" then ns:Printf("actor scale %.2f", scale) end
    end
    local cam = last.frame.GetActiveCamera and last.frame:GetActiveCamera()
    if cam and cam.GetZoomDistance then
        ns:Printf("camera %.2f (journal %.2f), frame %dx%d", cam:GetZoomDistance(), last.baseZoom or -1,
            last.frame:GetWidth() or 0, last.frame:GetHeight() or 0)
    end
    ns:Printf("fitted to box %s, wants %.2f%s", last.fitBox or "?", last.want or -1, last.oddBox and " (odd box: journal framing kept)"
        or last.standIn and " (stand-in box: journal framing kept)" or "")
    for _, step in ipairs(last.trace or {}) do ns:Print(step) end
end

function ns.UI.NewModelViewer(parent, opts)
    opts = opts or {}
    local v = { angle = 0, holdUntil = 0, turnSpeed = opts.turnSpeed or 0.3 }
    viewers[v] = true
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

    -- only ever moves the camera back: small pets keep the journal's framing
    function v:Fit()
        if not useScene or not self.actor or not self.actor.GetActiveBoundingBox then return end
        local cam = self.frame.GetActiveCamera and self.frame:GetActiveCamera()
        if not cam or not cam.SetZoomDistance or not cam.GetZoomDistance then return end
        if self.actor.IsLoaded and not self.actor:IsLoaded() then return end
        local x1, y1, z1, x2, y2, z2 = self.actor:GetActiveBoundingBox()
        if not (x1 and x2) or x2 - x1 <= 0 then return end
        self.fitBox = format("%.2f x %.2f x %.2f", x2 - x1, y2 - y1, z2 - z1)
        -- the journal's distance for this pet, read once per load before we move it
        self.baseZoom = self.baseZoom or cam:GetZoomDistance()
        -- measured, but not worth fitting to: the journal's framing stays
        if ns.UI.IsStandInBox(x2 - x1, y2 - y1, z2 - z1) then self.standIn = true return true end
        local scale = self.actor.GetScale and self.actor:GetScale() or 1
        local w, h = self.frame:GetWidth(), self.frame:GetHeight()
        if not (w and h) or h <= 0 then return end
        local fov = cam.GetFieldOfView and cam:GetFieldOfView() or nil
        local want = ns.UI.FitDistance((x2 - x1) * scale, (y2 - y1) * scale, (z2 - z1) * scale, w / h, fov)
        self.want = want
        if want > self.baseZoom * MAX_BACK then
            self.oddBox = true
            self.angle = 0
            self:SetYaw(0)
            return true
        end
        if want > cam:GetZoomDistance() then
            if cam.GetMaxZoomDistance and cam.SetMaxZoomDistance and cam:GetMaxZoomDistance() < want then
                cam:SetMaxZoomDistance(want)
            end
            cam:SetZoomDistance(want)
            -- the camera glides to a new distance; the pet would show close up on the way
            if cam.SnapToTargetInterpolationZoom then cam:SnapToTargetInterpolationZoom() end
        end
        return true
    end

    -- what a fit depends on: the box, and the scale the actor sets once the model is in
    local function shape(actor)
        if actor.IsLoaded and not actor:IsLoaded() then return nil end
        local x1, y1, z1, x2, y2, z2 = actor:GetActiveBoundingBox()
        if not (x1 and x2) or x2 - x1 <= 0 then return nil end
        return format("%.2f x %.2f x %.2f, scale %.2f", x2 - x1, y2 - y1, z2 - z1, actor:GetScale() or 1)
    end

    -- the last load step by step, for /pcall model
    function v:Note(what)
        self.trace[#self.trace + 1] = format("%4d ms %s", (GetTime() - self.loadedAt) * 1000, what)
    end

    -- Fits the model to what it measures now, and fits it again from the journal's framing
    -- when that changed since (a model can report a box while it is still loading, and
    -- the actor sets its scale a frame after the model is in). The first fit shows it.
    function v:Settle()
        local seen = self.actor and shape(self.actor)
        if not seen or seen == self.fitShape then return end
        local cam = self.fitShape and self.frame:GetActiveCamera()
        if cam and self.baseZoom then
            cam:SetZoomDistance(self.baseZoom)
            if cam.SnapToTargetInterpolationZoom then cam:SnapToTargetInterpolationZoom() end
            self.oddBox, self.standIn, self.want = nil, nil, nil
        end
        if not self:Fit() then return end
        self.fitShape = seen
        self:Note(format("fitted to %s, camera %.2f", seen, tonumber(self.frame:GetActiveCamera():GetZoomDistance()) or 0))
        if self.fitUntil then self:Reveal("shown") end
    end

    -- The journal's camera is too close for some pets and the model would show there
    -- first, so it stays hidden until it is fitted. The actor says when it has set the
    -- model's size; every frame the shape is also looked at, and fitted once it comes
    -- the same twice in a row. A model that does not load in time shows unfitted.
    function v:FitPending()
        local seen = shape(self.actor)
        if seen and seen == self.lastShape then self:Settle() end
        self.lastShape = seen
        if self.fitUntil and GetTime() > self.fitUntil then self:Reveal("shown unfitted") end
    end
    function v:Reveal(what)
        self.fitUntil, self.lastShape = nil, nil
        self.actor:SetAlpha(self.alpha or 1)
        self:Note(what)
    end

    function v:FaceFront()
        self.angle, self.holdUntil = 0, GetTime() + HOLD
        self:SetYaw(0)
    end

    function v:Load(info)
        local displayID = info.displayID or select(12, C_PetJournal.GetPetInfoBySpeciesID(info.speciesID))
        self.info, self.displayID, self.loadedAt = info, displayID, GetTime()
        self.baseZoom, self.oddBox, self.want, self.standIn, self.fitBox = nil, nil, nil, nil, nil
        if useScene then
            local sceneID = C_PetJournal.GetPetModelSceneInfoBySpeciesID(info.speciesID)
            self.frame:TransitionToModelSceneID(sceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
            self.actor = self.frame:GetActorByTag("unwrapped")
            if self.actor then
                -- the scene may give the actor an alpha of its own: shown again with that
                -- (never 0: that is this viewer's own hiding, from a load cut short)
                local alpha = self.actor.GetAlpha and self.actor:GetAlpha() or 1
                self.alpha = alpha > 0 and alpha or 1
                self.actor:SetAlpha(0)
                self.trace, self.fitShape, self.lastShape = {}, nil, nil
                self.fitUntil = GetTime() + FIT_WAIT
                local token = self.loadedAt
                if self.actor.SetOnSizeChangedCallback then
                    self.actor:SetOnSizeChangedCallback(function()
                        if v.loadedAt ~= token then return end
                        v:Note("size set")
                        v:Settle()
                    end)
                end
                self.actor:SetModelByCreatureDisplayID(displayID, true)
                if Enum.ModelBlendOperation then self.actor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None) end
            end
        else
            self.frame:ClearModel()
            if displayID and displayID > 0 then self.frame:SetDisplayInfo(displayID) else self.frame:SetCreature(info.creatureID) end
        end
        self:FaceFront()
        -- once more a little later, for a box that changes after it was fitted
        if useScene and self.actor then
            local token = self.loadedAt
            ns:After(0.5, function() if v.loadedAt == token then v:Settle() end end)
        end
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
        if v.fitUntil then v:FitPending() end
        local dx = dragDelta()
        if dx then
            v.angle = v.angle + dx * 0.02
            v.holdUntil = 0                       -- the player took over
        else
            local t = GetTime() - v.holdUntil
            if t < 0 or v.oddBox then return end
            v.angle = v.angle + elapsed * v.turnSpeed * math.min(1, t / EASE)
        end
        v:SetYaw(v.angle)
    end)
    -- a PlayerModel load finishes later than requested; restart the hold when it appears
    if not useScene then v.frame:SetScript("OnModelLoaded", function() v:FaceFront() end) end
    return v
end
