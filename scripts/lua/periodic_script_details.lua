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

local periodic_script     = _GET["periodic_script"]

local ifstats = interface.getStats()
local ifId = ifstats.id

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(periodic_script == nil) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Periodic_Script parameter is missing (internal error ?)</div>")
   return
end

if(not ts_utils.exists("periodic_script:duration_ms", {ifid = ifId, periodic_script = periodic_script})) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No available stats for hash table "..periodic_script.."</div>")
   return
end

print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">Periodic Script: "..periodic_script.."</A> </li>")
print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i>\n")

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
]]

local schema = _GET["ts_schema"] or "custom:periodic_script:duration_ms"
local selected_epoch = _GET["epoch"] or ""
local url = ntop.getHttpPrefix()..'/lua/periodic_script_details.lua?ifid='..ifId..'&periodic_script='..periodic_script..'&page=historical'

local tags = {
   ifid = ifId,
   periodic_script = periodic_script,
}

drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
   timeseries = {
      {
         schema = "custom:periodic_script:duration_ms",
         label = i18n("internals.duration"),
         metrics_labels = { i18n("graphs.max_ms"), i18n("graphs.last_ms") },
         value_formatter = { "fmillis", "fmillis" },
      },
   }
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
