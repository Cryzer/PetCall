"""Run luacheck (pure Lua) under lupa with a Python-backed lfs (dev only).
Needs: python -m pip install --user lupa ; git clone https://github.com/lunarmodules/luacheck tools/.luacheck
       git clone https://github.com/luarocks/argparse tools/.argparse
Usage: python tools/luacheck.py [files...]   (default: Core UI tests)"""
import os
import sys
import lupa.lua51 as lupa

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)
args = sys.argv[1:] or ["Core", "UI", "Locales/enUS.lua"]
files = []
for a in args:
    if os.path.isdir(a):
        for d, _, fs in os.walk(a):
            files += [os.path.join(d, f).replace("\\", "/") for f in fs if f.endswith(".lua")]
    else:
        files.append(a)

lua = lupa.LuaRuntime(unpack_returned_tuples=True)

def attributes(path, attr=None):
    if not os.path.exists(path):
        return None
    info = {"mode": "directory" if os.path.isdir(path) else "file",
            "modification": int(os.stat(path).st_mtime), "size": os.stat(path).st_size}
    return info.get(attr) if attr else lua.table_from(info)

setup = lua.eval("""
function(py, lc, ap)
    package.path = lc .. "/src/?.lua;" .. lc .. "/src/?/init.lua;" .. ap .. "/src/?.lua;" .. package.path
    package.loaded.lfs = {
        currentdir = function() return py.cwd() end,
        attributes = function(p, a) return py.attributes(p, a) end,
        mkdir = function() return true end,
        _VERSION = "LuaFileSystem shim",
        dir = function(p) local t, i = py.listdir(p), 0; return function() i = i + 1; return t[i] end end,
    }
end""")
setup(lua.table_from({
    "cwd": lambda: os.getcwd().replace("\\", "/"),
    "attributes": attributes,
    "listdir": lambda p: lua.table_from([".", ".."] + os.listdir(p)),
}), "tools/.luacheck", "tools/.argparse")
lua.globals().arg = lua.table_from(files + ["--no-cache"])
# luacheck ends with os.exit inside its own error trap, so exit the process directly
def hard_exit(code):
    sys.stdout.flush()
    os._exit(int(code))

run = lua.eval("""
function(hard_exit)
    os.exit = function(c)
        io.stdout:flush()
        hard_exit((c == true and 0) or (c == false and 1) or c or 0)
    end
    require("luacheck.main")
    return 0
end""")
sys.exit(run(hard_exit))
