local wrap_script = {}
local fs = require("rocks.fs")

local cfg = require("luarocks.core.cfg")
local dir = require("luarocks.dir")
local path = require("luarocks.path")
local util = require("luarocks.util")

--- Check if platform is unix
-- @return boolean: true if LuaRocks is currently running on unix.
local function is_platform_unix() 
   if package.config:sub(1,1) == "/" then
      return true
   else
      return false
   end
end

--- Create a wrapper to make a script executable from the command-line.
-- @param script string: Pathname of script to be made executable.
-- @param target string: wrapper target pathname (without wrapper suffix).
-- @param name string: rock name to be used in loader context.
-- @param version string: rock version to be used in loader context.
-- @return boolean or (nil, string): True if succeeded, or nil and
-- an error message.
function wrap_script.wrap(script, target, deps_mode, name, version, ...)
    assert(type(script) == "string" or not script)
    assert(type(target) == "string")
    assert(type(deps_mode) == "string")
    assert(type(name) == "string" or not name)
    assert(type(version) == "string" or not version)
 
    local is_unix = is_platform_unix();
    local wrapper
    if is_unix then
      wrapper = io.open(target, "w")
      if not wrapper then
         return nil, "Could not open "..target.." for writing."
      end
    else
      local batname = target .. ".bat"
      wrapper = io.open(batname, "wb")
      if not wrapper then
         return nil, "Could not open "..batname.." for writing."
      end
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
 
    if is_unix then
      if name and version then
         local addctx = "local k,l,_=pcall(require,"..util.LQ("luarocks.loader")..") _=k " ..
                        "and l.add_context("..util.LQ(name)..","..util.LQ(version)..")"
         table.insert(luainit, addctx)
      end
   
      local argv = {
         fs.Q(dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter)),
         "-e",
         fs.Q(table.concat(luainit, ";")),
         script and fs.Q(script) or [[$([ "$*" ] || echo -i)]],
         ...
      }
      if remove_interpreter then
         table.remove(argv, 1)
         table.remove(argv, 1)
         table.remove(argv, 1)
      end

      wrapper:write("#!/bin/sh\n\n")
      wrapper:write("LUAROCKS_SYSCONFDIR="..fs.Q(cfg.sysconfdir) .. " ")
      wrapper:write("exec "..table.concat(argv, " ")..' "$@"\n')
      wrapper:close()

      if fs.set_permissions(target, "exec", "all") then
         return true
      else
         return nil, "Could not make "..target.." executable."
      end
    else
      if name and version then
         local addctx = "local k,l,_=pcall(require,'luarocks.loader') _=k " ..
                        "and l.add_context('"..name.."','"..version.."')"
         table.insert(luainit, addctx)
      end
   
      local argv = {
         fs.Qb(dir.path(cfg.variables["LUA_BINDIR"], cfg.lua_interpreter)),
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
end

return wrap_script