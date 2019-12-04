--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local page_utils = require "page_utils"
require "lua_utils"

local info = ntop.getInfo()

sendHTTPContentTypeHeader('text/html')
page_utils.print_header(i18n("about.about_x", { product=info.product }))

active_page = "about"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local plugins_utils = require("plugins_utils")
plugins_utils.loadPlugins()

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
