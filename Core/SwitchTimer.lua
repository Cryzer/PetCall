local _, ns = ...

local SwitchTimer = ns:NewModule("SwitchTimer")
ns.SwitchTimer = SwitchTimer

function SwitchTimer:OnInitialize()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    -- the new profile may have a different (or no) timer
    ns:RegisterCallback(self, "ProfileChanged", function()
        SwitchTimer:Stop()
        if ns:GetCurrentPet() then SwitchTimer:Start() end
    end)
    -- each set may have its own interval
    ns:RegisterCallback(self, "CurrentSetChanged", function()
        if ns:GetCurrentPet() then SwitchTimer:Start() else SwitchTimer:Stop() end
    end)
end

function SwitchTimer:Start(noRestart)
    if self.timer then
        if noRestart then return end
        self.timer:Cancel()
        self.timer = nil
    end
    local set = ns.Sets and ns.Sets:GetCurrent()
    local minutes = set and set:GetSwitch() or 0
    if minutes > 0 then
        self.interval = minutes * 60
        self.timer = ns:After(self.interval, function() SwitchTimer:Fire() end)
    end
end

function SwitchTimer:Stop()
    if self.timer then self.timer:Cancel() self.timer = nil end
end

function SwitchTimer:Fire()
    self.timer = nil
    local set = ns.Sets:GetCurrent()
    if set and select(2, set:GetSwitch()) then
        -- a hidden (secret) value cannot be tested: wait for the next round
        local resting = IsResting()
        if (issecretvalue and issecretvalue(resting)) or not resting then return self:Start() end
    end
    ns.Ready:Request("switch", "auto")
end

function SwitchTimer:PLAYER_ENTERING_WORLD()
    if ns:GetCurrentPet() then self:Start() end
end

function SwitchTimer:ZONE_CHANGED_NEW_AREA()
    local p = ns.db.profile
    if p.switchOnNewMap or p.autoSwitch.onZone then
        ns:After(1, function()
            local zone = GetZoneText()
            if zone ~= SwitchTimer.lastZone then
                ns.Ready:Request("switch", "auto")
                SwitchTimer.lastZone = zone
            end
        end)
    end
end
