local _, ns = ...

-- /pcall pseudo: every text comes out longer and accented, the way translations make it,
-- to see in game that the window holds every language. The saved variables load before
-- the addon's files (LoadSavedVariablesFirst), so texts change as they are written, also
-- the ones files keep from the moment they load.
local pseudo = type(PetCall3DB) == "table" and type(PetCall3DB.global) == "table" and PetCall3DB.global.pseudo

-- accents from Latin-1 only: the game's fonts have no others
local ACCENT = { a = "á", e = "é", i = "í", o = "ó", u = "ú", c = "ç", n = "ñ", y = "ý",
    A = "Á", E = "É", I = "Í", O = "Ó", U = "Ú", C = "Ç", N = "Ñ", Y = "Ý" }
-- escapes and format specifiers stay as they are
local KEEP = { "|c%x%x%x%x%x%x%x%x", "|r", "|T.-|t", "|A.-|a", "|n", "%%[%-%d%.]*[sdif%%]", "\n" }

-- Lengthens a text the way translations do (short labels the most) and accents its letters.
function ns.Pseudo(s)
    if type(s) ~= "string" or s == "" then return s end
    local out, pos, visible = {}, 1, 0
    while pos <= #s do
        local kept
        for _, pat in ipairs(KEEP) do
            local a, b = s:find("^" .. pat, pos)
            if a then kept = s:sub(a, b) pos = b + 1 break end
        end
        if kept then
            out[#out + 1] = kept
        else
            local c = s:sub(pos, pos)
            local len = c:byte() >= 240 and 4 or c:byte() >= 224 and 3 or c:byte() >= 192 and 2 or 1
            c = s:sub(pos, pos + len - 1)
            out[#out + 1] = ACCENT[c] or c
            pos = pos + len
            visible = visible + 1
        end
    end
    local factor = visible <= 10 and 2 or visible <= 20 and 1.8 or visible <= 40 and 1.5 or 1.3
    local pad = math.max(0, math.ceil(visible * (factor - 1)) - 2)
    return "[" .. table.concat(out) .. string.rep("·", pad) .. "]"
end

local function put(t, key, value) rawset(t, key, pseudo and ns.Pseudo(value) or value) end

local L = setmetatable({}, { __index = function(t, key)
    if not pseudo then return key end
    put(t, key, key)
    return rawget(t, key)
end })
ns.L = L

local writerDefault = setmetatable({}, {
    __newindex = function(_, key, value)
        put(L, key, value == true and key or value)
    end,
})
local writerClient = setmetatable({}, {
    __newindex = function(_, key, value)
        if value ~= true then put(L, key, value) end
    end,
})

function ns.NewLocale(locale, isDefault)
    if isDefault then return writerDefault end
    if locale == GetLocale() then return writerClient end
    return nil
end
