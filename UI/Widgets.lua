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
    b.onClick = onClick                -- a field, so a reused button can be given a new one
    b:SetScript("OnClick", function(self, button) self.onClick(self, button) end)
    ns.Skin:Apply("Button", b)
    return b
end

-- Quality colour lifted towards white when it is dark: the stock rare blue is hard to read
-- on dark backgrounds
function Widgets.QualityColor(quality)
    local r, g, b = C_Item.GetItemQualityColor((quality or 2) - 1)
    if 0.3 * r + 0.59 * g + 0.11 * b < 0.6 then
        r, g, b = r + (1 - r) * 0.35, g + (1 - g) * 0.35, b + (1 - b) * 0.35
    end
    return r, g, b
end

-- Marks a button as the picked one of a group: accent tint, accent underline, white text
function Widgets.SetPicked(b, on)
    if not b.pickBg then
        b.pickBg = b:CreateTexture(nil, "OVERLAY", nil, -1)
        b.pickBg:SetPoint("TOPLEFT", 2, -2)
        b.pickBg:SetPoint("BOTTOMRIGHT", -2, 2)
        b.pickLine = b:CreateTexture(nil, "OVERLAY")
        b.pickLine:SetPoint("BOTTOMLEFT", 2, 2)
        b.pickLine:SetPoint("BOTTOMRIGHT", -2, 2)
        b.pickLine:SetHeight(2)
    end
    local r, g, bl = ns.Skin:Accent()
    b.pickBg:SetColorTexture(r, g, bl, 0.18)
    b.pickLine:SetColorTexture(r, g, bl, 1)
    b.pickBg:SetShown(on)
    b.pickLine:SetShown(on)
    b.picked = on and true or false
    b:GetFontString():SetTextColor(1, on and 1 or 0.82, on and 1 or 0)   -- white when picked, gold otherwise
end

-- A menu pinned to a button (above it) instead of at the cursor, the way Blizzard's
-- dropdowns open; falls back to a plain context menu on clients without the menu manager.
function Widgets.OpenMenuAbove(owner, build)
    if MenuUtil.CreateRootMenuDescription and Menu and Menu.GetManager and MenuVariants and AnchorUtil then
        local root = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
        build(owner, root)
        Menu.GetManager():OpenMenu(owner, root, AnchorUtil.CreateAnchor("BOTTOMLEFT", owner, "TOPLEFT", 0, 2))
    else
        MenuUtil.CreateContextMenu(owner, build)
    end
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
            Widgets.SetPicked(b, b.value == cur)
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
    cb.getter, cb.setter = get, set    -- fields, so a reused box can be given new ones
    cb:SetScript("OnShow", function(self) self:SetChecked(self.getter() and true or false) end)
    cb:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        self.setter(self:GetChecked())
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

-- Setting it again replaces the text (hooked once per frame), and nil title and body
-- turn it off, so frames that are reused do not stack up tooltips.
function Widgets.Tooltip(frame, title, body)
    frame.tipTitle, frame.tipBody = title, body
    if frame.tipHooked then return end
    frame.tipHooked = true
    frame:HookScript("OnEnter", function(self)
        local t, b = self.tipTitle, self.tipBody
        if not t and not b then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        t = type(t) == "function" and t(self) or t
        if t then GameTooltip:SetText(t, 1, 1, 1) end
        if b then GameTooltip:AddLine(type(b) == "function" and b(self) or b, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function(self) if self.tipTitle or self.tipBody then GameTooltip:Hide() end end)
end

local function noop() end

-- Frames for a view that is drawn again from scratch: Release() puts every one away and
-- Take (or Label, Button...) gives back one of that kind, or makes it the first time.
-- The game never frees frames, so a redraw must not make new ones each time.
function Widgets.NewPool()
    local pool, used, free = {}, {}, {}

    -- make() builds a new frame; whoever takes it sets it up for its new use
    function pool:Take(kind, parent, make)
        local list = free[kind]
        if not list then list = {} free[kind] = list end
        local f = table.remove(list)
        if f then
            f:SetParent(parent)
            f:Show()
        else
            f = make()
            f.poolKind = kind
        end
        used[#used + 1] = f
        return f
    end

    function pool:Release()
        for _, f in ipairs(used) do
            f:Hide()
            f:ClearAllPoints()
            if f.tipHooked then Widgets.Tooltip(f, nil) end
            local list = free[f.poolKind]
            list[#list + 1] = f
        end
        wipe(used)
    end

    function pool:Label(parent, text, font)
        local fs = self:Take("label", parent, function() return Widgets.Label(parent) end)
        fs:SetFontObject(font or "GameFontHighlight")
        fs:SetWidth(0)
        fs:SetWordWrap(true)
        fs:SetText(text or "")
        return fs
    end

    -- kind: buttons a view changes further (colours, sizes) are kept apart from plain ones
    function pool:Button(parent, text, onClick, kind)
        local b = self:Take(kind or "button", parent, function() return Widgets.Button(parent, "", noop) end)
        b:SetText(text)
        b:SetHeight(22)
        b:SetWidth(math.max(80, b:GetFontString():GetStringWidth() + 24))
        b:SetEnabled(true)
        b.onClick = onClick
        return b
    end

    function pool:Dropdown(parent, width, buildMenu, defaultText)
        local dd = self:Take(defaultText and "textDropdown" or "dropdown", parent, function() return Widgets.Dropdown(parent, width, noop) end)
        dd:SetWidth(width)
        dd:SetupMenu(buildMenu)
        if defaultText then dd:SetDefaultText(defaultText) end
        return dd
    end

    function pool:Checkbox(parent, text, get, set)
        local cb = self:Take("checkbox", parent, function() return Widgets.Checkbox(parent, "", noop, noop) end)
        cb.text:SetText(text)
        cb.getter, cb.setter = get, set
        cb:SetChecked(get() and true or false)
        return cb
    end

    -- kind keeps boxes with different scripts apart; the caller sets size, text and scripts
    function pool:EditBox(parent, kind)
        return self:Take(kind, parent, function()
            local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
            eb:SetAutoFocus(false)
            ns.Skin:Apply("EditBox", eb)
            return eb
        end)
    end

    function pool:Frame(parent, kind)
        return self:Take(kind, parent, function() return CreateFrame("Frame", nil, parent) end)
    end

    return pool
end
