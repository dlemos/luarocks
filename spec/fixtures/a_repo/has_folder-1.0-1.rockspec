rockspec_format = "3.0"
package = "has_folder"
version = "1.0-1"
source = {
   url = "file://../upstream/has_folder-1.0.tar.gz"
}
description = {
   summary = "An example rockspec that has folders and subfolders.",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      ["in_base"] = "src/in_base.lua",
      ["folder"] = "src/folder/init.lua",
      ["folder.in_folder"] = "src/folder/in_folder.lua",
      ["folder.subfolder"] = "src/folder/subfolder/init.lua",
      ["folder.subfolder.in_subfolder"] = "src/folder/subfolder/in_subfolder.lua",
   },
}
