--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local shaper_utils

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   require "snmp_utils"
   shaper_utils = require("shaper_utils")
end

require "lua_utils"
require "graph_utils"
require "alert_utils"
require "historical_utils"

debug_hosts = false
page        = _GET["page"]
protocol_id = _GET["protocol"]
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

if((host_name == nil) or (host_ip == nil)) then
   sendHTTPHeader('text/html; charset=iso-8859-1')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Host parameter is missing (internal error ?)</div>")
   return
end

if(_GET["flow_rate_alert_threshold"] ~= nil and _GET["csrf"] ~= nil) then
   if (tonumber(_GET["flow_rate_alert_threshold"]) ~= nil) then
     page = "config"
     val = ternary(_GET["flow_rate_alert_threshold"] ~= "0", _GET["flow_rate_alert_threshold"], "25")
     ntop.setCache('ntopng.prefs.'..host_name..':'..tostring(host_vlan)..'.flow_rate_alert_threshold', val)
     interface.loadHostAlertPrefs(host_ip, host_vlan)
   end
end
if(_GET["syn_alert_threshold"] ~= nil and _GET["csrf"] ~= nil) then
   if (tonumber(_GET["syn_alert_threshold"]) ~= nil) then
     page = "config"
     val = ternary(_GET["syn_alert_threshold"] ~= "0", _GET["syn_alert_threshold"], "10")
     ntop.setCache('ntopng.prefs.'..host_name..':'..tostring(host_vlan)..'.syn_alert_threshold', val)
     interface.loadHostAlertPrefs(host_ip, host_vlan)
   end
end
if(_GET["flows_alert_threshold"] ~= nil and _GET["csrf"] ~= nil) then
   if (tonumber(_GET["flows_alert_threshold"]) ~= nil) then
     page = "config"
     val = ternary(_GET["flows_alert_threshold"] ~= "0", _GET["flows_alert_threshold"], "32768")
     ntop.setCache('ntopng.prefs.'..host_name..':'..tostring(host_vlan)..'.flows_alert_threshold', val)
     interface.loadHostAlertPrefs(host_ip, host_vlan)
   end
end
if _GET["re_arm_minutes"] ~= nil then
     page = "config"
     ntop.setHashCache(get_re_arm_alerts_hash_name(), get_re_arm_alerts_hash_key(ifId, hostkey), _GET["re_arm_minutes"])
end

if(protocol_id == nil) then protocol_id = "" end



-- print(">>>") print(host_info["host"]) print("<<<")
if(debug_hosts) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Host:" .. host_info["host"] .. ", Vlan: "..host_vlan.."\n") end

host = interface.getHostInfo(host_info["host"], host_vlan)
restoreFailed = false

if((host == nil) and ((_GET["mode"] == "restore") or (page == "historical"))) then
   if(debug_hosts) then traceError(TRACE_DEBUG,TRACE_CONSOLE, "Restored Host Info\n") end
   interface.restoreHost(host_info["host"], host_vlan)
   host = interface.getHostInfo(host_info["host"], host_vlan)
   restoreFailed = true
end

only_historical = false

if(host == nil) then
   if (rrd_exists(host_ip, "bytes.rrd") and always_show_hist == "true") then
      page = "historical"
      only_historical = true
      sendHTTPHeader('text/html; charset=iso-8859-1')
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
      sendHTTPHeader('text/html; charset=iso-8859-1')
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
	    print(' Click <A HREF="?ifname='..ifId..'&'..hostinfo2url(host_info) ..'&mode=restore">here</A> to restore it from cache.\n')
	 else
	    print(purgedErrorString())
	 end

	 print("</div>")
	 dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
      end
      return
   end
else
   sendHTTPHeader('text/html; charset=iso-8859-1')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

   --   Added global javascript variable, in order to disable the refresh of pie chart in case
   --  of historical interface
   print('\n<script>var refresh = 3000 /* ms */;</script>\n')

   if(host["ip"] ~= nil) then
      host_name = hostinfo2hostkey(host)
      host_info["host"] = host["ip"]
   end

   if(_GET["custom_name"] ~=nil) then
   	setHostAltName(hostinfo2hostkey(host_info), _GET["custom_name"])
   end

   host["label"] = getHostAltName(hostinfo2hostkey(host_info))

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
url=ntop.getHttpPrefix().."/lua/host_details.lua?ifname="..ifId.."&"..hostinfo2url(host_info)

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

if(page == "ndpi") then
  direction = _GET["direction"]
  print("<li class=\"active\"><a href=\"#\">Protocols</a></li>\n")
else
   if(host["ip"] ~= nil) then
      print("<li><a href=\""..url.."&page=ndpi\">Protocols</a></li>")
   end
end

if(prefs.is_flow_activity_enabled) then
  if(page == "activities") then
    print("<li class=\"active\"><a href=\"#\">Activities</a></li>\n")
  else
    if interface.isPcapDumpInterface() == false and host["ip"] ~= nil then
      print("<li><a href=\""..url.."&page=activities\">Activities</a></li>")
    end
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

if(ntop.isPro() and host['localhost']) then
   if(page == "snmp") then
      print("<li class=\"active\"><a href=\"#\">SNMP</a></li>\n")
   elseif interface.isPcapDumpInterface() == false then
      print("<li><a href=\""..url.."&page=snmp\">SNMP</a></li>")
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
-- NOTE: code temporarely disabled
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

if (host["ip"] ~= nil and host['localhost']) then
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
         print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-file-text fa-lg'></i></a></li>\n")
      else
         print("\n<li><a href=\""..url.."&page=traffic_report\"><i class='fa fa-file-text fa-lg'></i></a></li>")
      end
   else
      print("\n<li><a href=\"#\" title=\""..i18n('enterpriseOnly').."\"><i class='fa fa-file-text fa-lg'></i></A></li>\n")
   end
end

if ((host["ip"] ~= nil) and host['localhost']) then
   if(host["ip"] ~= nil) then
      if(page == "config") then
	 print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-cog fa-lg\"></i></a></li>\n")
      elseif interface.isPcapDumpInterface() == false then
	 print("\n<li><a href=\""..url.."&page=config\"><i class=\"fa fa-cog fa-lg\"></i></a></li>")
      end
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
	    print("<tr><th width=35%>(Router/AccessPoint) MAC Address</th><td>" ..get_symbolic_mac(host["mac"]).. " "..getHostIcon(host["mac"]).."</td><td>")
	 else
	    if(host["localhost"] == true and is_packetdump_enabled) then
	       print("<tr><th width=35%>Traffic Dump</th><td colspan=2>")
	    end
       end

      if(host["localhost"] == true and is_packetdump_enabled) then
	 dump_status = host["dump_host_traffic"]

	 if(_GET["dump_traffic"] ~= nil) then
	    if(_GET["dump_traffic"] == "true") then
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

	 if(isAdministrator()) then
	 print [[
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">]]

	 print[[<input type="hidden" name="host" value="]] print(host_info["host"]) print[[">]]
	 print[[<input type="hidden" name="vlan" value="]] print(tostring(host_info["vlan"])) print[[">]]

	 print('<input type="hidden" name="dump_traffic" value="'..dump_traffic_value..'"><input type="checkbox" value="1" '..dump_traffic_checked..' onclick="this.form.submit();"> <i class="fa fa-hdd-o fa-lg"></i> <a href="'..ntop.getHttpPrefix()..'/lua/if_stats.lua?if_name='..ifname..'&page=packetdump&'..hostinfo2url(host_info)..'">Dump Traffic</a> </input>')
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	 print('</form>')
	 end
	 print('</td></tr>')
      end

      if((host["mac"] ~= "") and (info["version.enterprise_edition"])) then
	 local ports = find_mac_snmp_ports(host["mac"])

	 if(ports ~= nil) then
	    local rsps = 1

	    for host,port in pairs(ports) do
	       rsps = rsps + 1
	    end
	    
	    if(rsps > 1) then
	    	    print("<tr><th width=35% rowspan="..rsps..">Host SNMP Location</th><th>SNMP Device</th><th>Device Port</th></tr>\n")
	    	    for host,port in pairs(ports) do
		    	       print("<tr><td align=right><A HREF=" .. ntop.getHttpPrefix() .. "/lua/host_details.lua?host="..host..">"..ntop.getResolvedAddress(host).."</A></td>")
			       	       print("<td align=right><A HREF=" .. ntop.getHttpPrefix() .. "/lua/pro/enterprise/snmp_device_info.lua?ip="..host .. "&ifIdx="..port..">"..port.."</td></tr>\n")
		    end
	    end
	 end
      end

   
      if host.deviceIfIdx ~= nil and host.deviceIfIdx ~= 0 and ntop.isPro() then
	 print("<tr><th>Device IP / Port Index</th><td colspan=2><A HREF="..ntop.getHttpPrefix().."/lua/pro/flow_device_info.lua?ip="..host.deviceIP.."&ifIndex=".. host.deviceIfIdx..">".. host.deviceIP .."</A>@"..host.deviceIfIdx.."</td></tr>\n")
      end

      print("<tr><th>IP Address</th><td colspan=1>" .. host["ip"])
      
      historicalProtoHostHref(getInterfaceId(ifname), host["ip"], nil, nil, nil)
      
      if(host["local_network_name"] ~= nil) then
	 print(" [ <A HREF="..ntop.getHttpPrefix().."/lua/flows_stats.lua?network_id="..host["local_network_id"].."&network_name="..escapeHTML(host["local_network_name"])..">".. host["local_network_name"].."</A> ]")
      end
   else
      if(host["mac"] ~= nil) then
	 print("<tr><th>MAC Address</th><td colspan=2>" .. host["mac"].. "</td></tr>\n")
      end
   end
   
   if((host["city"] ~= nil) and (host["city"] ~= "")) then
      print(" [ " .. host["city"] .." "..getFlag(host["country"]).." ]")
   end

   drop_host_traffic = _GET["drop_host_traffic"]
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

   if(host["ip"] ~= nil) then
      print [[
</td>

<td nowrap>
<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
	 <input type="hidden" name="host" value="]]

      print(host_info["host"])
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print('</form>')
      print('</td></tr>')
   end

   if(ifstats.vlan and (host["vlan"] ~= nil)) then
      print("<tr><th>")

      if(ifstats.sprobe) then
	 print('Source Id')
      else
	 print('VLAN ID')
      end

      print("</th><td colspan=2>"..host["vlan"].."</td></tr>\n")
   end

   if(ifstats.inline and (host.localhost or host.systemhost)) then
      print("<tr><th>Host Traffic Policy</th><td>")
      print('<div class="dropdown">')

      if(host["l7_traffic_policy"] ~= nil) then
print [[
      <button class="btn btn-default btn-xs dropdown-toggle" type="button" id="dropdownMenu2" data-toggle="dropdown" aria-expanded="true">
        Blacklisted Protocols
        <span class="caret"></span>
      </button>
      <ul class="dropdown-menu" role="menu">
]]

	 for k,v in pairs(host["l7_traffic_policy"]) do
	    print('<li role="presentation"><a role="menuitem" tabindex="-1">'..k.."</a></li>\n")
	 end

	 print("</ul>")
      end

      print('<A class="btn btn-default btn-xs" HREF="'..ntop.getHttpPrefix()..'/lua/if_stats.lua?page=filtering&view_network='..host["ip"])
      if(host["ip"]:match(":")) then print("/128") else print("/32") end
      print("@")
      if(host["vlan"] ~= nil) then print(""..host["vlan"]) else print("0") end
      print('">Modify Host Traffic Policy</A></div>')

      if(host["bridge.ingress_shaper_id"] ~= nil) then
	 ingress_max_rate = shaper_utils.getShaperMaxRate(ifId, host["bridge.ingress_shaper_id"])
	 egress_max_rate = shaper_utils.getShaperMaxRate(ifId, host["bridge.egress_shaper_id"])
	 print("<p><table class=\"table table-bordered table-striped\"width=100%>")
	 print("<tr><th>Ingress Policer</th><td>"..maxRateToString(ingress_max_rate).."</td></tr>")
	 print("<tr><th>Egress Policer</th><td>"..maxRateToString(egress_max_rate).."</td></tr>")
         print("</table>")
      end

      print('</td>')

      print('<td>')
      if(host["localhost"] == true) then
	 drop_traffic = ntop.getHashCache("ntopng.prefs.drop_host_traffic", host_key)
	 if(drop_traffic == "true") then
	    drop_traffic_checked = 'checked="checked"'
	    drop_traffic_value = "false" -- Opposite
	 else
	    drop_traffic_checked = ""
	    drop_traffic_value = "true" -- Opposite
	 end

	 print('<form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">')
	 print[[<input type="hidden" name="host" value="]] print(host_info["host"]) print[[">]]
	 print[[<input type="hidden" name="vlan" value="]] print(tostring(host_info["vlan"])) print[[">]]
	 print('<input type="hidden" name="drop_host_traffic" value="'..drop_traffic_value..'"><input type="checkbox" value="1" '..drop_traffic_checked..' onclick="this.form.submit();"> Drop All Host Traffic</input>')
	 print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
	 print('</form>')
      else
	 print('&nbsp;')
      end

      print('</td></tr></tr>')
   end

   if((ifstats.inline and (host.localhost or host.systemhost)) or (host["os"] ~= "")) then
   print("<tr>")
   if(host["os"] ~= "") then
     print("<th>OS</th><td> <A HREF="..ntop.getHttpPrefix().."/lua/hosts_stats.lua?os=" .. string.gsub(host["os"], " ", '%%20').. ">"..mapOS2Icon(host["os"]) .. "</A></td>\n")
   else
     print("<th></th><td></td>\n")
   end

   if(ifstats.inline and (host.localhost or host.systemhost) and isAdministrator()) then
	 if(_GET["host_quota"] ~= nil) then
	    interface.select(ifname) -- if we submitted a form, nothing is select()ed
	    interface.setHostQuota(tonumber(_GET["host_quota"]), host_info["host"], host_vlan)
	 end

         host_quota_value = host["host_quota_mb"]
         if(_GET["host_quota"] ~= nil) then host_quota_value = _GET["host_quota"] end
	 print [[<td><form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">]]

	 print[[<input type="hidden" name="host" value="]] print(host_info["host"]) print[[">]]
	 print[[<input type="hidden" name="vlan" value="]] print(tostring(host_info["vlan"])) print[[">]]

	 print('<input type="hidden" name="host_quota" value="'..host_quota_value..'">Host quota <input type="number" name="host_quota" placeholder="" min="0" step="100" max="100000" value="')print(tostring(host_quota_value))
         print [[" onclick="this.form.submit();"> MB</input>]]print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
         print('</form>')
	 print('</td></tr>')
   else
     print("<td></td></tr>")
   end
end

local labelKey = host_info["host"].."@"..host_info["vlan"]

if(_GET["custom_icon"] ~=nil) then
 setHostIcon(labelKey, _GET["custom_icon"])
end

   if((host["asn"] ~= nil) and (host["asn"] > 0)) then
      print("<tr><th>ASN</th><td>")

      print("<A HREF=" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=".. host.asn ..">"..host.asname.."</A> [ ASN <A HREF=" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=".. host.asn..">".. host.asn.."</A> ]</td>")
      print('<td><A HREF="http://itools.com/tool/arin-whois-domain-search?q='.. host["ip"] ..'&submit=Look+up">Whois Lookup</A> <i class="fa fa-external-link"></i></td>')
      print("</td></tr>\n")
   end

   if(host["ip"] ~= nil) then
      if(host["name"] == nil) then
	 host["name"] = ntop.getResolvedAddress(host["ip"])
      end
      print("<tr><th>Name</th>")

      if(isAdministrator()) then
	 print("<td><A HREF=\"http://" .. host["name"] .. "\"> <span id=name>")
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
      if(host["systemhost"] == true) then print(' <span class="label label-info">System IP<i class=\"fa fa-flag\"></i></span>') end
      if(host["is_blacklisted"] == true) then print(' <span class="label label-danger">Blacklisted Host</span>') end

      print(getHostIcon(labelKey))
      print("</td>\n")
   end


if(host["ip"] ~= nil) then
    if(isAdministrator()) then
       print("<td>")

       print [[<form class="form-inline" style="margin-bottom: 0px;">]]

       print[[<input type="hidden" name="host" value="]] print(host_info["host"]) print[[">]]
       print[[<input type="hidden" name="vlan" value="]] print(tostring(host_info["vlan"])) print[[">]]

       print[[<input type="text" name="custom_name" placeholder="Custom Name" value="]]
      if(host["label"] ~= nil) then print(host["label"]) end
print("\"></input>")

pickIcon(labelKey)

print [[
	 &nbsp;<button type="submit" class="btn btn-default">Save</button>]]
print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

print [[</form>
</td></tr>
   ]]
end
    else
--       print("<td colspan=2>"..host_info["host"].."</td></tr>")
    end


if(host["num_alerts"] > 0) then
   print("<tr><th><i class=\"fa fa-warning fa-lg\" style='color: #B94A48;'></i>  <A HREF="..ntop.getHttpPrefix().."/lua/host_details.lua?ifname="..ifId.."&"..hostinfo2url(host_info).."&page=alerts>Alerts</A></th><td colspan=2></li> <span id=num_alerts>"..host["num_alerts"] .. "</span> <span id=alerts_trend></span></td></tr>\n")
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

   if(host["json"] ~= nil) then print("<tr><th><A HREF=http://en.wikipedia.org/wiki/JSON>JSON</A></th><td colspan=2><i class=\"fa fa-download fa-lg\"></i> <A HREF="..ntop.getHttpPrefix().."/lua/host_get_json.lua?ifId="..ifId.."&"..hostinfo2url(host_info)..">Download<A></td></tr>\n") end



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
      hostinfo2json(host_info)
      print [[
      </table>

        <script type='text/javascript'>
	       window.onload=function() {

		   do_pie("#sizeSentDistro", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_pkt_distro.lua', { distr: "size", mode: "sent", ifname: "]] print(ifId.."") print ('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
	print [[
		   do_pie("#sizeRecvDistro", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_pkt_distro.lua', { distr: "size", mode: "recv", ifname: "]] print(ifId.."") print ('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
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
print [[/lua/iface_ports_list.lua', { mode: "client", ifname: "]] print(ifId.."") print ('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
	print [[
		   do_pie("#serverPortsDistro", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_ports_list.lua', { mode: "server", ifname: "]] print(ifId.."") print ('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
	print [[

		}

	    </script><p>
	]]

   elseif((page == "peers")) then
host_info = url2hostinfo(_GET)
flows     = interface.getFlowPeers(host_info["host"], host_info["vlan"])
found     = 0

for key, value in pairs(flows) do
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
      print("url: '"..ntop.getHttpPrefix().."/lua/host_top_peers_protocols.lua?ifname="..ifId.."&host="..host_info["host"])
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
print [[/lua/host_l4_stats.lua', { ifname: "]] print(ifId.."") print('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
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
	       print("<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifname="..ifId.."&"..hostinfo2url(host_info) .. "&page=historical&rrd_file=".. k ..".rrd\">".. label .."</A>")
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
print [[/lua/iface_ndpi_stats.lua', { ifname: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);

				   do_pie("#topApplicationBreeds", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_ndpi_stats.lua', { breed: "true", ifname: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);



				}

	    </script>


<p>
	]]

      print("</table>\n")

  local direction_filter = ""
  local base_url = ntop.getHttpPrefix().."/lua/host_details.lua?ifname="..ifId.."&"..hostinfo2url(host_info).."&page=ndpi";

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
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     ]]

     print("<thead><tr><th>Application Protocol</th><th>Sent</th><th>Received</th><th>Breakdown</th><th colspan=2>Total</th></tr></thead>\n")

  print ('<tbody id="host_details_ndpi_tbody">\n')
  print ("</tbody>")
  print("</table>\n")

  print [[
<script>
function update_ndpi_table() {
  $.ajax({
    type: 'GET',
    url: ']]
print (ntop.getHttpPrefix())
print [[/lua/host_details_ndpi.lua',
    data: { ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info))
    if direction ~= nil then print(", filter:\"") print(direction..'"') end
    print [[ },
    //data: { ifid: ]] print('"') print(tostring(ifId)) print('"') print(", hostip: ") print('"'..host["ip"]..'"') print [[ },
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
     print(ntop.getHttpPrefix().."/lua/get_host_activitymap.lua?ifname="..ifId.."&"..hostinfo2url(host_info)..'",\n')

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
									     print("\""..ntop.getHttpPrefix().."/lua/get_host_activitymap.lua?ifname="..ifId.."&"..hostinfo2url(host_info)..'\");\n')
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

      <div id="userctivityContainer"></div>

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
  print('Please enable <A HREF="/lua/admin/prefs.lua?subpage_active=on_disk_rrds">Activities Timeseries</A> preferences to save historical host activities.<p>')
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

         function formatBytes(bytes, precision) {
            var sizes = [1, 1024, 1024*1024, 1024*1024*1024, 1024*1024*1024*1024];
            var labels = [" B", " KB", " MB", " GB", " TB"];
            var value = Math.abs(bytes);
            var i=0;

            if (value >= 1) {
               for(; i<sizes.length && value >= sizes[i]; i++) ;
               i--;

               value = bytes / sizes[i];
            }
            return value.toFixed(precision) + labels[i];
         }

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
	       $('#userctivity').remove();

	       if (context) {
		  context.stop();
		  delete rrdserver;
		  delete horizon;
		  delete context;
	       }

	       var div = $('<div id="userctivity"></div>')
		  .css("margin", "2em 0 1em 0")
		  .css("position", "relative")
		  .css("width", HorizonGraphWidth);
	       $('#userctivityContainer').append(div);

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
	       $('#userctivity').empty();
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
                  JSON.parse(content).sort().map(function(activity) {
                     metrics.push(rrdserver.metric(activitiesurl+"&activity="+activity, activity, mode === "bg"));
                  });
		  if (metrics.length > 0) {
		     // data
		     d3.select("#userctivity")
			.selectAll(".horizon")
			.data(metrics)
			.enter().append("div", ".bottom")
			.attr("class", "horizon")
			.call(horizon.format(function(x) { return formatBytes(x,2); }));

		     // bottom axis
		     d3.select("#userctivity")
			.append("div")
			.attr("class", "axis")
			.call(context.axis().orient("bottom"));

		     // vertical line on mousemove
		     d3.select("#userctivity")
			.append("div")
			.attr("class", "rule")
			.call(context.rule());

		     context.start();
		  } else {
		     $('#userctivity').text("No data so far");
		  }
               }
            });
         }
	 
         setShowMode("updown", 300);
      </script>
      <p>
      <b>NOTE:</b><br>The above map filters host application traffic by splitting it in real user reaffic (e.g. web page access)
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
print [[/lua/host_dns_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, mode: "sent" }, "", refresh);
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
print [[/lua/host_dns_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, mode: "rcvd" }, "", refresh);
         </script>
         </td></tr>
]]
end

	print('<tr><th>Request vs Reply</th><td colspan=5>')
	breakdownBar(host["dns"]["sent"]["num_queries"], "Queries", host["dns"]["rcvd"]["num_replies_ok"]+host["dns"]["rcvd"]["num_replies_error"], "Replies", 30, 70)
	print('</td></tr>\n')
        print("</table>\n")
      end
   elseif(page == "http") then
      if(http ~= nil) then
	 print("<table class=\"table table-bordered table-striped\">\n")

	 if(host["sites"] ~= nil) then
	    old_top_len = table.len(host["sites.old"])  if(old_top_len > 10) then old_top_len = 10 end
	    top_len = table.len(host["sites"])          if(top_len > 10) then top_len = 10 end
	    if(old_top_len > top_len) then num = old_top_len else num = top_len end

	    print("<tr><th rowspan="..(1+num)..">Top Visited Sites</th><th>Current Sites</th><th>Contacts</th><th>Last 5 Minute Sites</th><th>Contacts</th></tr>\n")
	    sites = {} 
	    for k,v in pairsByValues(host["sites"], rev) do
	       table.insert(sites, { k, v })
	    end

	    sites_old = {} 
	    for k,v in pairsByValues(host["sites.old"], rev) do
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

	 print("<tr><th rowspan=6 width=20%><A HREF=http://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#Request_methods>HTTP Queries</A></th><th width=20%>Method</th><th width=20%>Requests</th><th colspan=2>Distribution</th></tr>")
	 print("<tr><th>GET</th><td style=\"text-align: right;\"><span id=http_query_num_get>".. formatValue(http["sender"]["query"]["num_get"]) .."</span> <span id=trend_http_query_num_get></span></td><td colspan=2 rowspan=5>")

print [[
         <div class="pie-chart" id="httpQueries"></div>
         <script type='text/javascript'>

	     do_pie("#httpQueries", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_http_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, mode: "queries" }, "", refresh);
         </script>
]]

	 print("</td></tr>")
	 print("<tr><th>POST</th><td style=\"text-align: right;\"><span id=http_query_num_post>".. formatValue(http["sender"]["query"]["num_post"]) .."</span> <span id=trend_http_query_num_post></span></td></tr>")
	 print("<tr><th>HEAD</th><td style=\"text-align: right;\"><span id=http_query_num_head>".. formatValue(http["sender"]["query"]["num_head"]) .."</span> <span id=trend_http_query_num_head></span></td></tr>")
	 print("<tr><th>PUT</th><td style=\"text-align: right;\"><span id=http_query_num_put>".. formatValue(http["sender"]["query"]["num_put"]) .."</span> <span id=trend_http_query_num_put></span></td></tr>")
	 print("<tr><th>Other Method</th><td style=\"text-align: right;\"><span id=http_query_num_other>".. formatValue(http["sender"]["query"]["num_other"]) .."</span> <span id=trend_http_query_num_other></span></td></tr>")
	 print("<tr><th colspan=4>&nbsp;</th></tr>")
	 print("<tr><th rowspan=6 width=20%><A HREF=http://en.wikipedia.org/wiki/List_of_HTTP_status_codes>HTTP Responses</A></th><th width=20%>Response code</th><th width=20%>Responses</th><th colspan=2>Distribution</th></tr>")
	 print("<tr><th>1xx (Informational)</th><td style=\"text-align: right;\"><span id=http_response_num_1xx>".. formatValue(http["receiver"]["response"]["num_1xx"]) .."</span> <span id=trend_http_response_num_1xx></span></td><td colspan=2 rowspan=5>")

print [[
         <div class="pie-chart" id="httpResponses"></div>
         <script type='text/javascript'>

	     do_pie("#httpResponses", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_http_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, mode: "responses" }, "", refresh);
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
		  print("<tr><td><A HREF=http://"..k..">"..k.."</A> <i class='fa fa-external-link'></i>")
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
print [[/lua/get_flows_data.lua?ifname=]]
print(ifId.."&")
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

if(show_sprobe) then
print [[
  //console.log(url_update);
   flow_rows_option["sprobe"] = true;
   flow_rows_option["type"] = 'host';
   $("#table-flows").datatable({
      url: url_update ,
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
			     title: "Info",
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
print [[/lua/host_category_stats.lua', { ifname: "]] print(ifId.."") print('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
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
elseif(page == "snmp") then
if(ntop.isPro()) then
   print_snmp_report(host_ip, true, ifId)
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
  var zoomIP = "]] print('ifname='..ifId.."&"..hostinfo2url(host_info)) print [[ ";
  var url_prefix = "]] print(ntop.getHttpPrefix()) print [[";
</script>
    <script type="text/javascript" src="]] print(ntop.getHttpPrefix()) print [[/js/googleMapJson.js" ></script>
]]

elseif(page == "jaccard") then
-- NOTE: code temporarely disabled

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

if(host["name"] == nil) then host["name"] = ntop.getResolvedAddress(host["ip"]) end

for v,k in pairsByKeys(vals, rev) do

   if(v > 0) then
      if(n == 0) then
	 print("<table class=\"table table-bordered table-striped\">\n")
	 print("<tr><th>Local Hosts Similar to ".. hostinfo2hostkey(host) .."</th><th>Jaccard Coefficient</th><th>Activity Map</th>\n")
      end

      correlated_host = interface.getHostInfo(k)
      if(correlated_host ~= nil) then

	 if(correlated_host["name"] == nil) then correlated_host["name"] = ntop.getResolvedAddress(correlated_host["ip"]) end

         -- print the host row together with the Jaccard coefficient
	 print("<tr>")
   -- print("<th align=left><A HREF="..ntop.getHttpPrefix().."/lua/host_details.lua?host="..k..">"..correlated_host["name"].."</a></th>")
	 print("<th align=left><A HREF="..ntop.getHttpPrefix().."/lua/host_details.lua?ifname="..ifId.."&"..hostinfo2url(correlated_host)..">"..hostinfo2hostkey(correlated_host).."</a></th>")
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
  print(ntop.getHttpPrefix().."/lua/get_host_activitymap.lua?ifname="..ifId.."&"..hostinfo2url(correlated_host)..'",\n')
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
					    print("\""..ntop.getHttpPrefix().."/lua/get_host_activitymap.lua?ifname="..ifId.."&"..hostinfo2url(correlated_host)..'\");\n')
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
	 <li>Jaccard Similarity considers only activity map as shown in the <A HREF=]]
print (ntop.getHttpPrefix())
print [[/lua/host_details.lua?ifname="]] print(ifId.."&"..hostinfo2url(host_info)) print [[>host overview</A>.
<li>Two hosts are similar according to the Jaccard coefficient when their activity tends to overlap. In particular when their activity map is very similar. The <A HREF=http://en.wikipedia.org/wiki/Jaccard_index>Jaccard similarity coefficient</A> is a number between +1 and 0.
</ul>
]]
end

elseif(page == "contacts") then

if(num > 0) then
   mode = "embed"
   if(host["name"] == nil) then host["name"] = ntop.getResolvedAddress(host["ip"]) end
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
      if(info["name"] ~= nil) then n = info["name"] else n = ntop.getResolvedAddress(info["ip"]) end
      url = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifname="..ifId.."&"..hostinfo2url(info).."\">"..n.."</A>"
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
	    if(info["name"] ~= nil) then n = info["name"] else n = ntop.getResolvedAddress(info["ip"]) end
	    url = "<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifname="..ifId.."&"..hostinfo2url(info).."\">"..n.."</A>"
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
      i18n("show_alerts.host_delete_config_btn"), i18n("show_alerts.host_delete_config_confirm"),
      "host_details.lua", {ifname=ifId, host=host_ip},
      host_name, "host")

elseif (page == "config") then
   local re_arm_minutes = ""
   
   if(isAdministrator()) then
      trigger_alerts = _GET["trigger_alerts"]
      if(trigger_alerts ~= nil) then
         if(trigger_alerts == "true") then
	    ntop.delHashCache(get_alerts_suppressed_hash_name(ifname), hostkey)
	    interface.enableHostAlerts(host_ip, host_vlan)
         else
	    ntop.setHashCache(get_alerts_suppressed_hash_name(ifname), hostkey, trigger_alerts)
	    interface.disableHostAlerts(host_ip, host_vlan)
         end
      end
   end

   local flow_rate_alert_thresh = 'ntopng.prefs.'..host_ip..':'..tostring(host_vlan)..'.flow_rate_alert_threshold'
   local syn_alert_thresh = 'ntopng.prefs.'..host_ip..':'..tostring(host_vlan)..'.syn_alert_threshold'
   local flows_alert_thresh = 'ntopng.prefs.'..host_ip..':'..tostring(host_vlan)..'.flows_alert_threshold'
   
   if _GET["flow_rate_alert_threshold"] ~= nil and _GET["flow_rate_alert_threshold"] ~= "" then
      ntop.setPref(flow_rate_alert_thresh, _GET["flow_rate_alert_threshold"])
      flow_rate_alert_thresh = _GET["flow_rate_alert_threshold"]
   else
      local v = ntop.getPref(flow_rate_alert_thresh)
      if v ~= nil and v ~= "" then
	 flow_rate_alert_thresh = v
      else
	 flow_rate_alert_thresh = 25
      end
   end

   if _GET["syn_alert_threshold"] ~= nil and _GET["syn_alert_threshold"] ~= "" then
      ntop.setPref(syn_alert_thresh, _GET["syn_alert_threshold"])
      syn_alert_thresh = _GET["syn_alert_threshold"]
   else
      local v = ntop.getPref(syn_alert_thresh)
      if v ~= nil and v ~= "" then
	 syn_alert_thresh = v
      else
	 syn_alert_thresh = 10
      end
   end
   if _GET["flows_alert_threshold"] ~= nil and _GET["flows_alert_threshold"] ~= "" then
      ntop.setPref(flows_alert_thresh, _GET["flows_alert_threshold"])
      flows_alert_thresh = _GET["flows_alert_threshold"]
   else
      local v = ntop.getPref(flows_alert_thresh)
      if v ~= nil and v ~= "" then
	 flows_alert_thresh = v
      else
	 flows_alert_thresh = 32768
      end
   end

   re_arm_minutes = ntop.getHashCache(get_re_arm_alerts_hash_name(), get_re_arm_alerts_hash_key(ifId, hostkey))
   if re_arm_minutes == "" then re_arm_minutes=default_re_arm_minutes end

   print("<table class=\"table table-striped table-bordered\">\n")
   print("<tr><th width=250>Host Flow Alert Threshold</th>\n")
   print [[<td>]]
   print[[<form class="form-inline" style="margin-bottom: 0px;">]]

   print[[<input type="hidden" name="host" value="]] print(host_info["host"]) print[[">]]
   print[[<input type="hidden" name="vlan" value="]] print(tostring(host_info["vlan"])) print[[">]]

   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
   print('<input type="number" name="flow_rate_alert_threshold" placeholder="" min="0" step="1" max="100000" value="')
   print(tostring(flow_rate_alert_thresh))
   print [["></input>
	&nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
<small>
    Max number of new flows/sec over which a host is considered a flooder. Default: 25.<br>
</small>]]
  print[[
    </td></tr>
       ]]

       print("<tr><th width=250>Host SYN Alert Threshold</th>\n")
      print [[<td>]]
      print[[<form class="form-inline" style="margin-bottom: 0px;">]]

      print[[<input type="hidden" name="host" value="]] print(host_info["host"]) print[[">]]
      print[[<input type="hidden" name="vlan" value="]] print(tostring(host_info["vlan"])) print[[">]]

      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="syn_alert_threshold" placeholder="" min="0" step="5" max="100000" value="]]
         print(tostring(syn_alert_thresh))
         print [["></input>
      &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
<small>
    Max number of sent TCP SYN packets/sec over which a host is considered a flooder. Default: 10.<br>
</small>]]
  print[[
    </td></tr>
       ]]

       print("<tr><th width=250>Host Flows Threshold</th>\n")
      print [[<td>]]
      print[[<form class="form-inline" style="margin-bottom: 0px;">]]

      print[[<input type="hidden" name="host" value="]] print(host_info["host"]) print[[">]]
      print[[<input type="hidden" name="vlan" value="]] print(tostring(host_info["vlan"])) print[[">]]
   
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print [[<input type="number" name="flows_alert_threshold" placeholder="" min="0" step="1" max="100000" value="]]
         print(tostring(flows_alert_thresh))
         print [["></input>
      &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
    </form>
<small>
    Max number of flows over which a host is considered a flooder. Default: 32768.<br>
</small>]]
  print[[
    </td></tr>
       ]]
    local suppressAlerts = ntop.getHashCache(get_alerts_suppressed_hash_name(ifname), hostkey)
    if((suppressAlerts == "") or (suppressAlerts == nil) or (suppressAlerts == "true")) then
       alerts_checked = 'checked="checked"'
       alerts_value = "false" -- Opposite
    else
       alerts_checked = ""
       alerts_value = "true" -- Opposite
    end

    print [[
         <tr><th>Host Alerts</th><td nowrap>
         <form id="alert_prefs" class="form-inline" style="margin-bottom: 0px;">
         <input type="hidden" name="tab" value="alerts_preferences">]]

    print[[<input type="hidden" name="host" value="]] print(host_info["host"]) print[[">]]
    print[[<input type="hidden" name="vlan" value="]] print(tostring(host_info["vlan"])) print[[">]]

      print('<input type="hidden" name="trigger_alerts" value="'..alerts_value..'"><input type="checkbox" value="1" '..alerts_checked..' onclick="this.form.submit();"> <i class="fa fa-exclamation-triangle fa-lg"></i> Trigger alerts for host '..host_ip..'</input>')
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
      print('<input type="hidden" name="page" value="config">')
      print('</form>')
      print('</td>')
      print [[</tr>]]

   print[[<tr><form class="form-inline" style="margin-bottom: 0px;">]]

      print[[<input type="hidden" name="host" value="]] print(host_info["host"]) print[[">]]
      print[[<input type="hidden" name="vlan" value="]] print(tostring(host_info["vlan"])) print[[">]]
   
      print[[<input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
         <td style="text-align: left; white-space: nowrap;" ><b>Rearm minutes</b></td>
         <td>
            <input type="number" name="re_arm_minutes" min="1" value=]] print(tostring(re_arm_minutes)) print[[>
            &nbsp;<button type="submit" style="position: absolute; margin-top: 0; height: 26px" class="btn btn-default btn-xs">Save</button>
            <br><small>The rearm is the dead time between one alert generation and the potential generation of the next alert of the same kind. </small>
         </td>
      </form></tr>]]

    print("</table>")

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
drawRRD(ifId, host_key, rrdfile, _GET["graph_zoom"], ntop.getHttpPrefix()..'/lua/host_details.lua?ifname='..ifId..'&'..host_url..'&page=historical', 1, _GET["epoch"], nil, makeTopStatsScriptsArray())
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
print [[/lua/host_sflow_distro.lua', { distr: users_type, mode: "user", filter: users_filter , ifname: "]] print(ifId.."") print ('", '..hostinfo2json(host_info).." }, \"\", refresh); \n")

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
print [[/lua/host_sflow_distro.lua?host=..&distr="+users_type+"&mode=user&filter="+users_filter); }
    users.setUrlParams({ type: users_type, mode: "user", filter: users_filter, ifname: "]] print(ifId.."") print ('",'.. hostinfo2json(host_info) .. "}") print [[ );
    }); ]]

print [[
$("#show_users input:radio").change(function() {
    users_filter = this.value
    if(sprobe_debug) { alert("users_type: "+users_type+"\n users_filter: "+users_filter); }
    if(sprobe_debug) { alert("url: ]]
print (ntop.getHttpPrefix())
print [[/lua/host_sflow_distro.lua?host=..&distr="+users_type+"&mode=user&filter="+users_filter); }
    users.setUrlParams({ type: users_type, mode: "user", filter: users_filter, ifname: "]] print(ifId.."") print ('",'.. hostinfo2json(host_info) .. "}") print [[ );
});]]


-- Processes graph javascritp

print [[
processes = do_pie("#topProcess", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_sflow_distro.lua', { distr: processes_type, mode: "process", filter: processes_filter , ifname: "]] print(ifId.."")print ('", '..hostinfo2json(host_info).." }, \"\", refresh); \n")

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
    processes.setUrlParams({ type: processes_type, mode: "process", filter: processes_filter , ifname: "]] print(ifId.."") print ('",'.. hostinfo2json(host_info) .. "}") print [[ );
    }); ]]

print [[
$("#show_processes input:radio").change(function() {
    processes_filter = this.value
    if(sprobe_debug) { alert("processes_type: "+processes_type+"\n processes_filter: "+processes_filter); }
    processes.setUrlParams({ type: processes_type, mode: "process", filter: processes_filter, ifname: "]] print(ifId.."") print ('",'.. hostinfo2json(host_info) .. "}") print [[ );
});]]


-- Processes Tree graph javascript
print [[
  tree = do_sequence_sunburst("chart_processTree","sequence_processTree",refresh,']]
print (ntop.getHttpPrefix())
print [[/lua/sflow_tree.lua',{distr: "bytes" , filter: tree_filter ]] print (','.. hostinfo2json(host_info)) print [[ },"","Bytes"); ]]

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
    tree[0].setUrlParams({type: tree_type , filter: tree_filter ]] print (','.. hostinfo2json(host_info).." }") print [[ );
    }); ]]

print [[

  $("#show_tree input:radio").change(function() {
    tree_filter = this.value
    if(sprobe_debug) { alert("tree_type: "+tree_type+"\ntree_filter: "+tree_filter); }
    tree[0].setUrlParams({type: tree_type , filter: tree_filter]] print (','.. hostinfo2json(host_info).." }") print [[ );
});]]

print [[ </script>]]

-- End Sprobe Page
end
end

if (host ~= nil) then
   print [[ 
   <script>
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
   		    data: { ifname: "]] print(ifId.."")  print('", '..hostinfo2json(host_info)) print [[ },
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
