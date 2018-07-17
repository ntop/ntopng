--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    require "snmp_utils"
end

require "lua_utils"
require "graph_utils"
local ts_utils = require"ts_utils"

local info = ntop.getInfo(false)
local vlan_id        = _GET["vlan"]
local page           = "historical" -- only historical for now _GET["page"]

interface.select(ifname)
ifId = getInterfaceId(ifname)

sendHTTPContentTypeHeader('text/html')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if vlan_id == nil or tonumber(vlan_id) == nil or tonumber(vlan_id) == 0 then
    print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("vlan_details.vlan_id_parameter_missing_or_invalid_message") .. "</div>")
    return
end

if(not ts_utils.exists("vlan:traffic", {ifid=ifId, vlan=vlan_id})) then
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("vlan_details.no_available_stats_for_vlan_message",{vlan_id=vlan_id, product=info["product"]}).."</div>")

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

   print("<li><a href=\"#\">"..i18n("vlan")..": "..vlan_id.."</A> </li>")

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
      local schema = _GET["ts_schema"] or "vlan:traffic"
      local selected_epoch = _GET["epoch"] or ""
      local vlan_url = ntop.getHttpPrefix()..'/lua/vlan_details.lua?ifid='..ifId..'&vlan='..vlan_id..'&page=historical'

      local tags = {
         ifid = ifId,
         vlan = vlan_id,
         protocol = _GET["protocol"],
      }

      drawGraphs(ifId, schema, tags, _GET["zoom"], vlan_url, selected_epoch, {
         top_protocols = "top:vlan:ndpi",
         timeseries = {
            {schema="vlan:traffic",             	  label=i18n("traffic")},
         },
      })
   end

end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

