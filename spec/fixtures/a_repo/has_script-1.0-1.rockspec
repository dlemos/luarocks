rockspec_format = "3.0"
package = "has_script"
version = "1.0-1"
source = {
   url = "file://../upstream/has_script-1.0.tar.gz"
}
description = {
   summary = "An example rockspec that has a script.",
}
dependencies = {
   "a_rock",
   "lua >= 5.1",
}
build_dependencies = {
   "a_build_dep",
}
build = {
   type = "builtin",
   modules = {
      a_module = "a_module.lua"
   },
   install = {
      bin = {
         a_script = "a_script",
      }
   },
}
