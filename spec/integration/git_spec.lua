local helper = require("spec.util.helper")
local run = helper.run

local git_repo = require("spec.util.git_repo")

describe("#unix build from #git", function()
   local git

   before_each(helper.before_each_integration)

   lazy_setup(function()
      git = git_repo.start()
   end)

   teardown(function()
      helper.teardown_integration()
      if git then
         git:stop()
      end
   end)

   it("build --branch", function()
      helper.run_in_tmp(function(tmpdir)
         helper.write_file("my_branch-1.0-1.rockspec", [[
            rockspec_format = "3.0"
            package = "my_branch"
            version = "1.0-1"
            source = {
               url = "git://localhost/testrock"
            }
         ]], finally)
         assert.is_true(run.luarocks_bool("init"))
         assert.is_false(run.luarocks_bool("build --branch unknown-branch ./my_branch-1.0-1.rockspec"))
         assert.is_true(run.luarocks_bool("build --branch test-branch ./my_branch-1.0-1.rockspec"))
      end)
   end)

   it("install --branch", function()
      helper.run_in_tmp(function(tmpdir)
         helper.write_file("my_branch-1.0-1.rockspec", [[
            rockspec_format = "3.0"
            package = "my_branch"
            version = "1.0-1"
            source = {
               url = "git://localhost/testrock"
            }
         ]], finally)
         assert.is_true(run.luarocks_bool("init"))
         assert.is_false(run.luarocks_bool("install --branch unknown-branch ./my_branch-1.0-1.rockspec"))
         assert.is_true(run.luarocks_bool("install --branch test-branch ./my_branch-1.0-1.rockspec"))
      end)
   end)
end)
