local helper = require("spec.util.helper")

local rockspecs = require("luarocks.rockspecs")

local build_builtin = require("luarocks.build.builtin")

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

describe("LuaRocks build #unit", function()
   setup(helper.setup_unit)
   teardown(helper.teardown_unit)
   before_each(helper.before_each_unit)

   describe("build.builtin", function()
      describe("builtin.autodetect_external_dependencies", function()
         it("returns false if the given build table has no external dependencies", function()
            local build_table = {
               type = "builtin"
            }

            assert.falsy(build_builtin.autodetect_external_dependencies(build_table))
         end)

         it("returns a table of the external dependencies found in the given build table", function()
            local build_table = {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = { "foo1", "foo2" },
                  },
                  module2 = {
                     libraries = "foo3"
                  },
               }
            }

            local extdeps = build_builtin.autodetect_external_dependencies(build_table)
            assert.same(extdeps["FOO1"], { library = "foo1" })
            assert.same(extdeps["FOO2"], { library = "foo2" })
            assert.same(extdeps["FOO3"], { library = "foo3" })
         end)

         it("adds proper include and library dirs to the given build table", function()
            local build_table

            build_table = {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo"
                  }
               }
            }
            build_builtin.autodetect_external_dependencies(build_table)
            assert.same(build_table, {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "$(FOO_INCDIR)" },
                     libdirs = { "$(FOO_LIBDIR)" }
                  }
               }
            })

            build_table = {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "INCDIRS" }
                  }
               }
            }
            build_builtin.autodetect_external_dependencies(build_table)
            assert.same(build_table, {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "INCDIRS" },
                     libdirs = { "$(FOO_LIBDIR)" }
                  }
               }
            })

            build_table = {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     libdirs = { "LIBDIRS" }
                  }
               }
            }
            build_builtin.autodetect_external_dependencies(build_table)
            assert.same(build_table, {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "$(FOO_INCDIR)" },
                     libdirs = { "LIBDIRS" }
                  }
               }
            })

            build_table = {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "INCDIRS" },
                     libdirs = { "LIBDIRS" }
                  }
               }
            }
            build_builtin.autodetect_external_dependencies(build_table)
            assert.same(build_table, {
               type = "builtin",
               modules = {
                  module1 = {
                     libraries = "foo",
                     incdirs = { "INCDIRS" },
                     libdirs = { "LIBDIRS" }
                  }
               }
            })
         end)
      end)

      describe("builtin.autodetect_modules", function()

         local libs = { "foo1", "foo2" }
         local incdirs = { "$(FOO1_INCDIR)", "$(FOO2_INCDIR)" }
         local libdirs = { "$(FOO1_LIBDIR)", "$(FOO2_LIBDIR)" }

         it("returns a table of the modules having as location the current directory", function()
            helper.write_file("module1.lua", "", finally)
            helper.write_file("module2.c", "", finally)
            helper.write_file("module3.c", "int luaopen_my_module()", finally)
            helper.write_file("test.lua", "", finally)
            helper.write_file("tests.lua", "", finally)

            local modules = build_builtin.autodetect_modules(libs, incdirs, libdirs)
            assert.same(modules, {
               module1 = "module1.lua",
               module2 = {
                  sources = "module2.c",
                  libraries = libs,
                  incdirs = incdirs,
                  libdirs = libdirs
               },
               my_module = {
                  sources = "module3.c",
                  libraries = libs,
                  incdirs = incdirs,
                  libdirs = libdirs
               }
            })
         end)

         local test_with_location = function(location)
            lfs.mkdir(location)
            lfs.mkdir(location .. "/dir1")
            lfs.mkdir(location .. "/dir1/dir2")

            helper.write_file(location .. "/module1.lua", "", finally)
            helper.write_file(location .. "/dir1/module2.c", "", finally)
            helper.write_file(location .. "/dir1/dir2/module3.c", "int luaopen_my_module()", finally)
            helper.write_file(location .. "/test.lua", "", finally)
            helper.write_file(location .. "/tests.lua", "", finally)

            local modules = build_builtin.autodetect_modules(libs, incdirs, libdirs)
            assert.same(modules, {
               module1 = location .. "/module1.lua",
               ["dir1.module2"] = {
                  sources = location .. "/dir1/module2.c",
                  libraries = libs,
                  incdirs = incdirs,
                  libdirs = libdirs
               },
               my_module = {
                  sources = location .. "/dir1/dir2/module3.c",
                  libraries = libs,
                  incdirs = incdirs,
                  libdirs = libdirs
               }
            })

            lfs.rmdir(location .. "/dir1/dir2")
            lfs.rmdir(location .. "/dir1")
            lfs.rmdir(location)
         end

         it("returns a table of the modules having as location the src directory", function()
            test_with_location("src")
         end)

         it("returns a table of the modules having as location the lua directory", function()
            test_with_location("lua")
         end)

         it("returns as second and third argument tables of the bin files and copy directories", function()
            lfs.mkdir("doc")
            lfs.mkdir("docs")
            lfs.mkdir("samples")
            lfs.mkdir("tests")
            lfs.mkdir("bin")
            helper.write_file("bin/binfile", "", finally)

            local _, install, copy_directories = build_builtin.autodetect_modules({}, {}, {})
            assert.same(install, { bin = { "bin/binfile" } })
            assert.same(copy_directories, { "doc", "docs", "samples", "tests" })

            lfs.rmdir("doc")
            lfs.rmdir("docs")
            lfs.rmdir("samples")
            lfs.rmdir("tests")
            lfs.rmdir("bin")
         end)
      end)

      describe("builtin.run", function()
         it("returns false if the rockspec has no build modules and its format does not support autoextraction", function()
            local rockspec = {
               package = "test",
               version = "1.0-1",
               source = {
                  url = "http://example.com/test"
               },
               build = {}
            }

            rockspecs.from_persisted_table("test-1.0-1.rockspec", rockspec)
            assert.falsy(build_builtin.run(rockspec))
            rockspec.rockspec_format = "1.0"
            assert.falsy(build_builtin.run(rockspec))
         end)

         it("returns false if lua.h could not be found", function()
            local rockspec = {
               package = "c_module",
               version = "1.0-1",
               source = {
                  url = "http://example.com/c_module"
               },
               build = {
                  type = "builtin",
                  modules = {
                     c_module = "c_module.c"
                  }
               }
            }
            helper.write_file("c_module.c", c_module_source, finally)

            rockspecs.from_persisted_table("c_module-1.0-1.rockspec", rockspec)
            rockspec.variables = { LUA_INCDIR = "invalid" }
            assert.falsy(build_builtin.run(rockspec))
         end)

         it("returns false if the build fails", function()
            local rockspec = {
               package = "c_module",
               version = "1.0-1",
               source = {
                  url = "http://example.com/c_module"
               },
               build = {
                  type = "builtin",
                  modules = {
                     c_module = "c_module.c"
                  }
               }
            }
            helper.write_file("c_module.c", c_module_source .. "invalid", finally)

            rockspecs.from_persisted_table("c_module-1.0-1.rockspec", rockspec)
            assert.falsy(build_builtin.run(rockspec))
         end)

         it("returns true if the build succeeds with C module", function()
            local rockspec = {
               package = "c_module",
               version = "1.0-1",
               source = {
                  url = "http://example.com/c_module"
               },
               build = {
                  type = "builtin",
                  modules = {
                     c_module = "c_module.c"
                  }
               }
            }
            helper.write_file("c_module.c", c_module_source, finally)

            rockspecs.from_persisted_table("c_module-1.0-1.rockspec", rockspec)
            assert.truthy(build_builtin.run(rockspec))
            assert.truthy(lfs.attributes(helper.rocks_dir() .. "/c_module/1.0-1/lib/c_module." .. helper.lib_extension()))
         end)

         it("returns true if the build succeeds with Lua module", function()
            local rockspec = {
               rockspec_format = "1.0",
               package = "test",
               version = "1.0-1",
               source = {
                  url = "http://example.com/test"
               },
               build = {
                  type = "builtin",
                  modules = {
                     test = "test.lua"
                  }
               }
            }
            helper.write_file("test.lua", "return {}", finally)

            rockspecs.from_persisted_table("test-1.0-1.rockspec", rockspec)
            assert.truthy(build_builtin.run(rockspec))
            assert.truthy(lfs.attributes(helper.rocks_dir() .. "/test/1.0-1/lua/test.lua"))
         end)

         it("automatically extracts the modules and libraries if they are not given and builds against any external dependencies", function()
            local fdir = helper.fixtures_dir()
            if helper.os() == "windows" then
               if os.getenv("COMPILER") == "mingw" then
                  os.execute("gcc -shared -o " .. fdir .. "/libfixturedep.dll -Wl,--out-implib," .. fdir .."/libfixturedep.a " .. fdir .. "/fixturedep.c")
               else
                  os.execute("cl " .. fdir .. "\\fixturedep.c /link /export:fixturedep_fn /out:" .. fdir .. "\\fixturedep.dll /implib:" .. fdir .. "\\fixturedep.lib")
               end
            elseif helper.os() == "macos" then
               os.execute("cc -dynamiclib -o " .. fdir .. "/libfixturedep.dylib " .. fdir .. "/fixturedep.c")
            else
               os.execute("gcc -shared -o " .. fdir .. "/libfixturedep.so " .. fdir .. "/fixturedep.c")
            end

            local rockspec = {
               rockspec_format = "3.0",
               package = "c_module",
               version = "1.0-1",
               source = {
                  url = "http://example.com/c_module"
               },
               external_dependencies = {
                  FIXTUREDEP = {
                     library = "fixturedep"
                  }
               },
               build = {
                  type = "builtin"
               }
            }
            helper.write_file("c_module.c", c_module_source, finally)

            rockspecs.from_persisted_table("c_module-1.0-1.rockspec", rockspec)
            rockspec.variables["FIXTUREDEP_LIBDIR"] = helper.fixtures_dir()
            assert.truthy(build_builtin.run(rockspec))
         end)

         it("returns false if any external dependency is missing", function()
            local rockspec = {
               rockspec_format = "3.0",
               package = "c_module",
               version = "1.0-1",
               source = {
                  url = "https://example.com/c_module"
               },
               external_dependencies = {
                  EXTDEP = {
                    library = "missing"
                  }
               },
               build = {
                  type = "builtin"
               }
            }
            helper.write_file("c_module.c", c_module_source, finally)

            rockspecs.from_persisted_table("c_module-1.0-1.rockspec", rockspec)
            rockspec.variables["EXTDEP_INCDIR"] = lfs.currentdir()
            rockspec.variables["EXTDEP_LIBDIR"] = lfs.currentdir()
            assert.falsy(build_builtin.run(rockspec))
         end)
      end)
   end)
end)

