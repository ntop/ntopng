--
-- (C) 2013-19 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo() 
local page_utils = require("page_utils")
local format_utils = require("format_utils")

sendHTTPContentTypeHeader('text/html')
page_utils.print_header(i18n("about.about_x", { product=info.product }))

active_page = "about"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- checks all the hosts of the current interface (TODO: iterate all interfaces)
ntop.checkHostsAlertsMin()

-- checks the current interface alerts
interface.checkAlertsMin()

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

