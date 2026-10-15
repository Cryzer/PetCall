local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

local writerDefault = setmetatable({}, {
    __newindex = function(_, key, value)
        rawset(L, key, value == true and key or value)
    end,
})
local writerClient = setmetatable({}, {
    __newindex = function(_, key, value)
        if value ~= true then rawset(L, key, value) end
    end,
})

function ns.NewLocale(locale, isDefault)
    if isDefault then return writerDefault end
    if locale == GetLocale() then return writerClient end
    return nil
end
