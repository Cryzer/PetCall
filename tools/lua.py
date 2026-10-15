"""Run a Lua 5.1 script via lupa (dev only). Usage: python tools/lua.py file.lua [args...]"""
import os
import sys

try:
    import lupa.lua51 as lupa
except ImportError:
    sys.exit("lupa is required: python -m pip install --user lupa")

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)
lua = lupa.LuaRuntime(unpack_returned_tuples=True)
lua.globals().arg = lua.table_from(sys.argv[2:])
run = lua.eval("function(p) local f = assert(loadfile(p)); return f() end")
code = run(sys.argv[1].replace("\\", "/"))
sys.exit(code if isinstance(code, int) else 0)
