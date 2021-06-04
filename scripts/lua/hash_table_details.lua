--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   local snmp_utils = require "snmp_utils"
end

require "lua_utils"
local graph_utils = require "graph_utils"
local alert_utils = require "alert_utils"
local page_utils = require("page_utils")
local os_utils = require "os_utils"
local ts_utils = require "ts_utils"

local hash_table     = _GET["hash_table"]

local ifstats = interface.getStats()
local ifId = ifstats.id

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.interface, {ifname=getHumanReadableInterfaceName(ifId)})

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(hash_table == nil) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> Hash_Table parameter is missing (internal error ?)</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

if(not ts_utils.exists("ht:state", {ifid = ifId, hash_table = hash_table})) then
   print("<div class=\"alert alert alert-danger\"><i class='fas fa-exclamation-triangle fa-lg fa-ntopng-warning'></i> No available stats for hash table "..hash_table.."</div>")
   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
   return
end

local nav_url = ntop.getHttpPrefix().."/lua/hash_table_details.lua?ifid="..ifId
local title = i18n("internals.hash_table").. ": "..hash_table

page_utils.print_navbar(title, nav_url,
			{
			   {
			      active = page == "historical" or not page,
			      page_name = "historical",
			      label = "<i class='fas fa-lg fa-chart-area'></i>",
			   },
			}
)

local schema = _GET["ts_schema"] or "ht:state"
local selected_epoch = _GET["epoch"] or ""
local url = ntop.getHttpPrefix()..'/lua/hash_table_details.lua?ifid='..ifId..'&page=historical'

local tags = {
   ifid = ifId,
   hash_table = hash_table,
}

graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
   timeseries = {
      {schema = "ht:state", label = i18n("hash_table.CountriesHash"), extra_params = {hash_table = "CountriesHash"}},
      {schema = "ht:state", label = i18n("hash_table.HostHash"), extra_params = {hash_table = "HostHash"}},
      {schema = "ht:state", label = i18n("hash_table.MacHash"), extra_params = {hash_table = "MacHash"}},
      {schema = "ht:state", label = i18n("hash_table.FlowHash"), extra_params = {hash_table = "FlowHash"}},
      {schema = "ht:state", label = i18n("hash_table.AutonomousSystemHash"), extra_params = {hash_table = "AutonomousSystemHash"}},
      {schema = "ht:state", label = i18n("hash_table.VlanHash"), extra_params = {hash_table = "VlanHash"}},
   }
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
