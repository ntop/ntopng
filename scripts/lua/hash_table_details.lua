--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   require "snmp_utils"
end

require "lua_utils"
require "graph_utils"
require "alert_utils"
local page_utils = require("page_utils")
local os_utils = require "os_utils"
local ts_utils = require "ts_utils"

local hash_table     = _GET["hash_table"]

local ifstats = interface.getStats()
local ifId = ifstats.id

active_page = "if_stats"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(hash_table == nil) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Hash_Table parameter is missing (internal error ?)</div>")
   return
end

if(not ts_utils.exists("ht:state", {ifid = ifId, hash_table = hash_table})) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No available stats for hash table "..hash_table.."</div>")
   return
end

print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">".. i18n("internals.iface_hash_tables", {iface = getHumanReadableInterfaceName(getInterfaceName(ifId))}) .."</A> </li>")
print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i>\n")

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
]]

local schema = _GET["ts_schema"] or "ht:state"
local selected_epoch = _GET["epoch"] or ""
local url = ntop.getHttpPrefix()..'/lua/hash_table_details.lua?ifid='..ifId..'&page=historical'

local tags = {
   ifid = ifId,
   hash_table = hash_table,
}

drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
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
