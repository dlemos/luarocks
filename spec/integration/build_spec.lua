local helper = require("spec.util.helper")
local lfs = require("lfs")
local run = helper.run

local c_module_source = [[
   #include <lua.h>
   #include <lauxlib.h>

   int luaopen_c_module(lua_State* L) {
     lua_newtable(L);
     lua_pushinteger(L, 1);
     lua_setfield(L, -2, "c_module");
     return 1;
   }
]]

describe("LuaRocks build #integration", function()
   before_each(helper.before_each_integration)
   teardown(helper.teardown_integration)

   describe("basic testing set", function()
      it("invalid", function()
         assert.is_false(run.luarocks_bool("build invalid"))
      end)

      it("with no arguments behaves as luarocks make", function()
         helper.run_in_tmp(function(tmpdir)
            helper.write_file("c_module-1.0-1.rockspec", [[
               package = "c_module"
               version = "1.0-1"
               source = {
                  url = "http://example.com/c_module"
               }
               build = {
                  type = "builtin",
                  modules = {
                     c_module = { "c_module.c" }
                  }
               }
            ]], finally)
            helper.write_file("c_module.c", c_module_source, finally)

            assert.is_true(run.luarocks_bool("init"))
            assert.is_true(run.luarocks_bool("build"))
            assert.truthy(lfs.attributes(tmpdir .. "/c_module." .. helper.lib_extension()))
         end, finally)
      end)
   end)

   describe("building with flags", function()
      it("fails if it doesn't have the permissions to access the specified tree #unix", function()
         assert.is_false(run.luarocks_bool("build --tree=/usr spec/fixtures/a_rock-1.0.1-rockspec"))
         assert.falsy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
      end)

      it("fails if it doesn't have the permissions to access the specified tree's parent #unix", function()
         assert.is_false(run.luarocks_bool("build --tree=/usr/invalid spec/fixtures/a_rock-1.0-1.rockspec"))
         assert.falsy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
      end)

      it("verbose", function()
         helper.run_in_tmp(function(tmpdir)
            helper.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            helper.write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("build --verbose test-1.0-1.rockspec"))
            assert.truthy(lfs.attributes(helper.rocks_dir() .. "/test/1.0-1/test-1.0-1.rockspec"))
         end, finally)
      end)

      it("fails if the deps-mode argument is invalid", function()
         assert.is_false(run.luarocks_bool("build --deps-mode=123 spec/fixtures/a_rock-1.0-1.rockspec"))
         assert.falsy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
      end)

      it("with --only-sources", function()
         assert.is_true(run.luarocks_bool("download --rockspec a_rock 1.0"))
         assert.is_false(run.luarocks_bool("build --only-sources=\"http://example.com\" a_rock-1.0-1.rockspec"))
         assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))

         assert.is_true(run.luarocks_bool("download --source a_rock 1.0"))
         assert.is_true(run.luarocks_bool("build --only-sources=\"http://example.com\" a_rock-1.0-1.src.rock"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))

         assert.is_true(os.remove("a_rock-1.0-1.rockspec"))
         assert.is_true(os.remove("a_rock-1.0-1.src.rock"))
      end)

      it("fails if an empty tree is given", function()
         assert.is_false(run.luarocks_bool("build --tree=\"\" spec/fixtures/a_rock-1.0-1.rockspec"))
         assert.falsy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
      end)
   end)

   describe("basic builds", function()
      it("diff version", function()
         assert.is_true(run.luarocks_bool("build a_rock 1.0"))
         assert.is_true(run.luarocks_bool("build a_rock 2.0"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1/a_rock-2.0-1.rockspec"))
      end)

      it("with a script", function()
         assert.is_true(run.luarocks_bool("build has_script"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/has_script/1.0-1/has_script-1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.bin_dir() .. "/a_script"))
      end)

      it("fails if the current platform is not supported", function()
         helper.run_in_tmp(function(tmpdir)
            helper.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               supported_platforms = {
                  "unix", "macosx"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            helper.write_file("test.lua", "return {}", finally)

            if helper.os() == "windows" then
               assert.is_false(run.luarocks_bool("build test-1.0-1.rockspec")) -- Error: This rockspec does not support windows platforms
               assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/test/1.0-1/test-1.0-1.rockspec"))
            else
               assert.is_true(run.luarocks_bool("build test-1.0-1.rockspec"))
               assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/test/1.0-1/test-1.0-1.rockspec"))
            end
         end, finally)
      end)

      it("with skipping dependency checks", function()
         helper.run_in_tmp(function(tmpdir)
            helper.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               dependencies = {
                  "a_rock 1.0"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            helper.write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("build test-1.0-1.rockspec --deps-mode=none"))
            assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/test/1.0-1/test-1.0-1.rockspec"))
         end)
      end)

      it("supports --pin #pinning", function()
         helper.run_in_tmp(function(tmpdir)
            helper.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               dependencies = {
                  "a_rock >= 0.8"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            helper.write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("build test-1.0-1.rockspec --pin --tree=lua_modules"))
            assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/1.0-1/test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/a_rock/2.0-1/a_rock-2.0-1.rockspec"))
            local lockfilename = "./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/1.0-1/luarocks.lock"
            assert.is.truthy(lfs.attributes(lockfilename))
            local lockdata = loadfile(lockfilename)()
            assert.same({
               dependencies = {
                  ["a_rock"] = "2.0-1",
                  ["lua"] = helper.lua_version() .. "-1",
               }
            }, lockdata)
         end)
      end)

      it("supports --pin --only-deps #pinning", function()
         helper.run_in_tmp(function(tmpdir)
            helper.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               dependencies = {
                  "a_rock >= 0.8"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            helper.write_file("test.lua", "return {}", finally)

            assert.is_true(run.luarocks_bool("build test-1.0-1.rockspec --pin --only-deps --tree=lua_modules"))
            assert.is.falsy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/1.0-1/test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/a_rock/2.0-1/a_rock-2.0-1.rockspec"))
            assert.is.truthy(lfs.attributes("./luarocks.lock"))
            local lockfilename = "./luarocks.lock"
            assert.is.truthy(lfs.attributes(lockfilename))
            local lockdata = loadfile(lockfilename)()
            assert.same({
               dependencies = {
                  ["a_rock"] = "2.0-1",
                  ["lua"] = helper.lua_version() .. "-1",
               }
            }, lockdata)
         end)
      end)

      it("dependency using ~> builds right version", function()
         assert.is_true(run.luarocks_bool("build for_lua_version"))

         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/for_lua_version/1." .. helper.lua_version() .. "-1/for_lua_version-1." .. helper.lua_version() .. "-1.rockspec"))
      end)
   end)

   describe("#namespaces", function()
      it("builds a namespaced package from the command-line", function()
         assert(run.luarocks_bool("build a_user/a_rock" ))
         assert.is_false(run.luarocks_bool("show a_rock 1.0"))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1/rock_namespace"))
      end)

      it("builds a package with a namespaced dependency", function()
         assert(run.luarocks_bool("build has_namespaced_dep" ))
         assert(run.luarocks_bool("show has_namespaced_dep"))
         assert.is_false(run.luarocks_bool("show a_rock 1.0"))
         assert(run.luarocks_bool("show a_rock 2.0"))
      end)

      it("builds a package reusing a namespaced dependency", function()
         assert(run.luarocks_bool("build a_user/a_rock" ))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1/rock_namespace"))
         local output = run.luarocks("build has_namespaced_dep" )
         assert.has.no.match("Missing dependencies", output)
      end)

      it("builds a package considering namespace of locally installed package", function()
         assert(run.luarocks_bool("build a_user/a_rock" ))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1/rock_namespace"))
         local output = run.luarocks("build has_another_namespaced_dep" )
         assert.has.match("Missing dependencies", output)
         print(output)
         assert(run.luarocks_bool("show a_rock 3.0"))
      end)
   end)

   describe("more complex tests", function()
      it("downgrades directories correctly", function()
         assert(run.luarocks_bool("build --nodeps non_lua_file 1.0-2"))
         assert(run.luarocks_bool("build --nodeps non_lua_file 1.0-1"))
         assert(run.luarocks_bool("build --nodeps non_lua_file 1.0-2"))
      end)

      it("only deps", function()
         assert.is_true(run.luarocks_bool("build build_only_deps --only-deps"))
         assert.is_false(run.luarocks_bool("show build_only_deps"))
         assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/build_only_deps/0.1-1/build_only_deps-0.1-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
      end)

      it("only deps of a given rockspec", function()
         helper.run_in_tmp(function(tmpdir)
            helper.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               dependencies = {
                  "a_rock 1.0"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            helper.write_file("test.lua", "return {}", finally)

            assert.is.truthy(run.luarocks_bool("build test-1.0-1.rockspec --only-deps"))
            assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/test/1.0-1/test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
         end, finally)
      end)

      it("only deps of a given rock", function()
         helper.run_in_tmp(function(tmpdir)
            helper.write_file("test-1.0-1.rockspec", [[
               package = "test"
               version = "1.0-1"
               source = {
                  url = "file://]] .. tmpdir:gsub("\\", "/") .. [[/test.lua"
               }
               dependencies = {
                  "a_rock 1.0"
               }
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            ]], finally)
            helper.write_file("test.lua", "return {}", finally)

            assert.is.truthy(run.luarocks_bool("pack test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes("test-1.0-1.src.rock"))

            assert.is.truthy(run.luarocks_bool("build test-1.0-1.src.rock --only-deps"))
            assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/test/1.0-1/test-1.0-1.rockspec"))
            assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
         end, finally)
      end)

      it("fails if given an argument with an invalid patch", function()
         assert.is_false(run.luarocks_bool("build spec/fixtures/invalid_patch-0.1-1.rockspec"))
      end)
   end)
end)

describe("rockspec format 3.0 #rs3", function()
   before_each(function()
      lfs.mkdir("autodetect")
      helper.write_file("autodetect/bla.lua", "return {}", finally)
      helper.write_file("c_module.c", c_module_source, finally)
   end)

   it("defaults to build.type == 'builtin'", function()
      local rockspec = "a_rock-1.0-1.rockspec"
      helper.write_file("a_rock.lua", [[return {}]])
      helper.write_file(rockspec, [[
         rockspec_format = "3.0"
         package = "a_rock"
         version = "1.0-1"
         source = {
            url = "file://./a_rock.lua"
         }
         description = {
            summary = "An example rockspec",
         }
         dependencies = {
            "lua >= 5.1"
         }
         build = {
            modules = {
               build = "a_rock.lua"
            },
         }
      ]], finally)
      assert.truthy(run.luarocks_bool("build " .. rockspec))
      assert.is.truthy(run.luarocks("show a_rock"))
   end)

   it("'builtin' detects lua files if build is not given", function()
      local rockspec = "autodetect-1.0-1.rockspec"
      helper.write_file(rockspec, [[
         rockspec_format = "3.0"
         package = "autodetect"
         version = "1.0-1"
         source = {
            url = "file://autodetect/bla.lua"
         }
         description = {
            summary = "An example rockspec",
         }
         dependencies = {
            "lua >= 5.1"
         }
      ]], finally)
      assert.truthy(run.luarocks_bool("build " .. rockspec))
      assert.match("bla.lua", run.luarocks("show autodetect"))
   end)

   it("'builtin' synthesizes external_dependencies if not given but a library is given in build", function()
      local rockspec = "autodetect-1.0-1.rockspec"
      helper.write_file(rockspec, [[
         rockspec_format = "3.0"
         package = "autodetect"
         version = "1.0-1"
         source = {
            url = "file://c_module.c"
         }
         description = {
            summary = "An example rockspec",
         }
         dependencies = {
            "lua >= 5.1"
         }
         build = {
            modules = {
               c_module = {
                  sources = "c_module.c",
                  libraries = "inexistent_library",
               }
            }
         }
      ]], finally)
      assert.match("INEXISTENT_LIBRARY_DIR", run.luarocks("build " .. rockspec))
   end)
end)

describe("external dependencies", function()
   before_each(helper.before_each_integration)
   teardown(helper.teardown_integration)

   it("fails when missing external dependency", function()
      helper.run_in_tmp(function(tmpdir)
         helper.write_file("build.lua", [[return {}]])
         helper.write_file("missing_external-0.1-1.rockspec", [[
            package = "missing_external"
            version = "0.1-1"
            source = {
               url = "file://./build.lua"
            }
            external_dependencies = {
               INEXISTENT = {
                  library = "inexistentlib*",
                  header = "inexistentheader*.h",
               }
            }
            dependencies = {
               "lua >= 5.1"
            }
            build = {
               type = "builtin",
               modules = {
                  build = "build.lua"
               }
            }
         ]], finally)
         assert.is_false(run.luarocks_bool("build missing_external-0.1-1.rockspec INEXISTENT_INCDIR=\"/invalid/dir\""))
      end, finally)
   end)

   it("builds with external dependency", function()
      helper.run_in_tmp(function(tmpdir)
         helper.write_file("with_external_dep-0.1-1.rockspec", [[
            package = "with_external_dep"
            version = "0.1-1"
            source = {
               url = "file://]] .. helper.fixtures_dir() .. [[/with_external_dep.c"
            }
            description = {
               summary = "An example rockspec",
            }
            external_dependencies = {
               FOO = {
                  header = "foo/foo.h"
               }
            }
            dependencies = {
               "lua >= 5.1"
            }
            build = {
               type = "builtin",
               modules = {
                  with_external_dep = {
                     sources = "with_external_dep.c",
                     incdirs = "$(FOO_INCDIR)",
                  }
               }
            }
         ]])
         local foo_incdir = helper.fixtures_dir() .. "/with_external_dep"
         assert.is_truthy(run.luarocks_bool("build with_external_dep-0.1-1.rockspec FOO_INCDIR=\"" .. foo_incdir .. "\""))
         assert.is.truthy(run.luarocks("show with_external_dep"))
      end, finally)
   end)

   it("builds with a build dependency", function()
      assert(run.luarocks_bool("build has_build_dep" ))
      assert(run.luarocks_bool("show has_build_dep 1.0"))
      assert(run.luarocks_bool("show a_build_dep 1.0"))
   end)

   it("builtin auto installs files in lua subdir", function()
      helper.run_in_tmp(function(tmpdir)
         lfs.mkdir("lua")
         helper.write_file("lua_module-1.0-1.rockspec", [[
            package = "lua_module"
            version = "1.0-1"
            source = {
               url = "http://example.com/lua_module"
            }
            build = {
               type = "builtin",
               modules = {}
            }
         ]], finally)
         helper.write_file("lua/lua_module.lua", "return 123", finally)

         assert.is_true(run.luarocks_bool("build"))
         assert.match("[\\/]lua_module%.lua", run.luarocks("show lua_module"))
      end, finally)
   end)
end)
