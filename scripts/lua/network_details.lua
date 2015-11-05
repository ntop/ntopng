--
-- (C) 2013-15 - ntop.org
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

network        = _GET["network"]

interface.select(ifname)
ifstats = aggregateInterfaceStats(interface.getStats())
ifId = ifstats.id

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if(network == nil) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Network parameter is missing (internal error ?)</div>")
   return   
end

network_name = ntop.getNetworkNameById(tonumber(network))

rrdname = dirs.workingdir .. "/" .. ifId .. "/subnetstats/" .. getPathFromKey(network_name) .. "/bytes.rrd"

if(not ntop.exists(rrdname)) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No available stats for network "..network_name.."</div>")
   return
end

print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

print("<li><a href=\"#\">Network: "..network_name.."</A> </li>")
print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i>\n")

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
]]

if(_GET["rrd_file"] == nil) then
   rrdfile = "bytes.rrd"
else
   rrdfile=_GET["rrd_file"]
end

host_url = ntop.getHttpPrefix()..'/lua/network_details.lua?ifname='..ifId..'&network='..network..'&page=historical'
drawRRD(ifId, 'net:'..network_name, rrdfile, _GET["graph_zoom"], host_url, 1, _GET["epoch"], nil, makeTopStatsScriptsArray())

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
