--
-- (C) 2013-18 - ntop.org
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
local discover = require "discover_utils"
local ts_utils = require "ts_utils"
local info = ntop.getInfo()

local have_nedge = ntop.isnEdge()

local debug_hosts = false
local page        = _GET["page"]
local protocol_id = _GET["protocol"]
local application = _GET["application"]
local category    = _GET["category"]
local host_info   = url2hostinfo(_GET)
local host_ip     = host_info["host"]
local host_name   = hostinfo2hostkey(host_info)
local host_vlan   = host_info["vlan"] or 0
local always_show_hist = _GET["always_show_hist"]

local ntopinfo    = ntop.getInfo()
local active_page = "hosts"

interface.select(ifname)
local ifstats = interface.getStats()

ifId = ifstats.id

local is_packetdump_enabled = isLocalPacketdumpEnabled()
local host = nil
local family = nil

local prefs = ntop.getPrefs()

local hostkey = hostinfo2hostkey(host_info, nil, true --[[ force show vlan --]])
local hostkey_compact = hostinfo2hostkey(host_info) -- do not force vlan
local labelKey = host_info["host"].."@"..host_info["vlan"]

if((host_name == nil) or (host_ip == nil)) then
   sendHTTPContentTypeHeader('text/html')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("host_details.host_parameter_missing_message") .. "</div>")
   return
end

-- print(">>>") print(host_info["host"]) print("<<<")
if(debug_hosts) then traceError(TRACE_DEBUG,TRACE_CONSOLE, i18n("host_details.trace_debug_host_info",{hostinfo=host_info["host"],vlan=host_vlan}).."\n") end

local host = interface.getHostInfo(host_info["host"], host_vlan)

local restoreFailed = false

if((host == nil) and ((_POST["mode"] == "restore") or (page == "historical"))) then
   if(debug_hosts) then traceError(TRACE_DEBUG,TRACE_CONSOLE, i18n("host_details.trace_debug_restored_host_info").."\n") end
   interface.restoreHost(host_info["host"], host_vlan)
   host = interface.getHostInfo(host_info["host"], host_vlan)
   restoreFailed = true
end

local only_historical = false

local host_pool_id = nil

if (host ~= nil) then
   if (isAdministrator() and (_POST["pool"] ~= nil)) then
      host_pool_id = _POST["pool"]
      local prev_pool = tostring(host["host_pool_id"])

      if host_pool_id ~= prev_pool then
         local key = host2member(host["ip"], host["vlan"])
         if not host_pools_utils.changeMemberPool(ifId, key, host_pool_id, host) then
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
   -- NOTE: this features is not currently enabled as it may incur into thread concurrency issues
   if (ts_utils.exists("host:traffic", {ifid=ifId, host=host_ip}) and always_show_hist == "true") then
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
	 print('<div class=\"alert alert-danger\"><i class="fa fa-warning fa-lg"></i> '.. i18n("host_details.host_cannot_be_found_message",{host=hostinfo2hostkey(host_info)}) .. " ")
	 if((json ~= nil) and (json ~= "")) then
	    print[[<form id="host_restore_form" method="post">]]
	    print[[<input name="mode" type="hidden" value="restore" />]]
	    print[[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />]]
	    print[[</form>]]
	    print[[ ]] print(i18n("host_details.restore_from_cache_message",{js_code="\"javascript:void(0);\" onclick=\"$(\'#host_restore_form\').submit();\""}))
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

print [[
<div class="bs-docs-example">
            <nav class="navbar navbar-default" role="navigation">
              <div class="navbar-collapse collapse">
<ul class="nav navbar-nav">
]]
if((debug_hosts) and (host["ip"] ~= nil)) then traceError(TRACE_DEBUG,TRACE_CONSOLE, i18n("host_details.trace_debug_host_ip",{hostip=host["ip"],vlan=host["vlan"]}).."\n") end
url=ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(host_info)

print("<li><a href=\"#\">"..i18n("host_details.host")..": "..host_info["host"].."</A> </li>")

if((page == "overview") or (page == nil)) then
   print("<li class=\"active\"><a href=\"#\"><i class=\"fa fa-home fa-lg\"></i>\n")
else
   print("<li><a href=\""..url.."&page=overview\"><i class=\"fa fa-home fa-lg\"></i>\n")
end

if(page == "traffic") then
   print("<li class=\"active\"><a href=\"#\">".. i18n("traffic") .. "</a></li>\n")
else
   if(host["ip"] ~= nil) then
      print("<li><a href=\""..url.."&page=traffic\">" .. i18n("traffic") .. "</a></li>")
   end
end

if(page == "packets") then
   print("<li class=\"active\"><a href=\"#\">" .. i18n("packets") .. "</a></li>\n")
elseif not have_nedge then
   if((host["ip"] ~= nil) and (
   	(host["udp.packets.sent"] > 0)
	or (host["udp.packets.rcvd"] > 0)
   	or (host["tcp.packets.sent"] > 0)
	or (host["tcp.packets.rcvd"] > 0))) then
      print("<li><a href=\""..url.."&page=packets\">" .. i18n("packets") .. "</a></li>")
   end
end

if(page == "ports") then
   print("<li class=\"active\"><a href=\"#\">" .. i18n("ports") .. "</a></li>\n")
else
   if(host["ip"] ~= nil) then
      print("<li><a href=\""..url.."&page=ports\">" .. i18n("ports") .. "</a></li>")
   end
end

if(not(isLoopback(ifname))) then
   if(page == "peers") then
      print("<li class=\"active\"><a href=\"#\">" .. i18n("peers") .. "</a></li>\n")
   else
      if(host["ip"] ~= nil) then
	 print("<li><a href=\""..url.."&page=peers\">" .. i18n("peers") .. "</a></li>")
      end
   end
end

if((host["ICMPv4"] ~= nil) or (host["ICMPv6"] ~= nil)) then
   if(page == "ICMP") then
      print("<li class=\"active\"><a href=\"#\">"..i18n("icmp").."</a></li>\n")
   else
      print("<li><a href=\""..url.."&page=ICMP\">"..i18n("icmp").."</a></li>")
   end      
end

if(page == "ndpi") then
  direction = _GET["direction"]
  print("<li class=\"active\"><a href=\"#\">" .. i18n("protocols") .."</a></li>\n")
else
   if(host["ip"] ~= nil) then
      print("<li><a href=\""..url.."&page=ndpi\">" .. i18n("protocols") .. "</a></li>")
   end
end

if(page == "dns") then
  print("<li class=\"active\"><a href=\"#\">"..i18n("dns").."</a></li>\n")
else
   if((host["dns"] ~= nil)
   and ((host["dns"]["sent"]["num_queries"]+host["dns"]["rcvd"]["num_queries"]) > 0)) then
      print("<li><a href=\""..url.."&page=dns\">"..i18n("dns").."</a></li>")
   end
end

http = host["http"]

if(page == "http") then
  print("<li class=\"active\"><a href=\"#\">"..i18n("http"))
else
   if((http ~= nil)
      and ((http["sender"]["query"]["total"]+ http["receiver"]["response"]["total"]) > 0)) then
      print("<li><a href=\""..url.."&page=http\">"..i18n("http"))
      if(host["active_http_hosts"] > 0) then print(" <span class='badge badge-top-right'>".. host["active_http_hosts"] .."</span>") end
   end
end

print("</a></li>\n")

if(page == "flows") then
  print("<li class=\"active\"><a href=\"#\">"..i18n("flows").."</a></li>\n")
else
   if(host["ip"] ~= nil) then
      print("<li><a href=\""..url.."&page=flows\">"..i18n("flows").."</a></li>")
   end
end

if host["localhost"] == true then
   if ntop.isEnterprise() then
      if(page == "snmp") then
	 print("<li class=\"active\"><a href=\"#\">"..i18n("host_details.snmp").."</a></li>\n")
      else
	 print("<li><a href=\""..url.."&page=snmp\">"..i18n("host_details.snmp").."</a></li>")
      end
   end
end

if(not(isLoopback(ifname))) then
   if(page == "talkers") then
      print("<li class=\"active\"><a href=\"#\">"..i18n("talkers").."</a></li>\n")
   else
      print("<li><a href=\""..url.."&page=talkers\">"..i18n("talkers").."</a></li>")
   end

   if(page == "geomap") then
      print("<li class=\"active\"><a href=\"#\"><i class='fa fa-globe fa-lg'></i></a></li>\n")
   else
      if(host["ip"] ~= nil) then
	 print("<li><a href=\""..url.."&page=geomap\"><i class='fa fa-globe fa-lg'></i></a></li>")
      end
   end
else

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

if (host["ip"] ~= nil and host['localhost']) and areAlertsEnabled() and not ifstats.isView then
   if(page == "alerts") then
      print("\n<li class=\"active\"><a href=\"#\"><i class=\"fa fa-warning fa-lg\"></i></a></li>\n")
   elseif interface.isPcapDumpInterface() == false then
      print("\n<li><a href=\""..url.."&page=alerts\"><i class=\"fa fa-warning fa-lg\"></i></a></li>")
   end
end

if(ts_utils.exists("host:traffic", {ifid=ifId, host=host_ip})) then
   if(page == "historical") then
     print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i></a></li>\n")
   else
     print("\n<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
   end
end

if (host["localhost"] == true) and (ts_utils.getDriverName() == "rrd") then
   if(ntop.isEnterprise()) then
      if(page == "traffic_report") then
         print("\n<li class=\"active\"><a href=\"#\"><i class='fa fa-file-text report-icon'></i></a></li>\n")
      else
         print("\n<li><a href=\""..url.."&page=traffic_report\"><i class='fa fa-file-text report-icon'></i></a></li>")
      end
   elseif not have_nedge then
      print("\n<li><a href=\"#\" title=\""..i18n('enterpriseOnly').."\"><i class='fa fa-file-text report-icon'></i></A></li>\n")
   end
end

if ntop.isEnterprise() and ifstats.inline and host_pool_id ~= host_pools_utils.DEFAULT_POOL_ID then
  if page == "quotas" then
    print("\n<li class=\"active\"><a href=\"#\">"..i18n("quotas").."</a></li>\n")
  else
    print("\n<li><a href=\""..url.."&page=quotas\">"..i18n("quotas").."</a></li>\n")
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

local macinfo = interface.getMacInfo(host["mac"])

--tprint(host)
if((page == "overview") or (page == nil)) then
   print("<table class=\"table table-bordered table-striped\">\n")
   if(host["ip"] ~= nil) then
      if(host["mac"]  ~= "00:00:00:00:00:00") then
	 print("<tr><th width=35%>"..i18n("details.router_access_point_mac_address").."</th><td>" ..get_symbolic_mac(host["mac"]).. " " .. discover.devtype2icon(host["device_type"]))
	 print('</td><td>')

	 if(host['localhost'] and (macinfo ~= nil)) then
	    -- This is a known device type
	    print(discover.devtype2icon(macinfo.devtype) .. " ")
	    if macinfo.devtype ~= 0 then
	       print(discover.devtype2string(macinfo.devtype) .. " ")
	    else
	       print(i18n("host_details.unknown_device_type") .. " ")
	    end
	    print('<a href="'..ntop.getHttpPrefix()..'/lua/mac_details.lua?'..hostinfo2url(macinfo)..'&page=config"><i class="fa fa-cog"></i></a>\n')
	 else
	    print("&nbsp;")
	 end
	 
	 print('</td></tr>')
      end

      if(host['localhost'] and (host["mac"] ~= "") and (info["version.enterprise_edition"])) then
	 print_host_snmp_localization_table_entry(host["mac"])
      end
      print("</tr>")
      
      print("<tr><th>"..i18n("ip_address").."</th><td colspan=1>" .. host["ip"])
      if(host.childSafe == true) then print(getSafeChildIcon()) end

     if(host.operatingSystem ~= 0) then
       print(" "..getOperatingSystemIcon(host.operatingSystem).." ")
     end

      historicalProtoHostHref(getInterfaceId(ifname), host["ip"], nil, nil, nil)
      
      if(host["local_network_name"] ~= nil) then
	 print(" [&nbsp;<A HREF='"..ntop.getHttpPrefix().."/lua/network_details.lua?network="..host["local_network_id"].."&page=historical'>".. host["local_network_name"].."</A>&nbsp;]")
      end

      if((host["city"] ~= nil) and (host["city"] ~= "")) then
         print(" [ " .. host["city"] .." "..getFlag(host["country"]).." ]")
      end

      print[[</td><td><span>]] print(i18n(ternary(have_nedge, "nedge.user", "details.host_pool"))..": ")
      if not ifstats.isView then
	 print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/hosts_stats.lua?pool=]] print(host_pool_id) print[[">]] print(host_pools_utils.getPoolName(ifId, host_pool_id)) print[[</a></span>]]
	 print[[&nbsp; <a href="]] print(ntop.getHttpPrefix()) print[[/lua/host_details.lua?]] print(hostinfo2url(host)) print[[&page=config&ifid=]] print(tostring(ifId)) print[[">]]
	 print[[<i class="fa fa-sm fa-cog" aria-hidden="true"></i></a></span>]]
      else
        -- no link for view interfaces
        print(host_pools_utils.getPoolName(ifId, host_pool_id))
      end
      print("</td></tr>")
   else
      if(host["mac"] ~= nil) then
	 print("<tr><th>"..i18n("mac_address").."</th><td colspan=2>" .. host["mac"].. "</td></tr>\n")
      end
   end

   if(ifstats.vlan and (host["vlan"] ~= nil)) then
      print("<tr><th>")

      if(ifstats.sprobe) then
         print(i18n("details.source_id"))
      else
	 print(i18n("details.vlan_id"))
      end

      print("</th><td colspan=2><A HREF="..ntop.getHttpPrefix().."/lua/hosts_stats.lua?vlan="..host["vlan"]..">"..host["vlan"].."</A></td></tr>\n")
   end

   if(host["os"] ~= "") then
      print("<tr>")
      if(host["os"] ~= "") then
         print("<th>"..i18n("os").."</th><td> <A HREF='"..ntop.getHttpPrefix().."/lua/hosts_stats.lua?os=" .. string.gsub(host["os"], " ", '%%20').. "'>"..mapOS2Icon(host["os"]) .. "</A></td><td></td>\n")
      else
         print("<th></th><td></td>\n")
      end
      print("</tr>")
   end

   if((host["asn"] ~= nil) and (host["asn"] > 0)) then
      print("<tr><th>"..i18n("asn").."</th><td>")

      print("<A HREF='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=".. host.asn .."'>"..host.asname.."</A> [ "..i18n("asn").." <A HREF='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=".. host.asn.."'>".. host.asn.."</A> ]</td>")
      print('<td><A HREF="http://itools.com/tool/arin-whois-domain-search?q='.. host["ip"] ..'&submit=Look+up">'..i18n("details.whois_lookup")..'</A> <i class="fa fa-external-link"></i></td>')
      print("</td></tr>\n")
   end

   if(host["ip"] ~= nil) then
      if(host["name"] == nil) then
	 host["name"] = getResolvedAddress(hostkey2hostinfo(host["ip"]))
      end
      
      print("<tr><th>"..i18n("name").."</th>")

      if(isAdministrator()) then
	 print("<td><A HREF=\"http://" .. getIpUrl(host["ip"]) .. "\"> <span id=name>")
      else
	 print("<td colspan=2>")
      end

      if(host["ip"] == host["name"]) then
	 print("<img border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber> ")
      end

      -- tprint(host) io.write("\n")
      print(host["name"] .. "</span></A> <i class=\"fa fa-external-link\"></i> ")

      print[[ <a href="]] print(ntop.getHttpPrefix()) print[[/lua/host_details.lua?]] print(hostinfo2url(host)) print[[&page=config&ifid=]] print(tostring(ifId)) print[[">]]
      print[[<i class="fa fa-sm fa-cog" aria-hidden="true" title="Set Host Alias"></i></a></span> ]]

      if(host["localhost"] == true) then
	 print('<span class="label label-success">'..i18n("details.label_local_host")..'</span>')
      elseif(host["is_multicast"] == true) then print(' <span class="label label-default">Multicast</span> ')
      elseif(host["is_broadcast"] == true) then print(' <span class="label label-default">Broadcast</span> ')
      else print('<span class="label label-default">'..i18n("details.label_remote")..'</span>')
      end
      
      if(host["privatehost"] == true) then print(' <span class="label label-warning">'..i18n("details.label_private_ip")..'</span>') end
      if(host["systemhost"] == true) then print(' <span class="label label-info">'..i18n("details.label_system_ip")..' '..'<i class=\"fa fa-flag\"></i></span>') end
      if(host["is_blacklisted"] == true) then print(' <span class="label label-danger">'..i18n("details.label_blacklisted_host")..'</span>') end

      print("</td><td></td>\n")
   end

if(host["num_alerts"] > 0) then
   print("<tr><th><i class=\"fa fa-warning fa-lg\" style='color: #B94A48;'></i>  <A HREF='"..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(host_info).."&page=alerts'>"..i18n("details.alerts").."</A></th><td colspan=2></li> <span id=num_alerts>"..host["num_alerts"] .. "</span> <span id=alerts_trend></span></td></tr>\n")
end

   if ntop.isPro() and ifstats.inline and (host["has_blocking_quota"] or host["has_blocking_shaper"]) then

   local msg = ""
   local target = ""
   local quotas_page = "/lua/host_details.lua?"..hostinfo2url(host).."&page=quotas&ifid="..ifId
   local policies_page = "/lua/if_stats.lua?ifid="..ifId.."&page=filtering&pool="..host_pool_id

      if host["has_blocking_quota"] then
         if host["has_blocking_shaper"] then
            msg = i18n("host_details.host_traffic_blocked_quota_and_shaper")
            target = quotas_page
         else
            msg = i18n("host_details.host_traffic_blocked_quota")
            target = quotas_page
         end
      else
         msg = i18n("host_details.host_traffic_blocked_shaper")
         target = policies_page
      end

       print("<tr><th><i class=\"fa fa-ban fa-lg\"></i> <a href=\""..ntop.getHttpPrefix()..target.."\">"..i18n("host_details.blocked_traffic").."</a></th><td colspan=2>"..msg)
      print(".")
      print("</td></tr>")
   end

   print("<tr><th>"..i18n("details.first_last_seen").."</th><td nowrap><span id=first_seen>" .. formatEpoch(host["seen.first"]) ..  " [" .. secondsToTime(os.time()-host["seen.first"]) .. " "..i18n("details.ago").."]" .. "</span></td>\n")
   print("<td  width='35%'><span id=last_seen>" .. formatEpoch(host["seen.last"]) .. " [" .. secondsToTime(os.time()-host["seen.last"]) .. " "..i18n("details.ago") .. "]" .. "</span></td></tr>\n")


   if((host["bytes.sent"]+host["bytes.rcvd"]) > 0) then
      print("<tr><th>"..i18n("details.sent_vs_received_traffic_breakdown").."</th><td colspan=2>")
      breakdownBar(host["bytes.sent"], i18n("sent"), host["bytes.rcvd"], i18n("details.rcvd"), 0, 100)
      print("</td></tr>\n")
   end

   print("<tr><th>"..i18n("details.traffic_sent_received").."</th><td><span id=pkts_sent>" .. formatPackets(host["packets.sent"]) .. "</span> / <span id=bytes_sent>".. bytesToSize(host["bytes.sent"]) .. "</span> <span id=sent_trend></span></td><td><span id=pkts_rcvd>" .. formatPackets(host["packets.rcvd"]) .. "</span> / <span id=bytes_rcvd>".. bytesToSize(host["bytes.rcvd"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")

   local flows_th = i18n("details.flows_non_packet_iface")
   if interface.isPacketInterface() then
      if interface.isPcapDumpInterface() == false then
         flows_th = i18n("details.flows_packet_iface")
      else
         flows_th = i18n("details.flows_packet_pcap_dump_iface")
      end
   end

   print("<tr><th rowspan=2>"..flows_th.."</th><th>'"..i18n("details.as_client").."'</th><th>'"..i18n("details.as_server").."'</th></tr>\n")
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

   if interface.isBridgeInterface(ifstats) then
      print("<tr id=bridge_dropped_flows_tr ") if not host["flows.dropped"] then print("style='display:none;'") end print(">")

      print("<th><i class=\"fa fa-ban fa-lg\"></i> "..i18n("details.flows_dropped_by_bridge").."</th>")
      print("<td colspan=2><span id=bridge_dropped_flows>" .. formatValue((host["flows.dropped"] or 0)) .. "</span>  <span id=trend_bridge_dropped_flows></span>")

      print("</tr>")
   end


   if host["tcp.packets.seq_problems"] == true then
      print("<tr><th width=30% rowspan=4>"..i18n("details.tcp_packets_sent_analysis").."</th><th>"..i18n("details.retransmissions").."</th><td align=right><span id=pkt_retransmissions>".. formatPackets(host["tcp.packets.retransmissions"]) .."</span> <span id=pkt_retransmissions_trend></span></td></tr>\n")
      print("<tr></th><th>"..i18n("details.out_of_order").."</th><td align=right><span id=pkt_ooo>".. formatPackets(host["tcp.packets.out_of_order"]) .."</span> <span id=pkt_ooo_trend></span></td></tr>\n")
      print("<tr></th><th>"..i18n("details.lost").."</th><td align=right><span id=pkt_lost>".. formatPackets(host["tcp.packets.lost"]) .."</span> <span id=pkt_lost_trend></span></td></tr>\n")
      print("<tr></th><th>"..i18n("details.keep_alive").."</th><td align=right><span id=pkt_keep_alive>".. formatPackets(host["tcp.packets.keep_alive"]) .."</span> <span id=pkt_keep_alive_trend></span></td></tr>\n")
   end

   
   if((host["info"] ~= nil) or (host["label"] ~= nil))then
      print("<tr><th>"..i18n("details.further_host_names_information").."</th><td colspan=2>")
      if(host["info"] ~= nil) then  print(host["info"]) end
      if((host["label"] ~= nil) and (host["info"] ~= host["label"])) then print(host["label"]) end
      print("</td></tr>\n")
   end
   
   if(host["json"] ~= nil) then
      print("<tr><th>"..i18n("download").."&nbsp;<i class=\"fa fa-download fa-lg\"></i></th><td")
      if(not isAdministrator()) then print(" colspan=2") end
      print("><A HREF='"..ntop.getHttpPrefix().."/lua/host_get_json.lua?ifid="..ifId.."&"..hostinfo2url(host_info).."'>JSON</A></td>")

      if(isAdministrator()) then
	 print [[<td>]]

         local live_traffic_utils = require("live_traffic_utils")
         live_traffic_utils.printLiveTrafficForm(ifId, host_info)

         print[[</td>]]
      end

      print("</tr>\n")
   end

   if(host["ssdp"] ~= nil) then
      print("<tr><th><A HREF='https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol'>SSDP (UPnP)</A></th><td colspan=2><i class=\"fa fa-external-link fa-lg\"></i> <A HREF='"..host["ssdp"].."'>"..host["ssdp"].."<A></td></tr>\n")
   end

   print("</table>\n")

   elseif((page == "packets")) then
      print [[

      <table class="table table-bordered table-striped">
	 ]]

      if(host["bytes.sent"] > 0) then
	 print('<tr><th class="text-left">'..i18n("packets_page.sent_distribution")..'</th><td colspan=5><div class="pie-chart" id="sizeSentDistro"></div></td></tr>')
      end
      if(host["bytes.rcvd"] > 0) then
	 print('<tr><th class="text-left">'..i18n("packets_page.received_distribution")..'</th><td colspan=5><div class="pie-chart" id="sizeRecvDistro"></div></td></tr>')
      end
      if (host["tcp.packets.rcvd"] + host["tcp.packets.sent"] > 0) then
	 print('<tr><th class="text-left">'..i18n("packets_page.tcp_flags_distribution")..'</th><td colspan=5><div class="pie-chart" id="flagsDistro"></div></td></tr>')
      end
      if (not isEmptyString(host["mac"])) and (host["mac"] ~= "00:00:00:00:00:00") then
         if (macinfo ~= nil) and (macinfo["arp_requests.sent"] + macinfo["arp_requests.rcvd"] + macinfo["arp_replies.sent"] + macinfo["arp_replies.rcvd"] > 0) then
            print('<tr><th class="text-left">'..i18n("packets_page.arp_distribution")..'</th><td colspan=5><div class="pie-chart" id="arpDistro"></div></td></tr>')
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
	 print('<tr><th class="text-left">'..i18n("ports_page.client_ports")..'</th><td colspan=5><div class="pie-chart" id="clientPortsDistro"></div></td></tr>')
      end
      if(host["bytes.rcvd"] > 0) then
	 print('<tr><th class="text-left">'..i18n("ports_page.server_ports")..'</th><td colspan=5><div class="pie-chart" id="serverPortsDistro"></div></td></tr>')
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
       <strong>]] print(i18n("peers_page.top_peers_for_host",{hostkey=hostinfo2hostkey(host_info)})) print  [[</strong>
       <div class="clearfix"></div>
   </div>

   <div id="chart-ring-protocol">
       <strong>]] print(i18n("peers_page.top_peer_protocol")) print[[</strong>
       <div class="clearfix"></div>
   </div>
   </td></tr></table>

<div class="row">
    <div>
    <table class="table table-hover dc-data-table">
        <thead>
        <tr class="header">
            <th>]] print(i18n("peers_page.host")) print[[</th>
            <th>]] print(i18n("l7_protocol")) print[[</th>
            <th>]] print(i18n("peers_page.traffic_volume")) print[[</th>
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
   print("<disv class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("peers_page.no_active_flows_message").."</div>")
end
   elseif((page == "traffic")) then
     total = 0
     for id, _ in ipairs(l4_keys) do
	k = l4_keys[id][2]
	if(host[k..".bytes.sent"] ~= nil) then total = total + host[k..".bytes.sent"] end
	if(host[k..".bytes.rcvd"] ~= nil) then total = total + host[k..".bytes.rcvd"] end
     end

     if(total == 0) then
	print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> "..i18n("traffic_page.no_traffic_observed_message").."</div>")
     else
      print [[

      <table class="table table-bordered table-striped">
      	<tr><th class="text-left">]] print(i18n("traffic_page.l4_proto_overview")) print[[</th><td colspan=5><div class="pie-chart" id="topApplicationProtocols"></div></td></tr>
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

     print("<tr><th>"..i18n("protocol").."</th><th>"..i18n("sent").."</th><th>"..i18n("received").."</th><th>"..i18n("breakdown").."</th><th colspan=2>"..i18n("total").."</th></tr>\n")

     for id, _ in ipairs(l4_keys) do
	label = l4_keys[id][1]
	k = l4_keys[id][2]
	sent = host[k..".bytes.sent"]
	if(sent == nil) then sent = 0 end
	rcvd = host[k..".bytes.rcvd"]
	if(rcvd == nil) then rcvd = 0 end

	if((sent > 0) or (rcvd > 0)) then
	    print("<tr><th>")
	    if(ts_utils.exists("host:ndpi", {ifid=ifId, host=host_ip, protocol=k})) then
	       print("<A HREF=\""..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(host_info) .. "&page=historical&ts_schema=host:ndpi&protocol=".. k .."\">".. label .."</A>")
	    else
	       print(label)
	    end
	    t = sent+rcvd
	    historicalProtoHostHref(ifId, host, l4_keys[id][3], nil, nil)
	    print("</th><td class=\"text-right\">" .. bytesToSize(sent) .. "</td><td class=\"text-right\">" .. bytesToSize(rcvd) .. "</td><td>")
	    breakdownBar(sent, i18n("sent"), rcvd, i18n("traffic_page.rcvd"), 0, 100)
	    print("</td><td class=\"text-right\">" .. bytesToSize(t).. "</td><td class=\"text-right\">" .. round((t * 100)/total, 2).. " %</td></tr>\n")
	 end
      end
      print("</table></tr>\n")

      print("</table>\n")
   end


elseif((page == "ICMP")) then

  print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     <thead><tr><th>]] print(i18n("icmp_page.icmp_message")) print[[</th><th>]] print(i18n("icmp_page.last_sent_peer")) print[[</th><th>]] print(i18n("icmp_page.last_rcvd_peer")) print[[</th><th>]] print(i18n("breakdown")) print[[</th><th style='text-align:right;'>]] print(i18n("icmp_page.packets_sent")) print[[</th><th style='text-align:right;'>]] print(i18n("icmp_page.packets_received")) print[[</th><th style='text-align:right;'>]] print(i18n("total")) print[[</th></tr></thead>
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
    <tr>
      <th class="text-left" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("ndpi_page.application_protocol")})) print[[</th>
      <td>
        <div class="pie-chart" id="topApplicationProtocols"></div>
      </td>
      <td colspan=2>
        <div class="pie-chart" id="topApplicationBreeds"></div>
      </td>
    </tr>
    <tr>
      <th class="text-left" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("ndpi_page.application_protocol_category")})) print[[</th>
      <td colspan=2>
        <div class="pie-chart" id="topApplicationCategories"></div>
      </td>
    </tr>
  </table>

        <script type='text/javascript'>
	       window.onload=function() {

				   do_pie("#topApplicationProtocols", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_ndpi_stats.lua', { ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);

				   do_pie("#topApplicationCategories", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_ndpi_stats.lua', { ndpi_category: "true", ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);

				   do_pie("#topApplicationBreeds", ']]
print (ntop.getHttpPrefix())
print [[/lua/iface_ndpi_stats.lua', { breed: "true", ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);


				}

	    </script>
           <p>
	]]

  local direction_filter = ""
  local base_url = ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&"..hostinfo2url(host_info).."&page=ndpi";

  if(direction ~= nil) then
    direction_filter = '<span class="glyphicon glyphicon-filter"></span>'
  end

  print('<div class="dt-toolbar btn-toolbar pull-right">')
  print('<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Direction ' .. direction_filter .. '<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" id="direction_dropdown">')
  print('<li><a href="'..base_url..'">'..i18n("all")..'</a></li>')
  print('<li><a href="'..base_url..'&direction=sent">'..i18n("ndpi_page.sent_only")..'</a></li>')
  print('<li><a href="'..base_url..'&direction=recv">'..i18n("ndpi_page.received_only")..'</a></li>')
  print('</ul></div></div>')

  print [[
     <table class="table table-bordered table-striped">
     ]]

  print("<thead><tr><th>"..i18n("ndpi_page.application_protocol").."</th><th>"..i18n("duration").."</th><th>"..i18n("sent").."</th><th>"..i18n("received").."</th><th>"..i18n("breakdown").."</th><th colspan=2>"..i18n("total").."</th></tr></thead>\n")

  print ('<tbody id="host_details_ndpi_applications_tbody">\n')
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
      $('#host_details_ndpi_applications_tbody').html(content);
      // Let the TableSorter plugin know that we updated the table
      $('#h_ndpi_tbody').trigger("update");
    }
  });
}
update_ndpi_table();
setInterval(update_ndpi_table, 5000);
</script>

]]

  print [[
     <table class="table table-bordered table-striped">
     ]]

  print("<thead><tr><th>"..i18n("ndpi_page.application_protocol_category").."</th><th>"..i18n("duration").."</th><th colspan=2>"..i18n("total").."</th></tr></thead>\n")

  print ('<tbody id="host_details_ndpi_categories_tbody">\n')
  print ("</tbody>")
  print("</table>\n")

  print [[
<script>
function update_ndpi_categories_table() {
  $.ajax({
    type: 'GET',
    url: ']]
  print(ntop.getHttpPrefix())
  print [[/lua/host_details_ndpi_categories.lua',
    data: { ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ },
    success: function(content) {
      $('#host_details_ndpi_categories_tbody').html(content);
      // Let the TableSorter plugin know that we updated the table
      $('#h_ndpi_tbody').trigger("update");
    }
  });
}
update_ndpi_categories_table();
setInterval(update_ndpi_categories_table, 5000);

</script>
]]
  
  local host_ndpi_timeseries_creation = ntop.getCache("ntopng.prefs.host_ndpi_timeseries_creation")

  print("<b>"..i18n("notes").."</b>")

  if host_ndpi_timeseries_creation ~= "both" and host_ndpi_timeseries_creation ~= "per_protocol" then
     print("<li>"..i18n("ndpi_page.note_historical_per_protocol_traffic",{what=i18n("ndpi_page.application_protocol"), url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=on_disk_ts",flask_icon="<i class=\"fa fa-flask\"></i>"}).." ")
  end

  if host_ndpi_timeseries_creation ~= "both" and host_ndpi_timeseries_creation ~= "per_category" then
     print("<li>"..i18n("ndpi_page.note_historical_per_protocol_traffic",{what=i18n("ndpi_page.application_protocol_category"), url=ntop.getHttpPrefix().."/lua/admin/prefs.lua",flask_icon="<i class=\"fa fa-flask\"></i>"}).." ")
  end

  print("<li>"..i18n("ndpi_page.note_possible_probing_alert",{icon="<i class=\"fa fa-warning fa-sm\" style=\"color: orange;\"></i>",url=ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifId.."&host=".._GET["host"].."&page=historical"}))
  print("<li>"..i18n("ndpi_page.note_protocol_usage_time"))
  print("</ul>")


   end

   elseif(page == "dns") then
      if(host["dns"] ~= nil) then
	 print("<table class=\"table table-bordered table-striped\">\n")
	 print("<tr><th>"..i18n("dns_page.dns_breakdown").."</th><th>"..i18n("dns_page.queries").."</th><th>"..i18n("dns_page.positive_replies").."</th><th>"..i18n("dns_page.error_replies").."</th><th colspan=2>"..i18n("dns_page.reply_breakdown").."</th></tr>")
	 print("<tr><th>"..i18n("sent").."</th><td class=\"text-right\"><span id=dns_sent_num_queries>".. formatValue(host["dns"]["sent"]["num_queries"]) .."</span> <span id=trend_sent_num_queries></span></td>")
	 print("<td class=\"text-right\"><span id=dns_sent_num_replies_ok>".. formatValue(host["dns"]["sent"]["num_replies_ok"]) .."</span> <span id=trend_sent_num_replies_ok></span></td>")
	 print("<td class=\"text-right\"><span id=dns_sent_num_replies_error>".. formatValue(host["dns"]["sent"]["num_replies_error"]) .."</span> <span id=trend_sent_num_replies_error></span></td><td colspan=2>")
	 breakdownBar(host["dns"]["sent"]["num_replies_ok"], "OK", host["dns"]["sent"]["num_replies_error"], "Error", 0, 100)
	 print("</td></tr>")

	 if(host["dns"]["sent"]["num_queries"] > 0) then
	    print [[
		     <tr><th>]] print(i18n("dns_page.dns_query_sent_distribution")) print[[</th><td colspan=5>
		     <div class="pie-chart" id="dnsSent"></div>
		     <script type='text/javascript'>

					 do_pie("#dnsSent", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_dns_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, direction: "sent" }, "", refresh);
				      </script>
					 </td></tr>
           ]]
         end

	 print("<tr><th>"..i18n("dns_page.rcvd").."</th><td class=\"text-right\"><span id=dns_rcvd_num_queries>".. formatValue(host["dns"]["rcvd"]["num_queries"]) .."</span> <span id=trend_rcvd_num_queries></span></td>")
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

	print('<tr><th rowspan=2>'..i18n("dns_page.request_vs_reply")..'</th><th colspan=2>'..i18n("dns_page.ratio")..'<th colspan=2>'..i18n("breakdown")..'</th></tr>')
        local dns_ratio = tonumber(host["dns"]["sent"]["num_queries"]) / tonumber(host["dns"]["rcvd"]["num_replies_ok"]+host["dns"]["rcvd"]["num_replies_error"])
        local dns_ratio_str = string.format("%.2f", dns_ratio)

        if(dns_ratio < 0.9) then
          dns_ratio_str = "<font color=red>".. dns_ratio_str .."</font>" 
        end

	print('<tr><td colspan=2 align=right>'..  dns_ratio_str ..'</td><td colspan=2>')
	breakdownBar(host["dns"]["sent"]["num_queries"], i18n("dns_page.queries"), host["dns"]["rcvd"]["num_replies_ok"]+host["dns"]["rcvd"]["num_replies_error"], i18n("dns_page.replies"), 30, 70)

print [[
	</td></tr>
        </table>
       <small><b>]] print(i18n("dns_page.note")) print[[:</b><br>]] print(i18n("dns_page.note_dns_ratio")) print[[
</small>
]]
      end
   elseif(page == "http") then
      if(http ~= nil) then
	 print("<table class=\"table table-bordered table-striped\">\n")

	 if(host["sites"] ~= nil) then
	    local top_sites = json.decode(host["sites"], 1, nil)
	    local top_sites_old = json.decode(host["sites.old"], 1, nil)
	    local old_top_len = table.len(top_sites_old)  if(old_top_len > 10) then old_top_len = 10 end
	    local top_len = table.len(top_sites)          if(top_len > 10) then top_len = 10 end
	    if(old_top_len > top_len) then num = old_top_len else num = top_len end

	    print("<tr><th rowspan="..(1+num)..">"..i18n("http_page.top_visited_sites").."</th><th>"..i18n("http_page.current_sites").."</th><th>"..i18n("http_page.contacts").."</th><th>"..i18n("http_page.last_5_minutes_sites").."</th><th>"..i18n("http_page.contacts").."</th></tr>\n")
	    local sites = {}
	    for k,v in pairsByValues(top_sites, rev) do
	       table.insert(sites, { k, v })
	    end

	    local sites_old = {}
	    for k,v in pairsByValues(top_sites_old, rev) do
	       table.insert(sites_old, { k, v })
	    end

	    for i = 1,num do
	       if(sites[i] == nil) then sites[i] = { "", 0 } end
	       if(sites_old[i] == nil) then sites_old[i] = { "", 0 } end
	       print("<tr><th>")
	       if(sites[i][1] ~= "") then
		  print(formatWebSite(sites[i][1]).."</th><td align=right>"..sites[i][2].."</td>\n")
	       else
		  print("&nbsp;</th><td>&nbsp;</td>\n")
	       end

	       if(sites_old[i][1] ~= "") then
		  print("<th>"..formatWebSite(sites_old[i][1]).."</th><td align=right>"..sites_old[i][2].."</td>\n")
	       else
		  print("<th>&nbsp;</th><td>&nbsp;</td>\n")
	       end

	       print("</tr>")
	    end
	 end

	 print("<tr><th rowspan=6 width=20%><A HREF='http://en.wikipedia.org/wiki/Hypertext_Transfer_Protocol#Request_methods'>"..i18n("http_page.http_queries").."</A></th><th width=20%>"..i18n("http_page.method").."</th><th width=20%>"..i18n("http_page.requests").."</th><th colspan=2>"..i18n("http_page.distribution").."</th></tr>")
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
	 print("<tr><th>"..i18n("http_page.other_method").."</th><td style=\"text-align: right;\"><span id=http_query_num_other>".. formatValue(http["sender"]["query"]["num_other"]) .."</span> <span id=trend_http_query_num_other></span></td></tr>")
	 print("<tr><th colspan=4>&nbsp;</th></tr>")
	 print("<tr><th rowspan=6 width=20%><A HREF='http://en.wikipedia.org/wiki/List_of_HTTP_status_codes'>"..i18n("http_page.http_responses").."</A></th><th width=20%>"..i18n("http_page.response_code").."</th><th width=20%>"..i18n("http_page.responses").."</th><th colspan=2>"..i18n("http_page.distribution").."</th></tr>")
	 print("<tr><th>"..i18n("http_page.response_code_1xx").."</th><td style=\"text-align: right;\"><span id=http_response_num_1xx>".. formatValue(http["receiver"]["response"]["num_1xx"]) .."</span> <span id=trend_http_response_num_1xx></span></td><td colspan=2 rowspan=5>")

print [[
         <div class="pie-chart" id="httpResponses"></div>
         <script type='text/javascript'>

	     do_pie("#httpResponses", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_http_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, http_mode: "responses" }, "", refresh);
         </script>
]]
	 print("</td></tr>")
	 print("<tr><th>"..i18n("http_page.response_code_2xx").."</th><td style=\"text-align: right;\"><span id=http_response_num_2xx>".. formatValue(http["receiver"]["response"]["num_2xx"]) .."</span> <span id=trend_http_response_num_2xx></span></td></tr>")
	 print("<tr><th>"..i18n("http_page.response_code_3xx").."</th><td style=\"text-align: right;\"><span id=http_response_num_3xx>".. formatValue(http["receiver"]["response"]["num_3xx"]) .."</span> <span id=trend_http_response_num_3xx></span></td></tr>")
	 print("<tr><th>"..i18n("http_page.response_code_4xx").."</th><td style=\"text-align: right;\"><span id=http_response_num_4xx>".. formatValue(http["receiver"]["response"]["num_4xx"]) .."</span> <span id=trend_http_response_num_4xx></span></td></tr>")
	 print("<tr><th>"..i18n("http_page.response_code_5xx").."</th><td style=\"text-align: right;\"><span id=http_response_num_5xx>".. formatValue(http["receiver"]["response"]["num_5xx"]) .."</span> <span id=trend_http_response_num_5xx></span></td></tr>")

         vh = http["virtual_hosts"]
	 if(vh ~= nil) then
	    local now    = os.time()
	    local ago1h  = now - 3600
  	    num = table.len(vh)
	    if(num > 0) then
	       local ifId = getInterfaceId(ifname)
	       print("<tr><th rowspan="..(num+1).." width=20%>"..i18n("http_page.virtual_hosts").."</th><th>Name</th><th>"..i18n("http_page.traffic_sent").."</th><th>"..i18n("http_page.traffic_received").."</th><th>"..i18n("http_page.requests_served").."</th></tr>\n")
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
elseif (category ~= nil) then
   print("category="..category.."&")
end
print (hostinfo2url(host_info)..'";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")
if(ifstats.sprobe) then show_sprobe = true else show_sprobe = false end
if(ifstats.vlan)   then show_vlan = true else show_vlan = false end
-- Set the host table option
if(show_sprobe) then print ('flow_rows_option["sprobe"] = true;\n') end
if(show_vlan) then print ('flow_rows_option["vlan"] = true;\n') end


local active_flows_msg = i18n("flows_page.active_flows",{filter=""})
if not interface.isPacketInterface() then
   active_flows_msg = i18n("flows_page.recently_active_flows",{filter=""})
elseif interface.isPcapDumpInterface() then
   active_flows_msg = i18n("flows")
end

local dt_buttons = ''

if not category then
   local application_filter = ''
   if(application ~= nil) then
      application_filter = '<span class="glyphicon glyphicon-filter"></span>'
   end
   dt_buttons = dt_buttons.."'<div class=\"btn-group\"><button class=\"btn btn-link dropdown-toggle\" data-toggle=\"dropdown\">"..i18n("flows_page.applications").. " " .. application_filter .. "<span class=\"caret\"></span></button> <ul class=\"dropdown-menu\" role=\"menu\" >"
   dt_buttons = dt_buttons..'<li><a href="'..url..'&page=flows">'..i18n("flows_page.all_proto")..'</a></li>'

   for key, value in pairsByKeys(host["ndpi"] or {}, asc) do
      local class_active = ''
      if(key == application) then
	 class_active = ' class="active"'
      end
      dt_buttons = dt_buttons..'<li '..class_active..'><a href="'..url..'&page=flows&application='..key..'">'..key..'</a></li>'
   end

   dt_buttons = dt_buttons .. "</ul></div>',"
end

if not application then
   local category_filter = ''
   if(category ~= nil) then
      category_filter = '<span class="glyphicon glyphicon-filter"></span>'
   end
   dt_buttons = dt_buttons.."'<div class=\"btn-group\"><button class=\"btn btn-link dropdown-toggle\" data-toggle=\"dropdown\">"..i18n("users.categories").. " " .. category_filter .. "<span class=\"caret\"></span></button> <ul class=\"dropdown-menu pull-right\" role=\"menu\" >"
   dt_buttons = dt_buttons..'<li><a href="'..url..'&page=flows">'..i18n("flows_page.all_categories")..'</a></li>'

   for key, value in pairsByKeys(host["ndpi_categories"] or {}, asc) do
      local class_active = ''
      if(key == category) then
	 class_active = ' class="active"'
      end
      dt_buttons = dt_buttons..'<li '..class_active..'><a href="'..url..'&page=flows&category='..key..'">'..key..'</a></li>'
   end

   dt_buttons = dt_buttons .. "</ul></div>',"

end

dt_buttons = "["..dt_buttons.."]"

if(show_sprobe) then
print [[
  //console.log(url_update);
   flow_rows_option["sprobe"] = true;
   flow_rows_option["type"] = 'host';
   $("#table-flows").datatable({
      url: url_update,
      buttons: ]] print(dt_buttons) print[[,
      rowCallback: function ( row ) { return flow_table_setID(row); },
      tableCallback: function()  { $("#dt-bottom-details > .pull-left > p").first().append('. ]]
   print(i18n('flows_page.idle_flows_not_listed'))
   print[['); },
         showPagination: true,
]]
-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if(preference ~= "") then print ('perPage: '..preference.. ",\n") end

print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')


print('title: "'..active_flows_msg..'",')

print [[
	       title: "]] print(i18n("sflows_stats.active_flows")) print[[",
	        columns: [
			     {
         field: "key",
         hidden: true
         	},
         {
			     title: "]] print(i18n("info")) print[[",
				 field: "column_key",
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("application")) print[[",
				 field: "column_ndpi",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("sflows_stats.l4_proto")) print[[",
				 field: "column_proto_l4",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
  			     {
			     title: "]] print(i18n("sflows_stats.client_process")) print[[",
				 field: "column_client_process",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("sflows_stats.client_peer")) print[[",
				 field: "column_client",
				 sortable: true,
				 },
			     {
                             title: "]] print(i18n("sflows_stats.server_process")) print[[",
				 field: "column_server_process",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("sflows_stats.server_peer")) print[[",
				 field: "column_server",
				 sortable: true,
				 },
			     {
			     title: "]] print(i18n("duration")) print[[",
				 field: "column_duration",
				 sortable: true,
	 	             css: { 
			        textAlign: 'center'
			       }
			       },

]]

  prefs = ntop.getPrefs()

print [[
			     {
			     title: "]] print(i18n("breakdown")) print[[",
				 field: "column_breakdown",
				 sortable: false,
	 	             css: { 
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("sflows_stats.total_bytes")) print[[",
				 field: "column_bytes",
				 sortable: true,
	 	             css: { 
			        textAlign: 'right'
			     }
				 }
			     ]
	       });
       </script>
]]
else

print [[
  flow_rows_option["type"] = 'host';
	 $("#table-flows").datatable({
         url: url_update,
         buttons: ]] print(dt_buttons) print[[,
         rowCallback: function ( row ) { return flow_table_setID(row); },
         tableCallback: function()  { $("#dt-bottom-details > .pull-left > p").first().append('. ]]
print(i18n('flows_page.idle_flows_not_listed'))
print[['); },
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
                             title: "]] print(i18n("application")) print[[",
				 field: "column_ndpi",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },
			     {
			     title: "]] print(i18n("flows_page.l4_proto")) print[[",
				 field: "column_proto_l4",
				 sortable: true,
	 	             css: {
			        textAlign: 'center'
			     }
				 },]]

if(show_vlan) then

if(ifstats.sprobe) then
   print('{ title: "'..i18n("flows_page.source_id")..'",\n')
else
   if(ifstats.vlan) then
     print('{ title: "'..i18n("vlan")..'",\n')
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
			     title: "]] print(i18n("client")) print[[",
				 field: "column_client",
				 sortable: true,
				 },
			     {
			     title: "]] print(i18n("server")) print[[",
				 field: "column_server",
				 sortable: true,
				 },
			     {
                             title: "]] print(i18n("duration")) print[[",
				 field: "column_duration",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			       }
			       },
			     {
			     title: "]] print(i18n("flows_page.actual_throughput")) print[[",
				 field: "column_thpt",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }
				 },
			     {
                             title: "]] print(i18n("flows_page.total_bytes")) print[[",
				 field: "column_bytes",
				 sortable: true,
	 	             css: {
			        textAlign: 'right'
			     }

				 }
			     ,{
                             title: "]] print(i18n("info")) print[[",
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
elseif(page == "snmp" and ntop.isEnterprise()) then
   local snmp_devices = get_snmp_devices()

   if snmp_devices[host_ip] == nil then -- host has not been configured
      local msg = i18n("snmp_page.not_configured_as_snmp_device_message",{host_ip=host_ip})
      msg = msg.." "..i18n("snmp_page.guide_snmp_page_message",{url=ntop.getHttpPrefix().."/lua/pro/enterprise/snmpdevices_stats.lua"})

      print("<div class='alert alert-info'><i class='fa fa-info-circle fa-lg' aria-hidden='true'></i> "..msg.."</div>")
   else
      local snmp_device = require "snmp_device"
      local snmp_device_ip = snmp_devices[host_ip]["ip"]
      snmp_device.init(snmp_device_ip)

      local cache_status = snmp_device.get_cache_status()
      if not cache_status["system"] or cache_status["system"]["last_updated"] < os.time() - 86400 then
	 local res = snmp_device.cache_system()
	 if res["status"] ~= "OK" then
	    snmp_handle_cache_errors(snmp_device_ip, res)
	 end
      end

      print_snmp_device_system_table(snmp_device.get_device())
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

dofile(dirs.installdir .. "/scripts/lua/show_geolocation_note.lua")

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

elseif(page == "contacts") then

if(num > 0) then
   mode = "embed"
   if(host["name"] == nil) then host["name"] = getResolvedAddress(hostkey2hostinfo(host["ip"])) end
   name = host["name"]
   dofile(dirs.installdir .. "/scripts/lua/hosts_interaction.lua")

   print("<table class=\"table table-bordered table-striped\">\n")
   print("<tr><th width=50%>"..i18n("contacts_page.client_contacts_initiator").."</th><th width=50%>"..i18n("contacts_page.server_contacts_receiver").."</th></tr>\n")

   print("<tr>")

   if(cnum  == 0) then
      print("<td>"..i18n("contacts_page.no_client_contacts_so_far").."</td>")
   else
      print("<td><table class=\"table table-bordered table-striped\">\n")
      print("<tr><th width=75%>"..i18n("contacts_page.server_address").."</th><th>"..i18n("contacts_page.contacts").."</th></tr>\n")

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
      print("<td>"..i18n("contacts_page.no_server_contacts_so_far").."</td>")
   else
      print("<td><table class=\"table table-bordered table-striped\">\n")
      print("<tr><th width=75%>"..i18n("contacts_page.client_address").."</th><th>"..i18n("contacts_page.contacts").."</th></tr>\n")

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
   print(i18n("contacts_page.no_contacts_message"))
end

elseif(page == "alerts") then

   drawAlertSourceSettings("host", hostkey,
      i18n("show_alerts.host_delete_config_btn", {host=host_name}), "show_alerts.host_delete_config_confirm",
      "host_details.lua", {ifid=ifId, host=hostkey},
      host_name, "host", {host_ip=host_ip, host_vlan=host_vlan})

elseif (page == "quotas" and ntop.isEnterprise() and host_pool_id ~= host_pools_utils.DEFAULT_POOL_ID and ifstats.inline) then
   local page_params = {ifid=ifId, pool=host_pool_id, host=hostkey, page=page}
   host_pools_utils.printQuotas(host_pool_id, host, page_params)

elseif (page == "config") then
   local dump_status = host["dump_host_traffic"]
   local trigger_alerts = true

   if(not isAdministrator()) then
      return
   end

   local top_hiddens = ntop.getMembersCache(getHideFromTopSet(ifId) or {})
   local is_top_hidden = swapKeysValues(top_hiddens)[hostkey_compact] ~= nil

   if _SERVER["REQUEST_METHOD"] == "POST" then
      if(host["localhost"] == true and is_packetdump_enabled) then
         if(_POST["dump_traffic"] == "1") then
            dump_status = true
         else
            dump_status = false
         end
         interface.setHostDumpPolicy(dump_status, host_info["host"], host_vlan)
      end

      if host["localhost"] == true then
         if _POST["trigger_alerts"] ~= "1" then
            trigger_alerts = false
         else
            trigger_alerts = true
         end

         ntop.setHashCache(get_alerts_suppressed_hash_name(getInterfaceId(ifname)), hostkey, tostring(trigger_alerts))

         interface.select(ifname)
         interface.refreshHostsAlertsConfiguration(host_ip, host_vlan)
      end

      if(ifstats.inline and (host.localhost or host.systemhost)) then
         local drop_host_traffic = _POST["drop_host_traffic"]
         local host_key = hostinfo2hostkey(host_info)

         if(drop_host_traffic ~= "1") then
            ntop.delHashCache("ntopng.prefs.drop_host_traffic", host_key)
         else
            ntop.setHashCache("ntopng.prefs.drop_host_traffic", host_key, "true")
         end

         interface.updateHostTrafficPolicy(host_info["host"], host_vlan)
      end

      local new_top_hidden = (_POST["top_hidden"] == "1")

      if new_top_hidden ~= is_top_hidden then
         local set_name = getHideFromTopSet(ifId)

         if new_top_hidden then
            ntop.setMembersCache(set_name, hostkey_compact)
         else
            ntop.delMembersCache(set_name, hostkey_compact)
         end

         is_top_hidden = new_top_hidden
         interface.reloadHideFromTop()
      end
   end

   if(host["localhost"] == true and is_packetdump_enabled) then
      if(dump_status) then
         dump_traffic_checked = 'checked="checked"'
         dump_traffic_value = "false" -- Opposite
      else
         dump_traffic_checked = ""
         dump_traffic_value = "true" -- Opposite
      end
   end

   local trigger_alerts_checked

   if host["localhost"] == true then
      trigger_alerts = ntop.getHashCache(get_alerts_suppressed_hash_name(getInterfaceId(ifname)), hostkey)

      if trigger_alerts == "false" then
         trigger_alerts = false
         trigger_alerts_checked = ""
      else
         trigger_alerts = true
         trigger_alerts_checked = "checked"
      end
   end

   print[[
   <form id="host_config" class="form-inline" method="post">
   <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   <table class="table table-bordered table-striped">
      <tr>
         <th>]] print(i18n("host_config.host_alias")) print[[</th>
         <td>
               <input type="text" name="custom_name" class="form-control" placeholder="Custom Name" style="width: 280px;" value="]]
   if(host["label"] ~= nil) then print(host["label"]) end
   print[["></input> ]]

   print [[
         </td>
      </tr>]]

   if not ifstats.isView then
      printPoolChangeDropdown(ifId, host_pool_id, have_nedge)
   end

   local top_hidden_checked = ternary(is_top_hidden, "checked", "")

   print [[<tr>
         <th>]] print(i18n("host_config.hide_from_top")) print[[</th>
         <td>
               <input type="checkbox" name="top_hidden" value="1" ]] print(top_hidden_checked) print[[>
                  ]] print(i18n("host_config.hide_host_from_top_descr", {host=host["name"]})) print[[
               </input>
         </td>
      </tr>]]

   if host["localhost"] then
      print [[<tr>
         <th>]] print(i18n("host_config.trigger_host_alerts")) print[[</th>
         <td>
               <input type="checkbox" name="trigger_alerts" value="1" ]] print(trigger_alerts_checked) print[[>
                  <i class="fa fa-exclamation-triangle fa-lg"></i>
                  ]] print(i18n("host_config.trigger_alerts_for_host",{host=host["name"]})) print[[
               </input>
         </td>
      </tr>]]
   end

   if(host["localhost"] == true and is_packetdump_enabled and not have_nedge) then
      print [[<tr>
         <th>]] print(i18n("host_config.dump_host_traffic")) print[[</th>
         <td>
               <input type="checkbox" name="dump_traffic" value="1" ]] print(dump_traffic_checked) print[[>
                  <i class="fa fa-hdd-o fa-lg"></i>
                  <a href="]] print(ntop.getHttpPrefix()) print[[/lua/if_stats.lua?ifid=]] print(getInterfaceId(ifname).."") print[[&page=packetdump">]] print(i18n("host_config.dump_traffic")) print[[</a>
               </input>]]

      local dump_status_tap = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_tap')
      local dump_status_disk = ntop.getCache('ntopng.prefs.'..ifstats.name..'.dump_disk')
      if dump_status_tap ~= "true" and dump_status_disk ~= "true" then
	 print[[<small>]]
	 print(i18n("host_config.dump_host_traffic_description",
		    {to_disk = i18n("packetdump_page.packet_dump_to_disk"),
		     to_tap = i18n("packetdump_page.dump_traffic_to_tap"),
		     url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=packetdump"}))
	 print[[</small>]]
      end

      print[[
         </td>
      </tr>]]
   end

   if(ifstats.inline and (host.localhost or host.systemhost)) then
      -- Traffic policy
      print("<tr><th>" .. i18n("host_config.host_traffic_policy") .. "</th><td>")

      if(host["localhost"] == true) then
         local host_key = hostinfo2hostkey(host_info)
         drop_traffic = ntop.getHashCache("ntopng.prefs.drop_host_traffic", host_key)

         if(drop_traffic == "true") then
            drop_traffic_checked = 'checked="checked"'
            drop_traffic_value = "false" -- Opposite
         else
            drop_traffic_checked = ""
            drop_traffic_value = "true" -- Opposite
         end

         print('<input type="checkbox" name="drop_host_traffic" value="1" '..drop_traffic_checked..'"> '..i18n("host_config.drop_all_host_traffic")..'</input> &nbsp;')
      end

      print[[<a class="btn btn-default btn-sm" href="]]
      print(ntop.getHttpPrefix())

      if not have_nedge then
         print[[/lua/if_stats.lua?page=filtering&pool=]]
         print(tostring(host["host_pool_id"]))
         print[[#protocols">]] print(i18n("host_config.modify_host_pool_policy_btn")) print[[</a>]]
      else
         print[[/lua/pro/nedge/admin/nf_edit_user.lua]]
         print(ternary(host_pool_id == host_pools_utils.DEFAULT_POOL_ID, "", "?username=" .. host_pools_utils.poolIdToUsername(host_pool_id)))
         print[[">]] print(i18n("host_config.modify_host_pool_policy_btn")) print[[</a>]]
      end

      print('</td></tr>')

      print('</form>')
      print('</td></tr>')
   end

   print[[
   </table>
   <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>
   </form>
   <script>
      aysHandleForm("#host_config");
   </script>]]

elseif(page == "historical") then

host_url = "host="..host_ip
host_key = host_ip
if(host_vlan and (host_vlan > 0)) then
   host_url = host_url.."&vlan="..host_vlan
   host_key = host_key.."@"..host_vlan
end

local schema = _GET["ts_schema"] or "host:traffic"
local selected_epoch = _GET["epoch"] or ""

local tags = {
   ifid = ifId,
   host = host_key,
   protocol = _GET["protocol"],
   category = _GET["category"],
}

local url = ntop.getHttpPrefix()..'/lua/host_details.lua?ifid='..ifId..'&'..host_url..'&page=historical'

drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
   top_protocols = "top:host:ndpi",
   top_categories = "top:host:ndpi_categories",
   show_historical = true,
   timeseries = {
      {schema="host:traffic",                label=i18n("traffic")},
      {schema="host:flows",                  label=i18n("graphs.active_flows")},
   }
})

elseif(page == "traffic_report") then
   dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/traffic_report.lua")
elseif(page == "sprobe") then


print [[
  <br>
  <!-- Left Tab -->
  <div class="tabbable tabs-left">

    <ul class="nav nav-tabs">
      <li class="active"><a href="#Users" data-toggle="tab">]] print(i18n("sprobe_page.users")) print[[</a></li>
      <li><a href="#Processes" data-toggle="tab">]] print(i18n("sprobe_page.processes")) print[[</a></li>
      <li ><a href="#Tree" data-toggle="tab">]] print(i18n("sprobe_page.tree")) print[[</a></li>
    </ul>

    <!-- Tab content-->
    <div class="tab-content">
]]

print [[
      <div class="tab-pane active" id="Users">
      Show :
          <div class="btn-group btn-toggle btn-sm" data-toggle="buttons" id="show_users">
            <label class="btn btn-default btn-sm active">
              <input type="radio" name="show_users" value="All">]] print(i18n("all")) print[[</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_users" value="Client" checked="">]] print(i18n("client")) print[[</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_users" value="Server" checked="">]] print(i18n("server")) print[[</label>
          </div>
        Aggregated by :
          <div class="btn-group">
            <button id="aggregation_users_displayed" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">
            Traffic <span class="caret"></span></button>
            <ul class="dropdown-menu" id="aggregation_users">
            <li><a>]] print(i18n("traffic")) print[[</a></li>
            <li><a>]] print(i18n("sprobe_page.active_memory")) print[[</a></li>
            <!-- <li><a>print(i18n("sprobe_page.latency"))</a></li> -->
            </ul>
          </div><!-- /btn-group -->
         <br/>
         <br/>
        <table class="table table-bordered table-striped">
          <tr>
            <th class="text-center span3">]] print(i18n("sprobe_page.top_users")) print[[</th>
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
              <input type="radio" name="show_processes" value="All">]] print(i18n("all")) print[[</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_processes" value="Client" checked="">]] print(i18n("client")) print[[</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_processes" value="Server" checked="">]] print(i18n("server")) print[[</label>
          </div>
        Aggregated by :
          <div class="btn-group">
            <button id="aggregation_processes_displayed" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">Traffic <span class="caret"></span></button>
            <ul class="dropdown-menu" id="aggregation_processes">
            <li><a>]] print(i18n("traffic")) print[[</a></li>
            <li><a>]] print(i18n("sprobe_page.active_memory")) print[[</a></li>
            <!-- <li><a>print(i18n("sprobe_page.latency"))</a></li> -->
            </ul>
          </div><!-- /btn-group -->
         <br/>
         <br/>
        <table class="table table-bordered table-striped">
          <tr>
            <th class="text-center span3">]] print(i18n("sprobe_page.top_processes")) print[[</th>
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
              <input type="radio" name="show_tree" value="All">]] print(i18n("all")) print[[</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_tree" value="Client" checked="">]] print(i18n("client")) print[[</label>
            <label class="btn btn-default btn-sm">
              <input type="radio" name="show_tree" value="Server" checked="">]] print(i18n("server")) print[[</label>
          </div>
        Aggregated by :
          <div class="btn-group">
            <button id="aggregation_tree_displayed" class="btn btn-default btn-sm dropdown-toggle" data-toggle="dropdown">Traffic <span class="caret"></span></button>
            <ul class="dropdown-menu" id="aggregation_tree">
            <li><a>]] print(i18n("traffic")) print[[</a></li>
            <li><a>]] print(i18n("sprobe_page.active_memory")) print[[</a></li>
            <!-- <li><a>print(i18n("sprobe_page.latency"))</a></li> -->
            </ul>
          </div><!-- /btn-group -->
         <br/>
         <br/>
        <table class="table table-bordered table-striped">
          <tr>
            <th class="text-center span3">]] print(i18n("sprobe_page.processes_traffic_tree")) print[[
            </th>
             <td class="span3">
              <div id="sequence_sunburst" >
                <div id="sequence_processTree" class="sequence"></div>
                <div id="chart_processTree" class="chart"></div>
                <div align="center" class="info">]] print(i18n("sprobe_page.show_more_info")) print[[</div>
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
   print("var last_tcp_keep_alive = " .. host["tcp.packets.keep_alive"] .. ";\n")

   if isBridgeInterface(ifstats) then
      print("var last_dropped_flows = " .. (host["flows.dropped"] or 0) .. ";\n")
   end

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
   		    /* error: function(content) { alert("]] print(i18n("mac_details.json_error_inactive", {product=info["product"]})) print[["); }, */
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
   			$('#pkt_keep_alive').html(formatPackets(host["tcp.packets.keep_alive"]));
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

   if isBridgeInterface(ifstats) then
print [[
                        if(host["flows.dropped"] > 0) {
                          if(host["flows.dropped"] == last_dropped_flows) {
                            $('#trend_bridge_dropped_flows').html("<i class=\"fa fa-minus\"></i>");
                          } else {
                            $('#trend_bridge_dropped_flows').html("<i class=\"fa fa-arrow-up\"></i>");
                          }

                          $('#bridge_dropped_flows').html(addCommas(host["flows.dropped"]));

                          $('#bridge_dropped_flows_tr').show();
                          last_dropped_flows = host["flows.dropped"];
                        } else {
                          $('#bridge_dropped_flows_tr').hide();
                        }
]]
   end

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
 		        $('#pkt_keep_alive_trend').html(drawTrend(host["tcp.packets.keep_alive"], last_tcp_keep_alive, ""));

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
   			last_tcp_keep_alive = host["tcp.packets.keep_alive"];
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
