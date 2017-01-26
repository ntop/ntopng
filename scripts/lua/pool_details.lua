--
-- (C) 2017 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    require "snmp_utils"
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

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(pool_id == nil) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Network parameter is missing (internal error ?)</div>")
    return
end

print [[
<div class="bs-docs-example">
  <nav class="navbar navbar-default" role="navigation">
    <div class="navbar-collapse collapse">
      <ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">Host Pool: "..pool_name.."</A> </li>")
print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i>\n")

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
      </ul>
    </div>
  </nav>
</div>
]]

local rrdbase = host_pools_utils.getRRDBase(ifId, pool_id)

if(not ntop.exists(rrdbase.."/bytes.rrd")) then
  print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No available data for Host Pool '"..pool_name.."'. ")
  print('Host Pool timeseries can be enabled from the <A HREF="'..ntop.getHttpPrefix()..'/lua/admin/prefs.lua"><i class="fa fa-flask"></i> Preferences</A>. Few minutes are necessary to see the first data points.</div>')
else
  local rrdfile
  if(not isEmptyString(_GET["rrd_file"])) then
    rrdfile = _GET["rrd_file"]
  else
    rrdfile = "bytes.rrd"
  end

  local host_url = ntop.getHttpPrefix()..'/lua/pool_details.lua?ifname='..ifId..'&pool='..pool_id..'&page=historical'
  drawRRD(ifId, 'pool:'..pool_id, rrdfile, _GET["graph_zoom"], host_url, 1, _GET["epoch"], nil, makeTopStatsScriptsArray())
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
