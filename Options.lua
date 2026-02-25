
local addon_name, addon = ...

local module = addon:NewModule("Options", "AceConsole-3.0")

local L = LibStub("AceLocale-3.0"):GetLocale("PetCall")

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local LibPetJournal = LibStub("LibPetJournal-2.0")

local error, hooksecurefunc, ipairs, pairs, PlaySound, select,
    setmetatable, strfind, string, table, tinsert, tostring, tremove,
    type, wipe
    = error, hooksecurefunc, ipairs, pairs, PlaySound, select,
    setmetatable, strfind, string, table, tinsert, tostring, tremove,
    type, wipe

local LibDBIcon = LibStub("LibDBIcon-1.0")

--
--
--

local W = 8
local L_WeightValues = {
    -- value, short, long
   {0,      false,          "|cffff0000"..L["Never"].."|r"},
   {W^-2,   "|cffff6600-2", "|cffff6600"..L["Extra Low Priority"].."|r"},
   {W^-1,   "|cffff9900-1", "|cffff9900"..L["Low Priority"].."|r"},
   {W^0,    true,           "|cffddff00"..L["Normal"].."|r"},
   {W^1,    "|cff99ff00+1", "|cff99ff00"..L["High Priority"].."|r"},
   {W^2,    "|cff00ff00+2", "|cff00ff00"..L["Extra High Priority"].."|r"},
}

local L_WeightValuesFlat = {}
for _, item in ipairs(L_WeightValues) do
    L_WeightValuesFlat[item[1]] = item[3]
end

local L_SetPriority = {}
for _, item in ipairs(L_WeightValues) do
    if item[2] ~= false then
        L_SetPriority[item[1]] = item[3]
    end
end

local options = {
    name = "PetCall",
    handler = addon,
    type = 'group',
    args = {
        main = {
            name = GENERAL,
            type = 'group',
            childGroups = "tab",
            args = {
                general = {
                    name = GENERAL,
                    type = "group",
                    order = 10,
                    get = function(info) return addon.db.profile[info[#info]] end,
                    set = function(info, val) 
                        addon.db.profile[info[#info]] = val
                        addon.Ready:UpdateChecks()
                    end,
                    args = {
                        enable = {
                            type = "toggle",
                            name = ENABLE,
                            desc = L["Automatically summon a companion pet when entering a new area or when idle. Respects your pet selection, filters, and trigger settings."],
                            order = 10,
                            width = "full",
                            get = function(info) return addon:IsEnabledSummoning() end,
                            set = function(info,v) addon:EnableSummoning(v) end,
                        },
                        nearPEWOnly = {
                            type = "toggle",
                            name = L["Only Summon After Zoning"],
                            desc = L["Only summon a pet when entering a new area or zone. When disabled, a pet is also summoned after standing still for the configured wait time."],
                            order = 11,
                            width = "double"
                        },
                        enableInBattleground = {
                            type = "toggle",
                            name = L["Enable In Battlegrounds/Arena"],
                            desc = L["Allow PetCall to summon pets while in battlegrounds and arenas. Cannot be combined with Dismiss In Battlegrounds."],
                            order = 13,
                            width = "double",
                            disabled = function() return addon.db.profile.dismissInBattleground end,
                        },
                        enableInPVE = {
                            type = "toggle",
                            name = L["Enable In PVE Instances"],
                            desc = L["Allow PetCall to summon pets while in dungeons and raids. Cannot be combined with Dismiss In PVE Instances."],
                            order = 13,
                            width = "double",
                            disabled = function() return addon.db.profile.dismissInPVE end,
                        },
                        disableOutsideCities = {
                            type = "toggle",
                            name = L["Only Enable in Cities"],
                            desc = L["Restrict pet summoning to city areas only. Your pet will be dismissed when you leave a city."],
                            order = 14,
                            width = "double",
                        },
                        dismissWhenStealthed = {
                            type = "toggle",
                            name = L["Dismiss When Stealthed or Invisible"],
                            desc = L["Automatically dismiss your pet when you enter stealth or use an invisibility effect."],
                            order = 15,
                            width = "double",
                        },
                        dismissInBattleground = {
                            type = "toggle",
                            name = L["Dismiss In Battlegrounds/Arena"],
                            desc = L["Automatically dismiss your pet when entering a battleground or arena. Cannot be combined with Enable In Battlegrounds."],
                            order = 17,
                            width = "double",
                            disabled = function() return addon.db.profile.enableInBattleground end,
                        },
                        dismissInPVE = {
                            type = "toggle",
                            name = L["Dismiss In PVE Instances"],
                            desc = L["Automatically dismiss your pet when entering a dungeon or raid. Cannot be combined with Enable In PVE Instances."],
                            order = 17,
                            width = "double",
                            disabled = function() return addon.db.profile.enableInPVE end,
                        },
                        overrideSetLoadout = {
                            type = "toggle",
                            name = L["Override Pet Battle Loadout"],
                            desc = L["Re-summon your PetCall pet after the game auto-summons one via the Pet Battle Loadout screen."],
                            order = 30,
                            width = "double",
                        },
                        waitTimerValue = {
                            type = "range",
                            name = L["Wait Time (Seconds)"],
                            desc = L["Seconds of inactivity before PetCall summons a pet. Only applies when Only Summon After Zoning is disabled."],
                            order = 40,
                            min = 1,
                            step = .5,
                            bigStep = 1,
                            max = 30,
                            get = function()
                                return addon.db.profile.waitTimer
                            end,
                            set = function(info,v)
                                addon.db.profile.waitTimer = v
                            end
                        },
                        verbose = {
                            type = "toggle",
                            name = L["Verbose"],
                            desc = L["Print a message in the chat window each time a pet is summoned or dismissed."],
                            order = 100,
                            width = "double",
                        },
                        showMinimapButton = {
                            type = "toggle",
                            name = L["Show Minimap Button"],
                            desc = L["Show the PetCall icon on the minimap for quick access to the pet selection menu."],
                            order = 101,
                            width = "double",
                            get = function()
                                return not addon.db.profile.minimap.hide
                            end,
                            set = function(info, v)
                                addon.db.profile.minimap.hide = not v
                                if v then
                                    LibDBIcon:Show("PetCall")
                                else
                                    LibDBIcon:Hide("PetCall")
                                end
                            end
                        }
                    },
                },
                autoSwitch = {
                    name = L["Auto Switch Pet"],
                    type = "group",
                    order = 30,
                    args = {
                        autoSwitchTimerEnable = {
                            type = "toggle",
                            name = L["Enable Timed Auto Switch"],
                            desc = L["Automatically switch to a different random pet from your selection after a set amount of time."],
                            width = "double",
                            order = 31,
                            get = function() return addon.db.profile.autoSwitch.timer end,
                            set = function(info,v)
                                addon.db.profile.autoSwitch.timer = v
                                if(v) then
                                    addon.SwitchTimer:Start()
                                end
                            end
                        },
                        autoSwitchTimerValue = {
                            type = "range",
                            name = L["Seconds between switch"],
                            desc = L["How often (in seconds) to automatically switch to a different pet from your selection."],
                            order = 32,
                            min = 60,
                            step = 1,
                            bigStep = 60,
                            max = 3600,
                            disabled = function() return not addon.db.profile.autoSwitch.timer end,
                            get = function()
                                return addon.db.profile.autoSwitch.timerValue
                            end,
                            set = function(info,v)
                                addon.db.profile.autoSwitch.timerValue = v
                                addon.SwitchTimer:Start()
                            end
                        },
                        autoSwitchCitiesOnly = {
                            type = "toggle",
                            name = L["Only use Timed Auto Switch in cities"],
                            desc = L["Restrict timed pet switching to city areas. Automatic switching pauses when you leave a city."],
                            width = "double",
                            order = 33,
                            get = function() return addon.db.profile.autoSwitch.citiesOnly end,
                            set = function(info,v) addon.db.profile.autoSwitch.citiesOnly = v end,
                        },
                        autoSwitchOnZone = {
                            type = "toggle",
                            name = L["Auto Switch when changing maps"],
                            desc = L["Switch to a different random pet each time you travel to a new map or zone."],
                            width = "double",
                            order = 40,
                            get = function() return addon.db.profile.autoSwitch.onZone end,
                            set = function(info,v) addon.db.profile.autoSwitch.onZone = v end,
                        }
                    }
                }
            }
        }
    },
    plugins = {}
}

local options_slashcmd = {
    name = "PetCall Slash Command",
    handler = addon,
    type = "group",
    order = -2,
    args = {
        config = {
            type = "execute",
            name = L["Open Configuration"],
            dialogHidden = true,
            order = 1,
            func = function(info) addon:OpenOptions() end
        },
        resummon = {
            type = "execute",
            name = L["Summon Another Pet"],
            desc = L["Dismiss your current pet and summon another pet.  Enable summoning if needed."],
            order = 20,
            func = function(info) addon:ResummonPet(true, true) end
        },
        dismiss = {
            type = "execute",
            name = L["Dismiss Pet"],
            desc = L["Dismiss your currently summoned pet.  Disable summoning."],
            order = 21,
            func = function(info) addon:DismissPet(true) end
        },
        desummon = {
            -- included for backwards compat
            type = "execute",
            name = L["Dismiss Pet"],
            hidden = true,
            func = function(info) addon:DismissPet(true) end
        },
        togglePet = {
            type = "execute",
            name = L["Toggle Non-Combat Pet"],
            order = 22,
            func = function(info) addon:TogglePet() end
        },
        enable = options.args.main.args.general.args.enable,
        dismissWhenStealthed = options.args.main.args.general.args.dismissWhenStealthed,
        debugstate = {
            type = "execute",
            name = "Debug State",
            hidden = true,
            func = function(info) addon:DumpDebugState() end
        },
        migrate = {
            type = "execute",
            name = "Import PetLeash",
            hidden = true,
            func = function(info) addon:ManualMigratePrompt() end
        }
    },
}

function module:OnInitialize()
    self.db = addon.db

    self.options = options
    self.options.args.profiles = AceDBOptions:GetOptionsTable(self.db)
    self.options_slashcmd = options_slashcmd

    AceConfig:RegisterOptionsTable(addon.name, options)
    AceConfig:RegisterOptionsTable(addon.name .. "SlashCmd", options_slashcmd)

    -- Register slash commands manually so that bare /pcall opens the config panel
    -- instead of printing AceConfigCmd help text.
    local AceConfigCmd = LibStub("AceConfigCmd-3.0")
    local function slashHandler(input)
        if not input or input:trim() == "" then
            module:OpenOptions()
        else
            AceConfigCmd:HandleCommand("petcall", addon.name .. "SlashCmd", input)
        end
    end
    addon:RegisterChatCommand("petcall", slashHandler)
    addon:RegisterChatCommand("pcall",   slashHandler)

    -- WoW 10.0+: Settings API requires categories to be registered at load time
    -- (old lazy-init pattern no longer works; AddToBlizOptions must run on startup)
    self:SetupOptions()
end

function module:OpenOptions()
    self:SetupOptions()
    -- WoW 10.0+: Settings.OpenToCategory replaces InterfaceOptionsFrame_OpenToCategory
    -- AceConfigDialog v92+ returns (frame, categoryID) from AddToBlizOptions
    if self._mainCategoryID then
        Settings.OpenToCategory(self._mainCategoryID)
    end
end

function module:SetupOptions()
    -- we delay setting up options until here so that plugins in seperate
    -- addons will load properly
    if self.didSetup then return end
    self.didSetup = true

    -- AceConfigDialog v92+ returns (frame, categoryID); capture both
    self.optionsFrame, self._mainCategoryID = AceConfigDialog:AddToBlizOptions(addon.name, addon.name, nil, "main")
    self._mainCategoryID = self._mainCategoryID or (self.optionsFrame and self.optionsFrame.name)

    self.PetSelection = AceGUI:Create("BlizOptionsGroup")
    self.PetSelection:SetUserData("options", {
        showSetConfig = false,
        showList = false,
        showTriggerTab = false
    })
    self.PetSelection:SetName(L["Pet Selection"], addon.name)
    self.PetSelection:SetTitle(L["Pet Selection"])
    self.PetSelection:SetLayout("flow")
    self.PetSelection:SetCallback("OnShow", function() self:PetSelection_Fill(self.PetSelection, "$Default") end)
    self.PetSelection:SetCallback("OnHide", function() self:PetSelection_Clear(self.PetSelection) end)
    -- WoW 10.0+: register as subcategory under addon.name
    -- Use BlizOptionsIDMap + Settings.GetCategory (AceConfigDialog v92+ pattern)
    do
        local idMap = AceConfigDialog.BlizOptionsIDMap
        local parentID = idMap and idMap[addon.name]
        local parentCat = parentID and Settings.GetCategory(parentID)
        local cat
        if parentCat then
            cat = Settings.RegisterCanvasLayoutSubcategory(parentCat, self.PetSelection.frame, L["Pet Selection"])
        else
            cat = Settings.RegisterCanvasLayoutCategory(self.PetSelection.frame, L["Pet Selection"])
            Settings.RegisterAddOnCategory(cat)
        end
        self.PetSelection.frame.settingsCategory = cat
    end

    self.PetTriggers = AceGUI:Create("BlizOptionsGroup")
    self.PetTriggers:SetUserData("options", {
        showSetConfig = true,
        showList = true,
        showTriggerTab = true
    })
    self.PetTriggers:SetName(L["Pet Triggers"], addon.name)
    self.PetTriggers:SetTitle(L["Pet Triggers"])
    self.PetTriggers:SetLayout("flow")
    self.PetTriggers:SetCallback("OnShow", function() self:PetSelection_Fill(self.PetTriggers) end)
    self.PetTriggers:SetCallback("OnHide", function() self:PetSelection_Clear(self.PetTriggers) end)
    do
        local idMap = AceConfigDialog.BlizOptionsIDMap
        local parentID = idMap and idMap[addon.name]
        local parentCat = parentID and Settings.GetCategory(parentID)
        local cat
        if parentCat then
            cat = Settings.RegisterCanvasLayoutSubcategory(parentCat, self.PetTriggers.frame, L["Pet Triggers"])
        else
            cat = Settings.RegisterCanvasLayoutCategory(self.PetTriggers.frame, L["Pet Triggers"])
            Settings.RegisterAddOnCategory(cat)
        end
        self.PetTriggers.frame.settingsCategory = cat
    end

    for name, module in addon:IterateModules() do
        local f = module["SetupOptions"]
        if f then
            f(module, function(appName, name) AceConfigDialog:AddToBlizOptions(appName, name, addon.name) end)
        end
    end

    self.Profile = AceConfigDialog:AddToBlizOptions(addon.name, L["Profiles"], addon.name, "profiles")
    -- Custom About panel (replaces LibAboutPanel)
    do
        local aboutFrame = CreateFrame("Frame", nil, UIParent)
        aboutFrame:Hide()   -- must be hidden first so OnShow fires when Settings shows it

        -- Register as subcategory under PetCall (WoW 10.0+ Settings API)
        do
            local idMap = AceConfigDialog.BlizOptionsIDMap
            local parentID = idMap and idMap[addon.name]
            local parentCat = parentID and Settings.GetCategory(parentID)
            local cat
            if parentCat then
                cat = Settings.RegisterCanvasLayoutSubcategory(parentCat, aboutFrame, "About")
            else
                cat = Settings.RegisterCanvasLayoutCategory(aboutFrame, "About")
                Settings.RegisterAddOnCategory(cat)
            end
            aboutFrame.settingsCategory = cat
        end

        -- Build content lazily on first show (frame geometry is available after show)
        aboutFrame:SetScript("OnShow", function(self)
            if self._built then return end
            self._built = true

            -- Own scroll frame (canvas layout doesn't auto-scroll)
            local sf = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
            sf:SetPoint("TOPLEFT",     self, "TOPLEFT",     0, -4)
            sf:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -28, 4)

            local c = CreateFrame("Frame", nil, sf)
            c:SetWidth(sf:GetWidth())
            sf:SetScrollChild(c)

            local PAD     = 20
            local INDENT  = 12
            local LINE_SM = 20
            local LINE_MD = 24

            local function div(atY)
                local d = c:CreateTexture(nil, "ARTWORK")
                d:SetColorTexture(0.25, 0.25, 0.40, 0.35)
                d:SetHeight(1)
                d:SetPoint("TOPLEFT",  c, "TOPLEFT",  PAD,  atY)
                d:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, atY)
            end

            local function head(text, atY)
                local fs = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                fs:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, atY)
                fs:SetText("|cffd4af37" .. text .. "|r")
            end

            local function body(text, atY, extraIndent)
                local fs = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                fs:SetPoint("TOPLEFT",  c, "TOPLEFT",  PAD + (extraIndent or 0), atY)
                fs:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, atY)
                fs:SetJustifyH("LEFT")
                fs:SetNonSpaceWrap(true)
                fs:SetText(text)
            end

            local function twoCol(label, value, atY, labelW)
                labelW = labelW or 140
                local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                lbl:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + INDENT, atY)
                lbl:SetWidth(labelW)
                lbl:SetJustifyH("LEFT")
                lbl:SetText(label)
                local val = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                val:SetPoint("TOPLEFT",  c, "TOPLEFT",  PAD + INDENT + labelW + 8, atY)
                val:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, atY)
                val:SetJustifyH("LEFT")
                val:SetText("|cff888899" .. value .. "|r")
            end

            local y = -PAD

            -- ── HEADER ───────────────────────────────────────────────────
            local ver = C_AddOns.GetAddOnMetadata("PetCall", "Version") or "1.0.1"

            local titleFS = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            titleFS:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, y)
            titleFS:SetText("|cffd4af37PetCall|r  |cff777799" .. ver .. "|r")
            y = y - 30

            body("Automatically summons your companion pet based on configurable triggers, filters, and priority sets.", y)
            y = y - 44

            local buildFS = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            buildFS:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, y)
            buildFS:SetText("|cff555577WoW: Midnight  ·  Interface 120001|r")
            y = y - 28

            -- ── WHAT'S NEW ───────────────────────────────────────────────
            div(y - 6); y = y - 24
            head("What's New — " .. ver, y); y = y - LINE_MD

            local changes = addon.releaseNotes or {}
            for _, line in ipairs(changes) do
                body("|cff667766•|r  " .. line, y, INDENT)
                y = y - LINE_SM
            end

            -- ── COMMANDS ─────────────────────────────────────────────────
            div(y - 4); y = y - 22
            head("Commands", y); y = y - LINE_MD

            local cmds = {
                { "|cff77cc77/petcall|r,  |cff77cc77/pcall|r",  "Open configuration panel" },
                { "|cff77cc77/petcall resummon|r",               "Summon another pet; enable if needed" },
                { "|cff77cc77/petcall dismiss|r",                "Dismiss current pet; disable summoning" },
                { "|cff77cc77/petcall togglePet|r",              "Toggle pet on / off without changing enable state" },
                { "|cff77cc77/petcall enable|r",                 "Toggle auto-summon on / off" },
                { "|cff77cc77/petcall migrate|r",                "Import PetLeash profile data" },
            }
            for _, row in ipairs(cmds) do
                twoCol(row[1], row[2], y, 210)
                y = y - LINE_SM
            end

            -- ── KEY BINDINGS ─────────────────────────────────────────────
            div(y - 4); y = y - 22
            head("Key Bindings", y); y = y - LINE_MD

            local binds = {
                { "Summon Another Pet",    "PETCALL_SUMMON"   },
                { "Dismiss Pet",           "PETCALL_DESUMMON" },
                { "Toggle Non-Combat Pet", "PETCALL_TOGGLE"   },
                { "Open Configuration",    "PETCALL_CONFIG"   },
            }
            for _, row in ipairs(binds) do
                local key = GetBindingKey(row[2]) or "|cff555566not bound|r"
                twoCol("|cffcccccc" .. row[1] .. "|r", key, y, 210)
                y = y - LINE_SM
            end
            body("|cff444466Configure in Game Menu > Key Bindings > AddOns > PetCall.|r", y, INDENT)
            y = y - LINE_SM

            -- ── CREDITS ──────────────────────────────────────────────────
            div(y - 8); y = y - 26
            head("Credits", y); y = y - LINE_MD

            local credits = {
                { "|cffddddddCryzer|r",    "WoW 12.0 refactor, new features" },
                { "|cffddddddEnd|r",       "Original PetLeash 3.1.5 (2018)" },
                { "|cffff8c42Claude AI|r", "Development assistance (Anthropic)" },
            }
            for _, row in ipairs(credits) do
                twoCol(row[1], row[2], y, 120)
                y = y - LINE_SM
            end
            body("|cff444466Translations maintained by the WoW community.|r", y, INDENT)
            y = y - LINE_SM

            -- Set content height so the scroll frame knows the full extent
            c:SetHeight(-y + PAD)
        end)

        module.About = aboutFrame
    end
end

--
-- Pet Selection Options
--

do
    --
    -- mainTree
    --

    local mainPage_Fill, mainPage_FillList

    function module:PetSelection_Fill(frame, set)
        if not set then
            mainPage_FillList(frame)
        else
            mainPage_Fill(frame, set)
        end
    end

    function module:PetSelection_Clear(frame)
        frame:ReleaseChildren()
    end

    do
        -- 
        -- mainPage (List)
        --

        local function newSet_onEnterPressed(frame, event, value)
            value = string.gsub(value, "^%s*(.-)%s*$", "%1")
        
            if #value == 0 or strfind(value, "^%$") then
                PlaySound(SOUNDKIT.IG_PLAYER_INVITE_DECLINE)
                UIErrorsFrame:AddMessage("Set name cannot be empty or begin with '$'.", 1, 0.3, 0.3)
                return
            end
        
            addon:NewSet(value)
            mainPage_FillList(frame:GetUserData("mainPage"))

            frame:SetText("")
        end

        local function setEditButton_OnClick(frame, event)
            module:PetSelection_Fill(frame:GetUserData("mainPage"),
                                     frame:GetUserData("setName"))
        end

        local function setDeleteButton_OnClick(frame, event)
            local set = addon:GetSetByName(frame:GetUserData("setName"))
            if set then set:Delete() end
            mainPage_FillList(frame:GetUserData("mainPage"))
        end

        local setsTmp = {}
        function mainPage_FillList(frame)
            frame:ReleaseChildren()

            frame:PauseLayout()
            frame:SetTitle(L["Pet Triggers"])

            local desc = AceGUI:Create("Label")
            desc:SetText("Pet Trigger Sets define when and which pets to summon.  Create a named set, then use Edit to configure its trigger conditions and pet pool.")
            desc:SetFullWidth(true)
            frame:AddChild(desc)

            local addNew = AceGUI:Create("EditBox")
            addNew:SetLabel("Add New Set")
            addNew:SetCallback("OnEnterPressed", newSet_onEnterPressed)
            addNew:SetUserData("mainPage", frame)
            frame:AddChild(addNew)

            local importButton = AceGUI:Create("Button")
            importButton:SetText("Import Set")
            importButton:SetCallback("OnClick", function()
                addon:ShowImportDialog(function()
                    mainPage_FillList(frame)
                end)
            end)
            frame:AddChild(importButton)

            local scroll = AceGUI:Create("ScrollFrame")
            scroll:SetLayout("Flow")
            scroll:SetFullWidth(true)
            scroll:SetFullHeight(true)
            frame:SetUserData("scrollFrame", scroll)
            frame:AddChild(scroll)

            local setDB = addon.db.profile.sets
            wipe(setsTmp)
            for setName in pairs(setDB) do
                if not strfind(setName, "^%$") then
                    tinsert(setsTmp, setName)
                end
            end
            table.sort(setsTmp)

            if #setsTmp == 0 then
                local emptyLabel = AceGUI:Create("Label")
                emptyLabel:SetText("|cffaaaaadNo sets yet.  Type a name above and press Enter to create your first trigger set.|r")
                emptyLabel:SetFullWidth(true)
                scroll:AddChild(emptyLabel)
            end

            for _,setName in pairs(setsTmp) do
                local setData = setDB[setName]
                local group = AceGUI:Create("InlineGroup")
                group:SetTitle(setData.name or setName)
                group:SetFullWidth(true)

                local trigCount = #(setData.trigger or {})
                local petCount = 0
                if setData.pets then
                    for _, w in pairs(setData.pets) do
                        if type(w) == "number" and w > 0 then petCount = petCount + 1 end
                    end
                end
                local summary = AceGUI:Create("Label")
                summary:SetText(string.format("|cffaaaaad%d trigger%s, %d pet%s selected|r",
                    trigCount, trigCount == 1 and "" or "s",
                    petCount,  petCount  == 1 and "" or "s"))
                summary:SetFullWidth(true)
                group:AddChild(summary)

                local editButton = AceGUI:Create("Button")
                editButton:SetText(L["Edit"])
                editButton:SetUserData("setName", setName)
                editButton:SetUserData("mainPage", frame)
                editButton:SetCallback("OnClick", setEditButton_OnClick)
                group:AddChild(editButton)

                local deleteButton = AceGUI:Create("Button")
                deleteButton:SetText(DELETE)
                deleteButton:SetUserData("setName", setName)
                deleteButton:SetUserData("mainPage", frame)
                deleteButton:SetCallback("OnClick", setDeleteButton_OnClick)
                group:AddChild(deleteButton)

                local exportButton = AceGUI:Create("Button")
                exportButton:SetText("Export")
                exportButton:SetUserData("setName", setName)
                exportButton:SetCallback("OnClick", function(btn)
                    addon:ShowExportDialog(btn:GetUserData("setName"))
                end)
                group:AddChild(exportButton)

                scroll:AddChild(group)
            end

            frame:ResumeLayout()
            frame:DoLayout()
        end
    end

    do 
        -- 
        -- mainPage
        --

        local selectTab_Fill
        local filterTriggerTab_Fill
        local deleteRenameTab_Fill

        local function backButton_OnClick(frame, event)
            module:PetSelection_Fill(frame:GetUserData("mainPage"), nil)
        end

        local function enabled_OnValueChanged(frame, event, value)
            local set = frame:GetUserData("set")
            set.settings.enabled = value
            set:Refresh()
        end

        local function priority_OnValueChanged(frame, event, key)
            local set = frame:GetUserData("set")
            set.settings.priority = key
            set:Refresh()
        end

        local function immediate_OnValueChanged(frame, event, v)
            local set = frame:GetUserData("set")
            set.settings.immediate = v
            set:Refresh()
        end

        local function tab_onGroupSelected(frame, event, value)
            frame:PauseLayout()

            local set = frame:GetUserData("set")
            if value == "select" then
                selectTab_Fill(frame, set)
            elseif value == "filter" then
                filterTriggerTab_Fill(frame, set, "filter")
            elseif value == "trigger" then
                filterTriggerTab_Fill(frame, set, "trigger")
            elseif value == "deleteRename" then
                deleteRenameTab_Fill(frame, set)
            end

            frame:ResumeLayout()
            frame:DoLayout()
        end

        function mainPage_Fill(parent, setName)
            parent:ReleaseChildren()
            parent:PauseLayout()

            local options = parent:GetUserData("options")
            local set = addon:GetSetByName(setName)

            if options.showList then
                parent:SetTitle("")     -- create our own title to put back button on same line
                local title = AceGUI:Create("Label")
                title:SetText(setName)
                title:SetFontObject(GameFontNormalLarge)
                title:SetColor(1.0, 0.82, 0)
                parent:AddChild(title)

                local backButton = AceGUI:Create("Button")
                backButton:SetText(L[" <<< Back "])
                backButton:SetUserData("mainPage", parent)
                backButton:SetCallback("OnClick", backButton_OnClick)
                parent:AddChild(backButton)
            end

            if options.showSetConfig then
                local enabledGroup = AceGUI:Create("SimpleGroup")
                enabledGroup:SetFullWidth(true)
                enabledGroup:SetLayout("Flow")
                parent:AddChild(enabledGroup)

                local enabled = AceGUI:Create("CheckBox")
                enabled:SetUserData("set", set)
                enabled:SetLabel(ENABLE)
                enabled:SetWidth(145)
                enabled:SetValue(set.settings.enabled)
                enabled:SetCallback("OnValueChanged", enabled_OnValueChanged)
                enabledGroup:AddChild(enabled)

                local prio = AceGUI:Create("Dropdown")
                prio:SetUserData("set", set)
                prio:SetWidth(145)
                prio:SetLabel(L["Priority"])
                prio:SetList(L_SetPriority)
                prio:SetValue(set.settings.priority)
                prio:SetCallback("OnValueChanged", priority_OnValueChanged)
                enabledGroup:AddChild(prio)

                local immediate = AceGUI:Create("CheckBox")
                immediate:SetUserData("set", set)
                immediate:SetWidth(145)
                immediate:SetLabel(L["Immediate"])
                immediate:SetValue(set.settings.immediate)
                immediate:SetCallback("OnValueChanged", immediate_OnValueChanged)
                enabledGroup:AddChild(immediate)

                local configHint = AceGUI:Create("Label")
                configHint:SetText("|cffaaaaadPriority: when multiple sets match, the highest-priority one wins.  Immediate: summon without waiting for the idle timer.|r")
                configHint:SetFullWidth(true)
                parent:AddChild(configHint)
            end

            local tabTree = { { text = L["Select Pets"], value= "select" }, { text = L["Filters"], value = "filter" } }
            if options.showTriggerTab then
                tinsert(tabTree, 1, { text = "Triggers", value= "trigger" })
                tinsert(tabTree, { text = "Delete/Rename", value= "deleteRename" })
            end

            local tabs = AceGUI:Create("TabGroup")
            tabs:SetTabs(tabTree)
            tabs:SetLayout("Fill")
            tabs:SetFullWidth(true)
            tabs:SetFullHeight(true)
            tabs:SetCallback("OnGroupSelected", tab_onGroupSelected)
            tabs:SetUserData("mainPage", parent)
            parent:AddChild(tabs)

            tabs:SetUserData("setName", setName)
            tabs:SetUserData("set", set)

            if options.showTriggerTab then
                tabs:SelectTab("trigger")
            else
                tabs:SelectTab("select")
            end

            parent:ResumeLayout()
            parent:DoLayout()
        end

        do
            --
            -- selectTab
            --

            local function selector_OnDefaultChanged(self, event, value)
                local set = self:GetUserData("set")

                if set.settings.defaultValue ~= value then
                    set.settings.defaultValue = value
                end
                set:Refresh()
            end

            local function selector_OnClear(self, event)
                local set = self:GetUserData("set")
                set:Refresh()
            end

            function selectTab_Fill(frame, set)
                frame:ReleaseChildren()

                local selector = AceGUI:Create("PetCall_PetSelectList")
                selector:SetFullWidth(true)
                selector:SetFullHeight(true)
                selector:SetDefault(set.settings.defaultValue)
                selector:SetTable(set.settings.pets)
                selector:SetWeightValues(L_WeightValues)
                selector:SetCallback("OnDefaultChanged", selector_OnDefaultChanged)
                selector:SetCallback("OnClear", selector_OnClear)
                frame:AddChild(selector)

                selector:SetUserData("set", set)
            end
        end

        do
            --
            -- filterTab/triggerTab
            --

            local filterTrigger = {
                filter = {
                    addHeading = L["Add Filter"],
                    settingsKey = "filter",
                    iterator = "IterateFilters",
                    get = "GetFilterByKey",
                    hasPriority = true,
                },
                trigger = {
                    addHeading = L["Add Trigger Condition"],
                    settingsKey = "trigger",
                    iterator = "IterateTriggers",
                    get = "GetTriggerByKey",
                    hasPriority = false,
                }
            }

            local function filterTriggerTab_reload(tab)
                filterTriggerTab_Fill(tab, tab:GetUserData("set"), tab:GetUserData("type"))
            end

            local function addButton_OnClick(frame, event)
                local settings = frame:GetUserData("settings")
                local ft = frame:GetUserData("ft")
                tinsert(settings, ft:New())

                filterTriggerTab_reload(frame:GetUserData("tab"))
            end

            local function prio_OnValueChanged(frame, event, value)
                local settings = frame:GetUserData("settings")
                settings[2] = value
            end

            local function deleteButton_onClick(frame, event)
                tremove(frame:GetUserData("settings"), frame:GetUserData("i"))
                filterTriggerTab_reload(frame:GetUserData("tab"))
            end

            local function cmpButton(a, b)
                return a:GetUserData("ft"):GetName() < b:GetUserData("ft"):GetName()
            end

            local addButtonTmp = {}
            local function filterTriggerTab_FillItems(tab, frame, type, settings, isRoot)
                if not tab then
                    tab = frame:GetUserData("tab")
                end

                frame:SetUserData("settings", settings)

                local set = tab:GetUserData("set")
                for fti, ftsettings in ipairs(settings) do
                    local ft = addon[filterTrigger[type].get](addon, ftsettings[1])

                    local group = AceGUI:Create("InlineGroup")
                    group:SetLayout("Flow")
                    group:SetTitle(ft:GetName())
                    group:SetFullWidth(true)
                    group:SetUserData("_fillFunc", filterTriggerTab_FillItems)
                    group:SetUserData("tab", tab)

                    local bound = setmetatable({ set = set }, {__index=ft})
                    bound:FillOptions(group, ftsettings)

                    local footerGroup = AceGUI:Create("SimpleGroup")
                    footerGroup:SetFullWidth(true)
                    footerGroup:SetLayout("Flow")
                    group:AddChild(footerGroup)

                    if filterTrigger[type].hasPriority and isRoot then
                        local prio = AceGUI:Create("Dropdown")
                        prio:SetLabel(L["Priority"])
                        prio:SetUserData("settings", ftsettings)
                        prio:SetList(L_WeightValuesFlat)
                        prio:SetValue(ftsettings[2])
                        prio:SetWidth(160)
                        prio:SetCallback("OnValueChanged", prio_OnValueChanged)
                        footerGroup:AddChild(prio)
                    end

                    local deleteButton = AceGUI:Create("Button")
                    deleteButton:SetText(DELETE)
                    deleteButton:SetWidth(110)
                    deleteButton:SetCallback("OnClick", deleteButton_onClick)
                    deleteButton:SetUserData("tab", tab)
                    deleteButton:SetUserData("type", type)
                    deleteButton:SetUserData("settings", settings)
                    deleteButton:SetUserData("i", fti)
                    footerGroup:AddChild(deleteButton)
                    
                    frame:AddChild(group)
                end

                local addGroup = AceGUI:Create("InlineGroup")
                addGroup:SetLayout("Flow")
                addGroup:SetFullWidth(true)
                addGroup:SetTitle(filterTrigger[type].addHeading)

                wipe(addButtonTmp)
                for name,ft in addon[filterTrigger[type].iterator](addon) do
                    local button = AceGUI:Create("Button")
                    if name == "OR" or name == "AND" then
                        button:SetWidth(85)
                    else
                        button:SetWidth(170)
                    end
                    button:SetText(ft:GetName())
                    button:SetUserData("tab", tab)
                    button:SetUserData("type", type)
                    button:SetUserData("settings", settings)
                    button:SetUserData("ft", ft)
                    button:SetCallback("OnClick", addButton_OnClick)
                    tinsert(addButtonTmp, button)
                end

                table.sort(addButtonTmp, cmpButton)
                for _, button in ipairs(addButtonTmp) do
                    addGroup:AddChild(button)
                end
                if type == "trigger" and isRoot then
                    local andOrNote = AceGUI:Create("Label")
                    andOrNote:SetText("|cffaaaaad(And): all sub-conditions must match.  (Or): any sub-condition is enough.|r")
                    andOrNote:SetFullWidth(true)
                    addGroup:AddChild(andOrNote)
                end
                frame:AddChild(addGroup)
            end

            function filterTriggerTab_Fill(frame, set, type)
                frame:ReleaseChildren()

                local scroll = AceGUI:Create("ScrollFrame")
                frame:AddChild(scroll)

                local helpText = AceGUI:Create("Label")
                if type == "trigger" then
                    helpText:SetText("Triggers define WHEN this set becomes active.  All top-level conditions must match (AND logic).  Use the (And)/(Or) blocks to build complex rules.")
                else
                    helpText:SetText("Filters adjust WHICH pets are preferred.  Each filter adds a priority bonus to pets matching that condition.  Higher priority = more likely to be picked.")
                end
                helpText:SetFullWidth(true)
                scroll:AddChild(helpText)

                local settings = set.settings[filterTrigger[type].settingsKey]
                frame:SetUserData("settings", settings)
                frame:SetUserData("type", type)
                frame:SetUserData("set", set)

                filterTriggerTab_FillItems(frame, scroll, type, settings, true)
            end
        end

        do
            --
            -- delete/Rename tab
            --

            local function renameText_onEnterPressed(frame, event, value)
                local set = frame:GetUserData("set")
                if not value or #value == 0 then
                    return
                elseif not strfind(value, "^%$") then
                    set:Rename(value)
                    mainPage_Fill(frame:GetUserData("mainPage"), value)
                else
                    -- TODO show a message
                    PlaySound(SOUNDKIT.IG_PLAYER_INVITE_DECLINE)
                end
            end

            local function delete_onClick(frame, event)
                local set = frame:GetUserData("set")
                set:Delete()
                mainPage_FillList(frame:GetUserData("mainPage"))
            end

            function deleteRenameTab_Fill(frame, set)
                frame:ReleaseChildren()

                local scroll = AceGUI:Create("ScrollFrame")
                scroll:SetLayout("Flow")
                
                local renameHeading = AceGUI:Create("Heading")
                renameHeading:SetText("Rename")
                renameHeading:SetFullWidth(true)
                scroll:AddChild(renameHeading)

                local renameText = AceGUI:Create("EditBox")
                renameText:SetLabel(L["Rename to"])
                renameText:SetUserData("set", set)
                renameText:SetUserData("mainPage", frame:GetUserData("mainPage"))
                renameText:SetCallback("OnEnterPressed", renameText_onEnterPressed)
                scroll:AddChild(renameText)

                local deleteHeading = AceGUI:Create("Heading")
                deleteHeading:SetText("Delete")
                deleteHeading:SetFullWidth(true)
                scroll:AddChild(deleteHeading)

                local delete = AceGUI:Create("Button")
                delete:SetUserData("set", set)
                delete:SetUserData("mainPage", frame:GetUserData("mainPage"))
                delete:SetText("Delete")
                delete:SetCallback("OnClick", delete_onClick)
                scroll:AddChild(delete)

                frame:AddChild(scroll)
            end
        end
    end
end

--
-- Option Factory Helper
--

do
    local function widget_update(frame)
        local widgetType = frame:GetUserData("widgetType")
        if widgetType then
            local settings = frame:GetUserData("settings")
            local value = settings[frame:GetUserData("key")]

            local valueMap = frame:GetUserData("valueMap")
            local name = valueMap and valueMap[value]

            if value then
                if name == nil and frame.SetValue then
                    frame:SetValue(value)
                else
                    frame:SetText(name or value)
                end
            end
        end
    end

    local function widget_execute(frame, event, ...)
        local settings = frame:GetUserData("settings")
        local widgetType = frame:GetUserData("widgetType")

        if widgetType == "execute" then
            frame:GetUserData("func")(frame, settings)
        else
            settings[frame:GetUserData("key")] = ...
            frame:GetUserData("parent"):_SettingsChanged()
        end

        widget_update(frame)
    end

    local tmpOpt = {}
    function addon._FT_MakeOption(parent, key, widgetType, settings, ...)
        wipe(tmpOpt)
        for i = 1, select('#', ...), 2 do
            local key, value = select(i, ...)
            tmpOpt[key] = value
        end

        -- actually make
        local widget
        if widgetType == "execute" then
            widget = AceGUI:Create("Button")
            widget:SetCallback("OnClick", widget_execute)
            widget:SetText(tmpOpt.name or "Click")
        elseif widgetType == "input" then
            if tmpOpt.multiline then
                widget = AceGUI:Create("MultiLineEditBox")
            else
                widget = AceGUI:Create("EditBox")
            end 
            widget:SetCallback("OnEnterPressed", widget_execute)

            if tmpOpt.name then
                widget:SetLabel(tmpOpt.name)
            end
        elseif widgetType == "toggle" then
            widget = AceGUI:Create("CheckBox")
            widget:SetCallback("OnValueChanged", widget_execute)
            
            if tmpOpt.name then
                widget:SetLabel(tmpOpt.name)
            end
        elseif widgetType == "range" then
            widget = AceGUI:Create("Slider")
            widget:SetCallback("OnValueChanged", widget_execute)

            if tmpOpt.name then
                widget:SetLabel(tmpOpt.name)
            end
            widget:SetSliderValues(tmpOpt.min or 0, tmpOpt.max or 100, tmpOpt.step or 1)
            widget:SetIsPercent(tmpOpt.isPercent)
        elseif widgetType == "select" then
            widget = AceGUI:Create("Dropdown")
            widget:SetCallback("OnValueChanged", widget_execute)

            if tmpOpt.name then
                widget:SetLabel(tmpOpt.name)
            end

            widget:SetUserData("valueMap", tmpOpt.values)
            widget:SetList(tmpOpt.values, tmpOpt.order)
        elseif widgetType == "multiselect" then
            error("not implemented")
        else
            error("got unexpected widgetType "..tostring(widgetType))
        end

        local width = tmpOpt.width
        if width == "full" then
            widget:SetFullWidth(true)
        elseif type(width) == "number" then
            widget:SetWidth(width)
        end

        for k,v in pairs(tmpOpt) do
            widget:SetUserData(k, v)
        end

        widget:SetUserData("parent", parent)
        widget:SetUserData("widgetUpdate", widget_update)
        widget:SetUserData("key", key)
        widget:SetUserData("widgetType", widgetType)
        widget:SetUserData("settings", settings)

        widget_update(widget)

        return widget
    end
end
