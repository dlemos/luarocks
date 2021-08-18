rockspec_format = "3.0"
package = "for_lua_version"
version = "1.5.4-1"
source = {
   url = "file://../upstream/has_folder-1.0.tar.gz"
}
description = {
   summary = "An example rockspec that has folders and subfolders.",
}
dependencies = {
   "lua ~> 5.4",
}
build = {
   type = "builtin",
   modules = {
      ["in_base"] = "src/in_base.lua",
   },
}
