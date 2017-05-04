--
-- (C) 2017 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    require "snmp_utils"
    shaper_utils = require "shaper_utils"
end

require "lua_utils"
require "graph_utils"
require "alert_utils"
local host_pools_utils = require "host_pools_utils"

local pool_id     = _GET["pool"]
local page        = _GET["page"]

if (not ntop.isPro()) then
  return
end

interface.select(ifname)
local ifstats = interface.getStats()
local ifId = ifstats.id
local pool_name = host_pools_utils.getPoolName(ifId, pool_id)

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local base_url = ntop.getHttpPrefix()..'/lua/pool_details.lua'
local page_params = {}

page_params["ifid"] = ifId
page_params["pool"] = pool_id
page_params["page"] = page

if(pool_id == nil) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Pool parameter is missing (internal error ?)</div>")
    return
end

print [[
<div class="bs-docs-example">
  <nav class="navbar navbar-default" role="navigation">
    <div class="navbar-collapse collapse">
      <ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">Host Pool: "..pool_name.."</A> </li>")

local go_page_params = table.clone(page_params)

if page == "historical" then
  print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i>\n")
else
  go_page_params["page"] = "historical"
  print("<li><a href=\""..getPageUrl(base_url, go_page_params).."\"><i class='fa fa-area-chart fa-lg'></i>\n")
end

if ntop.isEnterprise() and ifstats.inline then
  if page == "quotas" then
    print("<li class=\"active\"><a href=\"#\">Quotas</i>\n")
  else
    go_page_params["page"] = "quotas"
    print("<li><a href=\""..getPageUrl(base_url, go_page_params).."\">Quotas\n")
  end
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
      </ul>
    </div>
  </nav>
</div>
]]

local pools_stats = interface.getHostPoolsStats()
local pool_stats = pools_stats and pools_stats[tonumber(pool_id)]

if ntop.isEnterprise() and ifstats.inline and (page == "quotas") and (pool_stats ~= nil) then
  local ndpi_stats = pool_stats.ndpi
  local category_stats = pool_stats.ndpi_categories
  local quota_and_protos = shaper_utils.getPoolProtoShapers(ifId, pool_id)

  -- Empty check
  local empty = true
  for _, proto in pairs(quota_and_protos) do
    if ((tonumber(proto.traffic_quota) > 0) or (tonumber(proto.time_quota) > 0)) then
      -- at least a quota is set
      empty = false
      break
    end
  end

  if empty then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>"..i18n("shaping.no_quota_data")..
      ". Create new quotas <a href=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?page=filtering&pool="..pool_id.."\">here</a>.</div>")
  else
    print[[
    <table class="table table-bordered table-striped">
    <thead>
      <tr>
        <th>]] print(i18n("protocol")) print[[</th>
        <th class="text-center">]] print(i18n("shaping.daily_traffic")) print[[</th>
        <th class="text-center">]] print(i18n("shaping.daily_time")) print[[</th>
      </tr>
    </thead>
    <tbody id="pool_quotas_ndpi_tbody">
    </tbody>
    </table>

    <script>
      function update_ndpi_table() {
        $.ajax({
          type: 'GET',
          url: ']]
    print(getPageUrl(ntop.getHttpPrefix().."/lua/pro/pool_details_ndpi.lua").."', data: ")
    print(tableToJsObject(page_params))
    print[[,
          success: function(content) {
            if(content)
              $('#pool_quotas_ndpi_tbody').html(content);
          }
        });
      }

      setInterval(update_ndpi_table, 5000);
      update_ndpi_table();
     </script>]]
  end
elseif page == "historical" then
  local rrdbase = host_pools_utils.getRRDBase(ifId, pool_id)

  if(not ntop.exists(rrdbase.."/bytes.rrd")) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No available data for Host Pool '"..pool_name.."'. ")
    print('Host Pool timeseries can be enabled from the <A HREF="'..ntop.getHttpPrefix()..'/lua/admin/prefs.lua?tab=on_disk_ts"><i class="fa fa-flask"></i> Preferences</A>. Few minutes are necessary to see the first data points.</div>')
  else
    local rrdfile
    if(not isEmptyString(_GET["rrd_file"])) then
      rrdfile = _GET["rrd_file"]
    else
      rrdfile = "bytes.rrd"
    end

    local host_url = getPageUrl(base_url, page_params)
    drawRRD(ifId, 'pool:'..pool_id, rrdfile, _GET["zoom"], host_url, 1, _GET["epoch"], nil, makeTopStatsScriptsArray())
  end
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
