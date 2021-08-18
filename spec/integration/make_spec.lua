local helper = require("spec.util.helper")
local lfs = require("lfs")
local run = helper.run

describe("luarocks make #integration", function()
   before_each(helper.before_each_integration)
   teardown(helper.teardown_integration)

   it("with no flags/arguments", function()
      assert(lfs.mkdir("empty"))
      assert(lfs.chdir("empty"))
      assert.is_false(run.luarocks_bool("make"))
   end)

   it("with rockspec", function()
      -- make has_script
      assert.is_true(run.luarocks_bool("download --source has_script 1.0-1"))
      assert.is_true(run.luarocks_bool("unpack has_script-1.0-1.src.rock"))
      lfs.chdir("has_script-1.0-1/has_script-1.0")
      assert.is_true(run.luarocks_bool("make has_script-1.0-1.rockspec"))

      -- test it
      assert.is_true(run.luarocks_bool("show has_script"))
      assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/has_script/1.0-1/has_script-1.0-1.rockspec"))
   end)

   it("--no-doc", function()
      assert.is_true(run.luarocks_bool("download --source has_doc 1.0-1"))
      assert.is_true(run.luarocks_bool("unpack has_doc-1.0-1.src.rock"))
      lfs.chdir("has_doc-1.0-1/has_doc-1.0/")
      assert.is_true(run.luarocks_bool("make --no-doc has_doc-1.0-1.rockspec"))

      assert.is_true(run.luarocks_bool("show has_doc"))
      assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/has_doc/1.0-1/doc"))
   end)

   it("--only-deps", function()
      local rockspec = "build_only_deps-0.1-1.rockspec"
      local src_rock = helper.fixtures_dir() .. "/build_only_deps-0.1-1.src.rock"

      helper.remove_dir("build_only_deps-0.1-1/")
      assert.is_true(run.luarocks_bool("unpack " .. src_rock))
      lfs.chdir("build_only_deps-0.1-1/")
      assert.is_true(run.luarocks_bool("make " .. rockspec .. " --only-deps"))
      assert.is_false(run.luarocks_bool("show build_only_deps"))
      assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/build_only_deps/0.1-1/build_only_deps-0.1-1.rockspec"))
      assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
   end)

   describe("LuaRocks making rockspecs (using has_script)", function()
      --download has_script and unpack it
      before_each(function()
         assert.is_true(run.luarocks_bool("download --source has_script 1.0-1"))
         assert.is_true(run.luarocks_bool("unpack has_script-1.0-1.src.rock"))
         assert.is_true(lfs.chdir("has_script-1.0-1/has_script-1.0/"))
      end)

      it("default rockspec", function()
         assert.is_true(run.luarocks_bool("new_version has_script-1.0-1.rockspec"))
         assert.is_true(run.luarocks_bool("make"))

         assert.is_true(run.luarocks_bool("show has_script"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/has_script/1.0-2/has_script-1.0-2.rockspec"))
      end)

      it("unnamed rockspec", function()
         finally(function()
            os.rename("rockspec", "has_script-1.0-1.rockspec")
         end)

         os.rename("has_script-1.0-1.rockspec", "rockspec")
         assert.is_true(run.luarocks_bool("make"))

         assert.is_true(run.luarocks_bool("show has_script"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/has_script/1.0-1/has_script-1.0-1.rockspec"))
      end)

      it("ambiguous rockspec", function()
         assert.is.truthy(os.rename("has_script-1.0-1.rockspec", "has_script2-1.0-1.rockspec"))
         local output = run.luarocks("make")
         assert.is.truthy(output:match("Error: Inconsistency between rockspec filename"))

         assert.is_false(run.luarocks_bool("show has_script"))
         assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/has_script/1.0-1/has_script-1.0-1.rockspec"))
      end)

      it("ambiguous unnamed rockspec", function()
         assert.is.truthy(os.rename("has_script-1.0-1.rockspec", "1_rockspec"))
         helper.copy("1_rockspec", "2_rockspec")
         local output = run.luarocks("make")
         assert.is.truthy(output:match("Error: Please specify which rockspec file to use"))

         assert.is_false(run.luarocks_bool("show has_script"))
         assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/has_script/1.0-1/has_script-1.0-1.rockspec"))
      end)

      it("pack binary rock", function()
         assert.is_true(run.luarocks_bool("make --deps-mode=none --pack-binary-rock"))
         assert.is.truthy(lfs.attributes("has_script-1.0-1.all.rock"))
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

         assert.is_true(run.luarocks_bool("make --server=" .. helper.fixtures_dir() .. "/a_repo --pin --tree=lua_modules"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/1.0-1/test-1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
         local lockfilename = "./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/1.0-1/luarocks.lock"
         assert.is.truthy(lfs.attributes(lockfilename))
         local lockdata = loadfile(lockfilename)()
         assert.same({
            dependencies = {
               ["a_rock"] = "1.0-1",
               ["lua"] = helper.lua_version() .. "-1",
            }
         }, lockdata)
      end)
   end)

   it("respects luarocks.lock when present #pinning", function()
      helper.run_in_tmp(function(tmpdir)
         helper.write_file("test-2.0-1.rockspec", [[
            package = "test"
            version = "2.0-1"
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
         helper.write_file("luarocks.lock", [[
            return {
               dependencies = {
                  ["a_rock"] = "1.0-1",
               }
            }
         ]], finally)

         print(run.luarocks("make --server=" .. helper.fixtures_dir() .. "/a_repo --tree=lua_modules"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/2.0-1/test-2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
         local lockfilename = "./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/2.0-1/luarocks.lock"
         assert.is.truthy(lfs.attributes(lockfilename))
         local lockdata = loadfile(lockfilename)()
         assert.same({
            dependencies = {
               ["a_rock"] = "1.0-1",
            }
         }, lockdata)
      end)
   end)

   it("overrides luarocks.lock with --pin #pinning", function()
      helper.run_in_tmp(function(tmpdir)
         helper.write_file("test-2.0-1.rockspec", [[
            package = "test"
            version = "2.0-1"
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
         helper.write_file("luarocks.lock", [[
            return {
               dependencies = {
                  ["a_rock"] = "1.0-1",
               }
            }
         ]], finally)

         print(run.luarocks("make --server=" .. helper.fixtures_dir() .. "/a_repo --tree=lua_modules --pin"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/2.0-1/test-2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/a_rock/2.0-1/a_rock-2.0-1.rockspec"))
         local lockfilename = "./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/2.0-1/luarocks.lock"
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

   describe("#ddt upgrading rockspecs with double deploy types", function()
      local so = helper.lib_extension()

      before_each(function()
         helper.copy_dir(helper.fixtures_dir() .. "/double_deploy_type", "ddt")
      end)

      after_each(function()
         helper.remove_dir("ddt")
         os.remove("ddt."..helper.lib_extension())
      end)

      it("when upgrading", function()
         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt.lua"))
         assert.same("ddt1", loadfile(helper.share_lua_dir().."/ddt.lua")())
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt_file"))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt_file~"))

         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt.lua"))
         assert.same("ddt2", loadfile(helper.share_lua_dir().."/ddt.lua")())
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt_file"))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt_file~"))
      end)

      it("modules with same name from lua/ and lib/ when upgrading with --keep", function()
         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt.lua"))
         assert.same("ddt1", loadfile(helper.share_lua_dir().."/ddt.lua")())
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt_file"))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt_file~"))

         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.2.0-1.rockspec --keep"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt.lua"))
         assert.same("ddt2", loadfile(helper.share_lua_dir().."/ddt.lua")())
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt_file"))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt_file~"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/double_deploy_type_0_1_0_1-ddt."..so))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/double_deploy_type_0_1_0_1-ddt.lua"))
         assert.same("ddt1", loadfile(helper.share_lua_dir().."/double_deploy_type_0_1_0_1-ddt.lua")())
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/double_deploy_type_0_1_0_1-ddt_file"))
      end)

      it("modules with same name from lua/ and lib/ when downgrading", function()
         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt.lua"))
         assert.same("ddt2", loadfile(helper.share_lua_dir().."/ddt.lua")())
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt_file"))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt_file~"))

         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt.lua"))
         assert.same("ddt1", loadfile(helper.share_lua_dir().."/ddt.lua")())
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt_file"))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt_file~"))
      end)

      it("modules with same name from lua/ and lib/ when downgrading with --keep", function()
         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt.lua"))
         assert.same("ddt2", loadfile(helper.share_lua_dir().."/ddt.lua")())
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt_file"))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt_file~"))

         assert.is_true(run.luarocks_bool("make ddt/double_deploy_type-0.1.0-1.rockspec --keep"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt.lua"))
         assert.same("ddt2", loadfile(helper.share_lua_dir().."/ddt.lua")())
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/ddt_file"))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/ddt."..so.."~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt.lua~"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/ddt_file~"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/double_deploy_type_0_1_0_1-ddt."..so))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/double_deploy_type_0_1_0_1-ddt.lua"))
         assert.same("ddt1", loadfile(helper.share_lua_dir().."/double_deploy_type_0_1_0_1-ddt.lua")())
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/double_deploy_type_0_1_0_1-ddt_file"))
      end)
   end)

   describe("upgrading rockspecs with mixed deploy types", function()
      before_each(function()
         helper.copy_dir(helper.fixtures_dir() .. "/mixed_deploy_type", "mdt")
      end)

      after_each(function()
         helper.remove_dir("mdt")
         os.remove("mdt."..helper.lib_extension())
      end)

      it("modules with same name from lua/ and lib/ when upgrading", function()
         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/mdt.lua"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/mdt_file"))

         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/mdt."..helper.lib_extension()))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/mdt_file"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/mdt.lua"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/mdt_file"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/mixed_deploy_type_0_1_0_1-mdt.lua"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/mixed_deploy_type_0_1_0_1-mdt_file"))
      end)

      it("modules with same name from lua/ and lib/ when upgrading with --keep", function()
         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/mdt.lua"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/mdt_file"))

         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.2.0-1.rockspec --keep"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/mdt."..helper.lib_extension()))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/mdt_file"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/mdt.lua"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/mdt_file"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/mixed_deploy_type_0_1_0_1-mdt.lua"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/mixed_deploy_type_0_1_0_1-mdt_file"))
      end)

      it("modules with same name from lua/ and lib/ when downgrading", function()
         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/mdt."..helper.lib_extension()))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/mdt_file"))

         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.1.0-1.rockspec"))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/mdt."..helper.lib_extension()))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/mdt_file"))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/mixed_deploy_type_0_1_0_1-mdt."..helper.lib_extension()))
         assert.is.falsy(lfs.attributes(helper.lib_lua_dir().."/mixed_deploy_type_0_1_0_1-mdt_file"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/mdt.lua"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/mdt_file"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/mixed_deploy_type_0_1_0_1-mdt.lua"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/mixed_deploy_type_0_1_0_1-mdt_file"))
      end)

      it("modules with same name from lua/ and lib/ when downgrading with --keep", function()
         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.2.0-1.rockspec"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/mdt."..helper.lib_extension()))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/mdt_file"))

         assert.is_true(run.luarocks_bool("make mdt/mixed_deploy_type-0.1.0-1.rockspec --keep"))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/mdt."..helper.lib_extension()))
         assert.is.truthy(lfs.attributes(helper.lib_lua_dir().."/mdt_file"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/mdt.lua"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir().."/mdt_file"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/mixed_deploy_type_0_1_0_1-mdt.lua"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir().."/mixed_deploy_type_0_1_0_1-mdt_file"))
      end)
   end)
end)
