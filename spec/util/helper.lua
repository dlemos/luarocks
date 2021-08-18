local helper = {}

local lfs = require("lfs")
local fs = require("rocks.fs")
local sysdetect = require("rocks.sysdetect")

local LUA_VERSION = _VERSION:sub(5)
local IS_WINDOWS = (package.config:sub(1, 1) == "\\")

----------

local function merge_tables(bottom, top)
   local t = {}
   if bottom then
      for k, v in pairs(bottom) do
         t[k] = v
      end
   end
   if top then
      for k, v in pairs(top) do
         t[k] = v
      end
   end
   return t
end

local function command_line(command, env_variables)
   local out = ""

   if env_variables then
      if IS_WINDOWS then
         for k,v in pairs(env_variables) do
            out = out .. "set " .. k .. "=" .. v .. "&"
         end
         out = out:sub(1, -2) .. "&"
      else
         out = out .. "export "
         for k,v in pairs(env_variables) do
            out = out .. k .. "='" .. v .. "' "
         end
         -- remove last space and add ';' to separate exporting variables from command
         out = out:sub(1, -2) .. "; "
      end
   end

   out = out .. command .. " 2>&1"

   if os.getenv("LUAROCKS_DEBUG") then
      print(out)
   end
   return out
end


----------

local root_dir
local helper_tree
local helper_env
local build_config_string
local build_config_table
local lua_executable
local luarocks_script

local fs_platforms = {
   linux = { "linux", "unix" },
   freebsd = { "freebsd", "unix" },
   netbsd = { "netbsd", "unix" },
   macosx = { "macosx", "unix" },
   windows = { "win32" },
}

local function init()
   local sys, _ = sysdetect.detect()
   fs.init(fs_platforms[sys] or { "unix" })

   root_dir = fs.absolute_name(".")
   local src_in_package_path = root_dir .. "/src/?.lua;" .. package.path
   helper_env = {
      LUA_PATH = src_in_package_path,
      ["LUA_PATH_5_" .. LUA_VERSION:sub(-1, -1)] = src_in_package_path,
   }
   local build_config_filename = "build/config-" .. LUA_VERSION .. ".lua"
   local build_config_fd = io.open(build_config_filename, "r")
   if build_config_fd then
      build_config_string = build_config_fd:read("*a")
      build_config_fd:close()
   else
      print(build_config_filename .. " not found. Please run ./configure and make prior to running the tests.")
      os.exit(1)
   end
   build_config_table = { home = os.getenv("HOME") or os.getenv("TEMP") }
   load(build_config_string, "", "t", build_config_table)()
   lua_executable = build_config_table.variables.LUA_BINDIR .. "/" .. build_config_table.lua_interpreter
   luarocks_script = root_dir .. "/src/bin/luarocks"
end

function helper.before_each_integration()
   -- cleanup from previous test
   if helper_tree then
      helper.remove_dir(helper_tree)
   end
   if helper_env.LUAROCKS_CONFIG then
      os.remove(helper_env.LUAROCKS_CONFIG)
   end

   -- setup for next test
   local tmpfile = os.tmpname()
   local fd = io.open(tmpfile, "w")
   helper_tree = root_dir .. "/tests/tmptree_" .. math.random(1000000)
   lfs.mkdir(helper_tree)
   fd:write(build_config_string)
   fd:write("\n")
   fd:write([[
      rocks_trees = {
          "]] .. helper_tree .. [["
      }
      rocks_servers = {
          "]] .. root_dir .. [[/spec/fixtures/a_repo",
      }
   ]])
   fd:close()
   helper_env.LUAROCKS_CONFIG = tmpfile

   lfs.chdir(helper_tree)
end

function helper.teardown_integration()
   fs.change_dir(root_dir)
end

local luacov_runner

function helper.setup_unit()
   local cfg = require("luarocks.core.cfg")
   local deps = require("luarocks.deps")
   luacov_runner = helper.init_luacov_runner()
   cfg.init()
   deps.check_lua_incdir(cfg.variables)
   deps.check_lua_libdir(cfg.variables)
end

function helper.teardown_unit()
   luacov_runner.shutdown()
   fs.change_dir(root_dir)
end

function helper.before_each_unit()
   fs.change_dir(root_dir)
   if helper_tree then
      helper.remove_dir(helper_tree)
   end

   helper_tree = root_dir .. "/tests/tmptree_" .. math.random(1000000)
   lfs.mkdir(helper_tree)
   fs.change_dir(helper_tree)
   local path = require("luarocks.path")
   path.use_tree(lfs.currentdir())
end

function helper.fixtures_dir()
   return root_dir .. "/spec/fixtures"
end

function helper.tree_dir()
   return helper_tree
end

function helper.rocks_dir()
   return helper_tree .. "/lib/luarocks/rocks-" .. LUA_VERSION
end

function helper.bin_dir()
   return helper_tree .. "/bin/"
end

function helper.lib_lua_dir()
   return helper_tree .. "/lib/lua/" .. LUA_VERSION
end

function helper.share_lua_dir()
   return helper_tree .. "/share/lua/" .. LUA_VERSION
end

function helper.lua_version()
   return LUA_VERSION
end

function helper.lib_extension()
   return IS_WINDOWS and "dll" or "so"
end

--- Create a file containing a string.
-- @param pathname string: path to file.
-- @param str string: content of the file.
function helper.write_file(pathname, str, finally)
   local file = assert(io.open(pathname, "w"))
   file:write(str)
   file:close()
   if finally then
      finally(function()
         os.remove(pathname)
      end)
   end
end

function helper.make_dir(path)
   path = path:gsub("[/\\]*$", "")
   -- try to make dir
   local ok, err = lfs.mkdir(path)
   if ok then
      return true
   end
   -- failed; try to split and get parent dir
   local base, rest = path:match("(.-)[/\\]([^/\\]+)$")
   if base then
      -- recursively try to create parent dir
      ok, err = helper.make_dir(base)
      if ok then
         -- if that worked, try to create dir again
         ok, err = lfs.mkdir(path)
      end
   end
   return ok, err
end

--- Remove directory recursively
-- @param path string: directory path to delete
function helper.remove_dir(path)
   if lfs.attributes(path, "mode") ~= nil then
      for file in lfs.dir(path) do
         if file ~= "." and file ~= ".." then
            local full_path = path..'/'..file

            if lfs.attributes(full_path, "mode") == "directory" then
               helper.remove_dir(full_path)
            else
               os.remove(full_path)
            end
         end
      end
   end
   lfs.rmdir(path)
end

function helper.copy(source, destination)
   local r_source, err = io.open(source, "r")
   local r_destination, err = io.open(destination, "w")

   while true do
      local block = r_source:read(8192)
      if not block then break end
      r_destination:write(block)
   end

   r_source:close()
   r_destination:close()
end

function helper.copy_dir(source_path, target_path)
   if IS_WINDOWS then
      os.execute("xcopy " .. source_path .. " " .. target_path .. " /s /e /i")
   else
      os.execute("cp -a ".. source_path .. "/. " .. target_path)
   end
end

function helper.os()
   if IS_WINDOWS then
      return "windows"
   else
      return sysdetect.detect()
   end
end

function helper.get_tmp_path()
   local path = os.tmpname()
   if IS_WINDOWS and not path:find(":") then
      path = os.getenv("TEMP") .. path
   end
   os.remove(path)
   return path
end

--- Helper function that runs the given function inside
-- a temporary directory, isolating it
-- @param f function: the function to be run
function helper.run_in_tmp(f, finally)
   local olddir = lfs.currentdir()
   local tmpdir = helper.get_tmp_path()
   lfs.mkdir(tmpdir)
   lfs.chdir(tmpdir)

   if finally then
      finally(function()
         lfs.chdir(olddir)
         lfs.rmdir(tmpdir)
      end)
   end

   f(tmpdir)
end

function helper.init_luacov_runner()
   local luacov_config_file = root_dir .. "/luacov.config"
   helper.write_file(luacov_config_file, [[
      return {
         statsfile = "]] .. root_dir .. [[/luacov.stats.out",
         reportfile = "]] .. root_dir .. [[/luacov.report.out",
         modules = {
            ["luarocks"] = "src/bin/luarocks",
            ["luarocks-admin"] = "src/bin/luarocks-admin",
            ["luarocks.*"] = "src",
            ["luarocks.*.*"] = "src",
            ["luarocks.*.*.*"] = "src"
         }
      }
   ]])
   local runner = require("luacov.runner")
   runner.init(luacov_config_file)
   runner.tick = true
   return runner
end

helper.run = {
   luarocks_bool = function(arg, user_env)
      local env = merge_tables(helper_env, user_env)
      local ok = os.execute(command_line(table.concat({lua_executable, luarocks_script, arg}, " "), env))
      return (ok == true or ok == 0)
   end,

   luarocks = function(arg, user_env)
      local env = merge_tables(helper_env, user_env)
      local pd = io.popen(command_line(table.concat({lua_executable, luarocks_script, arg}, " "), env), "r")
      if pd then
         local output = pd:read("*a")
         pd:close()
         return output
      end
      return nil
   end,
}

init()

return helper
