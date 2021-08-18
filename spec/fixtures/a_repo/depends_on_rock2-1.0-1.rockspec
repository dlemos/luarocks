rockspec_format = "3.0"
package = "depends_on_rock2"
version = "1.0-1"
source = {
   url = "file://../upstream/has_folder-1.0.tar.gz"
}
description = {
   summary = "An example rockspec",
}
dependencies = {
   "a_rock >= 2.0",
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      bla = "src/in_base.lua"
   },
}
