--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path


if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   require "snmp_utils"
   shaper_utils = require("shaper_utils")
   host_pools_utils = require "host_pools_utils"
end

require "lua_utils"
require "graph_utils"
require "alert_utils"
require "historical_utils"

local json = require ("dkjson")
local host_pools_utils = require "host_pools_utils"

debug_hosts = false
page        = _GET["page"]
protocol_id = _GET["protocol"]
application = _GET["application"]
host_info   = url2hostinfo(_GET)
host_ip     = host_info["host"]
host_name   = hostinfo2hostkey(host_info)
host_vlan   = host_info["vlan"] or 0
always_show_hist = _GET["always_show_hist"]

ntopinfo    = ntop.getInfo()
active_page = "hosts"

interface.select(ifname)
ifstats = interface.getStats()

ifId = ifstats.id

is_packetdump_enabled = isLocalPacketdumpEnabled()
host = nil
family = nil

prefs = ntop.getPrefs()

local hostkey = hostinfo2hostkey(host_info, nil, true --[[ force show vlan --]])
local labelKey = host_info["host"].."@"..host_info["vlan"]

if((host_name == nil) or (host_ip == nil)) then
   sendHTTPContentTypeHeader('text/html')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Host parameter is missing (internal error ?)</div>")
   return
end

if(protocol_id == nil) then protocol_id = "" end



-- print(">>>") print(host_info["host"]) print("<<<")
if(debug_hosts) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Host:" .. host_info["host"] .. ", Vlan: "..host_vlan.."\n") end

host = interface.getHostInfo(host_info["host"], host_vlan)
restoreFailed = false

if((host == nil) and ((_POST["mode"] == "restore") or (page == "historical"))) then
   if(debug_hosts) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Restored Host Info\n") end
   interface.restoreHost(host_info["host"], host_vlan)
   host = interface.getHostInfo(host_info["host"], host_vlan)
   restoreFailed = true
end

only_historical = false

local host_pool_id = nil

if (host ~= nil) then
   if (isAdministrator() and (_POST["pool"] ~= nil)) then
      host_pool_id = _POST["pool"]
      local prev_pool = tostring(host["host_pool_id"])

      if host_pool_id ~= prev_pool then
         local key = host2member(host["ip"], host["vlan"])
         if not host_pools_utils.changeMemberPool(ifId, key, prev_pool, host_pool_id) then
            host_pool_id = nil
         else
            interface.reloadHostPools()
         end
      end

   end

   if (host_pool_id == nil) then
      host_pool_id = tostring(host["host_pool_id"])
   end
end

if(host == nil) then
   if (rrd_exists(host_ip, "bytes.rrd") and always_show_hist == "true") then
      page = "historical"
      only_historical = true
      sendHTTPContentTypeHeader('text/html')
      ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
      dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
      print [[
         <div class="bs-docs-example">
         <nav class="navbar navbar-default" role="navigation">
         <div class="navbar-collapse collapse">
         <ul class="nav navbar-nav">
      ]]
      print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i></a></li>\n")
      print [[
         <li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
         </ul>
         </div>
         </nav>
         </div>
      ]]
   else
      -- We need to check if this is an aggregated host
      if(not(restoreFailed) and (host_info ~= nil) and (host_info["host"] ~= nil)) then json = ntop.getCache(host_info["host"].. "." .. ifId .. ".json") end
      sendHTTPContentTypeHeader('text/html')
      ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
      if page == "alerts" then
	 print('<script>window.location.href = "')
	 print(ntop.getHttpPrefix())
	 print('/lua/show_alerts.lua?entity='..alertEntity("host")..'&entity_val=')
	 print(hostkey)
	 print('";</script>')
      else
	 dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
	 print('<div class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i> Host '.. hostinfo2hostkey(host_info) .. ' cannot be found. ')
	 if((json ~= nil) and (json ~= "")) then
	    print[[<form id="host_restore_form" method="post">]]
	    print[[<input name="mode" type="hidden" value="restore" />]]
	    print[[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />]]
	    print[[</form>]]
	    print[[ Click <a href="javascript:void(0);" onclick="$('#host_restore_form').submit();">here</a> to restore it from cache.]]
	 else
	    print(purgedErrorString())
	 end

	 print("</div>")
	 dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
      end
      return
   end
else
   sendHTTPContentTypeHeader('text/html')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   print("<link href=\""..ntop.getHttpPrefix().."/css/tablesorted.css\" rel=\"stylesheet\">\n")
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

   --   Added global javascript variable, in order to disable the refresh of pie chart in case
   --  of historical interface
   print('\n<script>var refresh = 3000 /* ms */;</script>\n')

   if(host["ip"] ~= nil) then
      host_name = hostinfo2hostkey(host)
      host_info["host"] = host["ip"]
   end

   if(_POST["custom_name"] ~=nil) then
      setHostAltName(hostinfo2hostkey(host_info), _POST["custom_name"])
   end

   host["label"] = getHostAltName(hostinfo2hostkey(host_info), host["mac"])

   if((host["label"] == nil) or (host["label"] == "")) then
      host["label"] = getHostAltName(host["ip"])
   end

   hostbase = dirs.workingdir .. "/" .. ifId .. "/rrd/" .. getPathFromKey(hostinfo2hostkey(host_info))
   rrdname = hostbase .. "/bytes.rrd"
   -- print(rrdname)
print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]
if((debug_hosts) and (host["ip"] ~= nil)) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Host:" .. host["ip"] .. ", Vlan: "..host["vlan"].."\n") end
url=ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(host_info)

print("<li><a href=\"#\">Host: "..host_info["host"].."</A> </li>")

if((page == "overview") or (page == nil)) then
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i>\n")
else
   print("<li><a href=\""..url.."&page=overview\"><i class=\"fa fa-home fa-lg\"></i>\n")
end

if(page == "traffic") then
   print("<li class=\"active\"><a href=\"#\">Traffic</a></li>\n")
else
   if(host["ip"] ~= nil) then
      print("<li><a href=\""..url.."&page=traffic\">Traffic</a></li>")
   end
end

if(page == "packets") then
   print("<li class=\"active\"><a href=\"#\">Packets</a></li>\n")
else
   if((host["ip"] ~= nil) and (
   	(host["udp.packets.sent"] > 0)
	or (host["udp.packets.rcvd"] > 0)
   	or (host["tcp.packets.sent"] > 0)
	or (host["tcp.packets.rcvd"] > 0))) then
      print("<li><a href=\""..url.."&page=packets\">Packets</a></li>")
   end
end

if(page == "ports") then
   print("<li class=\"active\"><a href=\"#\">Ports</a></li>\n")
else
   if(host["ip"] ~= nil) then
      print("<li><a href=\""..url.."&page=ports\">Ports</a></li>")
   end
end

if(not(isLoopback(ifname))) then
   if(page == "peers") then
      print("<li class=\"active\"><a href=\"#\">Peers</a></li>\n")
   else
      if(host["ip"] ~= nil) then
	 print("<li><a href=\""..url.."&page=peers\">Peers</a></li>")
      end
   end
end

if((host["ICMPv4"] ~= nil) or (host["ICMPv6"] ~= nil)) then
   if(page == "ICMP") then
      print("<li class=\"active\"><a href=\"#\">ICMP</a></li>\n")
   else
      print("<li><a href=\""..url.."&page=ICMP\">ICMP</a></li>")
   end      
end

if(page == "ndpi") then
  direction = _GET["direction"]
  print("<li class=\"active\"><a href=\"#\">Protocols</a></li>\n")
else
   if(host["ip"] ~= nil) then
      print("<li><a href=\""..url.."&page=ndpi\">Protocols</a></li>")
   end
end

if(page == "activities") then
 print("<li class=\"active\"><a href=\"#\">Activities</a></li>\n")
else
 if interface.isPcapDumpInterface() == false and host["ip"] ~= nil then
   print("<li><a href=\""..url.."&page=activities\">Activities</a></li>")
 end
end

if(page == "dns") then
  print("<li class=\"active\"><a href=\"#\">DNS</a></li>\n")
else
   if((host["dns"] ~= nil)
   and ((host["dns"]["sent"]["num_queries"]+host["dns"]["rcvd"]["num_queries"]) > 0)) then
      print("<li><a href=\""..url.."&page=dns\">DNS</a></li>")
   end
end

http = host["http"]

if(page == "http") then
  print("<li class=\"active\"><a href=\"#\">HTTP")
else
   if((http ~= nil)
      and ((http["sender"]["query"]["total"]+ http["receiver"]["response"]["total"]) > 0)) then
      print("<li><a href=\""..url.."&page=http\">HTTP")
      if(host["active_http_hosts"] > 0) then print(" <span class='badge badge-top-right'>".. host["active_http_hosts"] .."</span>") end
   end
end

print("</a></li>\n")

if(page == "flows") then
  print("<li class=\"active\"><a href=\"#\">Flows</a></li>\n")
else
   if(host["ip"] ~= nil) then
      print("<li><a href=\""..url.."&page=flows\">Flows</a></li>")
   end
end

if(page == "categories") then
  print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-sort-alpha-asc fa-lg\"></i></a></li>\n")
else
   if(host["categories"] ~= nil) then
      print("<li><a href=\""..url.."&page=categories\"><i class=\"fa fa-sort-alpha-asc fa-lg\"></i></a></li>")
   end
end

if host["localhost"] == true then
   if(ntop.isPro()) then
      if(page == "snmp") then
	 print("<li class=\"active\"><a href=\"#\">SNMP</a></li>\n")
      elseif interface.isPcapDumpInterface() == false then
	 print("<li><a href=\""..url.."&page=snmp\">SNMP</a></li>")
      end
   end
end

if(not(isLoopback(ifname))) then
   if(page == "talkers") then
      print("<li class=\"active\"><a href=\"#\">Talkers</a></li>\n")
   else
      print("<li><a href=\""..url.."&page=talkers\">Talkers</a></li>")
   end

   if(page == "geomap") then
      print("<li class=\"active\"><a href=\"#\"><i class='fa fa-globe fa-lg'></i></a></li>\n")
   else
      if((host["ip"] ~= nil) and (host["privatehost"] == false)) then
	 print("<li><a href=\""..url.."&page=geomap\"><i class='fa fa-globe fa-lg'></i></a></li>")
      end
   end
else

end

if(false) then
-- NOTE: code temporarily disabled
if(not(isLoopback(ifname))) then
   if(page == "jaccard") then
      print("<li class=\"active\"><a href=\"#\">Similarity</a></li>\n")
   else
      if(host["ip"] ~= nil) then
	 print("<li><a href=\""..url.."&page=jaccard\">Similarity</a></li>")
      end
   end
end
end

if(host.systemhost) then
if(page == "sprobe") then
  print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-flag fa-lg\"></i></a></li>\n")
else
   if(ifstats.sprobe) then
      print("<li><a href=\""..url.."&page=sprobe\"><i class=\"fa fa-flag fa-lg\"></i></a></li>")
   end
end
end

if (host["ip"] ~= nil and host['localhost']) and areAlertsEnabled() then
   if(page == "alerts") then
      print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-warning fa-lg\"></i></a></li>\n")
   elseif interface.isPcapDumpInterface() == false then
      print("\n<li><a href=\""..url.."&page=alerts\"><i class=\"fa fa-warning fa-lg\"></i></a></li>")
   end
end

if(ntop.exists(rrdname)) then
   if(page == "historical") then
     print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i></a></li>\n")
   else
     print("\n<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   end
end

if host["localhost"] == true then
   if(ntop.isEnterprise()) then
      if(page == "traffic_report") then
         print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-file-text report-icon'></i></a></li>\n")
      else
         print("\n<li><a href=\""..url.."&page=traffic_report\"><i class='fa fa-file-text report-icon'></i></a></li>")
      end
   else
      print("\n<li><a href=\"#\" title=\""..i18n('enterpriseOnly').."\"><i class='fa fa-file-text report-icon'></i></A></li>\n")
   end
end

if ntop.isEnterprise() and ifstats.inline and host_pool_id ~= host_pools_utils.DEFAULT_POOL_ID then
  if page == "quotas" then
    print("\n<li class=\"active\"><a href=\"#\">Quotas</a></li>\n")
  else
    print("\n<li><a href=\""..url.."&page=quotas\">Quotas</a></li>\n")
  end
end

if ((isAdministrator()) and (host["ip"] ~= nil)) then
   if(page == "config") then
      print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-cog fa-lg\"></i></a></li>\n")
   elseif interface.isPcapDumpInterface() == false then
      print("\n<li><a href=\""..url.."&page=config\"><i class=\"fa fa-cog fa-lg\"></i></a></li>")
   end
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
</div>
   ]]

--tprint(host)
if((page == "overview") or (page == nil)) then
   print("<table class=\"table table-bordered table-striped\">\n")

   if(host["ip"] ~= nil) then
      if(host["mac"]  ~= "00:00:00:00:00:00") then
	    print("<tr><th width=35%>(Router/AccessPoint) MAC Address</th><td>" ..get_symbolic_mac(host["mac"]).. " "..getHostIcon(host["mac"]))
	    print('</td><td>&nbsp;</td></tr>')
      end

      if(host['localhost'] and (host["mac"] ~= "") and (info["version.enterprise_edition"])) then
	 local ports = find_mac_snmp_ports(host["mac"], _GET["snmp_recache"] == "true")

	 if(ports ~= nil) then
	    local rsps = 1

	    for snmp_device_ip,port in pairs(ports) do
	       rsps = rsps + 1
	    end

	    if(rsps > 1) then
	       print('<tr><td width=35% rowspan='..rsps..'><b>Host SNMP Localization <a href="'..url..'&snmp_recache=true" title="Refresh"><i class="fa fa-refresh fa-sm" aria-hidden="true"></i></a></b><p><small>NOTE: Hosts are located in SNMP devices using the <A HREF=https://tools.ietf.org/html/rfc4188>Bridge MIB</A>.</small></td>')
	       print("<th>SNMP Device</th><th>Device Port</th></tr>\n")
		    for snmp_device_ip,port in pairs(ports) do
		       local community = get_snmp_community(snmp_device_ip)
		       local trunk

		       print("<tr><td align=right><A HREF='" .. ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmp_device_info.lua?ip="..snmp_device_ip.."'>"..getResolvedAddress(hostkey2hostinfo(snmp_device_ip)).."</A></td>")

		       if(port.trunk) then trunk = ' <span class="label label-info">trunk<span>' else trunk = "" end
		       print("<td align=right><A HREF='" .. ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmp_device_info.lua?ip="..snmp_device_ip .. "&ifIdx="..port.id.."'>"..port.id.." <span class=\"label label-default\">"..get_snmp_port_label(snmp_device_ip, community, port.id).."</span>"..trunk.."</A></td></tr>\n")
		    end
	    end
	 end
      end
      print("</tr>")
      
      print("<tr><th>IP Address</th><td colspan=1>" .. host["ip"])
      if(host.childSafe == true) then print(getSafeChildIcon()) end
      
      historicalProtoHostHref(getInterfaceId(ifname), host["ip"], nil, nil, nil)
      
      if(host["local_network_name"] ~= nil) then
	 print(" [&nbsp;<A HREF='"..ntop.getHttpPrefix().."/lua/network_details.lua?network="..host["local_network_id"].."&page=historical'>".. host["local_network_name"].."</A>&nbsp;]")
      end

      if((host["city"] ~= nil) and (host["city"] ~= "")) then
         print(" [ " .. host["city"] .." "..getFlag(host["country"]).." ]")
      end

      print[[</td><td><span>Host Pool: ]]
      if not ifstats.isView then
	 print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/hosts_stats.lua?pool=]] print(host_pool_id) print[[">]] print(host_pools_utils.getPoolName(ifId, host_pool_id)) print[[</a></span>]]
	 print[[&nbsp; <a href="]] print(ntop.getHttpPrefix()) print[[/lua/host_details.lua?]] print(hostinfo2url(host)) print[[&page=config&ifid=]] print(tostring(ifId)) print[[">]]
	 print[[<i class="fa fa-sm fa-cog" aria-hidden="true" title="Change Host Pool"></i></a></span>]]
      else
        -- no link for view interfaces
        print(host_pools_utils.getPoolName(ifId, host_pool_id))
      end
      print("</td></tr>")
   else
      if(host["mac"] ~= nil) then
	 print("<tr><th>MAC Address</th><td colspan=2>" .. host["mac"].. "</td></tr>\n")
      end
   end

   if(ifstats.vlan and (host["vlan"] ~= nil)) then
      print("<tr><th>")

      if(ifstats.sprobe) then
	 print('Source Id')
      else
	 print('VLAN ID')
      end

      print("</th><td colspan=2><A HREF="..ntop.getHttpPrefix().."/lua/hosts_stats.lua?vlan="..host["vlan"]..">"..host["vlan"].."</A></td></tr>\n")
   end

   if(host["os"] ~= "") then
      print("<tr>")
      if(host["os"] ~= "") then
         print("<th>OS</th><td> <A HREF='"..ntop.getHttpPrefix().."/lua/hosts_stats.lua?os=" .. string.gsub(host["os"], " ", '%%20').. "'>"..mapOS2Icon(host["os"]) .. "</A></td><td></td>\n")
      else
         print("<th></th><td></td>\n")
      end
      print("</tr>")
   end

   if((host["asn"] ~= nil) and (host["asn"] > 0)) then
      print("<tr><th>ASN</th><td>")

      print("<A HREF='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=".. host.asn .."'>"..host.asname.."</A> [ ASN <A HREF='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=".. host.asn.."'>".. host.asn.."</A> ]</td>")
      print('<td><A HREF="http://itools.com/tool/arin-whois-domain-search?q='.. host["ip"] ..'&submit=Look+up">Whois Lookup</A> <i class="fa fa-external-link"></i></td>')
      print("</td></tr>\n")
   end

   if(host["ip"] ~= nil) then
      if(host["name"] == nil) then
	 host["name"] = getResolvedAddress(hostkey2hostinfo(host["ip"]))
      end
      print("<tr><th>Name</th>")

      if(isAdministrator()) then
	 print("<td><A HREF=\"http://" .. getIpUrl(host["ip"]) .. "\"> <span id=name>")
      else
	 print("<td colspan=2>")
      end

      if(host["ip"] == host["name"]) then
	 print("<img border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber> ")
      end

--tprint(host) io.write("\n")
      print(host["name"] .. "</span></A> <i class=\"fa fa-external-link\"></i> ")
      if(host["localhost"] == true) then print('<span class="label label-success">Local Host</span>') else print('<span class="label label-default">Remote</span>') end
      if(host["privatehost"] == true) then print(' <span class="label label-warning">Private IP</span>') end
      if(host["systemhost"] == true) then print(' <span class="label label-info">System IP <i class=\"fa fa-flag\"></i></span>') end
      if(host["is_blacklisted"] == true) then print(' <span class="label label-danger">Blacklisted Host</span>') end

      print(getHostIcon(labelKey))
      print("</td><td></td>\n")
   end

if(host["num_alerts"] > 0) then
   print("<tr><th><i class=\"fa fa-warning fa-lg\" style='color: #B94A48;'></i>  <A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(host_info).."&page=alerts'>Alerts</A></th><td colspan=2></li> <span id=num_alerts>"..host["num_alerts"] .. "</span> <span id=alerts_trend></span></td></tr>\n")
end

   if ntop.isPro() and ifstats.inline and (host["has_blocking_quota"] or host["has_blocking_shaper"]) then
      print("<tr><th><i class=\"fa fa-ban fa-lg\"></i> <a href=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..ifstats.id.."&page=filtering&pool="..host_pool_id.."\">Blocked Traffic</a></th><td colspan=2>")
      print("Some host traffic has been blocked by ")
      if host["has_blocking_quota"] then
         print(" an exceeded quota")
         if host["has_blocking_shaper"] then print(" and ") end
      end
      if host["has_blocking_shaper"] then
         print(" a blocking shaper")
      end
      print(".")
      print("</td></tr>")
   end

   print("<tr><th>First / Last Seen</th><td nowrap><span id=first_seen>" .. formatEpoch(host["seen.first"]) ..  " [" .. secondsToTime(os.time()-host["seen.first"]) .. " ago]" .. "</span></td>\n")
   print("<td  width='35%'><span id=last_seen>" .. formatEpoch(host["seen.last"]) .. " [" .. secondsToTime(os.time()-host["seen.last"]) .. " ago]" .. "</span></td></tr>\n")


   if((host["bytes.sent"]+host["bytes.rcvd"]) > 0) then
      print("<tr><th>Sent vs Received Traffic Breakdown</th><td colspan=2>")
      breakdownBar(host["bytes.sent"], "Sent", host["bytes.rcvd"], "Rcvd", 0, 100)
      print("</td></tr>\n")
   end

   print("<tr><th>Traffic Sent / Received</th><td><span id=pkts_sent>" .. formatPackets(host["packets.sent"]) .. "</span> / <span id=bytes_sent>".. bytesToSize(host["bytes.sent"]) .. "</span> <span id=sent_trend></span></td><td><span id=pkts_rcvd>" .. formatPackets(host["packets.rcvd"]) .. "</span> / <span id=bytes_rcvd>".. bytesToSize(host["bytes.rcvd"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")

   local flows_th = "Recently Active Flows / Total"
   if interface.isPacketInterface() then
      if interface.isPcapDumpInterface() == false then
	 flows_th = "Active Flows / Total Active / Low Goodput"
      else
	 flows_th = "Flows / Total Active / Low Goodput"
      end
   end

   print("<tr><th rowspan=2>"..flows_th.."</th><th>'As Client'</th><th>'As Server'</th></tr>\n")
   print("<tr><td><span id=active_flows_as_client>" .. formatValue(host["active_flows.as_client"]) .. "</span> <span id=trend_as_active_client></span> \n")
   print("/ <span id=flows_as_client>" .. formatValue(host["flows.as_client"]) .. "</span> <span id=trend_as_client></span> \n")
   if interface.isPacketInterface() then
      print("/ <span id=low_goodput_as_client>" .. formatValue(host["low_goodput_flows.as_client"]) .. "</span> <span id=low_goodput_trend_as_client></span>\n")
   end
   print("</td>")

   print("<td><span id=active_flows_as_server>" .. formatValue(host["active_flows.as_server"]) .. "</span>  <span id=trend_as_active_server></span> \n")
   print("/ <span id=flows_as_server>"..formatValue(host["flows.as_server"]) .. "</span> <span id=trend_as_server></span> \n")
   if interface.isPacketInterface() then
      print("/ <span id=low_goodput_as_server>" .. formatValue(host["low_goodput_flows.as_server"]) .. "</span> <span id=low_goodput_trend_as_server></span>\n")
   end
   print("</td></tr>")

   if host["tcp.packets.seq_problems"] == true then
      print("<tr><th width=30% rowspan=3>TCP Packets Sent Analysis</th><th>Retransmissions</th><td align=right><span id=pkt_retransmissions>".. formatPackets(host["tcp.packets.retransmissions"]) .."</span> <span id=pkt_retransmissions_trend></span></td></tr>\n")
      print("<tr></th><th>Out of Order</th><td align=right><span id=pkt_ooo>".. formatPackets(host["tcp.packets.out_of_order"]) .."</span> <span id=pkt_ooo_trend></span></td></tr>\n")
      print("<tr></th><th>Lost</th><td align=right><span id=pkt_lost>".. formatPackets(host["tcp.packets.lost"]) .."</span> <span id=pkt_lost_trend></span></td></tr>\n")
   end

   
   if((host["info"] ~= nil) or (host["label"] ~= nil))then
      print("<tr><th>Further Host Names/Information</th><td colspan=2>")
      if(host["info"] ~= nil) then  print(host["info"]) end
      if((host["label"] ~= nil) and (host["info"] ~= host["label"])) then print(host["label"]) end
      print("</td></tr>\n")
   end
   
   if(host["json"] ~= nil) then print("<tr><th><A HREF='http://en.wikipedia.org/wiki/JSON'>JSON</A></th><td colspan=2><i class=\"fa fa-download fa-lg\"></i> <A HREF='"..ntop.getHttpPrefix().."/lua/host_get_json.lua?ifid="..ifId.."&"..hostinfo2url(host_info).."'>Download<A></td></tr>\n") end


   print("</table>\n")

   elseif((page == "packets")) then
      print [[

      <table class="table table-bordered table-striped">
	 ]]

      if(host["bytes.sent"] > 0) then
	 print('<tr><th class="text-left">Sent Distribution</th><td colspan=5><div class="pie-chart" id="sizeSentDistro"></div></td></tr>')
      end
      if(host["bytes.rcvd"] > 0) then
	 print('<tr><th class="text-left">Received Distribution</th><td colspan=5><div class="pie-chart" id="sizeRecvDistro"></div></td></tr>')
      end
      if (host["tcp.packets.rcvd"] + host["tcp.packets.sent"] > 0) then
	 print('<tr><th class="text-left">TCP Flags Distribution</th><td colspan=5><div class="pie-chart" id="flagsDistro"></div></td></tr>')
      end
      if (not isEmptyString(host["mac"])) and (host["mac"] ~= "00:00:00:00:00:00") then
         local macinfo = interface.getMacInfo(host["mac"], host_info["vlan"])

         if (macinfo ~= nil) and (macinfo["arp_requests.sent"] + macinfo["arp_requests.rcvd"] + macinfo["arp_replies.sent"] + macinfo["arp_replies.rcvd"] > 0) then
            print('<tr><th class="text-left">ARP Distribution</th><td colspan=5><div class="pie-chart" id="arpDistro"></div></td></tr>')
         end
      end
      
      hostinfo2json(host_info)
      print [[
      </table>

        <script type='text/javascript'>
	       window.onload=function() {

		   do_pie("#sizeSentDistro", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_pkt_distro.lua', { distr: "size", direction: "sent", ifid: "]] print(ifId.."") print ('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
	print [[
		   do_pie("#sizeRecvDistro", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_pkt_distro.lua', { distr: "size", direction: "recv", ifid: "]] print(ifId.."") print ('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
	print [[
		   do_pie("#flagsDistro", ']]
print (ntop.getHttpPrefix())
print [[/lua/if_tcpflags_pkt_distro.lua', { ifid: "]] print(ifId.."") print ('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")

local macinfo = table.clone(host_info)
macinfo["host"] = host["mac"]

	print [[
		   do_pie("#arpDistro", ']]
print (ntop.getHttpPrefix())
print [[/lua/get_arp_data.lua', { ifid: "]] print(ifId.."") print ('", '..hostinfo2json(macinfo) .."}, \"\", refresh); \n")
	print [[

		}

	    </script><p>
	]]

   elseif((page == "ports")) then
      print [[

      <table class="table table-bordered table-striped">
	 ]]

      if(host["bytes.sent"] > 0) then
	 print('<tr><th class="text-left">Client Ports</th><td colspan=5><div class="pie-chart" id="clientPortsDistro"></div></td></tr>')
      end
      if(host["bytes.rcvd"] > 0) then
	 print('<tr><th class="text-left">Server Ports</th><td colspan=5><div class="pie-chart" id="serverPortsDistro"></div></td></tr>')
      end
      hostinfo2json(host_info)
      print [[
      </table>

        <script type='text/javascript'>
	       window.onload=function() {

		   do_pie("#clientPortsDistro", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_ports_list.lua', { clisrv: "client", ifid: "]] print(ifId.."") print ('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
	print [[
		   do_pie("#serverPortsDistro", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_ports_list.lua', { clisrv: "server", ifid: "]] print(ifId.."") print ('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
	print [[

		}

	    </script><p>
	]]

   elseif((page == "peers")) then
host_info = url2hostinfo(_GET)
peers     = getTopFlowPeers(hostinfo2hostkey(host_info), 1 --[[exists query]])
found     = 0

for key, value in pairs(peers) do
   found = 1
   break
end

if(found) then
   print [[

   <table border=0>
   <tr><td>
   <div id="chart-row-hosts">
       <strong>Top ]] print(hostinfo2hostkey(host_info) ) print [[ Peers</strong>
       <div class="clearfix"></div>
   </div>

   <div id="chart-ring-protocol">
       <strong>Top Peer Protocols</strong>
       <div class="clearfix"></div>
   </div>
   </td></tr></table>

<div class="row">
    <div>
    <table class="table table-hover dc-data-table">
        <thead>
        <tr class="header">
            <th>Host</th>
            <th>L7 Protocol</th>
            <th>Traffic Volume</th>
        </tr>
        </thead>
    </table>
</div>


<script>
var protocolChart = dc.pieChart("#chart-ring-protocol");
var hostChart     = dc.rowChart("#chart-row-hosts");

$.ajax({
      type: 'GET',]]
      print("url: '"..ntop.getHttpPrefix().."/lua/host_top_peers_protocols.lua?ifid="..ifId.."&host="..host_info["host"])
      if((host_info["vlan"] ~= nil) and ifstats.vlan) then print("&vlan="..host_info["vlan"]) end
      print("',\n")
print [[
      data: { },
      error: function(content) { console.log("Host Top Peers: Parse error"); },
      success: function(content) {
   var rsp;
// set crossfilter
var ndx = crossfilter(content),
    protocolDim  = ndx.dimension(function(d) {return d.l7proto;}),
    trafficDim = ndx.dimension(function(d) {return Math.floor(d.traffic/10);}),
    nameDim  = ndx.dimension(function(d) {return d.name;});
    // actually this script expects input data to be aggregated by host, otherwise we are making the sum of logarithms here
    trafficPerl7proto = protocolDim.group().reduceSum(function(d) {return +d.traffic;}),
    trafficPerhost = nameDim.group().reduceSum(function(d) {return +d.traffic;}),
    trafficHist    = trafficDim.group().reduceCount();

protocolChart
    .width(400).height(300)
    .dimension(protocolDim)
    .group(trafficPerl7proto)
    .innerRadius(70);

// Tooltip
protocolChart.title(function(d){
      return d.key+": " + bytesToVolume(Math.pow(10, d.value));
      })

protocolChart.on("click", function(){ alert("A"); });

hostChart
    .width(600).height(300)
    .dimension(nameDim)
    .group(trafficPerhost)
    .elasticX(true);

// Tooltip
hostChart.title(function(d){
      return "Host "+d.key+": " + bytesToVolume(Math.pow(10, d.value));
      })

hostChart.xAxis().tickFormat(function(_v) {
  var v = Math.pow(10, _v);

  if(v < 1024)
    return(v.toFixed(2));
  else
    return bytesToVolume(v);
});

  // dimension by full date
    var dateDimension = ndx.dimension(function (d) {
        return d.host;
    });

   dc.dataTable(".dc-data-table")
        .dimension(dateDimension)
        .group(function (d) { return d.name; })
        .size(10) // (optional) max number of records to be shown, :default = 25
        // dynamic columns creation using an array of closures
        .columns([
            function (d) {
                return d.url;
            },
            function (d) {
                return d.l7proto_url;
            },
            function (d) {
                return bytesToVolume(Math.pow(10, d.traffic));
            }
        ])
        // (optional) sort using the given field, :default = function(d){return d;}
        .sortBy(function (d) {
            return +d.traffic;
        })
        // (optional) sort order, :default ascending
        .order(d3.descending)
        // (optional) custom renderlet to post-process chart using D3
        .renderlet(function (table) {
            table.selectAll(".dc-table-group").classed("info", true);
        });


dc.renderAll();
}
});

</script>
   ]]


else
   print("<disv class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No active flows have been observed for the specified host</div>")
end
   elseif((page == "traffic")) then
     total = 0
     for id, _ in ipairs(l4_keys) do
	k = l4_keys[id][2]
	if(host[k..".bytes.sent"] ~= nil) then total = total + host[k..".bytes.sent"] end
	if(host[k..".bytes.rcvd"] ~= nil) then total = total + host[k..".bytes.rcvd"] end
     end

     if(total == 0) then
	print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> No traffic has been observed for the specified host</div>")
     else
      print [[

      <table class="table table-bordered table-striped">
      	<tr><th class="text-left">L4 Protocol Overview</th><td colspan=5><div class="pie-chart" id="topApplicationProtocols"></div></td></tr>
	</div>

        <script type='text/javascript'>
	       window.onload=function() {

				   do_pie("#topApplicationProtocols", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_l4_stats.lua', { ifid: "]] print(ifId.."") print('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
  print [[
				}

	    </script><p>
	]]

     print("<tr><th>Protocol</th><th>Sent</th><th>Received</th><th>Breakdown</th><th colspan=2>Total</th></tr>\n")

     for id, _ in ipairs(l4_keys) do
	label = l4_keys[id][1]
	k = l4_keys[id][2]
	sent = host[k..".bytes.sent"]
	if(sent == nil) then sent = 0 end
	rcvd = host[k..".bytes.rcvd"]
	if(rcvd == nil) then rcvd = 0 end

	if((sent > 0) or (rcvd > 0)) then
	    print("<tr><th>")
	    fname = getRRDName(ifId, hostinfo2hostkey(host_info), k)
	    if(not ntop.exists(fname)) then
	       print("<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(host_info) .. "&page=historical&rrd_file=".. k ..".rrd\">".. label .."</A>")
	    else
	       print(label)
	    end
	    t = sent+rcvd
	    historicalProtoHostHref(ifId, host, l4_keys[id][3], nil, nil)
	    print("</th><td class=\"text-right\">" .. bytesToSize(sent) .. "</td><td class=\"text-right\">" .. bytesToSize(rcvd) .. "</td><td>")
	    breakdownBar(sent, "Sent", rcvd, "Rcvd", 0, 100)
	    print("</td><td class=\"text-right\">" .. bytesToSize(t).. "</td><td class=\"text-right\">" .. round((t * 100)/total, 2).. " %</td></tr>\n")
	 end
      end
      print("</table></tr>\n")

      print("</table>\n")
   end


elseif((page == "ICMP")) then

  print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     <thead><tr><th>ICMP Message</th><th>Last Sent Peer</th><th>Last Rcvd Peer</th><th>Breakdown</th><th style='text-align:right;'>Packets Sent</th><th style='text-align:right;'>Packets Received</th><th style='text-align:right;'>Total</th></tr></thead>
     <tbody id="host_details_icmp_tbody">
     </tbody>
     </table>

<script>
function update_icmp_table() {
  $.ajax({
    type: 'GET',
    url: ']]
  print(ntop.getHttpPrefix())
  print [[/lua/get_icmp_data.lua',
    data: { ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info))

    print [[ },
    success: function(content) {
      $('#host_details_icmp_tbody').html(content);
      $('#myTable').trigger("update");
    }
  });
}

update_icmp_table();
setInterval(update_icmp_table, 5000);

</script>

]]
elseif((page == "ndpi")) then
   if(host["ndpi"] ~= nil) then
      print [[

      <table class="table table-bordered table-striped">
      	<tr><th class="text-left">Protocol Overview</th>
	       <td colspan=3>
	       <div class="pie-chart" id="topApplicationProtocols"></div>
	       </td>
	       <td colspan=2>
	       <div class="pie-chart" id="topApplicationBreeds"></div>
	       </td>
	       </tr>
	</div>

        <script type='text/javascript'>
	       window.onload=function() {

				   do_pie("#topApplicationProtocols", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_ndpi_stats.lua', { ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);

				   do_pie("#topApplicationBreeds", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_ndpi_stats.lua', { breed: "true", ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);



				}

	    </script>
           <p>
	]]

      print("</table>\n")

  local direction_filter = ""
  local base_url = ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(host_info).."&page=ndpi";

  if(direction ~= nil) then
    direction_filter = '<span class="glyphicon glyphicon-filter"></span>'
  end

  print('<div class="dt-toolbar btn-toolbar pull-right">')
  print('<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Direction ' .. direction_filter .. '<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" id="direction_dropdown">')
  print('<li><a href="'..base_url..'">All</a></li>')
  print('<li><a href="'..base_url..'&direction=sent">Sent only</a></li>')
  print('<li><a href="'..base_url..'&direction=recv">Received only</a></li>')
  print('</ul></div></div>')

  print [[
     <table class="table table-bordered table-striped">
     ]]

     print("<thead><tr><th>Application Protocol</th><th>Duration</th><th>Sent</th><th>Received</th><th>Breakdown</th><th colspan=2>Total</th></tr></thead>\n")

  print ('<tbody id="host_details_ndpi_tbody">\n')
  print ("</tbody>")
  print("</table>\n")

  print [[
<script>
function update_ndpi_table() {
  $.ajax({
    type: 'GET',
    url: ']]
  print(ntop.getHttpPrefix())
  print [[/lua/host_details_ndpi.lua',
    data: { ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info))
    if direction ~= nil then print(", sflow_filter:\"") print(direction..'"') end
    print [[ },
    success: function(content) {
      $('#host_details_ndpi_tbody').html(content);
      // Let the TableSorter plugin know that we updated the table
      $('#h_ndpi_tbody').trigger("update");
    }
  });
}
update_ndpi_table();
]]

--  Update interval ndpi table
print("setInterval(update_ndpi_table, 5000);")

print [[

</script>

]]

   end

   elseif(page == "activities") then
	 print("<table class=\"table table-bordered table-striped\">\n")

   print [[
	    <tr><th>Host Activity</th><td colspan=2>
	    <span id="sentHeatmap"></span>
	    <button id="sent-heatmap-prev-selector" style="margin-bottom: 10px;" class="btn btn-default btn-sm"><i class="fa fa-angle-left fa-lg""></i></button>
	    <button id="heatmap-refresh" style="margin-bottom: 10px;" class="btn btn-default btn-sm"><i class="fa fa-refresh fa-lg"></i></button>
	    <button id="sent-heatmap-next-selector" style="margin-bottom: 10px;" class="btn btn-default btn-sm"><i class="fa fa-angle-right fa-lg"></i></button>
	    <p><span id="heatmapInfo"></span>

	    <script type="text/javascript">

	 var sent_calendar = new CalHeatMap();
        sent_calendar.init({
		       itemSelector: "#sentHeatmap",
		       data: "]]
     print(ntop.getHttpPrefix().."/lua/get_host_activitymap.lua?ifid="..ifId.."&"..hostinfo2url(host_info)..'",\n')

     timezone = get_timezone()

     now = ((os.time()-5*3600)*1000)
     today = os.time()
     today = today - (today % 86400) - 2*3600
     today = today * 1000

     print("/* "..timezone.." */\n")
     print("\t\tstart:   new Date("..now.."),\n") -- now-3h
     print("\t\tminDate: new Date("..today.."),\n")
     print("\t\tmaxDate: new Date("..(os.time()*1000).."),\n")
		     print [[
   		       domain : "hour",
		       range : 6,
		       nextSelector: "#sent-heatmap-next-selector",
		       previousSelector: "#sent-heatmap-prev-selector",

			   onClick: function(date, nb) {
					  if(nb === null) { ("#heatmapInfo").html(""); }
				       else {
					     $("#heatmapInfo").html(date + ": detected traffic for <b>" + nb + "</b> seconds ("+ Math.round((nb*100)/60)+" % of time).");
				       }
				    }

		    });

	    $(document).ready(function(){
			    $('#heatmap-refresh').click(function(){
							      sent_calendar.update(]]
									     print("\""..ntop.getHttpPrefix().."/lua/get_host_activitymap.lua?ifid="..ifId.."&"..hostinfo2url(host_info)..'\");\n')
									     print [[
						    });
				      });

   </script>

	    </td></tr>
      ]]

-- Host activity stats
if host["localhost"] == true then
   print [[ <tr><th>Protocol Activity</th><td colspan=2>
      <div style='margin-top:0.5em;'>
         <input type="radio" name="showmode" value="updown" onclick="if(this.value != curmode) setShowMode(this.value);" checked> User Traffic<br>
         <input type="radio" name="showmode" value="bg" onclick="if(this.value != curmode) setShowMode(this.value);"> Background Traffic
      </div>

      <div id="useractivityContainer"></div>

      <div style='margin-bottom:1em;'>
	 Resolution:&nbsp;
	 <select onchange="onChangeStep(this);">
]]

if(ntop.getCache("ntopng.prefs.host_activity_rrd_creation") == "1") then
print [[


<option disabled>Historical</option>
	   <option value="86400">1 day</option>
	   <option value="3600">1 hour</option>
	   <option value="300" selected="selected">5 min</option>
<option disabled></option>
]]
end

print [[
<option disabled>Realtime</option>
	   <option value="60">1 min</option>
	   <option value="10">10 sec</option>
	   <option value="5">5 sec</option>
	   <option value="1">1 sec</option>
	 </select>
      </div>
]]

if(ntop.getCache("ntopng.prefs.host_activity_rrd_creation") == "0") then
  print('Please enable <A HREF="/lua/admin/prefs.lua?tab=on_disk_rrds">Activities Timeseries</A> preferences to save historical host activities.<p>')
end

print [[
      <script src="]] print(ntop.getHttpPrefix()) print [[/js/cubism.v1.js"></script>
      <script src="]] print(ntop.getHttpPrefix()) print [[/js/cubism.rrd-server.js"></script>
      <style type = "text/css">
         ]] ntop.dumpFile(dirs.installdir .. "/httpdocs/css/cubism.css") print[[
      </style>
      
         <script type="text/javascript">
	 var activitiesurl = "]] print(ntop.getHttpPrefix().."/lua/get_host_activity.lua?ifid="..ifId.."&host="..host_ip) print[[";
         var HorizonGraphWidth = 576;
	 var curmode = "updown";
	 var curstep = 0;
         var context = null;
         var horizon = null;
	 var rrdserver = null;

	 function onChangeStep(control) {
	    var newvalue = control.value;
	    
	    if (curstep != newvalue) {
	       $(control).blur();
	       setShowMode(curmode, newvalue);
	    }
	 }

	 function resetContext(newstep) {	 
	    if (newstep != curstep) {
	       // hard reset
	       curstep = newstep;
	       $('#useractivity').remove();

	       if (context) {
		  context.stop();
		  delete rrdserver;
		  delete horizon;
		  delete context;
	       }

	       var div = $('<div id="useractivity"></div>')
		  .css("margin", "2em 0 1em 0")
		  .css("position", "relative")
		  .css("width", HorizonGraphWidth);
	       $('#useractivityContainer').append(div);

	       context = cubism.context().size(HorizonGraphWidth).step(curstep*1000);
	       horizon = context.horizon();
	       rrdserver = cubism.rrdserver(context, HorizonGraphWidth);

	       // to set labels place on mousemove
	       context.on("focus", function(i) {
		  d3.selectAll(".value").style("right", i == null ? null : context.size() - i + "px");
	       });
	    } else {
	       // soft reset
	       d3.selectAll(".horizon").remove();
	       $('#useractivity').empty();
	    }
	 }

         function setShowMode(mode, newstep) {
	    curmode = mode;
	    newstep = newstep ? newstep : curstep;
	    if (context)
	       context.stop();
	    
            $.ajax({
               type: 'GET',
               url: activitiesurl + '&step=' + newstep,
               success: function(content) {
		  resetContext(newstep);
                  
                  var metrics = [];
                  var parsed = JSON.parse(content);
                  Object.keys(parsed).sort().map(function(activity_name) {
                     metrics.push(rrdserver.metric(activitiesurl+"&activity="+parsed[activity_name], activity_name, mode === "bg"));
                  });
		  if (metrics.length > 0) {
		     // data
		     d3.select("#useractivity")
			.selectAll(".horizon")
			.data(metrics)
			.enter().append("div", ".bottom")
			.attr("class", "horizon")
			.call(horizon.format(function(x) { return bytesToSize(x); }));

		     // bottom axis
		     d3.select("#useractivity")
			.append("div")
			.attr("class", "axis")
			.call(context.axis().orient("bottom"));

		     // vertical line on mousemove
		     d3.select("#useractivity")
			.append("div")
			.attr("class", "rule")
			.call(context.rule());

		     context.start();
		  } else {
		     $('#useractivity').text("No data so far");
		  }
               }
            });
         }
	 
         setShowMode("updown", 300);
      </script>
      <p>
      <b>NOTE:</b><br>The above map filters host application traffic by splitting it in real user traffic (e.g. web page access)
<br>and background traffic (e.g. your email client periodically checks for email presence). Host traffic sent (upload)<br>
is marked as negative value in <font color=blue>blue</font>, traffic received (download) is marked as positive in <font color=green>green</font>.
   </td></tr> ]]

   -- showHostActivityStats(hostbase, "", "1h")
end

	 print("</table>\n")
   elseif(page == "dns") then
      if(host["dns"] ~= nil) then
	 print("<table class=\"table table-bordered table-striped\">\n")
	 print("<tr><th>DNS Breakdown</th><th>Queries</th><th>Positive Replies</th><th>Error Replies</th><th colspan=2>Reply Breakdown</th></tr>")
	 print("<tr><th>Sent</th><td class=\"text-right\"><span id=dns_sent_num_queries>".. formatValue(host["dns"]["sent"]["num_queries"]) .."</span> <span id=trend_sent_num_queries></span></td>")
	 print("<td class=\"text-right\"><span id=dns_sent_num_replies_ok>".. formatValue(host["dns"]["sent"]["num_replies_ok"]) .."</span> <span id=trend_sent_num_replies_ok></span></td>")
	 print("<td class=\"text-right\"><span id=dns_sent_num_replies_error>".. formatValue(host["dns"]["sent"]["num_replies_error"]) .."</span> <span id=trend_sent_num_replies_error></span></td><td colspan=2>")
	 breakdownBar(host["dns"]["sent"]["num_replies_ok"], "OK", host["dns"]["sent"]["num_replies_error"], "Error", 0, 100)
	 print("</td></tr>")

	 if(host["dns"]["sent"]["num_queries"] > 0) then
	    print [[
		     <tr><th>DNS Query Sent Distribution</th><td colspan=5>
		     <div class="pie-chart" id="dnsSent"></div>
		     <script type='text/javascript'>

					 do_pie("#dnsSent", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_dns_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, direction: "sent" }, "", refresh);
				      </script>
					 </td></tr>
           ]]
         end

	 print("<tr><th>Rcvd</th><td class=\"text-right\"><span id=dns_rcvd_num_queries>".. formatValue(host["dns"]["rcvd"]["num_queries"]) .."</span> <span id=trend_rcvd_num_queries></span></td>")
	 print("<td class=\"text-right\"><span id=dns_rcvd_num_replies_ok>".. formatValue(host["dns"]["rcvd"]["num_replies_ok"]) .."</span> <span id=trend_rcvd_num_replies_ok></span></td>")
	 print("<td class=\"text-right\"><span id=dns_rcvd_num_replies_error>".. formatValue(host["dns"]["rcvd"]["num_replies_error"]) .."</span> <span id=trend_rcvd_num_replies_error></span></td><td colspan=2>")
	 breakdownBar(host["dns"]["rcvd"]["num_replies_ok"], "OK", host["dns"]["rcvd"]["num_replies_error"], "Error", 50, 100)
	 print("</td></tr>")

	 if(host["dns"]["rcvd"]["num_queries"] > 0) then
print [[
	 <tr><th>DNS Rcvd Query Distribution</th><td colspan=5>
         <div class="pie-chart" id="dnsRcvd"></div>
         <script type='text/javascript'>

	     do_pie("#dnsRcvd", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_dns_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, direction: "recv" }, "", refresh);
         </script>
         </td></tr>
]]
end

	print('<tr><th rowspan=2>Request vs Reply</th><th colspan=2>Ratio<th><th>Breakdown</th></tr>')
        local dns_ratio = tonumber(host["dns"]["sent"]["num_queries"]) / tonumber(host["dns"]["rcvd"]["num_replies_ok"]+host["dns"]["rcvd"]["num_replies_error"])
        local dns_ratio_str = string.format("%.2f", dns_ratio)

        if(dns_ratio < 0.9) then
          dns_ratio_str = "<font color=red>".. dns_ratio_str .."</font>" 
        end

	print('<tr><td align=right>'..  dns_ratio_str ..'</td><td colspan=3>')
	breakdownBar(host["dns"]["sent"]["num_queries"], "Queries", host["dns"]["rcvd"]["num_replies_ok"]+host["dns"]["rcvd"]["num_replies_error"], "Replies", 30, 70)

print [[
	</td></tr>
        </table>
       <small><b>NOTE:</b><br>Ideally the request vs reply DNS ratio should be 1 (one reply per request). When much lower than that then there are issues worth to be investigated as it means that the number of replies received is much lower than expected and this can indicate that we are using unresponsive DNS resolvers or that they are misconfigured (e.g. they have been move to another IP).
</small>
]]
      end
   elseif(page == "http") then
      if(http ~= nil) then
	 print("<table class=\"table table-bordered table-striped\">\n")

	 if(host["sites"] ~= nil) then
	    local top_sites = json.decode(host["sites"], 1, nil)
	    local top_sites_old = json.decode(host["sites.old"], 1, nil)
	    old_top_len = table.len(top_sites_old)  if(old_top_len > 10) then old_top_len = 10 end
	    top_len = table.len(top_sites)          if(top_len > 10) then top_len = 10 end
	    if(old_top_len > top_len) then num = old_top_len else num = top_len end

	    print("<tr><th rowspan="..(1+num)..">Top Visited Sites</th><th>Current Sites</th><th>Contacts</th><th>Last 5 Minute Sites</th><th>Contacts</th></tr>\n")
	    sites = {} 
	    for k,v in pairsByValues(top_sites, rev) do
	       table.insert(sites, { k, v })
	    end

	    sites_old = {} 
	    for k,v in pairsByValues(top_sites_old, rev) do
	       table.insert(sites_old, { k, v })
	    end

	    for i=1,num do
	       if(sites[i] == nil) then sites[i] = { "", 0 } end
	       if(sites_old[i] == nil) then sites_old[i] = { "", 0 } end
	       print("<tr><th>")
	       if(sites[i][1] ~= "") then 
		  print(formatWebSite(sites[i][1]).."</th><td align=right>"..sites[i][2].."</td>\n") 
	       else
		  print("&nbsp;</th><td>&nbsp;</td>\n")
	       end
	       
	       if(sites_old[i][1] ~= "") then 
		  print("<th>"..formatWebSite(sites_old[i][1]).."</th><td align=right>"..sites_old[i][2].."</td></tr>\n")
	       else
		  print("&nbsp;</th><td>&nbsp;</td></tr>\n") 
	       end
	    end	    
	 end

	 print("<tr><th rowspan=6 width=20%><A HREF='http://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#Request_methods'>HTTP Queries</A></th><th width=20%>Method</th><th width=20%>Requests</th><th colspan=2>Distribution</th></tr>")
	 print("<tr><th>GET</th><td style=\"text-align: right;\"><span id=http_query_num_get>".. formatValue(http["sender"]["query"]["num_get"]) .."</span> <span id=trend_http_query_num_get></span></td><td colspan=2 rowspan=5>")

print [[
         <div class="pie-chart" id="httpQueries"></div>
         <script type='text/javascript'>

	     do_pie("#httpQueries", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_http_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, http_mode: "queries" }, "", refresh);
         </script>
]]

	 print("</td></tr>")
	 print("<tr><th>POST</th><td style=\"text-align: right;\"><span id=http_query_num_post>".. formatValue(http["sender"]["query"]["num_post"]) .."</span> <span id=trend_http_query_num_post></span></td></tr>")
	 print("<tr><th>HEAD</th><td style=\"text-align: right;\"><span id=http_query_num_head>".. formatValue(http["sender"]["query"]["num_head"]) .."</span> <span id=trend_http_query_num_head></span></td></tr>")
	 print("<tr><th>PUT</th><td style=\"text-align: right;\"><span id=http_query_num_put>".. formatValue(http["sender"]["query"]["num_put"]) .."</span> <span id=trend_http_query_num_put></span></td></tr>")
	 print("<tr><th>Other Method</th><td style=\"text-align: right;\"><span id=http_query_num_other>".. formatValue(http["sender"]["query"]["num_other"]) .."</span> <span id=trend_http_query_num_other></span></td></tr>")
	 print("<tr><th colspan=4>&nbsp;</th></tr>")
	 print("<tr><th rowspan=6 width=20%><A HREF='http://en.wikipedia.org/wiki/List_of_HTTP_status_codes'>HTTP Responses</A></th><th width=20%>Response code</th><th width=20%>Responses</th><th colspan=2>Distribution</th></tr>")
	 print("<tr><th>1xx (Informational)</th><td style=\"text-align: right;\"><span id=http_response_num_1xx>".. formatValue(http["receiver"]["response"]["num_1xx"]) .."</span> <span id=trend_http_response_num_1xx></span></td><td colspan=2 rowspan=5>")

print [[
         <div class="pie-chart" id="httpResponses"></div>
         <script type='text/javascript'>

	     do_pie("#httpResponses", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_http_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, http_mode: "responses" }, "", refresh);
         </script>
]]
	 print("</td></tr>")
	 print("<tr><th>2xx (Success)</th><td style=\"text-align: right;\"><span id=http_response_num_2xx>".. formatValue(http["receiver"]["response"]["num_2xx"]) .."</span> <span id=trend_http_response_num_2xx></span></td></tr>")
	 print("<tr><th>3xx (Redirection)</th><td style=\"text-align: right;\"><span id=http_response_num_3xx>".. formatValue(http["receiver"]["response"]["num_3xx"]) .."</span> <span id=trend_http_response_num_3xx></span></td></tr>")
	 print("<tr><th>4xx (Client Error)</th><td style=\"text-align: right;\"><span id=http_response_num_4xx>".. formatValue(http["receiver"]["response"]["num_4xx"]) .."</span> <span id=trend_http_response_num_4xx></span></td></tr>")
	 print("<tr><th>5xx (Server Error)</th><td style=\"text-align: right;\"><span id=http_response_num_5xx>".. formatValue(http["receiver"]["response"]["num_5xx"]) .."</span> <span id=trend_http_response_num_5xx></span></td></tr>")

         vh = http["virtual_hosts"]
	 if(vh ~= nil) then
	    local now    = os.time()
	    local ago1h  = now - 3600
  	    num = table.len(vh)
	    if(num > 0) then
	       local ifId = getInterfaceId(ifname)
	       print("<tr><th rowspan="..(num+1).." width=20%>Virtual Hosts</th><th>Name</th><th>Traffic Sent</th><th>Traffic Received</th><th>Requests Served</th></tr>\n")
	       for k,v in pairsByKeys(vh, asc) do
		  local j = string.gsub(k, "%.", "___")
		  print("<tr><td><A HREF='http://"..k.."'>"..k.."</A> <i class='fa fa-external-link'></i>")
		  historicalProtoHostHref(ifId, host, nil, nil, k)
		  print("</td>")
		  print("<td align=right><span id="..j.."_bytes_vhost_sent>"..bytesToSize(vh[k]["bytes.sent"]).."</span></td>")
		  print("<td align=right><span id="..j.."_bytes_vhost_rcvd>"..bytesToSize(vh[k]["bytes.rcvd"]).."</span></td>")
		  print("<td align=right><span id="..j.."_num_vhost_req_serv>"..formatValue(vh[k]["http.requests"]).."</span></td></tr>\n")
	       end
	    end
         end

	 print("</table>\n")
      end
   elseif(page == "flows") then

print [[
      <div id="table-flows"></div>
	 <script>
   var url_update = "]]
print (ntop.getHttpPrefix())
print [[/lua/get_flows_data.lua?ifid=]]
print(ifId.."&")
if (application ~= nil) then
   print("application="..application.."&")
end
print (hostinfo2url(host_info)..'";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")
if(ifstats.sprobe) then show_sprobe = true else show_sprobe = false end
if(ifstats.vlan)   then show_vlan = true else show_vlan = false end
-- Set the host table option
if(show_sprobe) then print ('flow_rows_option["sprobe"] = true;\n') end
if(show_vlan) then print ('flow_rows_option["vlan"] = true;\n') end


local active_flows_msg = "Active Flows"
if not interface.isPacketInterface() then
   active_flows_msg = "Recently "..active_flows_msg
elseif interface.isPcapDumpInterface() then
   active_flows_msg = "Flows"
end

local application_filter = ''
if(application ~= nil) then
   application_filter = '<span class="glyphicon glyphicon-filter"></span>'
end
local dt_buttons = "['<div class=\"btn-group\"><button class=\"btn btn-link dropdown-toggle\" data-toggle=\"dropdown\">Applications " .. application_filter .. "<span class=\"caret\"></span></button> <ul class=\"dropdown-menu\" role=\"menu\" >"
dt_buttons = dt_buttons..'<li><a href="'..ntop.getHttpPrefix()..url..'&page=flows">All Proto</a></li>'

local ndpi_stats = interface.getnDPIStats(host_info["host"], host_vlan)

for key, value in pairsByKeys(ndpi_stats["ndpi"], asc) do
   local class_active = ''
   if(key == application) then
      class_active = ' class="active"'
   end
   dt_buttons = dt_buttons..'<li '..class_active..'><a href="'..ntop.getHttpPrefix()..url..'&page=flows&application='..key..'">'..key..'</a></li>'
end

dt_buttons = dt_buttons .. "</ul></div>']"

if(show_sprobe) then
print [[
  //console.log(url_update);
   flow_rows_option["sprobe"] = true;
   flow_rows_option["type"] = 'host';
   $("#table-flows").datatable({
      url: url_update ,
      buttons: ]] print(dt_buttons) print[[,
      rowCallback: function ( row ) { return flow_table_setID(row); },
         showPagination: true,
]]
-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if(preference ~= "") then print ('perPage: '..preference.. ",\n") end

print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')


print('title: "'..active_flows_msg..'",')

  ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/sflows_stats_top.inc")
  prefs = ntop.getPrefs()
  ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/sflows_stats_bottom.inc")
else

print [[
  flow_rows_option["type"] = 'host';
	 $("#table-flows").datatable({
         url: url_update,
         buttons: ]] print(dt_buttons) print[[,
         rowCallback: function ( row ) { return flow_table_setID(row); },
	       showPagination: true,
	       ]]

  print('title: "'..active_flows_msg..'",')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if(preference ~= "") then print ('perPage: '..preference.. ",\n") end


print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')

print [[
	        columns: [
           {
        title: "Key",
         field: "key",
         hidden: true
         },
			     {
			     title: "",
				 field: "column_key",
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "Application",
				 field: "column_ndpi",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "L4 Proto",
				 field: "column_proto_l4",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },]]

if(show_vlan) then

if(ifstats.sprobe) then
   print('{ title: "Source Id",\n')
else
   if(ifstats.vlan) then
     print('{ title: "VLAN",\n')
   end
end


print [[
         field: "column_vlan",
         sortable: true,
                 css: {
              textAlign: 'center'
           }

         },
]]
end
print [[
			     {
			     title: "Client",
				 field: "column_client",
				 sortable: true,
				 },
			     {
			     title: "Server",
				 field: "column_server",
				 sortable: true,
				 },
			     {
			     title: "Duration",
				 field: "column_duration",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			       }
			       },
			     {
			     title: "Actual Thpt",
				 field: "column_thpt",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }
				 },
			     {
			     title: "Total Bytes",
				 field: "column_bytes",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }

				 }
			     ,{
			     title: "Info",
				 field: "column_info",
				 sortable: true,
	 	             css: {
			        textAlign: 'left'
			     }
				 }
			     ]
	       });
       </script>

   ]]

end
elseif(page == "categories") then
print [[
      <table class="table table-bordered table-striped">
        <tr><th class="text-left">Traffic Categories</th><td><div class="pie-chart" id="topTrafficCategories"></div></td></tr>
        </div>

        <script type='text/javascript'>
	     window.onload=function() {

                                   do_pie("#topTrafficCategories", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_category_stats.lua', { ifid: "]] print(ifId.."") print('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
  print [[
	    }

            </script>

<tr><td colspan=2>
<div id="table-categories"></div>
         <script type='text/javascript'>
           $("#table-categories").datatable({
                        title: "",
                        url: "]] print(ntop.getHttpPrefix().."/lua/get_host_categories.lua?"..hostinfo2url(host_info).."&ifid="..ifId) print [[",
]]

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

-- Automatic default sorted. NB: the column must exist.
print ('sort: [ ["' .. getDefaultTableSort("host_categories") ..'","' .. getDefaultTableSortOrder("host_categories").. '"] ],')


print [[
               showPagination: true,
                columns: [
                         {
                             title: "Category Id",
                                 field: "column_id",
                                 hidden: true,
                                 sortable: true,
                          },
                          {
                             title: "Traffic Category",
                                 field: "column_label",
                                 sortable: true,
                             css: {
                                textAlign: 'left'
                             }
                                 },
                             {
                             title: "Traffic Volume",
                                 field: "column_bytes",
                                 sortable: true,
                             css: {
                                textAlign: 'right'
                             }
                                 },
                             {
                             title: "Traffic %",
                                 field: "column_pct",
                                 sortable: false,
                             css: {
                                textAlign: 'right'
                             }
                                 }
                             ]
               });
</script>
<div>
<small> <b>NOTE</b>:<ul><li>Percentages are related only to classified traffic.
]]
if ntop.getCache("ntopng.prefs.host_categories_rrd_creation") ~= "1" then
  print("<li>Historical per-category traffic data can be enabled via ntopng <a href=\""..ntop.getHttpPrefix().."/lua/admin/prefs.lua\"<i class=\"fa fa-flask\"></i> Preferences</a>.")
  print(" When enabled, RRDs with 5-minute samples will be created for each category detected and historical data will become accessible by clicking on each category.</li>")
else
  print("<li>Category labels can be clicked to browse historical data.</li>")
end
print [[
</ul>
</small>
</div>

</td></tr>
</table>
]]  
elseif(page == "snmp" and ntop.isPro()) then
   local sys_object_id = true
   local community = get_snmp_community(host_ip)

   local snmp_devices = get_snmp_devices()
   if snmp_devices[host_ip] == nil then -- host has not been configured

      local msg = "Host "..host_ip.. " has not been configured as an SNMP device."
      msg = msg.." Visit page <a href='"..ntop.getHttpPrefix().."/lua/pro/enterprise/snmpdevices_stats.lua'>SNMP</a> to add this host to the list of configured SNMP devices."

      local trying =  "<span id='trying_default_community'> Trying to retrieve host SNMP MIB using the default community '"..community.."'"
      trying = trying.. " <img border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style='vertical-align:text-top;' id=throbber></span>"
      if ntop.isEnterprise() then
        print("<div class='alert alert-info'><i class='fa fa-info-circle fa-lg' aria-hidden='true'></i> "..msg.."</div>")
      end
      print(trying)

      sys_object_id = get_snmp_value(host_ip, community, "1.3.6.1.2.1.1.2.0", false)
   end

   if(sys_object_id ~= nil) then
      print("<script type='text/javascript'>$('#trying_default_community').html(\"Showing SNMP MIB information retrieved using the default community '"..community.."':<br><br>\")</script>")
      print_snmp_report(host_ip, true)
   else
      print("<script type='text/javascript'>$('#trying_default_community').html(\"<div class='alert alert-warning'>Unable to retrieve host SNMP MIB using the default community '"..community.."'.</div>\")</script>")
   end

elseif(page == "talkers") then
print("<center>")
print('<div class="row">')
dofile(dirs.installdir .. "/scripts/lua/inc/sankey.lua")
print("</div></center></br>")
elseif(page == "geomap") then
print("<center>")


print [[
     <style type="text/css">
     #map-canvas { width: 800px; height: 480px; }
   </style>

</center>
]]

addGoogleMapsScript()

print[[

    <script src="]] print(ntop.getHttpPrefix()) print [[/js/markerclusterer.js"></script>
<div class="container-fluid">
  <div class="row-fluid">
    <div class="span8">
      <div id="map-canvas"></div>
]]

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/geolocation_disclaimer.inc")

print [[
</div>
</div>
</div>

<script type="text/javascript">
/* IP Address to zoom */
  var zoomIP = "]] print('ifid='..ifId.."&"..hostinfo2url(host_info)) print [[ ";
  var url_prefix = "]] print(ntop.getHttpPrefix()) print [[";
</script>
    <script type="text/javascript" src="]] print(ntop.getHttpPrefix()) print [[/js/googleMapJson.js" ></script>
]]

elseif(page == "jaccard") then
-- NOTE: code temporarily disabled

print [[
<div id="prg" class="container">
    <div class="progress progress-striped active">
	 <div class="bar" style="width: 100%;"></div>
    </div>
</div>
]]

jaccard = interface.similarHostActivity(host_info["host"],host_info["vlan"])

if(jaccard ~= nil) then
print [[
<script type="text/javascript">
  var $bar = $('#prg');

  $bar.hide();
  $bar.remove();
</script>
]]

vals = {}
for k,v in pairs(jaccard) do
   vals[v] = k
end

max_hosts = 10

n = 0

if(host["name"] == nil) then host["name"] = getResolvedAddress(hostkey2hostinfo(host["ip"])) end

for v,k in pairsByKeys(vals, rev) do

   if(v > 0) then
      if(n == 0) then
	 print("<table class=\"table table-bordered table-striped\">\n")
	 print("<tr><th>Local Hosts Similar to ".. hostinfo2hostkey(host) .."</th><th>Jaccard Coefficient</th><th>Activity Map</th>\n")
      end

      correlated_host = interface.getHostInfo(k)
      if(correlated_host ~= nil) then

	 if(correlated_host["name"] == nil) then correlated_host["name"] = getResolvedAddress(hostkey2hostinfo(correlated_host["ip"])) end

         -- print the host row together with the Jaccard coefficient
	 print("<tr>")
   -- print("<th align=left><A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?host="..k.."'>"..correlated_host["name"].."</a></th>")
	 print("<th align=left><A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(correlated_host).."'>"..hostinfo2hostkey(correlated_host).."</a></th>")
	 print("<th>"..round(v,2).."</th>");

	 -- print the activity map row
	 print("<td>");
	 print("<span id=\"sentHeatmap"..n.."\"></span>");
	 print [[
	 <script type="text/javascript">
	 	 var sent_calendar = new CalHeatMap();
		 sent_calendar.init({
	 ]]
	print("itemSelector: \"#sentHeatmap"..n.."\",data: \"");
  print(ntop.getHttpPrefix().."/lua/get_host_activitymap.lua?ifid="..ifId.."&"..hostinfo2url(correlated_host)..'",\n')
  -- print(ntop.getHttpPrefix().."/lua/get_host_activitymap.lua?host="..k..'",\n')

	timezone = get_timezone()

	now = ((os.time()-5*3600)*1000)
	today = os.time()
	today = today - (today % 86400) - 2*3600
	today = today * 1000

	print("/* "..timezone.." */\n")
	print("\t\tstart:   new Date("..now.."),\n") -- now-3h
	print("\t\tminDate: new Date("..today.."),\n")
	print("\t\tmaxDate: new Date("..(os.time()*1000).."),\n")
	print [[
	domain : "hour",
	range : 6,
	nextSelector: "#sent-heatmap-next-selector",
	previousSelector: "#sent-heatmap-prev-selector",
	    });

	    $(document).ready(function(){
			    $('#heatmap-refresh').click(function(){
				    sent_calendar.update(]]
					    print("\""..ntop.getHttpPrefix().."/lua/get_host_activitymap.lua?ifid="..ifId.."&"..hostinfo2url(correlated_host)..'\");\n')
				    print [[
				    });
			    });
	    </script>
	    </td>
	 ]]

	 print("</td></tr>")
	 n = n +1

	 if(n >= max_hosts) then
	    break
	 end
      end
   end
end

if(n > 0) then
   print("</table>\n")
else
   print("There is no host correlated to ".. hostinfo2hostkey(host).."<p>\n")
end

print [[
<b>Note</b>:
<ul>
	 <li>Jaccard Similarity considers only activity map as shown in the <A HREF="]]
print (ntop.getHttpPrefix())
print [[/lua/host_details.lua?ifid=]] print(ifId.."&"..hostinfo2url(host_info)) print [[">host overview</A>.
<li>Two hosts are similar according to the Jaccard coefficient when their activity tends to overlap. In particular when their activity map is very similar. The <A HREF="http://en.wikipedia.org/wiki/Jaccard_index">Jaccard similarity coefficient</A> is a number between +1 and 0.
</ul>
]]
end

elseif(page == "contacts") then

if(num > 0) then
   mode = "embed"
   if(host["name"] == nil) then host["name"] = getResolvedAddress(hostkey2hostinfo(host["ip"])) end
   name = host["name"]
   dofile(dirs.installdir .. "/scripts/lua/hosts_interaction.lua")

   print("<table class=\"table table-bordered table-striped\">\n")
   print("<tr><th width=50%>Client Contacts (Initiator)</th><th width=50%>Server Contacts (Receiver)</th></tr>\n")

   print("<tr>")

   if(cnum  == 0) then
      print("<td>No client contacts so far</td>")
   else
      print("<td><table class=\"table table-bordered table-striped\">\n")
      print("<tr><th width=75%>Server Address</th><th>Contacts</th></tr>\n")

      -- TOFIX VLAN (We need to remove the host vlan and add the client vlan)
      -- Client
      sortTable = {}
      for k,v in pairs(host["contacts"]["client"]) do

        sortTable[v]=k
      end

      num = 0
      max_num = 64 -- Do not create huge maps
      for _v,k in pairsByKeys(sortTable, rev) do

	 if(num >= max_num) then break end
	 num = num + 1
	 name = interface.getHostInfo(k)

   -- TOFIX VLAN (We need to remove the host vlan and add the client vlan)
	 v = host["contacts"]["client"][k]
   info = interface.getHostInfo(k)

   if(info ~= nil) then
      if(info["name"] ~= nil) then n = info["name"] else n = getResolvedAddress(hostkey2hostinfo(info["ip"])) end
      url = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(info).."\">"..n.."</A>"
   else
      url = k
   end

   if(info ~= nil) then
      url = url .. getFlag(info["country"]).." "
   end
   -- print(v.."<br>")
	 print("<tr><th>"..url.."</th><td class=\"text-right\">" .. formatValue(v) .. "</td></tr>\n")
      end
      print("</table></td>\n")
   end

   if(snum  == 0) then
      print("<td>No server contacts so far</td>")
   else
      print("<td><table class=\"table table-bordered table-striped\">\n")
      print("<tr><th width=75%>Client Address</th><th>Contacts</th></tr>\n")

      -- Server
      sortTable = {}
      for k,v in pairs(host["contacts"]["server"]) do sortTable[v]=k end

      for _v,k in pairsByKeys(sortTable, rev) do
	 v = host["contacts"]["server"][k]
   info = interface.getHostInfo(k)
	 if(info ~= nil) then
	    if(info["name"] ~= nil) then n = info["name"] else n = getResolvedAddress(hostkey2hostinfo(info["ip"])) end
	    url = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(info).."\">"..n.."</A>"
	 else
	    url = k
	 end

	 if(info ~= nil) then
	    url = url ..getFlag(info["country"]).." "
	 end
	 print("<tr><th>"..url.."</th><td class=\"text-right\">" .. formatValue(v) .. "</td></tr>\n")
      end
      print("</table></td>\n")
   end

print("</tr>\n")

print("</table>\n")
else
   print("No contacts for this host")
end

elseif(page == "alerts") then

   drawAlertSourceSettings(hostkey,
      i18n("show_alerts.host_delete_config_btn", {host=host_name}), "show_alerts.host_delete_config_confirm",
      "host_details.lua", {ifid=ifId, host=host_ip},
      host_name, "host")

elseif (page == "quotas" and ntop.isEnterprise() and host_pool_id ~= host_pools_utils.DEFAULT_POOL_ID and ifstats.inline) then
   local page_params = {ifid=ifId, pool=host_pool_id, host=hostkey, page=page}
   host_pools_utils.printQuotas(host_pool_id, host, page_params)

elseif (page == "config") then

   if(not isAdministrator()) then
      return
   end

   if(host["localhost"] == true and is_packetdump_enabled) then
      local dump_status = host["dump_host_traffic"]

      if(_POST["dump_traffic"] ~= nil) then
         if(_POST["dump_traffic"] == "true") then
            dump_status = true
         else
            dump_status = false
         end
         interface.select(ifname) -- if we submitted a form, nothing is select()ed
         interface.setHostDumpPolicy(dump_status, host_info["host"], host_vlan)
      end

      if(dump_status) then
         dump_traffic_checked = 'checked="checked"'
         dump_traffic_value = "false" -- Opposite
      else
         dump_traffic_checked = ""
         dump_traffic_value = "true" -- Opposite
      end
   end

   local trigger_alerts = true
   local trigger_alerts_checked = "checked"

   if host["localhost"] == true then
      if (_POST["trigger_alerts"] ~= nil) then
         if _POST["trigger_alerts"] ~= "true" then
            trigger_alerts = false
            trigger_alerts_checked = ""
         end

         ntop.setHashCache(get_alerts_suppressed_hash_name(getInterfaceId(ifname)), hostkey, tostring(trigger_alerts))

         interface.select(ifname)
         interface.refreshHostsAlertsConfiguration(host_ip, host_vlan)
      else
         trigger_alerts = ntop.getHashCache(get_alerts_suppressed_hash_name(getInterfaceId(ifname)), hostkey)
         if trigger_alerts == "false" then
            trigger_alerts = false
            trigger_alerts_checked = ""
         end
      end
   end

   if(_POST["custom_icon"] ~= nil) then
      setHostIcon(labelKey, _POST["custom_icon"])
   end

   print[[
   <table class="table table-bordered table-striped">
      <tr>
         <th>Host Alias</th>
         <td>
            <form class="form-inline" style="margin-bottom: 0px;" method="post">
               <input type="text" name="custom_name" class="form-control" placeholder="Custom Name" value="]]
   if(host["label"] ~= nil) then print(host["label"]) end
   print[["></input> ]]
   pickIcon(labelKey, host["mac"])
   print [[
               <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
               &nbsp;<button type="submit" class="btn btn-default">]] print(i18n("save")) print[[</button>
            </form>
         </td>
      </tr>]]
   if not ifstats.isView then
      print[[<tr>
         <th>Host Pool</th>
         <td>
            <form class="form-inline" style="margin-bottom: 0px; display:inline;" method="post">
               <select name="pool" class="form-control" style="width:20em; display:inline;">]]
   for _,pool in ipairs(host_pools_utils.getPoolsList(ifId)) do
      print[[<option value="]] print(pool.id) print[["]]
      if pool.id == host_pool_id then
         print[[ selected]]
      end
      print[[>]] print(pool.name) print[[</option>]]
   end
   print[[
               </select>&nbsp;
               <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
               <button type="submit" class="btn btn-default">]] print(i18n("save")) print[[</button>
            </form>
         </td>
      </tr>]]
   end

   if host["localhost"] then
      print [[<tr>
         <th>Trigger Host Alerts</th>
         <td>
            <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">
               <input type="hidden" name="trigger_alerts" value="]] print(not trigger_alerts) print[[">
               <input type="checkbox" value="1" ]] print(trigger_alerts_checked) print[[ onclick="this.form.submit();">
                  <i class="fa fa-exclamation-triangle fa-lg"></i>
                  Trigger alerts for Host ]] print(host["name"]) print[[
               </input>
               <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[["/>
            </form>
         </td>
      </tr>]]
   end

      print [[<tr>
         <th>Dump Host Traffic</th>
         <td>
            <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;" method="post">
               <input type="hidden" name="dump_traffic" value="]] print(dump_traffic_value) print[[">
               <input type="checkbox" value="1" ]] print(dump_traffic_checked) print[[ onclick="this.form.submit();">
                  <i class="fa fa-hdd-o fa-lg"></i>
                  <a href="]] print(ntop.getHttpPrefix()) print[[/lua/if_stats.lua?ifid=]] print(getInterfaceId(ifname).."") print[[&page=packetdump">Dump Traffic</a>
               </input>
               <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[["/>
            </form>
         </td>
      </tr>]]

   if(ifstats.inline and (host.localhost or host.systemhost)) then
      -- Traffic policy
      drop_host_traffic = _POST["drop_host_traffic"]
      host_key = hostinfo2hostkey(host_info)
      if(drop_host_traffic ~= nil) then
         if(drop_host_traffic == "false") then
            ntop.delHashCache("ntopng.prefs.drop_host_traffic", host_key)
         else
            ntop.setHashCache("ntopng.prefs.drop_host_traffic", host_key, drop_host_traffic)
         end

         interface.updateHostTrafficPolicy(host_info["host"], host_vlan)
      else
         drop_host_traffic = ntop.getHashCache("ntopng.prefs.drop_host_traffic", host_key)
         if(drop_host_traffic == nil) then drop_host_traffic = "false" end
      end

      print("<tr><th>Host Traffic Policy</th><td>")

      if(host["localhost"] == true) then
         drop_traffic = ntop.getHashCache("ntopng.prefs.drop_host_traffic", host_key)
         if(drop_traffic == "true") then
            drop_traffic_checked = 'checked="checked"'
            drop_traffic_value = "false" -- Opposite
         else
            drop_traffic_checked = ""
            drop_traffic_value = "true" -- Opposite
         end

         print[[<form id="alert_prefs" class="form-inline" style="margin-bottom:0px; margin-right:1em; display:inline;" method="post">]]
         print('<input type="hidden" name="drop_host_traffic" value="'..drop_traffic_value..'"><input type="checkbox" value="1" '..drop_traffic_checked..' onclick="this.form.submit();"> Drop All Host Traffic</input>')
         print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
         print('</form>')
      end

      print[[<a class="btn btn-default btn-sm" href="]]
      print(ntop.getHttpPrefix())
      print[[/lua/if_stats.lua?page=filtering&pool=]]
      print(tostring(host["host_pool_id"]))
      print[[#protocols">Modify Host Pool Policy</a>]]
      print('</td></tr>')

      print('</form>')
      print('</td></tr>')
   end

   print[[
   </table>]]

elseif(page == "historical") then
if(_GET["rrd_file"] == nil) then
   rrdfile = "bytes.rrd"
else
   rrdfile=_GET["rrd_file"]
end

host_url = "host="..host_ip
host_key = host_ip
if(host_vlan and (host_vlan > 0)) then
   host_url = host_url.."&vlan="..host_vlan
   host_key = host_key.."@"..host_vlan
end
drawRRD(ifId, host_key, rrdfile, _GET["zoom"], ntop.getHttpPrefix()..'/lua/host_details.lua?ifid='..ifId..'&'..host_url..'&page=historical', 1, _GET["epoch"], nil, makeTopStatsScriptsArray())
elseif(page == "traffic_report") then
   dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/traffic_report.lua")
elseif(page == "sprobe") then


print [[
  <br>
  <!-- Left Tab -->
  <div class="tabbable tabs-left">

    <ul class="nav nav-tabs">
      <li class="active"><a href="#Users" data-toggle="tab">Users</a></li>
      <li><a href="#Processes" data-toggle="tab">Processes</a></li>
      <li ><a href="#Tree" data-toggle="tab">Tree</a></li>
    </ul>

    <!-- Tab content-->
    <div class="tab-content">
]]

print [[
      <div class="tab-pane active" id="Users">
      Show :
          <div class="btn-group btn-toggle btn-sm" data-toggle="buttons" id="show_users">
            <label class="btn btn-default btn-sm active">
              <input type="radio" name="show_users" value="All">All</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_users" value="Client" checked="">Client</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_users" value="Server" checked="">Server</label>
          </div>
        Aggregated by :
          <div class="btn-group">
            <button id="aggregation_users_displayed" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">
            Traffic <span class="caret"></span></button>
            <ul class="dropdown-menu" id="aggregation_users">
            <li><a>Traffic</a></li>
            <li><a>Active memory</a></li>
            <!-- <li><a>Latency</a></li> -->
            </ul>
          </div><!-- /btn-group -->
         <br/>
         <br/>
        <table class="table table-bordered table-striped">
          <tr>
            <th class="text-center span3">Top Users</th>
            <td class="span3"><div class="pie-chart" id="topUsers"></div></td>

          </tr>
        </table>
      </div> <!-- Tab Users-->
]]

print [[
      <div class="tab-pane" id="Processes">
      Show :
          <div class="btn-group btn-toggle btn-sm" data-toggle="buttons" id="show_processes">
            <label class="btn btn-default btn-sm active">
              <input type="radio" name="show_processes" value="All">All</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_processes" value="Client" checked="">Client</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_processes" value="Server" checked="">Server</label>
          </div>
        Aggregated by :
          <div class="btn-group">
            <button id="aggregation_processes_displayed" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">Traffic <span class="caret"></span></button>
            <ul class="dropdown-menu" id="aggregation_processes">
            <li><a>Traffic</a></li>
            <li><a>Active memory</a></li>
            <!-- <li><a>Latency</a></li> -->
            </ul>
          </div><!-- /btn-group -->
         <br/>
         <br/>
        <table class="table table-bordered table-striped">
          <tr>
            <th class="text-center span3">Top Processes</th>
             <td class="span3"><div class="pie-chart" id="topProcess"></div></td>

          </tr>
        </table>
      </div> <!-- Tab Processes-->
]]

print [[
      <div class="tab-pane" id="Tree">

        Show :
          <div class="btn-group btn-toggle btn-sm" data-toggle="buttons" id="show_tree">
            <label class="btn btn-default btn-sm active">
              <input type="radio" name="show_tree" value="All">All</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_tree" value="Client" checked="">Client</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_tree" value="Server" checked="">Server</label>
          </div>
        Aggregated by :
          <div class="btn-group">
            <button id="aggregation_tree_displayed" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">Traffic <span class="caret"></span></button>
            <ul class="dropdown-menu" id="aggregation_tree">
            <li><a>Traffic</a></li>
            <li><a>Active memory</a></li>
            <!-- <li><a>Latency</a></li> -->
            </ul>
          </div><!-- /btn-group -->
         <br/>
         <br/>
        <table class="table table-bordered table-striped">
          <tr>
            <th class="text-center span3">Processes Traffic Tree
            </th>
             <td class="span3">
              <div id="sequence_sunburst" >
                <div id="sequence_processTree" class="sequence"></div>
                <div id="chart_processTree" class="chart"></div>
                <div align="center" class="info">Mouse over to show the process information or double click to show more information.</div>
              </div>
            </td>
          </tr>

        </table>
      </div> <!-- Tab Tree-->
]]

print [[
    </div> <!-- End Tab content-->
  </div> <!-- End Left Tab -->


]]

 print [[

        <link href="/css/sequence_sunburst.css" rel="stylesheet">
        <script src="/js/sequence_sunburst.js"></script>

        <script type='text/javascript'>
        // Default value
        var sprobe_debug = false;
        var processes;
        var processes_type = "bytes";
        var processes_filter = "All";
        var users;
        var users_type = "bytes";
        var users_filter = "All";
        var tree;
        var tree_type = "bytes";
        var tree_filter = "All";


]]

-- Users graph javascript
print [[
      users = do_pie("#topUsers", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_sflow_distro.lua', { distr: users_type, sflowdistro_mode: "user", sflow_filter: users_filter , ifid: "]] print(ifId.."") print ('", '..hostinfo2json(host_info).." }, \"\", refresh); \n")

print [[

  $('#aggregation_users li > a').click(function(e){
    $('#aggregation_users_displayed').html(this.innerHTML+' <span class="caret"></span>');

    if(this.innerHTML == "Active memory") {
      users_type= "memory"
    } else if(this.innerHTML == "Latency") {
      users_type = "latency";
    } else  {
      users_type = "bytes";
    }
    if(sprobe_debug) { alert("]]
print (ntop.getHttpPrefix())
print [[/lua/host_sflow_distro.lua?host=..&distr="+users_type+"&sflowdistro_mode=user&sflow_filter="+users_filter); }
    users.setUrlParams({ type: users_type, mode: "user", sflow_filter: users_filter, ifid: "]] print(ifId.."") print ('",'.. hostinfo2json(host_info) .. "}") print [[ );
    }); ]]

print [[
$("#show_users input:radio").change(function() {
    users_filter = this.value
    if(sprobe_debug) { alert("users_type: "+users_type+"\n users_filter: "+users_filter); }
    if(sprobe_debug) { alert("url: ]]
print (ntop.getHttpPrefix())
print [[/lua/host_sflow_distro.lua?host=..&distr="+users_type+"&sflowdistro_mode=user&sflow_filter="+users_filter); }
    users.setUrlParams({ type: users_type, mode: "user", sflow_filter: users_filter, ifid: "]] print(ifId.."") print ('",'.. hostinfo2json(host_info) .. "}") print [[ );
});]]


-- Processes graph javascript

print [[
processes = do_pie("#topProcess", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_sflow_distro.lua', { distr: processes_type, sflowdistro_mode: "process", sflow_filter: processes_filter , ifid: "]] print(ifId.."")print ('", '..hostinfo2json(host_info).." }, \"\", refresh); \n")

print [[

  $('#aggregation_processes li > a').click(function(e){
    $('#aggregation_processes_displayed').html(this.innerHTML+' <span class="caret"></span>');

    if(this.innerHTML == "Active memory") {
      processes_type= "memory"
    } else if(this.innerHTML == "Latency") {
      processes_type = "latency";
    } else  {
      processes_type = "bytes";
    }
    if(sprobe_debug) { alert(this.innerHTML+"-"+processes_type); }
    processes.setUrlParams({ type: processes_type, sflowdistro_mode: "process", sflow_filter: processes_filter , ifid: "]] print(ifId.."") print ('",'.. hostinfo2json(host_info) .. "}") print [[ );
    }); ]]

print [[
$("#show_processes input:radio").change(function() {
    processes_filter = this.value
    if(sprobe_debug) { alert("processes_type: "+processes_type+"\n processes_filter: "+processes_filter); }
    processes.setUrlParams({ type: processes_type, sflowdistro_mode: "process", sflow_filter: processes_filter, ifid: "]] print(ifId.."") print ('",'.. hostinfo2json(host_info) .. "}") print [[ );
});]]


-- Processes Tree graph javascript
print [[
  tree = do_sequence_sunburst("chart_processTree","sequence_processTree",refresh,']]
print (ntop.getHttpPrefix())
print [[/lua/sflow_tree.lua',{distr: "bytes" , sflow_filter: tree_filter ]] print (','.. hostinfo2json(host_info)) print [[ },"","Bytes"); ]]

print [[

  $('#aggregation_tree li > a').click(function(e){
    $('#aggregation_tree_displayed').html(this.innerHTML+' <span class="caret"></span>');

    if(this.innerHTML == "Active memory") {
      tree_type= "memory"
    } else if(this.innerHTML == "Latency") {
      tree_type = "latency";
    } else  {
      tree_type = "bytes";
    }
    if(sprobe_debug) { alert(this.innerHTML+"-"+tree_type); }
    tree[0].setUrlParams({type: tree_type , sflow_filter: tree_filter ]] print (','.. hostinfo2json(host_info).." }") print [[ );
    }); ]]

print [[

  $("#show_tree input:radio").change(function() {
    tree_filter = this.value
    if(sprobe_debug) { alert("tree_type: "+tree_type+"\ntree_filter: "+tree_filter); }
    tree[0].setUrlParams({type: tree_type , sflow_filter: tree_filter]] print (','.. hostinfo2json(host_info).." }") print [[ );
});]]

print [[ </script>]]

-- End Sprobe Page
end
end

if (host ~= nil) then
   print[[<script type="text/javascript" src="]] print(ntop.getHttpPrefix()) print [[/js/jquery.tablesorter.js"></script>]]

   print [[ 
   <script>

   $(document).ready(function() {
      $("#myTable").tablesorter();
   });

  ]]
   print("var last_pkts_sent = " .. host["packets.sent"] .. ";\n")
   print("var last_pkts_rcvd = " .. host["packets.rcvd"] .. ";\n")
   print("var last_num_alerts = " .. host["num_alerts"] .. ";\n")
   print("var last_active_flows_as_server = " .. host["active_flows.as_server"] .. ";\n")
   print("var last_active_flows_as_client = " .. host["active_flows.as_client"] .. ";\n")
   print("var last_flows_as_server = " .. host["flows.as_server"] .. ";\n")
   print("var last_flows_as_client = " .. host["flows.as_client"] .. ";\n")
   print("var last_low_goodput_flows_as_client = " .. host["low_goodput_flows.as_client"] .. ";\n")
   print("var last_low_goodput_flows_as_server = " .. host["low_goodput_flows.as_server"] .. ";\n")
   print("var last_tcp_retransmissions = " .. host["tcp.packets.retransmissions"] .. ";\n")
   print("var last_tcp_ooo = " .. host["tcp.packets.out_of_order"] .. ";\n")
   print("var last_tcp_lost = " .. host["tcp.packets.lost"] .. ";\n")

   if(host["dns"] ~= nil) then
      print("var last_dns_sent_num_queries = " .. host["dns"]["sent"]["num_queries"] .. ";\n")
      print("var last_dns_sent_num_replies_ok = " .. host["dns"]["sent"]["num_replies_ok"] .. ";\n")
      print("var last_dns_sent_num_replies_error = " .. host["dns"]["sent"]["num_replies_error"] .. ";\n")
      print("var last_dns_rcvd_num_queries = " .. host["dns"]["rcvd"]["num_queries"] .. ";\n")
      print("var last_dns_rcvd_num_replies_ok = " .. host["dns"]["rcvd"]["num_replies_ok"] .. ";\n")
      print("var last_dns_rcvd_num_replies_error = " .. host["dns"]["rcvd"]["num_replies_error"] .. ";\n")
   end

   if(http ~= nil) then
      print("var last_http_query_num_get = " .. http["sender"]["query"]["num_get"] .. ";\n")
      print("var last_http_query_num_post = " .. http["sender"]["query"]["num_post"] .. ";\n")
      print("var last_http_query_num_head = " .. http["sender"]["query"]["num_head"] .. ";\n")
      print("var last_http_query_num_put = " .. http["sender"]["query"]["num_put"] .. ";\n")
      print("var last_http_query_num_other = " .. http["sender"]["query"]["num_other"] .. ";\n")
      print("var last_http_response_num_1xx = " .. http["receiver"]["response"]["num_1xx"] .. ";\n")
      print("var last_http_response_num_2xx = " .. http["receiver"]["response"]["num_2xx"] .. ";\n")
      print("var last_http_response_num_3xx = " .. http["receiver"]["response"]["num_3xx"] .. ";\n")
      print("var last_http_response_num_4xx = " .. http["receiver"]["response"]["num_4xx"] .. ";\n")
      print("var last_http_response_num_5xx = " .. http["receiver"]["response"]["num_5xx"] .. ";\n")
   end

   print [[
   var host_details_interval = window.setInterval(function() {
   	  $.ajax({
   		    type: 'GET',
   		    url: ']]
   print (ntop.getHttpPrefix())
   print [[/lua/host_stats.lua',
   		    data: { ifid: "]] print(ifId.."")  print('", '..hostinfo2json(host_info)) print [[ },
   		    /* error: function(content) { alert("JSON Error: inactive host purged or ntopng terminated?"); }, */
   		    success: function(content) {
   			var host = jQuery.parseJSON(content);
                        var http = host.http;
   			$('#first_seen').html(epoch2Seen(host["seen.first"]));
   			$('#last_seen').html(epoch2Seen(host["seen.last"]));
   			$('#pkts_sent').html(formatPackets(host["packets.sent"]));
   			$('#pkts_rcvd').html(formatPackets(host["packets.rcvd"]));
   			$('#bytes_sent').html(bytesToVolume(host["bytes.sent"]));
   			$('#bytes_rcvd').html(bytesToVolume(host["bytes.rcvd"]));
   			$('#pkt_retransmissions').html(formatPackets(host["tcp.packets.retransmissions"]));
   			$('#pkt_ooo').html(formatPackets(host["tcp.packets.out_of_order"]));
   			$('#pkt_lost').html(formatPackets(host["tcp.packets.lost"]));
   			if(!host["name"]) {
   			   $('#name').html(host["ip"]);
   			} else {
   			   $('#name').html(host["name"]);
   			}
   			$('#num_alerts').html(host["num_alerts"]);
   			$('#active_flows_as_client').html(addCommas(host["active_flows.as_client"]));
   			$('#flows_as_client').html(addCommas(host["flows.as_client"]));
   			$('#low_goodput_as_client').html(addCommas(host["low_goodput_flows.as_client"]));
   			$('#active_flows_as_server').html(addCommas(host["active_flows.as_server"]));
   			$('#flows_as_server').html(addCommas(host["flows.as_server"]));
   			$('#low_goodput_as_server').html(addCommas(host["low_goodput_flows.as_server"]));
   		  ]]

   if(host["dns"] ~= nil) then
   print [[
   			   $('#dns_sent_num_queries').html(addCommas(host["dns"]["sent"]["num_queries"]));
   			   $('#dns_sent_num_replies_ok').html(addCommas(host["dns"]["sent"]["num_replies_ok"]));
   			   $('#dns_sent_num_replies_error').html(addCommas(host["dns"]["sent"]["num_replies_error"]));
   			   $('#dns_rcvd_num_queries').html(addCommas(host["dns"]["rcvd"]["num_queries"]));
   			   $('#dns_rcvd_num_replies_ok').html(addCommas(host["dns"]["rcvd"]["num_replies_ok"]));
   			   $('#dns_rcvd_num_replies_error').html(addCommas(host["dns"]["rcvd"]["num_replies_error"]));

   			   if(host["dns"]["sent"]["num_queries"] == last_dns_sent_num_queries) {
   			      $('#trend_sent_num_queries').html("<i class=\"fa fa-minus\"></i>");
   			   } else {
   			      last_dns_sent_num_queries = host["dns"]["sent"]["num_queries"];
   			      $('#trend_sent_num_queries').html("<i class=\"fa fa-arrow-up\"></i>");
   			   }

   			   if(host["dns"]["sent"]["num_replies_ok"] == last_dns_sent_num_replies_ok) {
   			      $('#trend_sent_num_replies_ok').html("<i class=\"fa fa-minus\"></i>");
   			   } else {
   			      last_dns_sent_num_replies_ok = host["dns"]["sent"]["num_replies_ok"];
   			      $('#trend_sent_num_replies_ok').html("<i class=\"fa fa-arrow-up\"></i>");
   			   }

   			   if(host["dns"]["sent"]["num_replies_error"] == last_dns_sent_num_replies_error) {
   			      $('#trend_sent_num_replies_error').html("<i class=\"fa fa-minus\"></i>");
   			   } else {
   			      last_dns_sent_num_replies_error = host["dns"]["sent"]["num_replies_error"];
   			      $('#trend_sent_num_replies_error').html("<i class=\"fa fa-arrow-up\"></i>");
   			   }

   			   if(host["dns"]["rcvd"]["num_queries"] == last_dns_rcvd_num_queries) {
   			      $('#trend_rcvd_num_queries').html("<i class=\"fa fa-minus\"></i>");
   			   } else {
   			      last_dns_rcvd_num_queries = host["dns"]["rcvd"]["num_queries"];
   			      $('#trend_rcvd_num_queries').html("<i class=\"fa fa-arrow-up\"></i>");
   			   }

   			   if(host["dns"]["rcvd"]["num_replies_ok"] == last_dns_rcvd_num_replies_ok) {
   			      $('#trend_rcvd_num_replies_ok').html("<i class=\"fa fa-minus\"></i>");
   			   } else {
   			      last_dns_rcvd_num_replies_ok = host["dns"]["rcvd"]["num_replies_ok"];
   			      $('#trend_rcvd_num_replies_ok').html("<i class=\"fa fa-arrow-up\"></i>");
   			   }

   			   if(host["dns"]["rcvd"]["num_replies_error"] == last_dns_rcvd_num_replies_error) {
   			      $('#trend_rcvd_num_replies_error').html("<i class=\"fa fa-minus\"></i>");
   			   } else {
   			      last_dns_rcvd_num_replies_error = host["dns"]["rcvd"]["num_replies_error"];
   			      $('#trend_rcvd_num_replies_error').html("<i class=\"fa fa-arrow-up\"></i>");
   			   }
   		     ]]
   end

   if((host ~= nil) and (http ~= nil)) then
      vh = http["virtual_hosts"]
      if(vh ~= nil) then
         num = table.len(vh)
         if(num > 0) then
   	 print [[
   	       var last_http_val = {};
   	       if((host !== undefined) && (http !== undefined)) {
   		  $.each(http["virtual_hosts"], function(idx, obj) {
   		      var key = idx.replace(/\./g,'___');
   		      $('#'+key+'_bytes_vhost_rcvd').html(bytesToVolume(obj["bytes.rcvd"])+" "+get_trend(obj["bytes.rcvd"], last_http_val[key+"_rcvd"]));
   		      $('#'+key+'_bytes_vhost_sent').html(bytesToVolume(obj["bytes.sent"])+" "+get_trend(obj["bytes.sent"], last_http_val[key+"_sent"]));
   		      $('#'+key+'_num_vhost_req_serv').html(addCommas(obj["http.requests"])+" "+get_trend(obj["http.requests"], last_http_val[key+"_req_serv"]));
   		      last_http_val[key+"_rcvd"] = obj["bytes.rcvd"];
   		      last_http_val[key+"_sent"] = obj["bytes.sent"];
   		      last_http_val[key+"_req_serv"] = obj["bytes.http_requests"];
   		   });
   	      }
   	 ]]
         end

      methods = { "get", "post", "head", "put", "other" }
      for i, method in ipairs(methods) do
         print('\t$("#http_query_num_'..method..'").html(addCommas(http["sender"]["query"]["num_'..method..'"]));\n')
         print('\tif(http["sender"]["query"]["num_'..method..'"] == last_http_query_num_'..method..') {\n\t$("#trend_http_query_num_'..method..'").html(\'<i class=\"fa fa-minus\"></i>\');\n')
         print('} else {\n\tlast_http_query_num_'..method..' = http["sender"]["query"]["num_'..method..'"];$("#trend_http_query_num_'..method..'").html(\'<i class=\"fa fa-arrow-up\"></i>\'); }\n')
      end

      retcodes = { "1xx", "2xx", "3xx", "4xx", "5xx" }
      for i, retcode in ipairs(retcodes) do
         print('\t$("#http_response_num_'..retcode..'").html(addCommas(http["receiver"]["response"]["num_'..retcode..'"]));\n')
         print('\tif(http["receiver"]["response"]["num_'..retcode..'"] == last_http_response_num_'..retcode..') {\n\t$("#trend_http_response_num_'..retcode..'").html(\'<i class=\"fa fa-minus\"></i>\');\n')
         print('} else {\n\tlast_http_response_num_'..retcode..' = http["receiver"]["response"]["num_'..retcode..'"];$("#trend_http_response_num_'..retcode..'").html(\'<i class=\"fa fa-arrow-up\"></i>\'); }\n')
      end
   end
   end

   print [[
   			/* **************************************** */

			$('#trend_as_active_client').html(drawTrend(host["active_flows.as_client"], last_active_flows_as_client, ""));
			$('#trend_as_client').html(drawTrend(host["flows.as_client"], last_flows_as_client, ""));
			$('#low_goodput_trend_as_client').html(drawTrend(host["low_goodput_flows.as_client"], last_low_goodput_flows_as_client, " style=\"color: #B94A48;\""));
			$('#trend_as_active_server').html(drawTrend(host["active_flows.as_server"], last_active_flows_as_server, ""));
			$('#trend_as_server').html(drawTrend(host["flows.as_server"], last_flows_as_server, ""));
			$('#low_goodput_trend_as_server').html(drawTrend(host["low_goodput_flows.as_server"], last_low_goodput_flows_as_server, " style=\"color: #B94A48;\""));
			
			$('#alerts_trend').html(drawTrend(host["num_alerts"], last_num_alerts, " style=\"color: #B94A48;\""));
			$('#sent_trend').html(drawTrend(host["packets.sent"], last_pkts_sent, ""));
			$('#rcvd_trend').html(drawTrend(host["packets.rcvd"], last_pkts_rcvd, ""));
			$('#pkt_retransmissions_trend').html(drawTrend(host["tcp.packets.retransmissions"], last_tcp_retransmissions, ""));
			$('#pkt_ooo_trend').html(drawTrend(host["tcp.packets.out_of_order"], last_tcp_ooo, ""));
 		        $('#pkt_lost_trend').html(drawTrend(host["tcp.packets.lost"], last_tcp_lost, ""));

   			last_num_alerts = host["num_alerts"];
   			last_pkts_sent = host["packets.sent"];
   			last_pkts_rcvd = host["packets.rcvd"];
   			last_active_flows_as_client = host["active_flows.as_client"];
   			last_active_flows_as_server = host["active_flows.as_server"];
   			last_flows_as_client = host["flows.as_client"];
   			last_low_goodput_flows_as_server = host["low_goodput_flows.as_server"];
   			last_low_goodput_flows_as_client = host["low_goodput_flows.as_client"];
   			last_flows_as_server = host["flows.as_server"];
   			last_tcp_retransmissions = host["tcp.packets.retransmissions"];
   			last_tcp_ooo = host["tcp.packets.out_of_order"];
   			last_tcp_lost = host["tcp.packets.lost"];
   		  ]]


   print [[

   			/* **************************************** */

   			/*
   			$('#throughput').html(rsp.throughput);

   			var values = thptChart.text().split(",");
   			values.shift();
   			values.push(rsp.throughput_raw);
   			thptChart.text(values.join(",")).change();
   			*/
   		     }
   	           });
   		 }, 3000);

   </script>
    ]]
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
