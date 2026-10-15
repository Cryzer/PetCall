-- Decoder for the AceSerializer-3.0 rev 1 format (PetCall 1.x export strings).
-- Derived from AceSerializer-3.0 (Ace3, BSD licence).
local _, ns = ...

local gsub, gmatch, strchar, strbyte, tonumber, error, pcall = string.gsub, string.gmatch, string.char, string.byte, tonumber, error, pcall

local function unescape(esc)
    if esc < "~\122" then return strchar(strbyte(esc, 2, 2) - 64) end
    if esc == "~\122" then return "\030" end
    if esc == "~\123" then return "\127" end
    if esc == "~\124" then return "\126" end
    if esc == "~\125" then return "\94" end
    error("bad escape")
end

local function number(s)
    if s == "1.#INF" or s == "inf" then return math.huge end
    if s == "-1.#INF" or s == "-inf" then return -math.huge end
    return tonumber(s)
end

local value

function value(iter, single, ctl, data)
    if not single then ctl, data = iter() end
    if not ctl then error("missing terminator") end
    if ctl == "^^" then return end
    local res
    if ctl == "^S" then
        res = gsub(data, "~.", unescape)
    elseif ctl == "^N" then
        res = number(data) or error("bad number")
    elseif ctl == "^F" then
        local ctl2, e = iter()
        if ctl2 ~= "^f" then error("bad float") end
        local m, ex = tonumber(data), tonumber(e)
        if not (m and ex) then error("bad float") end
        res = m * (2 ^ ex)
    elseif ctl == "^B" then
        res = true
    elseif ctl == "^b" then
        res = false
    elseif ctl == "^Z" then
        res = nil
    elseif ctl == "^T" then
        res = {}
        while true do
            ctl, data = iter()
            if ctl == "^t" then break end
            local k = value(iter, true, ctl, data)
            if k == nil then error("bad table") end
            ctl, data = iter()
            local v = value(iter, true, ctl, data)
            if v == nil then error("bad table") end
            res[k] = v
        end
    else
        error("bad control code")
    end
    if single then return res end
    return res, value(iter)
end

function ns.LegacyDeserialize(str)
    str = gsub(str or "", "[%c ]", "")
    local iter = gmatch(str, "(^.)([^^]*)")
    local ctl = iter()
    if ctl ~= "^1" then return false, "not AceSerializer data" end
    return pcall(value, iter)
end
