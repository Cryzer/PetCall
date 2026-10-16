local _, ns = ...

local CreateFrame, C_Timer = CreateFrame, C_Timer
local Widgets = {}
ns.Widgets = Widgets

-- Generic confirmation: StaticPopup_Show("PETCALL_CONFIRM", text, nil, { onAccept = fn })
StaticPopupDialogs["PETCALL_CONFIRM"] = {
    text = "%s", button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(_, data) data.onAccept() end,
}

-- Inline status dot; the game fonts have no circle glyphs. kind: "on" | "off" | "warn"
local DOTS = { on = "Interface\\COMMON\\Indicator-Green", off = "Interface\\COMMON\\Indicator-Gray",
    warn = "Interface\\COMMON\\Indicator-Yellow" }
function Widgets.Dot(kind) return "|T" .. DOTS[kind] .. ":12:12|t" end

function Widgets.Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end

function Widgets.Button(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetText(text)
    b:SetHeight(22)
    b:SetWidth(math.max(80, b:GetFontString():GetStringWidth() + 24))
    b:SetScript("OnClick", function(self, button) onClick(self, button) end)
    ns.Skin:Apply("Button", b)
    return b
end

-- Row of joined buttons, one selected: items = { {value =, label =} }, get() -> value
function Widgets.Segmented(parent, items, get, onPick)
    local f = CreateFrame("Frame", nil, parent)
    f.buttons = {}
    local x = 0
    for i, item in ipairs(items) do
        local b = Widgets.Button(f, item.label, function() onPick(item.value) f:Refresh() end)
        b:SetWidth(math.max(64, b:GetFontString():GetStringWidth() + 20))
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() - 2
        b.value = item.value
        f.buttons[i] = b
    end
    f:SetSize(math.max(1, x), 22)
    function f:Refresh()
        local cur = get()
        for _, b in ipairs(self.buttons) do
            local on = b.value == cur
            if on then b:LockHighlight() else b:UnlockHighlight() end
            b:GetFontString():SetTextColor(1, on and 1 or 0.82, on and 1 or 0)   -- white when picked, gold otherwise
        end
    end
    f:Refresh()
    return f
end

function Widgets.Checkbox(parent, label, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb.text:SetText(label)
    cb.text:SetFontObject("GameFontHighlight")
    cb:SetScript("OnShow", function(self) self:SetChecked(get() and true or false) end)
    cb:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        set(self:GetChecked())
    end)
    cb:SetChecked(get() and true or false)
    ns.Skin:Apply("Checkbox", cb)
    return cb
end

-- buildMenu(owner, rootDescription) uses MenuUtil description API (CreateRadio/CreateButton/...)
function Widgets.Dropdown(parent, width, buildMenu)
    local dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetWidth(width)
    dd:SetupMenu(buildMenu)
    ns.Skin:Apply("Dropdown", dd)
    return dd
end

function Widgets.Search(parent, onChanged)
    local eb = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
    eb:SetHeight(20)
    eb:SetAutoFocus(false)
    local timer
    eb:HookScript("OnTextChanged", function(self, userInput)
        if timer then timer:Cancel() end
        timer = C_Timer.NewTimer(userInput and 0.15 or 0, function()
            timer = nil
            onChanged(self:GetText())
        end)
    end)
    ns.Skin:Apply("EditBox", eb, { padInput = true })
    return eb
end

function Widgets.Inset(parent)
    local f = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    ns.Skin:Apply("Inset", f)
    return f
end

function Widgets.Tooltip(frame, title, body)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local t = type(title) == "function" and title(self) or title
        if t then GameTooltip:SetText(t, 1, 1, 1) end
        if body then GameTooltip:AddLine(type(body) == "function" and body(self) or body, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
