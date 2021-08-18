local helper = require("spec.util.helper")
local lfs = require("lfs")
local run = helper.run

describe("luarocks install #integration", function()
   before_each(helper.before_each_integration)
   teardown(helper.teardown_integration)

   describe("basic tests", function()
      it("fails with no flags/arguments", function()
         assert.is_false(run.luarocks_bool("install"))
      end)

      it("fails with invalid argument", function()
         assert.is_false(run.luarocks_bool("install --invalid"))
      end)

      it("fails invalid patch", function()
         assert.is_false(run.luarocks_bool("install " .. helper.fixtures_dir() .. "/invalid_patch-0.1-1.rockspec"))
      end)

      it("fails invalid rock", function()
         assert.is_false(run.luarocks_bool("install \"invalid.rock\" "))
      end)

      it("fails with local flag as root #unix", function()
         assert.is_false(run.luarocks_bool("install --local luasocket ", { USER = "root" } ))
      end)

      it("fails not a zip file", function()
         helper.write_file("not_a_zipfile-1.0-1.src.rock", [[
            I am not a .zip file!
         ]], finally)
         assert.is_false(run.luarocks_bool("install not_a_zipfile-1.0-1.src.rock"))
      end)

      it("only-deps does not install main rock", function()
         assert.is_false(run.luarocks_bool("show has_build_dep"))
         assert.is_false(run.luarocks_bool("show a_rock"))

         assert.is_true(run.luarocks_bool("install has_build_dep --only-deps"))

         assert.is_false(run.luarocks_bool("show has_build_dep"))
         assert.is_true(run.luarocks_bool("show a_rock"))
      end)

      it("fails with incompatible architecture", function()
         assert.is_false(run.luarocks_bool("install \"foo-1.0-1.impossible-x86.rock\" "))
      end)

      it("installs a package with an executable", function()
         assert(run.luarocks_bool("install has_script"))
         assert.is.truthy(lfs.attributes(helper.tree_dir() .. "/bin/a_script"))
      end)

      it("installs a package with a dependency", function()
         assert.is_true(run.luarocks_bool("install has_build_dep"))
         assert.is_true(run.luarocks_bool("show a_rock"))
      end)

      it("installs a package without its documentation", function()
         assert.is_true(run.luarocks_bool("install has_doc 1.0 --no-doc"))
         assert.is_true(run.luarocks_bool("show has_doc"))
         assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/has_doc/1.0-1/doc"))

         assert.is_true(run.luarocks_bool("install has_doc 1.0"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/has_doc/1.0-1/doc"))
      end)
   end)

   describe("#namespaces", function()
      it("installs a namespaced package from the command-line", function()
         assert(run.luarocks_bool("install a_user/a_rock --server=" .. helper.fixtures_dir() .. "/a_repo" ))
         assert.is_false(run.luarocks_bool("show a_rock 1.0"))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1/rock_namespace"))
      end)

      it("installs a namespaced package given an URL and any string in --namespace", function()
         -- This is not a "valid" namespace (as per luarocks.org rules)
         -- but we're not doing any format checking in the luarocks codebase
         -- so this keeps our options open.
         assert(run.luarocks_bool("install --namespace=x.y@z file://" .. helper.fixtures_dir() .. "/a_rock-1.0-1.src.rock" ))
         assert.truthy(run.luarocks_bool("show a_rock 1.0"))
         local fd = assert(io.open(helper.rocks_dir() .. "/a_rock/1.0-1/rock_namespace", "r"))
         finally(function() fd:close() end)
         assert.same("x.y@z", fd:read("*l"))
      end)

      it("installs a package with a namespaced dependency", function()
         assert(run.luarocks_bool("install has_namespaced_dep --server=" .. helper.fixtures_dir() .. "/a_repo" ))
         assert(run.luarocks_bool("show has_namespaced_dep"))
         assert.is_false(run.luarocks_bool("show a_rock 1.0"))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1/rock_namespace"))
      end)

      it("installs a package reusing a namespaced dependency", function()
         assert(run.luarocks_bool("install a_user/a_rock --server=" .. helper.fixtures_dir() .. "/a_repo" ))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1/rock_namespace"))
         local output = run.luarocks("install has_namespaced_dep --server=" .. helper.fixtures_dir() .. "/a_repo" )
         assert.has.no.match("Missing dependencies", output)
      end)

      it("installs a package considering namespace of locally installed package", function()
         assert(run.luarocks_bool("install a_user/a_rock --server=" .. helper.fixtures_dir() .. "/a_repo" ))
         assert(run.luarocks_bool("show a_rock 2.0"))
         assert(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1/rock_namespace"))
         local output = run.luarocks("install has_another_namespaced_dep --server=" .. helper.fixtures_dir() .. "/a_repo" )
         assert.has.match("Missing dependencies", output)
         print(output)
         assert(run.luarocks_bool("show a_rock 3.0"))
      end)
   end)

   describe("more complex tests", function()
      it('skipping dependency checks', function()
         assert.is_true(run.luarocks_bool("install has_build_dep --nodeps"))
         assert.is_true(run.luarocks_bool("show has_build_dep"))
         assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/a_rock"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/has_build_dep"))
      end)

      it('handle relative path in --tree #632', function()
         local relative_path = "./temp_dir_"..math.random(100000)
         if helper.os() == "windows" then
            relative_path = relative_path:gsub("/", "\\")
         end
         helper.remove_dir(relative_path)
         finally(function()
            helper.remove_dir(relative_path)
         end)
         assert.is.falsy(lfs.attributes(relative_path))
         assert.is_true(run.luarocks_bool("install a_rock --tree="..relative_path))
         assert.is.truthy(lfs.attributes(relative_path))
      end)

      it('handle versioned modules when installing another version with --keep #268', function()
         assert.is_true(run.luarocks_bool("install a_rock"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir() .. "/build.lua"))

         assert.is_true(run.luarocks_bool("install a_rock 1.0-1 --keep"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir() .. "/build.lua"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir() .. "/a_rock_1_0_1-build.lua"))

         assert.is_true(run.luarocks_bool("install a_rock"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir() .. "/build.lua"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir() .. "/a_rock_1_0_1-build.lua"))
      end)

      it('handle non-Lua files in build.install.lua when upgrading sailorproject/sailor#138', function()
         assert.is_true(run.luarocks_bool("install non_lua_file 1.0-1 --deps-mode=none"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir() .. "/sailor/blank-app/.htaccess"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir() .. "/sailor/blank-app/.htaccess~"))
         assert.is_true(run.luarocks_bool("install non_lua_file 1.0-2 --deps-mode=none"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir() .. "/sailor/blank-app/.htaccess"))
         assert.is.falsy(lfs.attributes(helper.share_lua_dir() .. "/sailor/blank-app/.htaccess~"))
      end)

      it("only-deps of packed rock", function()
         assert.is_true(run.luarocks_bool("build --pack-binary-rock has_build_dep 1.0"))
         local output = run.luarocks("install --only-deps ./has_build_dep-1.0-1.all.rock")
         finally(function()
            os.remove("./has_build_dep-1.0-1.all.rock")
         end)
         assert.match("Successfully installed dependencies for has_build_dep 1.0", output, 1, true)
      end)

      it("reinstall", function()
         assert.is_true(run.luarocks_bool("build --pack-binary-rock has_build_dep 1.0"))
         finally(function()
            os.remove("./has_build_dep-1.0-1.all.rock")
         end)
         assert.is_true(run.luarocks_bool("install ./has_build_dep-1.0-1.all.rock"))
         assert.is_true(run.luarocks_bool("install --deps-mode=none ./has_build_dep-1.0-1.all.rock"))
      end)

      it("installation rolls back on failure", function()
         assert.is_true(run.luarocks_bool("build --pack-binary-rock has_folder 1.0"))
         finally(function()
            os.remove("has_folder-1.0-1.all.rock")
         end)

         helper.make_dir(helper.share_lua_dir())

         run.luarocks_bool("remove has_folder")

         -- create a file where a folder should be
         local fd, err = io.open(helper.share_lua_dir() .. "/folder", "w+")
         assert.is_falsy(err)
         fd:write("\n")
         fd:close()

         -- try to install and fail
         assert.is_false(run.luarocks_bool("install has_folder-1.0-1.all.rock"))

         -- file is still there
         assert.is.truthy(lfs.attributes(helper.share_lua_dir() .. "/folder"))
         -- no left overs from failed installation
         assert.is.falsy(lfs.attributes(helper.share_lua_dir() .. "/in_base.lua"))

         -- remove file
         assert.is_true(os.remove(helper.share_lua_dir() .. "/folder"))

         -- try again and succeed
         assert.is_true(run.luarocks_bool("install has_folder-1.0-1.all.rock"))

         -- files installed successfully
         assert.is.truthy(lfs.attributes(helper.share_lua_dir() .. "/folder/init.lua"))
         assert.is.truthy(lfs.attributes(helper.share_lua_dir() .. "/in_base.lua"))
      end)

      it("accepts --no-manifest flag", function()
         assert.is_true(run.luarocks_bool("install has_folder 1.0"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/manifest"))
         assert.is.truthy(os.remove(helper.rocks_dir() .. "/manifest"))

         assert.is_true(run.luarocks_bool("install --no-manifest has_folder 1.0"))
         assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/manifest"))
      end)
   end)

   describe("New install functionality based on pull request 552", function()
      it("break dependencies warning", function()
         assert.is_true(run.luarocks_bool("install a_rock 2.0"))
         assert.is_true(run.luarocks_bool("install depends_on_rock2"))
         assert.is_true(run.luarocks_bool("install a_rock 1.0"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1"))
      end)
      it("break dependencies with --force", function()
         assert.is_true(run.luarocks_bool("install a_rock 2.0"))
         assert.is_true(run.luarocks_bool("install depends_on_rock2"))
         local output = run.luarocks("install --force a_rock 1.0")
         assert.is.truthy(output:find("Checking stability of dependencies"))
         assert.is.falsy(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1"))
      end)
      it("break dependencies with --force-fast", function()
         assert.is_true(run.luarocks_bool("install a_rock 2.0"))
         assert.is_true(run.luarocks_bool("install depends_on_rock2"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/a_rock/2.0-1"))
         local output = run.luarocks("install --force-fast a_rock 1.0")
         assert.is.falsy(output:find("Checking stability of dependencies"))
         assert.is.truthy(lfs.attributes(helper.rocks_dir() .. "/a_rock/1.0-1"))
      end)
   end)

   describe("#build_dependencies", function()
      it("install does not install a build dependency", function()
         assert(run.luarocks_bool("install has_build_dep --server=" .. helper.fixtures_dir() .. "/a_repo" ))
         assert(run.luarocks_bool("show has_build_dep 1.0"))
         assert.falsy(run.luarocks_bool("show a_build_dep 1.0"))
      end)
   end)

   it("respects luarocks.lock in package #pinning", function()
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
         helper.write_file("luarocks.lock", [[
            return {
               dependencies = {
                  ["a_rock"] = "1.0-1",
               }
            }
         ]], finally)

         assert.is_true(run.luarocks_bool("make --pack-binary-rock --server=" .. helper.fixtures_dir() .. "/a_repo test-1.0-1.rockspec"))
         assert.is_true(os.remove("luarocks.lock"))

         assert.is.truthy(lfs.attributes("./test-1.0-1.all.rock"))

         assert.is.falsy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/1.0-1/test-1.0-1.rockspec"))
         assert.is.falsy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))

         print(run.luarocks("install ./test-1.0-1.all.rock --tree=lua_modules --server=" .. helper.fixtures_dir() .. "/a_repo"))

         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/1.0-1/test-1.0-1.rockspec"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/test/1.0-1/luarocks.lock"))
         assert.is.truthy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/a_rock/1.0-1/a_rock-1.0-1.rockspec"))
         assert.is.falsy(lfs.attributes("./lua_modules/lib/luarocks/rocks-" .. helper.lua_version() .. "/a_rock/2.0-1"))
      end)
   end)
end)
