local fs = require("luarocks.fs")

local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local util = require("luarocks.util")


--- Create a wrapper to make a script executable from the command-line.
-- @param script string: Pathname of script to be made executable.
-- @param target string: wrapper target pathname (without wrapper suffix).
-- @param name string: rock name to be used in loader context.
-- @param version string: rock version to be used in loader context.
-- @return boolean or (nil, string): True if succeeded, or nil and
-- an error message.
function fs.wrap_script(script, target, deps_mode, name, version, ...)
    assert(type(script) == "string" or not script)
    assert(type(target) == "string")
    assert(type(deps_mode) == "string")
    assert(type(name) == "string" or not name)
    assert(type(version) == "string" or not version)
 
    local batname = target .. ".bat"
    local wrapper = io.open(batname, "wb")
    if not wrapper then
       return nil, "Could not open "..batname.." for writing."
    end
 
    local lpath, lcpath = path.package_paths(deps_mode)
 
    local luainit = {
       "package.path="..util.LQ(lpath..";").."..package.path",
       "package.cpath="..util.LQ(lcpath..";").."..package.cpath",
    }
 
    local remove_interpreter = false
    if target == "luarocks" or target == "luarocks-admin" then
       if cfg.is_binary then
          remove_interpreter = true
       end
       luainit = {
          "package.path="..util.LQ(package.path),
          "package.cpath="..util.LQ(package.cpath),
       }
    end
 
    if name and version then
       local addctx = "local k,l,_=pcall(require,'luarocks.loader') _=k " ..
                      "and l.add_context('"..name.."','"..version.."')"
       table.insert(luainit, addctx)
    end
 
    local argv = {
       fs.Qb(dir.path(fs.variables["LUA_BINDIR"], cfg.lua_interpreter)),
       "-e",
       fs.Qb(table.concat(luainit, ";")),
       script and fs.Qb(script) or "%I%",
       ...
    }
    if remove_interpreter then
       table.remove(argv, 1)
       table.remove(argv, 1)
       table.remove(argv, 1)
    end
 
    wrapper:write("@echo off\r\n")
    wrapper:write("setlocal\r\n")
    if not script then
       wrapper:write([[IF "%*"=="" (set I=-i) ELSE (set I=)]] .. "\r\n")
    end
    wrapper:write("set "..fs.Qb("LUAROCKS_SYSCONFDIR="..cfg.sysconfdir) .. "\r\n")
    wrapper:write(table.concat(argv, " ") .. " %*\r\n")
    wrapper:write("exit /b %ERRORLEVEL%\r\n")
    wrapper:close()
    return true
 end
 