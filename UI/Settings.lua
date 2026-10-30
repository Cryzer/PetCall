local _, ns = ...

local L = ns.L
ns.UI = ns.UI or {}
local S = {}
ns.UI.Settings = S

local category, layout

local function onChanged() ns.Ready:UpdateChecks() end

local function proxy(key, varType, label, default, get, set, tooltip, kind, options)
    local setting = Settings.RegisterProxySetting(category, "PETCALL_" .. key, varType, label, default, get, set)
    if kind == "slider" then
        Settings.CreateSlider(category, setting, options, tooltip)
    elseif kind == "dropdown" then
        Settings.CreateDropdown(category, setting, options, tooltip)
    else
        Settings.CreateCheckbox(category, setting, tooltip)
    end
    return setting
end

local function profileBool(key, label, tooltip, after)
    return proxy(key, Settings.VarType.Boolean, label, ns.DB.defaults[key],
        function() return ns.db.profile[key] end,
        function(v) ns:SetProfileValue(key, v) onChanged() if after then after(v) end end, tooltip)
end

-- three-state "where" lists map onto the 1.x pair of booleans
local function whereSetting(key, label, tooltip, enableKey, dismissKey)
    local function get()
        local p = ns.db.profile
        if p[dismissKey] then return 3 end
        return p[enableKey] and 1 or 2
    end
    local function set(v)
        local p = ns.db.profile
        p[enableKey], p[dismissKey] = v == 1, v == 3
        onChanged()
    end
    local function options()
        local c = Settings.CreateControlTextContainer()
        c:Add(1, L["Summon"])
        c:Add(2, L["Don't summon"])
        c:Add(3, L["Dismiss"])
        return c:GetData()
    end
    proxy(key, Settings.VarType.Number, label, 1, get, set, tooltip, "dropdown", options)
end

local function header(text) layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text)) end

local function build()
    category, layout = Settings.RegisterVerticalLayoutCategory("PetCall")

    layout:AddInitializer(CreateSettingsButtonInitializer(L["PetCall window"], L["Open"], function()
        SettingsPanel:Hide()
        ns:OpenWindow()
    end, L["Pick pets, create sets and set their conditions."], true))

    header(GENERAL)
    proxy("enable", Settings.VarType.Boolean, L["Auto-summon"], true,
        function() return ns:IsAutoSummon() end, function(v) ns:SetAutoSummon(v) end,
        L["Automatically summon a companion pet when entering a new area or when idle."])
    profileBool("nearPEWOnly", L["Only Summon After Zoning"], L["Only summon a pet when entering a new area or zone. When disabled, a pet is also summoned after standing still for the configured wait time."])
    do
        local opts = Settings.CreateSliderOptions(1, 30, 0.5)
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return format(L["%.1f s"], v) end)
        proxy("waitTimer", Settings.VarType.Number, L["Wait Time (Seconds)"], 3,
            function() return ns.db.profile.waitTimer end, function(v) ns:SetProfileValue("waitTimer", v) end,
            L["Seconds of inactivity before PetCall summons a pet."], "slider", opts)
    end
    profileBool("verbose", L["Chat messages"], L["Print a message in the chat window each time a pet is summoned."])
    proxy("minimap", Settings.VarType.Boolean, L["Show Minimap Button"], false,
        function() return not ns.db.profile.minimap.hide end,
        function(v) ns.db.profile.minimap.hide = not v if ns.UI.Broker then ns.UI.Broker:SetMinimapShown(v) end end,
        L["Show the PetCall icon on the minimap."])
    profileBool("overrideSetLoadout", L["Override Pet Battle Loadout"], L["Re-summon your PetCall pet after the game auto-summons one via the Pet Battle Loadout screen."])
    do
        local opts = Settings.CreateSliderOptions(0.8, 1.3, 0.05)
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return format("%d%%", v * 100 + 0.5) end)
        proxy("windowScale", Settings.VarType.Number, L["PetCall window scale"], 1,
            function() return ns.db.global.window.scale or 1 end, function(v) ns.UI.Main:SetScale(v) end,
            L["Scale of the PetCall window on top of the game's UI scale."], "slider", opts)
    end
    do
        local CHOICES = { "auto", "flat", "blizzard" }
        local function options()
            local c = Settings.CreateControlTextContainer()
            c:Add(1, L["Automatic"])
            c:Add(2, L["PetCall dark"])
            c:Add(3, L["Blizzard"])
            return c:GetData()
        end
        local function get()
            for i, v in ipairs(CHOICES) do if v == ns.Skin:GetChoice() then return i end end
            return 1
        end
        proxy("look", Settings.VarType.Number, L["Window look"], 1, get, function(v)
            if CHOICES[v] == ns.Skin:GetChoice() then return end
            ns.db.global.look = CHOICES[v]
            -- frames are styled as they are built: the new look needs a reload
            StaticPopup_Show("PETCALL_CONFIRM", L["The new look shows after the interface reloads. Reload now?"], nil,
                { onAccept = function() C_UI.Reload() end })
        end, L["Automatic: EllesmereUI's look when it is installed, PetCall dark with QUI (in QUI's colours), otherwise Blizzard's frames."],
            "dropdown", options)
    end

    header(L["Where"])
    whereSetting("bg", L["Battlegrounds and arenas"], L["What PetCall does in battlegrounds and arenas."], "enableInBattleground", "dismissInBattleground")
    whereSetting("pve", L["Dungeons and raids"], L["What PetCall does in dungeons and raids."], "enableInPVE", "dismissInPVE")
    profileBool("disableOutsideCities", L["Only Enable in Cities"], L["Restrict pet summoning to city areas only. Your pet will be dismissed when you leave a city."])
    profileBool("noSummonMounted", L["Don't summon while mounted"], L["Wait until you dismount. A summon on a mount uses the global cooldown and can get in the way of Skyriding abilities."])
    profileBool("dismissWhenStealthed", L["Dismiss When Stealthed or Invisible"], L["Automatically dismiss your pet when you enter stealth or use an invisibility effect."])

    header(L["Auto Switch Pet"])
    proxy("autoSwitchTimer", Settings.VarType.Boolean, L["Enable Timed Auto Switch"], false,
        function() return ns.db.profile.autoSwitch.timer end,
        function(v) ns.db.profile.autoSwitch.timer = v if v then ns.SwitchTimer:Start() else ns.SwitchTimer:Stop() end end,
        L["Automatically switch to a different random pet from your selection after a set amount of time."])
    do
        local opts = Settings.CreateSliderOptions(1, 60, 1)
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return format(L["%d min"], v) end)
        proxy("autoSwitchMinutes", Settings.VarType.Number, L["Switch every"], 30,
            function() return math.floor(ns.db.profile.autoSwitch.timerValue / 60 + 0.5) end,
            function(v) ns.db.profile.autoSwitch.timerValue = v * 60 ns.SwitchTimer:Start() end,
            L["How often to switch to a different pet."], "slider", opts)
    end
    proxy("autoSwitchCities", Settings.VarType.Boolean, L["Only use Timed Auto Switch in cities"], false,
        function() return ns.db.profile.autoSwitch.citiesOnly end, function(v) ns.db.profile.autoSwitch.citiesOnly = v end,
        L["Restrict timed pet switching to city areas."])
    proxy("autoSwitchZone", Settings.VarType.Boolean, L["Auto Switch when changing maps"], false,
        function() return ns.db.profile.autoSwitch.onZone end, function(v) ns.db.profile.autoSwitch.onZone = v end,
        L["Switch to a different random pet each time you travel to a new map or zone."])

    header(L["Special Items"])
    proxy("specialItems", Settings.VarType.Boolean, ENABLE, true,
        function() return ns.SpecialItems:IsEnabled() end, function(v) ns.SpecialItems:SetEnabled(v) end,
        L["EXPLAIN_SPECIAL_ITEMS"])
    for _, item in ipairs(ns.SpecialItems:List()) do
        local key = item.key
        local setting = Settings.RegisterProxySetting(category, "PETCALL_SI_" .. key:gsub(":", "_"), Settings.VarType.Boolean,
            item.name, true,
            function() return ns.SpecialItems.db.profile.items[key] and true or false end,
            function(v) ns.SpecialItems:SetItemEnabled(key, v) end)
        Settings.CreateCheckbox(category, setting)
    end

    Settings.RegisterAddOnCategory(category)
    S.category = category
    ns.UI.Profiles:Register(category)
    S:RegisterAbout(category)
end

function S:RegisterAbout(parent)
    local f = CreateFrame("Frame")
    f:Hide()
    S.aboutPage = f
    f:SetScript("OnShow", function(self)
        if self.built then return end
        self.built = true
        -- the page is longer than the panel: it scrolls
        local scroll = CreateFrame("ScrollFrame", nil, self, "ScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 0, -4)
        scroll:SetPoint("BOTTOMRIGHT", -24, 4)
        local body = CreateFrame("Frame", nil, scroll)
        body:SetSize(10, 10)
        scroll:SetScrollChild(body)
        self.scroll, self.body = scroll, body
        local lines = {}
        local function line(text, font, indent, gap)
            local fs = ns.Widgets.Label(body, text, font)
            fs:SetPoint("RIGHT", -16, 0)
            fs:SetWordWrap(true)
            lines[#lines + 1] = { fs = fs, indent = indent or 0, gap = gap or 0 }
        end
        -- wrapped lines get taller when the panel gets narrower, so they are placed again
        local function layout()
            local y = -12
            for _, l in ipairs(lines) do
                y = y - l.gap
                l.fs:SetPoint("TOPLEFT", 16 + l.indent, y)
                y = y - (tonumber(l.fs:GetStringHeight()) or 0) - 6
            end
            body:SetHeight(-y + 12)
        end
        local version, _, _, toc = GetBuildInfo()
        line("PetCall " .. ns.version, "GameFontNormalLarge")
        line(format(L["WoW %s · Interface %d"], version, toc), "GameFontDisableSmall")
        line(L["What's new"], "GameFontNormal", 0, 8)
        for _, note in ipairs(ns.releaseNotes or {}) do line("- " .. note, "GameFontHighlightSmall", 8) end
        line(L["Commands"], "GameFontNormal", 0, 8)
        for _, c in ipairs(ns.Commands:HelpLines()) do line(c, "GameFontHighlightSmall", 8) end
        line(L["Key bindings"], "GameFontNormal", 0, 8)
        for _, b in ipairs({ "PETCALL_SUMMON", "PETCALL_DESUMMON", "PETCALL_TOGGLE", "PETCALL_CONFIG" }) do
            line(format("%s: %s", _G["BINDING_NAME_" .. b], GetBindingKey(b) or L["not bound"]), "GameFontHighlightSmall", 8)
        end
        line(L["Credits"], "GameFontNormal", 0, 8)
        line("Cryzer – PetCall 2.0", "GameFontHighlightSmall", 8)
        line("End – PetLeash", "GameFontHighlightSmall", 8)
        line(L["Translations by the WoW community."], "GameFontHighlightSmall", 8)
        scroll:SetScript("OnSizeChanged", function(_, w) body:SetWidth(w) layout() end)
        body:SetWidth(math.max(10, (tonumber(scroll:GetWidth()) or 0)))
        layout()
    end)
    Settings.RegisterCanvasLayoutSubcategory(parent, f, L["About"])
end

local pendingOpen
function ns:OpenSettings()
    if InCombatLockdown() then
        if not pendingOpen then
            pendingOpen = {}
            ns:Print(L["Settings will open after combat."])
            ns.Events.Register(pendingOpen, "PLAYER_REGEN_ENABLED", function()
                ns.Events.Unregister(pendingOpen, "PLAYER_REGEN_ENABLED")
                pendingOpen = nil
                Settings.OpenToCategory(category:GetID())
            end)
        end
        return
    end
    Settings.OpenToCategory(category:GetID())
end

local loader = {}
ns.Events.Register(loader, "PLAYER_LOGIN", function()
    ns.Events.Unregister(loader, "PLAYER_LOGIN")
    build()
end)

-- 1.x key binding names (Bindings.xml)
BINDING_HEADER_PETCALL = "PetCall"
BINDING_NAME_PETCALL_SUMMON = L["Summon Another Pet"]
BINDING_NAME_PETCALL_DESUMMON = L["Dismiss Pet"]
BINDING_NAME_PETCALL_TOGGLE = L["Toggle Non-Combat Pet"]
BINDING_NAME_PETCALL_CONFIG = L["Open PetCall"]
