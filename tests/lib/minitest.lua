-- Minimal busted-like test runner for plain Lua 5.1.
local M = { results = { passed = 0, failed = 0, errors = {} } }
local stack = {}

local function deepEqual(a, b, seen)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    seen = seen or {}
    if seen[a] == b then return true end
    seen[a] = b
    for k, v in pairs(a) do
        if not deepEqual(v, b[k], seen) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local function dump(v, depth)
    depth = depth or 0
    if type(v) ~= "table" then return type(v) == "string" and string.format("%q", v) or tostring(v) end
    if depth > 3 then return "{...}" end
    local parts = {}
    for k, x in pairs(v) do
        parts[#parts + 1] = "[" .. dump(k, depth + 1) .. "]=" .. dump(x, depth + 1)
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

local function fail(msg) error({ minitest = true, msg = msg }, 3) end

assert = setmetatable({
    equal = function(e, a, m) if e ~= a then fail((m or "") .. " expected " .. dump(e) .. ", got " .. dump(a)) end end,
    same = function(e, a, m) if not deepEqual(e, a) then fail((m or "") .. " expected " .. dump(e) .. ", got " .. dump(a)) end end,
    is_true = function(v, m) if v ~= true then fail((m or "") .. " expected true, got " .. dump(v)) end end,
    is_false = function(v, m) if v ~= false then fail((m or "") .. " expected false, got " .. dump(v)) end end,
    is_nil = function(v, m) if v ~= nil then fail((m or "") .. " expected nil, got " .. dump(v)) end end,
    is_not_nil = function(v, m) if v == nil then fail((m or "") .. " expected non-nil") end end,
    has_error = function(f, m) if pcall(f) then fail((m or "") .. " expected an error") end end,
    has_no_error = function(f, m)
        local ok, err = pcall(f)
        if not ok then fail((m or "") .. " unexpected error: " .. tostring(type(err) == "table" and err.msg or err)) end
    end,
}, { __call = function(_, v, m) if not v then fail(m or "assertion failed") end return v end })

function describe(name, fn)
    stack[#stack + 1] = { name = name, before = {} }
    fn()
    stack[#stack] = nil
end

function before_each(fn)
    local b = stack[#stack].before
    b[#b + 1] = fn
end

function it(name, fn)
    local names, befores = {}, {}
    for _, s in ipairs(stack) do
        names[#names + 1] = s.name
        for _, b in ipairs(s.before) do befores[#befores + 1] = b end
    end
    names[#names + 1] = name
    local full = table.concat(names, " > ")
    local ok, err = pcall(function()
        for _, b in ipairs(befores) do b() end
        fn()
    end)
    if ok then
        M.results.passed = M.results.passed + 1
    else
        M.results.failed = M.results.failed + 1
        local msg = type(err) == "table" and err.msg or tostring(err)
        M.results.errors[#M.results.errors + 1] = full .. "\n    " .. msg
    end
end

return M
