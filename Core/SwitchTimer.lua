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
    -- a new interval for the current set (its own or Default's) starts over; Off stops
    ns:RegisterCallback(self, "SetsChanged", function()
        local set = ns.Sets:GetCurrent()
        local minutes = set and set:GetSwitch() or 0
        if minutes * 60 == (SwitchTimer.timer and SwitchTimer.interval or 0) then return end
        if ns:GetCurrentPet() then SwitchTimer:Start() else SwitchTimer:Stop() end
    end)
    -- a round that came due while Off or Paused found nothing to do
    ns:RegisterCallback(self, "AutoSummonChanged", function()
        if ns:GetAutoState() == "on" and ns:GetCurrentPet() then SwitchTimer:Start(true) end
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
        self.interval, self.startedAt = minutes * 60, GetTime()
        self.timer = ns:After(self.interval, function() SwitchTimer:Fire() end)
    end
end

function SwitchTimer:Stop()
    if self.timer then self.timer:Cancel() self.timer = nil end
end

-- seconds until the next new pet, nil with no timer running
function SwitchTimer:Remaining()
    if not self.timer then return end
    return math.max(0, self.startedAt + self.interval - GetTime())
end

function SwitchTimer:Fire()
    self.timer = nil
    -- away, the game may have sat you down without a word: a summon then only puts the pet away
    local afk = UnitIsAFK("player")
    if not (issecretvalue and issecretvalue(afk)) and afk then return self:Start() end
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
    if ns.db.profile.switchOnNewMap then
        ns:After(1, function()
            local zone = GetZoneText()
            if zone ~= SwitchTimer.lastZone then
                ns.Ready:Request("switch", "auto")
                SwitchTimer.lastZone = zone
            end
        end)
    end
end
