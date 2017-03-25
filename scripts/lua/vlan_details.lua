--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    require "snmp_utils"
end

require "lua_utils"
require "graph_utils"

local vlan_id        = _GET["vlan"]
local page           = "historical" -- only historical for now _GET["page"]
local rrdfile        = "bytes.rrd"
if(_GET["rrd_file"] ~= nil) then
   rrdfile=_GET["rrd_file"]
end

interface.select(ifname)
ifId = getInterfaceId(ifname)

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if vlan_id == nil or tonumber(vlan_id) == nil or tonumber(vlan_id) == 0 then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Vlan_Id parameter is missing or is not valid</div>")
    return
end

local rrdname = getRRDName(ifId, "vlan:"..vlan_id, rrdfile)

if(not ntop.exists(rrdname) and rrdfile ~= "all") then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No available stats for VLAN  "..vlan_id..". Please wait a few minutes to allow ntopng to harvest new statistics.</div>")

else

   --[[
      Create Menu Bar with buttons
   --]]
   local nav_url = ntop.getHttpPrefix().."/lua/vlan_details.lua?vlan"..vlan_id
   print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]

   print("<li><a href=\"#\">VLAN: "..vlan_id.."</A> </li>")

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
      vlan_url = ntop.getHttpPrefix()..'/lua/vlan_details.lua?ifid='..ifId..'&vlan'..vlan_id..'&page=historical'
      drawRRD(ifId, 'vlan:'..vlan_id, rrdfile, _GET["zoom"], vlan_url, 1, _GET["epoch"], nil, makeTopStatsScriptsArray())
   end

end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

