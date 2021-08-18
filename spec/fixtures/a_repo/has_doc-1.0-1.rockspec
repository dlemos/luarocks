rockspec_format = "3.0"
package = "has_doc"
version = "1.0-1"
source = {
   url = "file://../upstream/has_doc-1.0.tar.gz"
}
description = {
   summary = "An example rockspec that has a script.",
}
dependencies = {
   "lua >= 5.1",
}
build = {
   type = "builtin",
   modules = {
      has_doc = "has_doc.lua"
   },
   copy_directories = {
      "doc"
   },
}
