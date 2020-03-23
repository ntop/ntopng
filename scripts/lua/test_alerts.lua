--
-- (C) 2013-20 - ntop.org
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
page_utils.manage_system_interface()
page_utils.print_header(i18n("about.about_x", { product=info.product }))

if not isAdministrator() then
  return
end

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- checks all the hosts of the current interface (TODO: iterate all interfaces)
interface.checkHostsAlertsMin()

-- checks the current networks alerts
interface.checkNetworksAlertsMin()

-- checks the current interface alerts
interface.checkInterfaceAlertsMin()

-- run the system scripts
ntop.checkSystemScriptsMin()

--require "snmp_utils"
--run_5min_snmp_caching(600)
--dofile(dirs.installdir .. "/pro/scripts/callbacks/system/5min.lua")
ntop.checkSNMPDeviceAlerts5Min()

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

