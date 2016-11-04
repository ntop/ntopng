package = "i18n"
version = "0.9-2"
source = {
  url = "https://github.com/kikito/i18n.lua/archive/v0.9.0.tar.gz",
  dir = "i18n.lua-0.9.0"
}
description = {
  summary = "A very complete internationalization library for Lua",
  detailed = [[
    i18n can handle hierarchies of tags, accepts entries in several ways (one by one, in a table or in a file) and implements a lot of pluralization rules, fallbacks, and more.
  ]],
  homepage = "https://github.com/kikito/i18n.lua",
  license = "MIT <http://opensource.org/licenses/MIT>"
}
dependencies = {
  "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["i18n.init"]         = "i18n/init.lua",
    ["i18n.plural"]       = "i18n/plural.lua",
    ["i18n.variants"]     = "i18n/variants.lua",
    ["i18n.interpolate"]  = "i18n/interpolate.lua",
    ["i18n.version"]      = "i18n/version.lua"
  }
}
