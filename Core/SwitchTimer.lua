local _, ns = ...

local SwitchTimer = ns:NewModule("SwitchTimer")
ns.SwitchTimer = SwitchTimer

function SwitchTimer:OnInitialize()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end

function SwitchTimer:Start(noRestart)
    if self.timer then
        if noRestart then return end
        self.timer:Cancel()
        self.timer = nil
    end
    local cfg = ns.db.profile.autoSwitch
    if cfg.timer then
        self.timer = ns:After(cfg.timerValue, function() SwitchTimer:Fire() end)
    end
end

function SwitchTimer:Stop()
    if self.timer then self.timer:Cancel() self.timer = nil end
end

function SwitchTimer:Fire()
    self.timer = nil
    if ns.db.profile.autoSwitch.citiesOnly and not IsResting() then return self:Start() end
    ns:ResummonPet()
end

function SwitchTimer:PLAYER_ENTERING_WORLD()
    if ns:GetCurrentPet() then self:Start() end
end

function SwitchTimer:ZONE_CHANGED_NEW_AREA()
    if ns.db.profile.autoSwitch.onZone then
        ns:After(1, function()
            local zone = GetZoneText()
            if zone ~= SwitchTimer.lastZone then
                ns.Ready:QueueResummon()
                SwitchTimer.lastZone = zone
            end
        end)
    end
end
