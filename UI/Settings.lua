local _, ns = ...

local L = ns.L
ns.UI = ns.UI or {}
local S = {}
ns.UI.Settings = S

local category, layout

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

local PAD = 20
local measurer

-- a paragraph that wraps inside the settings list: the list sizes the row from GetExtent
local function textRow(text)
    local init = Settings.CreateElementInitializer("SettingsListElementTemplate", { name = text })
    local function width()
        local list = SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList
        return math.max(100, (tonumber(list and list:GetWidth()) or 600) - 2 * PAD)
    end
    function init:GetExtent()
        if not measurer then
            measurer = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            measurer:Hide()
            measurer:SetWordWrap(true)
        end
        measurer:SetWidth(width())
        measurer:SetText(text)
        return (tonumber(measurer:GetStringHeight()) or 0) + 8
    end
    function init:InitFrame(frame)
        if frame.Text then frame.Text:SetText("") end
        local fs = frame.pcText
        if not fs then
            fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            fs:SetPoint("TOPLEFT", PAD, -4)
            fs:SetPoint("RIGHT", -PAD, 0)
            fs:SetJustifyH("LEFT")
            fs:SetJustifyV("TOP")
            fs:SetWordWrap(true)
            frame.pcText = fs
        end
        fs:SetText(text)
    end
    return init
end

local pendingOpen
local function openWhenSafe(id)
    if InCombatLockdown() then
        if not pendingOpen then
            pendingOpen = {}
            ns:Print(L["Settings will open after combat."])
            ns.Events.Register(pendingOpen, "PLAYER_REGEN_ENABLED", function()
                ns.Events.Unregister(pendingOpen, "PLAYER_REGEN_ENABLED")
                pendingOpen = nil
                Settings.OpenToCategory(id)
            end)
        end
        return
    end
    Settings.OpenToCategory(id)
end

local function header(text) layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text)) end

function S:Build()
    category, layout = Settings.RegisterVerticalLayoutCategory("PetCall")

    layout:AddInitializer(CreateSettingsButtonInitializer(L["PetCall window"], L["Open"], function()
        SettingsPanel:Hide()
        ns:OpenWindow()
    end, L["Pick pets, create sets and set their conditions."], true))

    layout:AddInitializer(textRow(L["Which pets come out, where and how often is set in the PetCall window."]
        .. " " .. L["This page only changes how PetCall looks."]))

    header(L["Appearance"])
    proxy("minimap", Settings.VarType.Boolean, L["Show Minimap Button"], false,
        function() return not ns.db.profile.minimap.hide end,
        function(v) ns.db.profile.minimap.hide = not v if ns.UI.Broker then ns.UI.Broker:SetMinimapShown(v) end end,
        L["Show the PetCall icon on the minimap."])
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

    header(L["Keys and commands"])
    layout:AddInitializer(CreateSettingsButtonInitializer(L["Key bindings"], L["Open"], function()
        openWhenSafe(Settings.KEYBINDINGS_CATEGORY_ID)
    end, L["Open the game's key bindings, where PetCall's keys are listed."], true))
    layout:AddInitializer(textRow("/pcall · /pcall help"))

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

function ns:OpenSettings() openWhenSafe(category:GetID()) end

local loader = {}
ns.Events.Register(loader, "PLAYER_LOGIN", function()
    ns.Events.Unregister(loader, "PLAYER_LOGIN")
    S:Build()
end)

-- 1.x key binding names (Bindings.xml)
BINDING_HEADER_PETCALL = "PetCall"
BINDING_NAME_PETCALL_SUMMON = L["Summon Another Pet"]
BINDING_NAME_PETCALL_DESUMMON = L["Dismiss Pet"]
BINDING_NAME_PETCALL_TOGGLE = L["Toggle Non-Combat Pet"]
BINDING_NAME_PETCALL_CONFIG = L["Open PetCall"]
