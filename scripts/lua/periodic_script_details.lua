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
local internals_utils = require("internals_utils")

active_page = "if_stats"
sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">".. i18n("internals.iface_periodic_scripts", {iface = getHumanReadableInterfaceName(getInterfaceName(ifId))}) .."</A> </li>")
print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i>\n")

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
]]

local schema = _GET["ts_schema"] or "custom:flow_script:stats"
local selected_epoch = _GET["epoch"] or ""
local url = ntop.getHttpPrefix()..'/lua/periodic_script_details.lua?ifid='..ifId..'&page=historical'

local tags = {
   ifid = ifId,
   periodic_script = periodic_script,
}

local periodic_scripts_ts = {}

for script, max_duration in pairsByKeys(internals_utils.periodic_scripts_durations) do
   periodic_scripts_ts[#periodic_scripts_ts + 1] = {
      schema = "periodic_script:duration",
      label = script,
      extra_params = {periodic_script = script},
      metrics_labels = {i18n("flow_callbacks.last_duration")},

      -- Horizontal line with max duration
      extra_series = {
         {
            label = i18n("internals.max_duration_ms"),
            axis = 1,
            type = "line",
            color = "red",
            value = max_duration * 1000,
            class = "line-dashed",
         },
      }
   }
end

drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
   timeseries = table.merge(periodic_scripts_ts, {
      {separator=1, label="ht_state_update.lua"},
      {schema = "flow_script:lua_duration", label = i18n("internals.flow_lua_duration"), metrics_labels = {i18n("duration")}},
      {
         schema = "custom:flow_script:stats",
         label = i18n("internals.flow_calls_stats"),
         metrics_labels = { i18n("internals.missed_idle"), i18n("internals.missed_proto_detected"),
            i18n("internals.missed_periodic_update"), i18n("internals.pending_proto_detected"),
            i18n("internals.pending_periodic_update"), i18n("internals.successful_calls") },
      },
   })
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
