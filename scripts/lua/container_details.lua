--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

local page_utils = require("page_utils")
local format_utils = require("format_utils")

local container      = _GET["container"]
local page           = _GET["page"]

interface.select(ifname)
local ifId = getInterfaceId(ifname)
local ts_utils = require("ts_utils")
active_page = "hosts"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(container == nil) then
    return
end

local container_label = format_utils.formatContainerFromId(container)

if(not ts_utils.exists("container:num_flows", {ifid=ifId, container=container})) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("no_data_available") .. "</div>")
    return
end

--[[
Create Menu Bar with buttons
--]]
local nav_url = ntop.getHttpPrefix().."/lua/container_details.lua?container="..container
print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">" .. i18n("containers_stats.container") .. ": "..container_label.."</A> </li>")

if(page == "historical") then
    print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i></a></li>\n")
else
    print("\n<li><a href=\""..nav_url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
]]

--[[
Selectively render information pages
--]]
if page == "historical" then
  local schema = _GET["ts_schema"] or "container:num_flows"
  local selected_epoch = _GET["epoch"] or ""
  local url = ntop.getHttpPrefix()..'/lua/container_details.lua?container='..container..'&page=historical'

  local tags = {
    ifid = ifId,
    container = container,
  }

  drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
    timeseries = {
      {schema="container:num_flows",             label=i18n("graphs.active_flows")},
      {schema="container:rtt",                   label=i18n("containers_stats.avg_rtt")},
      {schema="container:rtt_variance",          label=i18n("containers_stats.avg_rtt_variance")},
    }
  })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
