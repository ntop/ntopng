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
ifstats = interface.getStats()
ifId = ifstats.id
local pool_name = host_pools_utils.getPoolName(ifId, pool_id)

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(pool_id == nil) then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Network parameter is missing (internal error ?)</div>")
    return
end

local rrdbase = host_pools_utils.getRRDBase(ifId, pool_id)

if(not ntop.exists(rrdbase.."/bytes.rrd")) then
  print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No available stats for Host Pool '"..pool_name.."'</div>")
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
