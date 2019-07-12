--
-- (C) 2013-19 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo() 
local page_utils = require("page_utils")
local alerts_api = require("alerts_api")
local format_utils = require("format_utils")

sendHTTPContentTypeHeader('text/html')
page_utils.print_header(i18n("about.about_x", { product=info.product }))

active_page = "about"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- checks all the hosts of the current interface (TODO: iterate all interfaces)
ntop.checkHostsAlertsMin()

-- checks the current networks alerts
ntop.checkNetworksAlertsMin()

-- checks the current interface alerts
interface.checkAlertsMin()

--alerts_api.new_trigger(alerts_api.hostAlertEntity("192.168.1.1", 0), alerts_api.thresholdCrossType("min", "bytes", 500, ">", 0))

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

