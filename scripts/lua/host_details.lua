--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   require "snmp_utils"
   shaper_utils = require("shaper_utils")
   host_pools_utils = require "host_pools_utils"
end

require "lua_utils"
local graph_utils = require "graph_utils"
local alert_utils = require "alert_utils"
require "historical_utils"

local json = require ("dkjson")
local host_pools_utils = require "host_pools_utils"
local discover = require "discover_utils"
local page_utils = require "page_utils"
local template = require "template_utils"
local mud_utils = require "mud_utils"
local fingerprint_utils = require "fingerprint_utils"
local companion_interface_utils = require "companion_interface_utils"
local flow_consts = require "flow_consts"
local alert_consts = require "alert_consts"
local plugins_utils = require "plugins_utils"
local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

local info = ntop.getInfo()

local have_nedge = ntop.isnEdge()

local debug_hosts = false

local page        = _GET["page"]
local protocol_id = _GET["protocol"]
local application = _GET["application"]
local category    = _GET["category"]
local host_info   = url2hostinfo(_GET)
local host_ip     = host_info["host"]
local host_vlan   = host_info["vlan"] or 0
local always_show_hist = _GET["always_show_hist"]
local format_utils = require("format_utils")

local ntopinfo    = ntop.getInfo()

if not isEmptyString(_GET["ifid"]) then
  interface.select(_GET["ifid"])
else
  interface.select(ifname)
end

local ifstats = interface.getStats()

ifId = ifstats.id

local charts_available = areHostTimeseriesEnabled(ifId, host_info)

local is_pcap_dump = interface.isPcapDumpInterface()

local host = nil
local family = nil

local prefs = ntop.getPrefs()

local hostkey = hostinfo2hostkey(host_info, nil, true --[[ force show vlan --]])
local hostkey_compact = hostinfo2hostkey(host_info) -- do not force vlan

if not host_ip then
   sendHTTPContentTypeHeader('text/html')

   page_utils.print_header()
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> " .. i18n("host_details.host_parameter_missing_message") .. "</div>")
   return
end

-- print(">>>") print(host_info["host"]) print("<<<")
if(debug_hosts) then traceError(TRACE_DEBUG,TRACE_CONSOLE, i18n("host_details.trace_debug_host_info",{hostinfo=host_info["host"],vlan=host_vlan}).."\n") end


local host = interface.getHostInfo(host_info["host"], host_vlan)

local tskey

if _GET["tskey"] then
   tskey = _GET["tskey"]
elseif host then
   tskey = host["tskey"]
else
   tskey = host_key
end

local restoreFailed = false
local restoreInProgress = false

if((host == nil) and ((_GET["mode"] == "restore"))) then
   restoreFailed = not interface.restoreHost(host_info["host"], host_vlan)

   if(not restoreFailed) then
      restoreInProgress = true
   end
end

local function printRestoreHostBanner(hidden)
   print('<div id=\"host_purged\" class=\"alert alert-danger\" ')
   if hidden then
      print('style=\"display:none;\"')
   end
   print('><i class="fas fa-exclamation-triangle"></i>')
   print[[<form class="form-inline" id="host_restore_form" method="get">]]
   print[[<input type="hidden" name="mode" value="restore">
   <input type="hidden" name="host" value="]] print(host_info["host"]) print[[">]]
   if((host_info["vlan"] ~= nil) and ifstats.vlan) then
      print[[<input type="hidden" name="vlan" value="]] print(host_info["vlan"]) print[[">]]
   end
   print[[</form>]]
   print[[ ]] print(i18n("host_details.restore_from_cache_message_v1",{host=hostinfo2hostkey(host_info), js_code="\"javascript:void(0);\" onclick=\"$(\'#host_restore_form\').submit();\""}))
   print("</div>")
end

local top_sites     = ((host ~= nil) and host["sites"] and json.decode(host["sites"])) or {}
local top_sites_old = ((host ~= nil) and host["sites.old"] and json.decode(host["sites.old"])) or {}
local labelKey      = host_info["host"].."@"..host_info["vlan"]
local host_pool_id  = nil

if (host ~= nil) then
   charts_available = charts_available and host["localhost"]

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

local only_historical = (host == nil) and ((page == "historical") or (page == "config") or (page == "alerts"))
local host_label

if(host == nil) and (not only_historical) then
      -- We need to check if this is an aggregated host
      sendHTTPContentTypeHeader('text/html')

      page_utils.set_active_menu_entry(page_utils.menu_entries.hosts)
      if page == "alerts" then
	 print('<script>window.location.href = "')
	 print(ntop.getHttpPrefix())
	 print('/lua/show_alerts.lua?entity='..alert_consts.alertEntity("host")..'&entity_val=')
	 print(hostkey)
	 print('";</script>')
      elseif restoreInProgress then
	 dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
	 print('<div class=\"alert alert-info\"> '.. i18n("host_details.host_restore_in_progress",{host=hostinfo2hostkey(host_info)}) .. " ")
	 print('<i class="fas fa-spinner fa-spin"></i>')
	 print("</div>")
	 print[[<script type='text/javascript'>
   let recheckInterval = null;

   function recheckHostRestore() {
      $.ajax({
	type: 'GET',
	url: ']]
      print (ntop.getHttpPrefix())
      print [[/lua/host_stats.lua',
	data: { ifid: "]] print(ifId.."")  print('", '..hostinfo2json(host_info)) print [[ },
	success: function(content) {
	 if(content && content != '"{}"') {
	    /* Host found, reload the page */
	    clearInterval(recheckInterval);
	    recheckInterval = null;
	    location.reload();
	 }
	}
      });
   }

   recheckInterval = setInterval(recheckHostRestore, 2000);
   recheckHostRestore();
</script>]]
	 dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
      else
	 dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
	 if(not(restoreFailed) and (host_info ~= nil) and canRestoreHost(ifId, host_info["host"], host_vlan)) then
	    printRestoreHostBanner()
	 else
	    print('<div class=\"alert alert-danger\"><i class="fas fa-exclamation-triangle"></i> ')
	    print(i18n("host_details.host_cannot_be_found_message",{host=hostinfo2hostkey(host_info)}) .. " ")
	    print(purgedErrorString())
	    print("</div>")
	 end

	 dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
      return
   end
else
   sendHTTPContentTypeHeader('text/html')


   page_utils.set_active_menu_entry(page_utils.menu_entries.hosts, nil, i18n("host", { host = host_info["host"] }))

   print("<link href=\""..ntop.getHttpPrefix().."/css/tablesorted.css\" rel=\"stylesheet\">\n")
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

   --   Added global javascript variable, in order to disable the refresh of pie chart in case
   --  of historical interface
   print('\n<script>var refresh = 3000 /* ms */;</script>\n')

   if _POST["action"] == "reset_stats" and isAdministrator() then
      if interface.resetHostStats(hostkey) then
         print("<div class=\"alert alert alert-success\">")
         print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
         print(i18n("host_details.reset_stats_in_progress"))
         print("</div>")
      end
   end

   if host == nil then
      -- only_historical = true here
      host = hostkey2hostinfo(host_info["host"] .. "@" .. host_vlan)
   end

   if(_POST["custom_name"] ~=nil) and isAdministrator() then
      setHostAltName(hostinfo2hostkey(host_info), _POST["custom_name"])
   end

   host_label = hostinfo2label(host)

   if canRestoreHost(ifId, host_info["host"], host_vlan) then
      printRestoreHostBanner(true --[[ hidden ]])
   else
      print('<div style=\"display:none;\" id=\"host_purged\" class=\"alert alert-danger\"><i class="fas fa-exclamation-triangle"></i>&nbsp;'..i18n("details.host_purged")..'</div>')
   end

   local title = i18n("host_details.host")..": "..host_info["host"]
   if host["broadcast_domain_host"] then
      title = title.." <i class='fas fa-sitemap' aria-hidden='true' title='"..i18n("hosts_stats.label_broadcast_domain_host").."'></i>"
   end

   if host.dhcpHost then
      title = title.." <i class='fas fa-flash' aria-hidden='true' title='DHCP Host'></i>"
   end

   local url = hostinfo2detailsurl(host, {tskey = _GET["tskey"]})

   local has_snmp_location = info["version.enterprise_edition"] and host_has_snmp_location(host["mac"])

   page_utils.print_navbar(title, url,
			   {
			      {
				 hidden = only_historical,
				 active = page == "overview" or page == nil,
				 page_name = "overview",
				 label = "<i class=\"fas fa-lg fa-home\"></i>",
			      },
			      {
				 hidden = only_historical,
				 active = page == "traffic",
				 page_name = "traffic",
				 label = i18n("traffic"),
			      },
			      {
				 hidden = have_nedge or only_historical or (host["packets.sent"] + host["packets.rcvd"] == 0),
				 active = page == "packets",
				 page_name = "packets",
				 label = i18n("packets"),
			      },
			      {
				 hidden = only_historical,
				 active = page == "ports",
				 page_name = "ports",
				 label = i18n("ports"),
			      },
			      {
				 hidden = only_historical or interface.isLoopback(),
				 active = page == "peers",
				 page_name = "peers",
				 label = i18n("peers"),
			      },
			      {
				 hidden = have_nedge or only_historical or not host["localhost"] or (not host["ICMPv4"] and not host["ICMPv6"]),
				 active = page == "ICMP",
				 page_name = "ICMP",
				 label = i18n("icmp"),
			      },
			      {
				 hidden = only_historical,
				 active = page == "ndpi",
				 page_name = "ndpi",
				 label = i18n("applications"),
			      },
			      {
				 hidden = have_nedge or only_historical or not host["localhost"],
				 active = page == "dns",
				 page_name = "dns",
				 label = i18n("dns"),
			      },
			      {
				 hidden = have_nedge or only_historical or not fingerprint_utils.has_fingerprint_stats(host, "ja3"),
				 active = page == "tls",
				 page_name = "tls",
				 label = i18n("tls"),
			      },
			      {
				 hidden = have_nedge or only_historical or not fingerprint_utils.has_fingerprint_stats(host, "hassh"),
				 active = page == "ssh",
				 page_name = "ssh",
				 label = i18n("ssh"),
			      },
			      {
				 hidden = only_historical
				    or have_nedge
				    or not host["localhost"]
				    or not host["http"]
				    or (host["http"]["sender"]["query"]["total"] == 0
				           and host["http"]["receiver"]["response"]["total"] == 0
				           and table.len(host["http"]["virtual_hosts"] or {}) == 0),
				 active = page == "http",
				 page_name = "http",
				 label = i18n("http"),
				 badge_num = host["active_http_hosts"],
			      },
			      {
				 hidden = only_historical,
				 active = page == "flows",
				 page_name = "flows",
				 label = i18n("flows"),
			      },
			      {
				 hidden = only_historical or not host["localhost"] or (table.len(top_sites) == 0 and table.len(top_sites_old) == 0),
				 active = page == "sites",
				 page_name = "sites",
				 label = i18n("sites_page.sites"),
			      },
			      {
				 hidden = not has_snmp_location,
				 active = page == "snmp",
				 page_name = "snmp",
				 label = i18n("host_details.snmp"),
			      },
			      {
				 hidden = only_historical or not host["systemhost"] or not interface.hasEBPF(),
				 active = page == "processes",
				 page_name = "processes",
				 label = i18n("user_info.processes"),
			      },
			      {
				 hidden = only_historical or host["is_broadcast"] or host["is_multicast"] or not ntop.hasGeoIP(),
				 active = page == "geomap",
				 page_name = "geomap",
				 label = "<i class='fas fa-lg fa-globe'></i>",
			      },
			      {
				 hidden = not areAlertsEnabled(),
				 active = page == "alerts",
				 page_name = "alerts",
				 label = "<i class=\"fas fa-lg fa-exclamation-triangle\"></i>",
			      },
			      {
				 hidden = not charts_available,
				 active = page == "historical",
				 page_name = "historical",
				 label = "<i class='fas fa-lg fa-chart-area'></i>",
			      },
			      {
				 hidden = only_historical or (not host["localhost"]) or (not hasTrafficReport()),
				 active = page == "traffic_report",
				 page_name = "traffic_report",
				 label = "<i class='fas fa-lg fa-file-alt report-icon'></i>",
			      },
			      {
				 hidden = only_historical or not ntop.isEnterpriseM() or not ifstats.inline or not host_pool_id ~= host_pools_utils.DEFAULT_POOL_ID,
				 active = page == "quotas",
				 page_name = "quotas",
				 label = i18n("quotas"),
			      },
			      {
				 hidden = not isAdministrator() or interface.isPcapDumpInterface(),
				 active = page == "config",
				 page_name = "config",
				 label = "<i class=\"fas fa-lg fa-cog\"></i></a></li>",
			      },
			   }
   )

   -- tprint(host.bins)
local macinfo = interface.getMacInfo(host["mac"])
local has_snmp_location = host['localhost'] and (host["mac"] ~= "")
   and (info["version.enterprise_edition"]) and host_has_snmp_location(host["mac"])
   and isAllowedSystemInterface()

print[[<form id="delete-mud-form" method="post">]]
print[[<input name="action" type="hidden" value="delete_mud" />]]
print[[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />]]
print[[</form>]]

if(isAdministrator() and (_POST["action"] == "delete_mud")) then
  mud_utils.deleteHostMUD(ifId, host_info.host)
end

local function printMudRecordingActions()
   if mud_utils.hasRecordedMUD(ifId, host_info.host) then
      print(" <a style=\"margin-left: 0.5em\" href=\""..ntop.getHttpPrefix().."/lua/rest/v1/get/host/mud.lua?host=".. host_info.host .."\"><i class=\"fas fa-download\"></i></a>")

      if isAdministrator() then
	 print("<a style=\"margin-left: 1em\" href=\"#\" onclick=\"$('#delete-mud-form').submit();\"><i class=\"fas fa-trash\"></i></a>")
      end
   end
end

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
	    print('<a href="'..ntop.getHttpPrefix()..'/lua/mac_details.lua?'..hostinfo2url(macinfo)..'&page=config"><i class="fas fa-cog"></i></a>\n')
	 else
	    print("&nbsp;")
	 end

	 print('</td></tr>')
      end

      if has_snmp_location then
         print_host_snmp_location(host["mac"], hostinfo2detailsurl(host, {page = "snmp"}))
      end

      print("</tr>")

      print("<tr><th>"..i18n("ip_address").."</th><td colspan=1>" .. host["ip"])
      if(host.childSafe == true) then print(getSafeChildIcon()) end

     if(host.os ~= 0) then
       print(" "..discover.getOsIcon(host.os).." ")
     end

      historicalProtoHostHref(getInterfaceId(ifname), host["ip"], nil, nil, nil)

      if(host["local_network_name"] ~= nil) then
	 print(" [&nbsp;<A HREF='"..ntop.getHttpPrefix().."/lua/network_details.lua?network="..host["local_network_id"].."&page=historical'>".. host["local_network_name"].."</A>&nbsp;]")
      end

      if((host["city"] ~= nil) and (host["city"] ~= "")) then
         print(" [ " .. host["city"] .." "..getFlag(host["country"]).." ]")
      end

      print[[</td><td><span>]] print(i18n(ternary(have_nedge, "nedge.user", "details.host_pool"))..": ")
      print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/hosts_stats.lua?pool=]] print(host_pool_id) print[[">]] print(host_pools_utils.getPoolName(ifId, host_pool_id)) print[[</a></span>]]
      print[[&nbsp;]]
      print(hostinfo2detailshref(host, {page = "config"}, '<i class="fas fa-sm fa-cog" aria-hidden="true"></i>'))
      print("</td></tr>")
   else
      if(host["mac"] ~= nil) then
	 print("<tr><th>"..i18n("mac_address").."</th><td colspan=2>" .. host["mac"].. "</td></tr>\n")
      end
   end

   if host["vlan"] and host["vlan"] > 0 then
      print("<tr><th>")
      print(i18n("details.vlan_id"))
      print("</th><td colspan=2><A HREF="..ntop.getHttpPrefix().."/lua/hosts_stats.lua?vlan="..host["vlan"]..">"..host["vlan"].."</A></td></tr>\n")
   end

   if(host["os"] ~= "" and host["os"] ~= 0) then
      print("<tr>")
      if(host["os"] ~= "") then
        local os_detail = ""
        if not isEmptyString(host["os_detail"]) then
          os_detail = os_detail .. " [" .. host["os_detail"] .. "]"
        end

         print("<th>"..i18n("os").."</th><td> <A HREF='"..ntop.getHttpPrefix().."/lua/hosts_stats.lua?os=" .. host["os"] .."'>".. discover.getOsAndIcon(host["os"])  .."</A>".. os_detail .."</td><td></td>\n")
      else
         print("<th></th><td></td>\n")
      end
      print("</tr>")
   end

   if((host["asn"] ~= nil) and (host["asn"] > 0)) then
      print("<tr><th>"..i18n("asn").."</th><td>")

      print("<A HREF='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=".. host.asn .."'>"..host.asname.."</A> [ "..i18n("asn").." <A HREF='" .. ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?asn=".. host.asn.."'>".. host.asn.."</A> ]</td>")
      print('<td><A HREF="http://itools.com/tool/arin-whois-domain-search?q='.. host["ip"] ..'&submit=Look+up">'..i18n("details.whois_lookup")..'</A> <i class="fas fa-external-link-alt"></i></td>')
      print("</td></tr>\n")
   end

   if(host["ip"] ~= nil) then
      print("<tr><th>"..i18n("name").."</th>")

      if(isAdministrator()) then
	 print("<td><A HREF=\"http://" .. getIpUrl(host["ip"]) .. "\"> <span id=name>")
      else
	 print("<td colspan=2>")
      end

      if ntop.shouldResolveHost(host["ip"]) then
	 print("<img border=0 src=".. ntop.getHttpPrefix() .. "/img/throbber.gif style=\"vertical-align:text-top;\" id=throbber> ")
      end

      -- tprint(host) io.write("\n")
      print(host_label .. "</span></A> <i class=\"fas fa-external-link-alt\"></i> ")

      if host["is_blacklisted"] then
	 print(" <i class=\'fas fa-ban fa-sm\' title=\'"..i18n("hosts_stats.blacklisted").."\'></i>")
      end

      print(hostinfo2detailshref(host, {page = "config"}, ' <i class="fas fa-sm fa-cog" aria-hidden="true"></i> '))

      if(host["localhost"] == true) then
	 print('<span class="badge badge-success">'..i18n("details.label_local_host")..'</span>')
      else print('<span class="badge badge-secondary">'..i18n("details.label_remote")..'</span>')
      end

      if(host["is_multicast"] == true) then print(' <span class="badge badge-secondary">Multicast</span> ')
      end

      if(host["is_broadcast"] == true) then print(' <span class="badge badge-secondary">Broadcast</span> ')
      end

      if host["broadcast_domain_host"] then
	 print(" <span class='badge badge-info'><i class='fas fa-sitemap' title='"..i18n("hosts_stats.label_broadcast_domain_host").."'></i></span>")
      end

      if(host["privatehost"] == true) then print(' <span class="badge badge-warning">'..i18n("details.label_private_ip")..'</span>') end
      if(host["systemhost"] == true) then print(' <span class="badge badge-info"><i class=\"fas fa-flag\" title=\"'..i18n("details.label_system_ip")..'\"></i></span>') end
      if(host["is_blacklisted"] == true) then print(' <span class="badge badge-danger">'..i18n("details.label_blacklisted_host")..'</span>') end
      if((host["privatehost"] == false) and (host["is_multicast"] == false) and (host["is_broadcast"] == false)) then
	 print(' <A HREF="https://www.virustotal.com/gui/ip-address/'.. host["ip"] ..'/detection" target=_blank><img  width="100" height="20" src=\"'..ntop.getHttpPrefix()..'/img/virustotal.svg\"></A> <i class=\"fas fa-external-link-alt\"></i>')
   end
      
      print("</td><td></td>\n")
   end

if(host["num_alerts"] > 0) then
   print("<tr><th><i class=\"fas fa-exclamation-triangle\" style='color: #B94A48;'></i> "..i18n("show_alerts.engaged_alerts").."</th><td colspan=2></li>"..hostinfo2detailshref(host, {page = "alerts"}, "<span id=num_alerts>"..host["num_alerts"] .. "</span>").."<span id=alerts_trend></span></td></tr>\n")
end

if isScoreEnabled() then
   local score_chart = ""

   if charts_available then
      score_chart = hostinfo2detailshref(host, {page = "historical", tskey = tskey, ts_schema = "host:score"}, '<i class="fas fa-chart-area fa-sm"></i>')
   end

   print("<tr><th>"..i18n("score").." " .. score_chart .."</th><td colspan=2></li> <span id=score>"..host["score"] .. "</span> <span id=score_trend></span></td></tr>\n")
end

-- Active monitoring
if am_utils and am_utils.isMeasurementAvailable('icmp') then
   local icmp = isIPv6(host["ip"]) and 'icmp6' or 'icmp'
   print([[
      <tr>
         <th>]] .. i18n("active_monitoring_stats.active_monitoring") .. [[</th>
   ]])
   if (not am_utils.hasHost(host["ip"], icmp)) then
      print([[
         <td colspan="2">
            <a href='#' id='btn-add-am-host'>]].. i18n('active_monitoring_stats.add_icmp') ..[[ <i class='fas fa-plus'></i></a>
         </td>
         <script type='text/javascript'>
            $(document).ready(function() {

               let am_csrf = "]].. ntop.getRandomCSRFValue() ..[[";
               $('#btn-add-am-host').click(function(e) {

                  e.preventDefault();
                  const data_to_send = {
                     action: 'add',
                     am_host: ']].. host["ip"] ..[[',
                     threshold: 100,
		     granularity: "min",
                     measurement: ']].. icmp ..[[',
                     csrf: am_csrf,
                  };

                  $.post(`${http_prefix}/plugins/edit_active_monitoring_host.lua`, data_to_send)
                  .then((data, result, xhr) => {

                     const $alert_message = $('<div class="alert"></div>');
                     if (data.success) {
                        $alert_message.addClass('alert-success').text(data.message);
                        $('#n-container').prepend($alert_message);

                        setTimeout(() => {
                           location.reload();
                        }, 1000);

                        return;
                     }

                     $alert_message.addClass('alert-danger').text(data.error);
                     $('#n-container').prepend($alert_message);
                     setTimeout(() => {
                        $alert_message.remove();
                     }, 5000);

                  })
                  .fail(() => {
                     const $alert_message = $('<div class="alert"></div>');
                     $alert_message.addClass('alert-danger').text("]].. i18n('expired_csrf') ..[[");

                  });

               });
            });
         </script>
      ]])

   else
      local last_update = am_utils.getLastAmUpdate(host['ip'], icmp)
      local last_rtt = ""

      if(last_update ~= nil) then
         last_rtt = last_update.value .. " " .. i18n("active_monitoring_stats.msec")
      else
	 last_rtt = i18n("active_monitoring_stats.no_updates_yet")
      end

      print([[
         <td colspan="2">
            <a href=']].. ntop.getHttpPrefix() ..[[/plugins/active_monitoring_stats.lua?host=]].. host['ip'] ..[[&measurement=]].. icmp ..[['>]].. last_rtt ..[[</a>
         </td>
      ]])

   end

   print("</tr>")
end


if(host["localhost"] and ((host_vlan == nil) or (host_vlan == 0)) and mud_utils.isMudScriptEnabled(ifId)) then
   local cur_mud_pref = mud_utils.getCurrentHostMUDRecording(ifId, host_info.host, host["devtype"])
   local in_progress = (cur_mud_pref ~= "disabled") and mud_utils.isMUDRecordingInProgress(ifId, host_info.host)
   local dev_list = nil
   local dev_lb = nil

   print("<tr><th>"..i18n("flow_callbacks_config.mud").." <a href=\"https://developer.cisco.com/docs/mud/#!what-is-mud\" target=\"_blank\"><i class='fas fa-external-link-alt'></i></a></th><td colspan=2></li> ".. mud_utils.getMudPrefLabel(cur_mud_pref) .. " ")

   if cur_mud_pref == "general_purpose" then
      dev_list = discover.getGeneralPurposeDevicesList()
      dev_lb = "host_details.list_of_general_purpose"
   elseif cur_mud_pref == "special_purpose" then
      dev_list = discover.getSpecialPurposeDevicesList()
      dev_lb = "host_details.list_of_special_purpose"
   end

   if not table.empty(dev_list) then
      print('<i class="fas fa-info-circle" title="'.. i18n(dev_lb, {list=table.concat(dev_list, ", ")}) ..'"></i>')
   end

   if in_progress then
      print('<i class="fas fa-circle fa-sm" title="'.. i18n("host_config.mud_is_recording") ..'" style="margin-left: 0.5em; color: #FC2222"></i>')
   end

   printMudRecordingActions()
   print("</td></tr>\n")
end

if(host["active_alerted_flows"] > 0) then
   print("<tr><th><i class=\"fas fa-exclamation-triangle\" style='color: #B94A48;'></i> "..i18n("host_details.active_alerted_flows").."</th><td colspan=2></li>"..hostinfo2detailshref(host, {page = "flows", flow_status = "alerted"}, "<span id=num_flow_alerts>"..host["active_alerted_flows"] .. "</span>").." <span id=flow_alerts_trend></span></td></tr>\n")
end

   if ntop.isPro() and ifstats.inline and (host["has_blocking_quota"] or host["has_blocking_shaper"]) then

   local msg = ""
   local target = ""
   local quotas_page = hostinfo2detailsurl(host, {page = "quota"})
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

       print("<tr><th><i class=\"fas fa-ban fa-lg\"></i> <a href=\""..ntop.getHttpPrefix()..target.."\">"..i18n("host_details.blocked_traffic").."</a></th><td colspan=2>"..msg)
      print(".")
      print("</td></tr>")
   end

   print("<tr><th>"..i18n("details.first_last_seen").."</th><td nowrap><span id=first_seen>" .. formatEpoch(host["seen.first"]) ..  " [" .. secondsToTime(os.time()-host["seen.first"]) .. " "..i18n("details.ago").."]" .. "</span></td>\n")
   print("<td  width='35%'><span id=last_seen>" .. formatEpoch(host["seen.last"]) .. " [" .. secondsToTime(os.time()-host["seen.last"]) .. " "..i18n("details.ago") .. "]" .. "</span></td></tr>\n")


   if((host["bytes.sent"]+host["bytes.rcvd"]) > 0) then
      print("<tr><th>"..i18n("details.sent_vs_received_traffic_breakdown").."</th><td colspan=2>")
      graph_utils.breakdownBar(host["bytes.sent"], i18n("sent"), host["bytes.rcvd"], i18n("details.rcvd"), 0, 100)
      print("</td></tr>\n")
   end

   print("<tr><th>"..i18n("details.traffic_sent_received").."</th><td><span id=pkts_sent>" .. formatPackets(host["packets.sent"]) .. "</span> / <span id=bytes_sent>".. bytesToSize(host["bytes.sent"]) .. "</span> <span id=sent_trend></span></td><td><span id=pkts_rcvd>" .. formatPackets(host["packets.rcvd"]) .. "</span> / <span id=bytes_rcvd>".. bytesToSize(host["bytes.rcvd"]) .. "</span> <span id=rcvd_trend></span></td></tr>\n")

   local flows_th = i18n("details.flows_non_packet_iface")
   if interface.isPacketInterface() then
      flows_th = i18n("details.flows_packet_iface")
   end

   if interfaceHasNindexSupport() then
      flows_th = flows_th .. ' <a href="?host='..hostinfo2hostkey(host_info)..'&page=historical&detail_view=flows&zoom=1h&flow_status=misbehaving"><i class="fas fa-search-plus"></i></a>'
   end

   print("<tr><th></th><th>"..i18n("details.as_client").."</th><th>"..i18n("details.as_server").."</th></tr>\n")
   print("<tr><th>"..flows_th.."</th><td><span id=active_flows_as_client>" .. formatValue(host["active_flows.as_client"]) .. "</span> <span id=trend_as_active_client></span> \n")
   print("/ <span id=flows_as_client>" .. formatValue(host["flows.as_client"]) .. "</span> <span id=trend_as_client></span> \n")
   print("/ <span id=misbehaving_flows_as_client>" .. formatValue(host["misbehaving_flows.as_client"]) .. "</span> <span id=trend_misbehaving_flows_as_client></span>")
   print(" / <span id=unreachable_flows_as_client>" .. formatValue(host["unreachable_flows.as_client"]) .. "</span> <span id=trend_unreachable_flows_as_client></span>")
   print("</td>")

   print("<td><span id=active_flows_as_server>" .. formatValue(host["active_flows.as_server"]) .. "</span>  <span id=trend_as_active_server></span> \n")
   print("/ <span id=flows_as_server>"..formatValue(host["flows.as_server"]) .. "</span> <span id=trend_as_server></span> \n")
   print("/ <span id=misbehaving_flows_as_server>" .. formatValue(host["misbehaving_flows.as_server"]) .. "</span> <span id=trend_misbehaving_flows_as_server></span>")
   print(" / <span id=unreachable_flows_as_server>" .. formatValue(host["unreachable_flows.as_server"]) .. "</span> <span id=trend_unreachable_flows_as_server></span>")
   print("</td></tr>")

   if(false) then
      print("<tr><th>"..i18n("details.misbehaving_flows_reasons").."</th><td nowrap><span id=misbehaving_flows_status_map_as_client>")
      for _, t in pairs(flow_consts.status_types) do
         local id = t.status_key
         if ntop.bitmapIsSet(host["misbehaving_flows_status_map.as_client"], id) then
            print(flow_consts.getStatusDescription(id).."<br />")
         end
      end
      print("</span></td>\n")
      print("<td  width='35%'><span id=misbehaving_flows_status_map_as_server>")
      for _, t in pairs(flow_consts.status_types) do
         local id = t.status_key
         if ntop.bitmapIsSet(host["misbehaving_flows_status_map.as_server"], id) then
            print(flow_consts.getStatusDescription(id).."<br />")
         end
      end
      print("</span></td></tr>\n")
   end

   print("<tr><th>"..i18n("details.peers").."</th>")
   print("<td><span id=active_peers_as_client>" .. formatValue(host["contacts.as_client"]) .. "</span> <span id=peers_trend_as_active_client></span> \n")
   print("<td><span id=active_peers_as_server>" .. formatValue(host["contacts.as_server"]) .. "</span>  <span id=peers_trend_as_active_server></span> \n")

   if ntop.isnEdge() then
      print("<tr id=bridge_dropped_flows_tr ") if not host["flows.dropped"] then print("style='display:none;'") end print(">")

      print("<th><i class=\"fas fa-ban fa-lg\"></i> "..i18n("details.flows_dropped_by_bridge").."</th>")
      print("<td colspan=2><span id=bridge_dropped_flows>" .. formatValue((host["flows.dropped"] or 0)) .. "</span>  <span id=trend_bridge_dropped_flows></span>")

      print("</tr>")
   end

   if host["tcp.packets.seq_problems"] == true then
      local tcp_seq_label = "TCP: "..i18n("details.retransmissions").." / "..i18n("details.out_of_order").." / "..i18n("details.lost").." / "..i18n("details.keep_alive")

      -- SENT ANALYSIS
      local tcp_retx_sent = "<span id=pkt_retransmissions_sent>"..formatPackets(host["tcpPacketStats.sent"]["retransmissions"]).."</span> <span id=pkt_retransmissions_sent_trend></span>"
      local tcp_ooo_sent = "<span id=pkt_ooo_sent>"..formatPackets(host["tcpPacketStats.sent"]["out_of_order"]).."</span> <span id=pkt_ooo_sent_trend></span>"
      local tcp_lost_sent = "<span id=pkt_lost_sent>"..formatPackets(host["tcpPacketStats.sent"]["lost"]).."</span> <span id=pkt_lost_sent_trend></span>"
      local tcp_keep_alive_sent = "<span id=pkt_keep_alive_sent>"..formatPackets(host["tcpPacketStats.sent"]["keep_alive"]).."</span> <span id=pkt_keep_alive_sent_trend></span>"

      -- RCVD ANALYSIS
      local tcp_retx_rcvd = "<span id=pkt_retransmissions_rcvd>"..formatPackets(host["tcpPacketStats.rcvd"]["retransmissions"]).."</span> <span id=pkt_retransmissions_rcvd_trend></span>"
      local tcp_ooo_rcvd = "<span id=pkt_ooo_rcvd>"..formatPackets(host["tcpPacketStats.rcvd"]["out_of_order"]).."</span> <span id=pkt_ooo_rcvd_trend></span>"
      local tcp_lost_rcvd = "<span id=pkt_lost_rcvd>"..formatPackets(host["tcpPacketStats.rcvd"]["lost"]).."</span> <span id=pkt_lost_rcvd_trend></span>"
      local tcp_keep_alive_rcvd = "<span id=pkt_keep_alive_rcvd>"..formatPackets(host["tcpPacketStats.rcvd"]["keep_alive"]).."</span> <span id=pkt_keep_alive_rcvd_trend></span>"

      print("<tr><th rowspan=2>"..tcp_seq_label.."</th><th>"..i18n("sent").."</th><th>"..i18n("received").."</th></tr>")
      print("<tr><td>"..string.format("%s / %s / %s / %s", tcp_retx_sent, tcp_ooo_sent, tcp_lost_sent, tcp_keep_alive_sent).."</td><td>"..string.format("%s / %s / %s / %s", tcp_retx_rcvd, tcp_ooo_rcvd, tcp_lost_rcvd, tcp_keep_alive_rcvd).."</td></tr>")
   end

   -- Stats reset
   print(
     template.gen("modal_confirm_dialog.html", {
       dialog={
         id      = "reset_host_stats_dialog",
         action  = "$('#reset_host_stats_form').submit();",
         title   = i18n("host_details.reset_host_stats"),
         message = i18n("host_details.reset_host_stats_confirm", {host=host_label}) .. "<br><br>" .. i18n("host_details.reset_host_stats_note"),
         confirm = i18n("reset"),
       }
     })
   )
   print[[<tr><th width=30% >]] print(i18n("host_details.reset_host_stats"))
   print[[</th><td colspan=2><form id='reset_host_stats_form' method="POST">
      <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
      <input name="action" type="hidden" value="reset_stats" />
   </form>
   <button class="btn btn-secondary" onclick="$('#reset_host_stats_dialog').modal('show')">]] print(i18n("host_details.reset_host_stats")) print[[</button>
   </td></tr>]]

   local num_extra_names = 0
   local extra_names = host["names"]
   local num_extra_names = table.len(extra_names)

   if num_extra_names > 0 then
      local name_sources = {}
      for source, name in pairsByKeys(extra_names, rev) do
	 if source == "resolved" then
	    source = "DNS Resolution"
	 else
	    source = source:upper()
	 end

	 if not name_sources[name] then
	    name_sources[name] = source
	 else
	    -- Collapse multiple sources in a single row when the name is the same
	    name_sources[name] = string.format("%s, %s", source, name_sources[name])
	    num_extra_names = num_extra_names - 1
	 end


      end

      print('<tr><td width=35% rowspan='..(num_extra_names + 1)..'><b>'.. i18n("details.further_host_names_information") ..' </a></b></td>')
      print("<th>"..i18n("details.source").."</th><th>"..i18n("name").."</th></tr>\n")
      for name, source in pairsByValues(name_sources, asc) do
	 print("<tr><td>"..source.."</td><td>"..name.."</td></tr>\n")
      end
   end

   print("<tr><th>"..i18n("download").."&nbsp;<i class=\"fas fa-download fa-lg\"></i></th><td")
   local show_live_capture = ntop.isPcapDownloadAllowed()
   if(not show_live_capture) then print(" colspan=2") end
   print("><A HREF='"..ntop.getHttpPrefix().."/lua/rest/v1/get/host/data.lua?ifid="..ifId.."&"..hostinfo2url(host_info).."'>JSON</A></td>")
   print [[<td>]]
   if (show_live_capture and ifstats.isView == false and ifstats.isDynamic == false and interface.isPacketInterface()) then
      local live_traffic_utils = require("live_traffic_utils")
      live_traffic_utils.printLiveTrafficForm(ifId, host_info)
   end

   print[[</td>]]
   print("</tr>\n")


   if(host["ssdp"] ~= nil) then
      print("<tr><th><A HREF='https://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol'>SSDP (UPnP)</A></th><td colspan=2><i class=\"fas fa-external-link-alt fa-lg\"></i> <A HREF='"..host["ssdp"].."'>"..host["ssdp"].."<A></td></tr>\n")
   end

   print("</table>\n")

   elseif((page == "packets")) then
      print [[

      <table class="table table-bordered table-striped">
	 ]]

      local tots = 0 for key, value in pairs(host["pktStats.sent"]["size"]) do tots = tots + value end
      local totr = 0 for key, value in pairs(host["pktStats.recv"]["size"]) do totr = totr + value end

   if((tots > 0) or (totr > 0)) then
     print('<tr><th class="text-left">'..i18n("packets_page.sent_vs_rcvd_distribution")..'</th>')
     if(tots > 0) then
       print('<td colspan=1><div class="pie-chart" id="sizeSentDistro"></div></td>')
     else
        print('<td colspan=1>&nbsp;</td>')
     end

     if(totr > 0) then
       print('<td colspan=1><div class="pie-chart" id="sizeRecvDistro"></div></td>')
     else
       print('<td colspan=1>&nbsp;</td>')
     end
     print('</tr>')
   end

   local has_tcp_distro = (host["tcp.packets.rcvd"] + host["tcp.packets.sent"] > 0)
   local has_arp_distro = (not isEmptyString(host["mac"])) and (host["mac"] ~= "00:00:00:00:00:00")

if(has_tcp_distro and has_arp_distro) then
print('<tr><th class="text-left">'..i18n("packets_page.tcp_flags_vs_arp_distribution")..'</th><td colspan=1><div class="pie-chart" id="flagsDistro"></div></td><td colspan=1><div class="pie-chart" id="arpDistro"></div></td></tr>')
else
      if (has_tcp_distro) then
	 print('<tr><th class="text-left">'..i18n("packets_page.tcp_flags_distribution")..'</th><td colspan=5><div class="pie-chart" id="flagsDistro"></div></td></tr>')
      end
      if (has_arp_distro) then
         if (macinfo ~= nil) and (macinfo["arp_requests.sent"] + macinfo["arp_requests.rcvd"] + macinfo["arp_replies.sent"] + macinfo["arp_replies.rcvd"] > 0) then
            print('<tr><th class="text-left">'..i18n("packets_page.arp_distribution")..'</th><td colspan=5><div class="pie-chart" id="arpDistro"></div></td></tr>')
         end
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

-- table.clone needed to change macinfo while keeping host_info unchanged
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

      print('<tr><th class="text-left">'..i18n("ports_page.client_ports")..'</th><td colspan=5><div class="pie-chart" id="clientPortsDistro"></div></td></tr>')
      print('<tr><th class="text-left">'..i18n("ports_page.server_ports")..'</th><td colspan=5><div class="pie-chart" id="serverPortsDistro"></div></td></tr>')

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

   <br />
   <table border=0>
   <tr>
     <td>
       <div id="chart-row-hosts">
         <strong>]] print(i18n("peers_page.top_peers_for_host",{hostkey=hostinfo2hostkey(host_info)})) print  [[</strong>
         <div class="clearfix"></div>
       </div>

       <div id="chart-ring-protocol">
         <strong>]] print(i18n("peers_page.top_peer_protocol")) print[[</strong>
         <div class="clearfix"></div>
       </div>
     </td>
   </tr>
   </table>
   <br />
   <table class="table table-hover dc-data-table">
        <thead>
        <tr class="header">
            <th>]] print(i18n("peers_page.host")) print[[</th>
            <th>]] print(i18n("application")) print[[</th>
            <th>]] print(i18n("peers_page.traffic_volume")) print[[</th>
        </tr>
        </thead>
   </table>

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
      return d.key+": " + bytesToVolume(d.value);
      })

hostChart
    .width(800).height(300)
    .dimension(nameDim)
    .group(trafficPerhost)
    .elasticX(true);

// Tooltip
hostChart.title(function(d){
      return "Host "+d.key+": " + bytesToVolume(d.value);
      })

hostChart.xAxis().tickFormat(function(v) {
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
                return bytesToVolume(d.traffic);
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
      	<tr><th colspan="2" class="text-left">]] print(i18n("traffic_page.l4_proto_overview"))
        print[[</th><td colspan=4><div class="pie-chart" id="topApplicationProtocols"></div></td></tr>]]

	local num_expired_client_flows = host["flows.as_client"]-host["active_flows.as_client"]
	local num_expired_server_flows = host["flows.as_server"]-host["active_flows.as_server"]

	if((num_expired_client_flows+num_expired_server_flows) > 0) then
	   print [[<tr><th colspan="2" class="text-left">]] print(i18n("traffic_page.flow_distribution")) print[[</th>
                <th colspan=2>]] print(i18n("traffic_page.flow_duration")) print[[</th>
                <th colspan=2>]] print(i18n("traffic_page.flow_frequency")) print[[</th>
               </tr>
               ]]

	      	-- ############

	   print [[<tr><th colspan="2" class="text-left">]] print(i18n("details.as_client")) print[[</th>]]
	   if(num_expired_client_flows) then
	      print [[
                  <td colspan=2><div class="pie-chart" id="flowsDistributionClientDuration"></div></td>
                  <td colspan=2><div class="pie-chart" id="flowsDistributionClientFrequency"></div></td>
              ]]
	   else
	      print("<td colspan=2>&nbsp;</td>td colspan=2>&nbsp;</td>")
	   end

	   -- ############

	   print [[<tr><th colspan="2" class="text-left">]] print(i18n("details.as_server")) print[[</th>]]
	   if(num_expired_server_flows) then
	      print [[
                  <td colspan=2><div class="pie-chart" id="flowsDistributionServerDuration"></div></td>
                  <td colspan=2><div class="pie-chart" id="flowsDistributionServerFrequency"></div></td>
              ]]
	   else
	      print("<td colspan=2>&nbsp;</td>td colspan=2>&nbsp;</td>")
	   end


	end


	print [[
	</div>

        <script type='text/javascript'>
          window.onload=function() {

  	   do_pie("#topApplicationProtocols", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_l4_stats.lua', { ifid: "]] print(ifId.."") print('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")

      if(num_expired_client_flows > 0) then
	 print [[
  	   do_pie("#flowsDistributionClientDuration", ']]
print (ntop.getHttpPrefix())
print [[/lua/get_host_flow_stats.lua', { mode: "client_duration", ifid: "]] print(ifId.."") print('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
  print [[
  	   do_pie("#flowsDistributionClientFrequency", ']]
print (ntop.getHttpPrefix())
print [[/lua/get_host_flow_stats.lua', { mode: "client_frequency", ifid: "]] print(ifId.."") print('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
	end


      if(num_expired_server_flows > 0) then
print [[
  	   do_pie("#flowsDistributionServerDuration", ']]
print (ntop.getHttpPrefix())
print [[/lua/get_host_flow_stats.lua', { mode: "server_duration", ifid: "]] print(ifId.."") print('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
  print [[
  	   do_pie("#flowsDistributionServerFrequency", ']]
print (ntop.getHttpPrefix())
print [[/lua/get_host_flow_stats.lua', { mode: "server_frequency", ifid: "]] print(ifId.."") print('", '..hostinfo2json(host_info) .."}, \"\", refresh); \n")
	end

	print [[
         }
	 </script>
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
	    if(charts_available) then
	       print(hostinfo2detailshref(host, {page = "historical", ts_schema = "host:l4protos", l4proto = k}, label))
	    else
	       print(label)
	    end
	    t = sent+rcvd
	    historicalProtoHostHref(ifId, host, l4_keys[id][3], nil, nil)
	    print("</th><td class=\"text-right\">" .. bytesToSize(sent) .. "</td><td class=\"text-right\">" .. bytesToSize(rcvd) .. "</td><td>")
	    graph_utils.breakdownBar(sent, i18n("sent"), rcvd, i18n("traffic_page.rcvd"), 0, 100)
	    print("</td><td class=\"text-right\">" .. bytesToSize(t).. "</td><td class=\"text-right\">" .. round((t * 100)/total, 2).. " %</td></tr>\n")
	 end
      end
      print("</table></tr>\n")

      print("</table>\n")
   end


elseif((page == "ICMP")) then

  print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     <thead><tr><th>]] print(i18n("icmp_page.icmp_message")) print[[</th><th>]] print(i18n("icmp_page.icmp_type")) print [[</th><th>]] print(i18n("icmp_page.icmp_code")) print [[</th><th>]] print(i18n("icmp_page.last_sent_peer")) print[[</th><th>]] print(i18n("icmp_page.last_rcvd_peer")) print[[</th><th>]] print(i18n("breakdown")) print[[</th><th style='text-align:right;'>]] print(i18n("icmp_page.packets_sent")) print[[</th><th style='text-align:right;'>]] print(i18n("icmp_page.packets_received")) print[[</th><th style='text-align:right;'>]] print(i18n("total")) print[[</th></tr></thead>
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
  <ul id="ndpiNav" class="nav nav-tabs" role="tablist">
    <li class="nav-item active"><a class="nav-link active" data-toggle="tab" role="tab" href="#applications" active>]] print(i18n("applications")) print[[</a></li>
    <li class="nav-item"><a class="nav-link" data-toggle="tab" role="tab" href="#categories">]] print(i18n("categories")) print[[</a></li>
  </ul>
  <div class="tab-content">
    <div id="applications" class="tab-pane in active">
      <br>
  <table class="table table-bordered table-striped">]]

      if ntop.isPro() and host["custom_apps"] then
	 print[[
    <tr>
      <th class="text-left">]] print(i18n("ndpi_page.overview", {what = i18n("ndpi_page.custom_applications")})) print [[</th>
      <td colspan=5><div class="pie-chart" id="topCustomApps"></div></td>
    </tr>
]]
      end

      print[[
    <tr>
      <th class="text-left" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("applications")})) print[[</th>
      <td><div class="pie-chart" id="topApplicationProtocols"></div></td>
      <td colspan=2><div class="pie-chart" id="topApplicationBreeds"></div></td>
    </tr>
  </table>]]

      local direction_filter = ""

      if(direction ~= nil) then
	 direction_filter = '<span class="fas fa-filter"></span>'
      end

      print('<div class="dt-toolbar btn-toolbar float-right">')
      print('<div class="btn-group float-right"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Direction ' .. direction_filter .. '<span class="caret"></span></button> <ul class="dropdown-menu scrollable-dropdown" role="menu" id="direction_dropdown">')
      print('<li>'..hostinfo2detailshref(host, {page = "ndpi"}, i18n("all"))..'</li>')
      print('<li>'..hostinfo2detailshref(host, {page = "ndpi", direction = "sent"}, i18n("ndpi_page.sent_only"))..'</li>')
      print('<li>'..hostinfo2detailshref(host, {page = "ndpi", direction = "recv"}, i18n("ndpi_page.received_only"))..'</li>')
      print('</ul></div></div>')

      print [[
     <table class="table table-bordered table-striped">
       <thead>
	 <tr>
	   <th>]] print(i18n("application")) print[[</th>
	   <th>]] print(i18n("duration")) print[[</th>
	   <th>]] print(i18n("sent")) print[[</th>
	   <th>]] print(i18n("received")) print[[</th>
	   <th>]] print(i18n("breakdown")) print[[</th>
	   <th colspan=2>]] print(i18n("total")) print[[</th>
	 </tr>
       </thead>
       <tbody id="host_details_ndpi_applications_tbody"></tbody>
     </table>
    </div>
    <div id="categories" class="tab-pane">
      <br>
      <table class="table table-bordered table-striped">
        <tr>
        <th class="text-left" colspan=2>]] print(i18n("ndpi_page.overview", {what = i18n("categories")})) print[[</th>
        <td colspan=2><div class="pie-chart" id="topApplicationCategories"></div></td>
      </tr>
      </table>
     <table class="table table-bordered table-striped">
       <thead>
	 <tr>
	   <th>]] print(i18n("category")) print[[</th>
	   <th>]] print(i18n("duration")) print[[</th>
	   <th colspan=2>]] print(i18n("total")) print[[</th>
	 </tr>
       </thead>
       <tbody id="host_details_ndpi_categories_tbody"></tbody>
     </table>
    </div>
]]

      print[[

	<script type='text/javascript'>
	       window.onload=function() {]]

      if ntop.isPro() and host["custom_apps"] then
	 print[[do_pie("#topCustomApps", ']]
	 print (ntop.getHttpPrefix())
	 print [[/lua/pro/get_custom_app_stats.lua', { ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);
]]
      end

      print[[ do_pie("#topApplicationProtocols", ']]
      print (ntop.getHttpPrefix())
      print [[/lua/rest/v1/get/host/l7/stats.lua', { ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);

				   do_pie("#topApplicationCategories", ']]
      print (ntop.getHttpPrefix())
      print [[/lua/rest/v1/get/host/l7/stats.lua', { ndpi_category: "true", ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);

				   do_pie("#topApplicationBreeds", ']]
      print (ntop.getHttpPrefix())
      print [[/lua/rest/v1/get/host/l7/stats.lua', { breed: "true", ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info)) print [[ }, "", refresh);


				}

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
	 print("<li>"..i18n("ndpi_page.note_historical_per_protocol_traffic",{what=i18n("application"), url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=on_disk_ts",flask_icon="<i class=\"fas fa-flask\"></i>"}).." ")
      end

      if host_ndpi_timeseries_creation ~= "both" and host_ndpi_timeseries_creation ~= "per_category" then
	 print("<li>"..i18n("ndpi_page.note_historical_per_protocol_traffic",{what=i18n("category"), url=ntop.getHttpPrefix().."/lua/admin/prefs.lua",flask_icon="<i class=\"fas fa-flask\"></i>"}).." ")
      end

      print("<li>"..i18n("ndpi_page.note_possible_probing_alert",{icon="<i class=\"fas fa-exclamation-triangle\" style=\"color: orange;\"></i>",url = hostinfo2detailsurl(host, {page = "historical"})}))
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
	 graph_utils.breakdownBar(host["dns"]["sent"]["num_replies_ok"], "OK", host["dns"]["sent"]["num_replies_error"], "Error", 0, 100)
	 print("</td></tr>")

	 print("<tr><th>"..i18n("dns_page.rcvd").."</th><td class=\"text-right\"><span id=dns_rcvd_num_queries>".. formatValue(host["dns"]["rcvd"]["num_queries"]) .."</span> <span id=trend_rcvd_num_queries></span></td>")
	 print("<td class=\"text-right\"><span id=dns_rcvd_num_replies_ok>".. formatValue(host["dns"]["rcvd"]["num_replies_ok"]) .."</span> <span id=trend_rcvd_num_replies_ok></span></td>")
	 print("<td class=\"text-right\"><span id=dns_rcvd_num_replies_error>".. formatValue(host["dns"]["rcvd"]["num_replies_error"]) .."</span> <span id=trend_rcvd_num_replies_error></span></td><td colspan=2>")
	 graph_utils.breakdownBar(host["dns"]["rcvd"]["num_replies_ok"], "OK", host["dns"]["rcvd"]["num_replies_error"], "Error", 50, 100)
	 print("</td></tr>")

	 if host["dns"]["rcvd"]["num_replies_ok"] + host["dns"]["rcvd"]["num_replies_error"] > 0 then
	    print('<tr><th>'..i18n("dns_page.request_vs_reply")..'</th>')
	    local dns_ratio = tonumber(host["dns"]["sent"]["num_queries"]) / tonumber(host["dns"]["rcvd"]["num_replies_ok"]+host["dns"]["rcvd"]["num_replies_error"])
	    local dns_ratio_str = string.format("%.2f", dns_ratio)

	    if(dns_ratio < 0.9) then
	       dns_ratio_str = "<font color=red>".. dns_ratio_str .."</font>"
	    end

	    print('<td colspan=2 align=right>'..  dns_ratio_str ..'</td><td colspan=2>')
	    graph_utils.breakdownBar(host["dns"]["sent"]["num_queries"], i18n("dns_page.queries"), host["dns"]["rcvd"]["num_replies_ok"]+host["dns"]["rcvd"]["num_replies_error"], i18n("dns_page.replies"), 30, 70)

	    print [[</td></tr>]]
	 end

         -- Charts
         if((host["dns"]["sent"]["num_queries"] + host["dns"]["rcvd"]["num_queries"]) > 0) then
	    print [[<tr><th>]] print(i18n("dns_page.dns_query_sent_vs_rcvd_distribution")) print[[</th>]]
	 if(host["dns"]["sent"]["num_queries"] > 0) then
	    print[[<td colspan=2>
		     <div class="pie-chart" id="dnsSent"></div>
		     <script type='text/javascript'>

					 do_pie("#dnsSent", ']]
            print (ntop.getHttpPrefix())
            print [[/lua/host_dns_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, direction: "sent" }, "", refresh);
				      </script>
					 </td>
           ]]
        else
           print[[<td colspan=2>&nbsp;</td>]]
         end


	 if(host["dns"]["rcvd"]["num_queries"] > 0) then
print [[
         <td colspan=2><div class="pie-chart" id="dnsRcvd"></div>
         <script type='text/javascript'>

	     do_pie("#dnsRcvd", ']]
print (ntop.getHttpPrefix())
print [[/lua/host_dns_breakdown.lua', { ]] print(hostinfo2json(host_info)) print [[, direction: "recv" }, "", refresh);
         </script>
         </td>
]]
	 else
	    print [[<td colspan=2>&nbsp;</td>]]
	 end
	 print("</tr>")
	 end

	print[[
        </table>
       <small><b>]] print(i18n("dns_page.note")) print[[:</b><br>]] print(i18n("dns_page.note_dns_ratio")) print[[
</small>
]]
      end
elseif(page == "tls") then
  print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     <thead><tr><th>]] print('<A HREF="https://github.com/salesforce/ja3" target="_blank">'..i18n("ja3_fingerprint")..'</A>') print[[</th>]]
  if not isEmptyString(companion_interface_utils.getCurrentCompanion(ifId)) then
     print[[<th>]] print(i18n("app_name")) print[[</th>]]
  end
  print[[<th>]] print(i18n("num_uses")) print[[</th>]]
  print[[</tr></thead>
     <tbody id="host_details_ja3_tbody">
     </tbody>
     </table>

<script>
function update_ja3_table() {
  $.ajax({
    type: 'GET',
    url: ']]
  print(ntop.getHttpPrefix())
  print [[/lua/get_fingerprint_data.lua',
    data: { fingerprint_type: 'ja3', ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info))

    print [[ },
    success: function(content) {
      $('#host_details_ja3_tbody').html(content);
      $('#myTable').trigger("update");
    }
  });
}

update_ja3_table();
setInterval(update_ja3_table, 5000);

</script>
]]


   print("<b>"..i18n("notes").."</b><ul><li>"..i18n("fingerprint_note").."</li></ul>")

elseif(page == "ssh") then
  print [[
     <table id="myTable" class="table table-bordered table-striped tablesorter">
     <thead><tr><th>]] print('<A HREF="https://engineering.salesforce.com/open-sourcing-hassh-abed3ae5044c" target="_blank">'..i18n("hassh_fingerprint")..'</A>') print[[</th>]]
  if not isEmptyString(companion_interface_utils.getCurrentCompanion(ifId)) then
     print[[<th>]] print(i18n("app_name")) print[[</th>]]
  end
  print[[<th>]] print(i18n("num_uses")) print[[</th></tr></thead>
     <tbody id="host_details_hassh_tbody">
     </tbody>
     </table>

<script>
function update_hassh_table() {
  $.ajax({
    type: 'GET',
    url: ']]
  print(ntop.getHttpPrefix())
  print [[/lua/get_fingerprint_data.lua',
    data: { fingerprint_type: 'hassh', ifid: "]] print(ifId.."") print ("\" , ") print(hostinfo2json(host_info))

    print [[ },
    success: function(content) {
      $('#host_details_hassh_tbody').html(content);
      $('#myTable').trigger("update");
    }
  });
}

update_hassh_table();
setInterval(update_hassh_table, 5000);

</script>
]]


   print("<b>"..i18n("notes").."</b><ul><li>"..i18n("fingerprint_note").."</li></ul>")

elseif(page == "http") then
   local http = host["http"]
   if http then
      print("<table class=\"table table-bordered table-striped\">\n")

      if http["sender"]["query"]["total"] > 0 then
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
      end

      if http["receiver"]["response"]["total"] > 0 then
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
      end

      local vh = http["virtual_hosts"]
      if vh then
	 local now    = os.time()
	 local ago1h  = now - 3600
	 local num = table.len(vh)
	 if(num > 0) then
	    local ifId = getInterfaceId(ifname)
	    print("<tr><th rowspan="..(num+1).." width=20%>"..i18n("http_page.virtual_hosts").."</th><th>Name</th><th>"..i18n("http_page.traffic_sent").."</th><th>"..i18n("http_page.traffic_received").."</th><th>"..i18n("http_page.requests_served").."</th></tr>\n")
	    for k,v in pairsByKeys(vh, asc) do
	       local j = string.gsub(k, "%.", "___")
	       print("<tr><td><A HREF='http://"..k.."'>"..k.."</A> <i class='fas fa-external-link-alt'></i>")
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


elseif(page == "sites") then
   if not prefs.are_top_talkers_enabled then
      local msg = i18n("sites_page.top_sites_not_enabled_message",{url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=protocols"})
      print("<div class='alert alert-info'><i class='fas fa-info-circle fa-lg' aria-hidden='true'></i> "..msg.."</div>")

   elseif table.len(top_sites) > 0 or table.len(top_sites_old) > 0 then
      print("<table class=\"table table-bordered table-striped\">\n")

      local old_top_len = table.len(top_sites_old)  if(old_top_len > 10) then old_top_len = 10 end
      local top_len = table.len(top_sites)          if(top_len > 10) then top_len = 10 end
      if(old_top_len > top_len) then num = old_top_len else num = top_len end

      print("<tr><th rowspan="..(1+num)..">"..i18n("sites_page.top_visited_sites").."</th><th>"..i18n("sites_page.current_sites").."</th><th>"..i18n("sites_page.contacts").."</th><th>"..i18n("sites_page.last_5_minutes_sites").."</th><th>"..i18n("sites_page.contacts").."</th></tr>\n")
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
      print("</table>\n")
   else
      local msg = i18n("sites_page.top_sites_not_seen")
      print("<div class='alert alert-info'><i class='fas fa-info-circle fa-lg' aria-hidden='true'></i> "..msg.."</div>")
   end

   elseif(page == "flows") then

      require("flow_utils")

print [[
      <div id="table-flows"></div>
	 <script>
   var url_update = "]]

local page_params = {
   application = _GET["application"],
   category = _GET["category"],
   flow_status = _GET["flow_status"],
   tcp_flow_state = _GET["tcp_flow_state"],
   flowhosts_type = _GET["flowhosts_type"],
   traffic_type = _GET["traffic_type"],
   version = _GET["version"],
   l4proto = _GET["l4proto"],
   host = hostinfo2hostkey(host),
   tskey = _GET["tskey"],
}

print(getPageUrl(ntop.getHttpPrefix().."/lua/get_flows_data.lua", page_params))

print('";')

if(ifstats.vlan)   then show_vlan = true else show_vlan = false end
local active_flows_msg = i18n("flows_page.active_flows",{filter=""})
if not interface.isPacketInterface() then
   active_flows_msg = i18n("flows_page.recently_active_flows",{filter=""})
elseif interface.isPcapDumpInterface() then
   active_flows_msg = i18n("flows")
end

local active_flows_msg = getFlowsTableTitle()

print [[
	 $("#table-flows").datatable({
         url: url_update,
         buttons: [ ]] printActiveFlowsDropdown("host_details.lua?page=flows", page_params, interface.getStats(), interface.getActiveFlowsStats(hostinfo2hostkey(host_info))) print[[ ],
         tableCallback: function()  {
	    ]] initFlowsRefreshRows() print[[
	 },
         showPagination: true,
	       ]]

  print('title: "'..active_flows_msg..'",')

-- Set the preference table
preference = tablePreferences("rows_number",_GET["perPage"])
if(preference ~= "") then print ('perPage: '..preference.. ",\n") end


print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')

print[[
   columns: [
      {
         title: "",
         field: "key",
         hidden: true,
      }, {
         title: "",
         field: "hash_id",
         hidden: true,
      }, {
         title: "",
         field: "column_key",
         css: {
            textAlign: 'center'
         }
      }, {
         title: "]] print(i18n("application")) print[[",
         field: "column_ndpi",
         sortable: true,
         css: {
            textAlign: 'center'
         }
      }, {
         title: "]] print(i18n("protocol")) print[[",
         field: "column_proto_l4",
         sortable: true,
         css: {
            textAlign: 'center'
         }
      },
]]

if(show_vlan) then
   print('{ title: "'..i18n("vlan")..'",\n')
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
                                textAlign: 'center'
                               }
                               },
                             {
                             title: "]] print(i18n("score")) print[[",
                                 field: "column_score",
                                 hidden: ]] print(ternary(isScoreEnabled(), "false", "true")) print[[,
                                 sortable: true,
                             css: {
                                textAlign: 'center'
                               }
                               },
                             {
                             title: "]] print(i18n("breakdown")) print[[",
                                 field: "column_breakdown",
                                 sortable: false,
                             css: {
                                textAlign: 'center'
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
]]

if(have_nedge) then
  printBlockFlowJs()
end

print[[
       </script>

   ]]

elseif(page == "snmp" and ntop.isEnterpriseM() and isAllowedSystemInterface()) then
   local snmp_devices = get_snmp_devices()

   if snmp_devices[host_ip] == nil then -- host has not been configured
      if not has_snmp_location then
         local msg = i18n("snmp_page.not_configured_as_snmp_device_message",{host_ip=host_ip})
         msg = msg.." "..i18n("snmp_page.guide_snmp_page_message",{url=ntop.getHttpPrefix().."/lua/pro/enterprise/snmpdevices_stats.lua"})

         print("<div class='alert alert-info'><i class='fas fa-info-circle fa-lg' aria-hidden='true'></i> "..msg.."</div>")
      end
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

   if has_snmp_location then
      print[[<table class="table table-bordered table-striped">]]
      print_host_snmp_localization_table_entry(host["mac"])
      print[[</table>]]
   end
elseif(page == "processes") then
   local ebpf_utils = require "ebpf_utils"
   ebpf_utils.draw_processes_graph(host_info)
elseif page == "geomap" then

   print ([[
      <div class="container-fluid">
        <div class="row">
          <div class='col-md-12 col-lg-12 col-xs-12'>
            <div class='mb-4'>
              <h2 class='h2'>]].. i18n("geo_map.hosts_geomap").. [[</h2>
            </div>
            <div id='geomap-alert' style="display: none" role="alert" class='alert alert-danger'>
              <button type="button" class="close" data-dismiss="alert" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
              <p id='error-message'></p>
            </div>
            <div style="height: 720px" id="map-canvas"></div>
            <div class='my-3'>
              <p id='my-location'></p>
            </div>
          </div>
        </div>
      </div>
      <link rel="stylesheet" href="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.css"/>
      <link rel="stylesheet" href="]].. ntop.getHttpPrefix() ..[[/leaflet/MarkerCluster.Default.css"/>
      <link rel="stylesheet" href="]].. ntop.getHttpPrefix() ..[[/leaflet/MarkerCluster.css"/>
      <script src="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.js" type="text/javascript"></script>
      <script src="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.curve.js" type="text/javascript"></script>
      <script src="]].. ntop.getHttpPrefix() ..[[/leaflet/leaflet.markercluster.js" type="text/javascript"></script>
      <script type='text/javascript'>

        const zoomIP = "ifid=]]..ifId..[[&]].. hostinfo2url(host_info) ..[[";
         console.log(zoomIP);

        const display_localized_error = (error_code) => {
          $('#geomap-alert p').html(`]].. i18n("geo_map.geolocation_error") ..[[[${error_code}]: ]].. i18n("geo_map.using_default_location") ..[[`);
          $('#geomap-alert').removeClass('alert-info').addClass('alert-danger').show();
        }

        const display_localized_position = (position) => {
            $('#my-location').html(`
            ]].. i18n("geo_map.browser_reported_home_map")..[[:
            <a href='https://www.openstreetmap.org/#map=6/${position[0]}/${position[1]}'>
            ]]..i18n("geo_map.latitude").. [[: ${position[0]}, ]].. i18n("geo_map.longitude").. [[: ${position[1]} </a>
          `);
        }

        const display_localized_no_geolocation_msg = () => {

            $('#geomap-alert p').html(`]].. i18n("geo_map.unavailable_geolocation") .. ' ' .. i18n("geo_map.using_default_location") ..[[`);
            $('#geomap-alert').addClass('alert-info').removeClass('alert-danger').show();

        }
      </script>
      <script src="]].. ntop.getHttpPrefix() ..[[/js/osm-maps.js"  type='text/javascript'></script>
   ]])


elseif(page == "contacts") then

if(num > 0) then
   mode = "embed"
   name = host_label
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
      if(info["name"] ~= nil) then n = info["name"] else n = hostinfo2label(info) end
      url = hostinfo2detailshref(info, nil, n)
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
	    if(info["name"] ~= nil) then n = info["name"] else n = hostinfo2label(info) end
	    url = hostinfo2detailshref(info, nil, n)
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
   alert_utils.printAlertTables("host", hostkey,
      "host_details.lua", {ifid=ifId, host=hostkey},
      host_label, "host", {host_ip=host_ip, host_vlan=host_vlan, remote_host = (not host["localhost"]),
			   enable_label = i18n("show_alerts.trigger_host_alert_descr", {host = hostinfo2hostkey(host)})})

elseif (page == "quotas" and ntop.isEnterpriseM() and host_pool_id ~= host_pools_utils.DEFAULT_POOL_ID and ifstats.inline) then
   local page_params = {ifid=ifId, pool=host_pool_id, host=hostkey, page=page}
   host_pools_utils.printQuotas(host_pool_id, host, page_params)

elseif (page == "config") then
   if(not isAdministrator()) then
      return
   end

   local top_hiddens = ntop.getMembersCache(getHideFromTopSet(ifId) or {})
   local is_top_hidden = swapKeysValues(top_hiddens)[hostkey_compact] ~= nil
   local host_key = hostinfo2hostkey(host_info, nil, true --[[show vlan]])

   if _SERVER["REQUEST_METHOD"] == "POST" then
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

      if _POST["mud_recording"] then
         mud_utils.setHostMUDRecordingPref(ifId, host_info.host, _POST["mud_recording"])
         interface.reloadHostPrefs(host_info.host)
      end
   end

   -- NOTE: this only configures the alias associated to the IP address, not to the MAC
   local ip_alias = ntop.getHashCache(getHostAltNamesKey(), host_info["host"])

   print[[
   <form id="host_config" class="form-inline" method="post">
   <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   <table class="table table-bordered table-striped">
      <tr>
         <th>]] print(i18n("host_config.host_alias")) print[[</th>
         <td>
               <input type="text" name="custom_name" class="form-control" placeholder="Custom Name" style="width: 280px;" value="]]
   if(ip_alias ~= host_label) then print(ip_alias) end
   print[["></input> ]]

   print [[
         </td>
      </tr>]]

   graph_utils.printPoolChangeDropdown(ifId, host_pool_id, have_nedge)

   print [[<tr>
         <th>]] print(i18n("host_config.hide_from_top")) print[[</th>
         <td>]]

   print(template.gen("on_off_switch.html", {
     id = "top_hidden",
     label = i18n("host_config.hide_host_from_top_descr", {host=host_label}),
     checked = is_top_hidden,
   }))

   print[[</td>
      </tr>]]

   if(host["localhost"] and ((host_vlan == nil) or (host_vlan == 0)) and mud_utils.isMudScriptEnabled(ifId)) then
      local mud_recording_pref = mud_utils.getHostMUDRecordingPref(ifId, host_info.host, _POST["mud_recording"])

      print [[<tr>
         <th>]] print(i18n("host_config.mud_recording")) print[[ <a href="https://developer.cisco.com/docs/mud/#!what-is-mud" target="_blank"><i class='fas fa-external-link-alt'></i></a></th>
         <td>
               <select name="mud_recording" class="form-control" style="width:20em;">
		  <option value="default" ]] if mud_recording_pref == "default" then print("selected") end print[[>]] print(i18n("default")) print[[</option>
                  <option value="disabled" ]] if mud_recording_pref == "disabled" then print("selected") end print[[>]] print(i18n("traffic_recording.disabled")) print[[</option>
                  <option value="general_purpose" ]] if mud_recording_pref == "general_purpose" then print("selected") end print[[>]] print(i18n("host_config.mud_general_purpose")) print[[</option>
                  <option value="special_purpose" ]] if mud_recording_pref == "special_purpose" then print("selected") end print[[>]] print(i18n("host_config.mud_special_purpose")) print[[</option>
               </select>]]

      printMudRecordingActions()

      print[[</td>
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

	 print(template.gen("on_off_switch.html", {
	    id = "drop_host_traffic",
	    label = i18n("host_config.drop_all_host_traffic"),
	    checked = drop_traffic == "true",
	 }))
      end

      print[[<a class="btn btn-secondary btn-sm" href="]]
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

   <button class="btn btn-primary" style="float:right; margin-right:1em; margin-left: auto" disabled="disabled" type="submit">]] print(i18n("save_settings")) print[[</button><br><br>

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
   l4proto = _GET["l4proto"],
}

local url = hostinfo2detailsurl(host, {page = "historical"})

graph_utils.drawGraphs(ifId, schema, tags, _GET["zoom"], url, selected_epoch, {
   top_protocols = "top:host:ndpi",
   top_categories = "top:host:ndpi_categories",
   l4_protocols = "host:l4protos",
   show_historical = true,
   tskey = tskey,
   timeseries = table.merge({
      {schema="host:traffic",                label=i18n("traffic"), split_directions = true --[[ split RX and TX directions ]]},
      {schema="host:score",                  label=i18n("score"), enterprise_only=true},
      {schema="host:active_flows",           label=i18n("graphs.active_flows")},
      {schema="host:total_flows",            label=i18n("db_explorer.total_flows")},
      {schema="host:misbehaving_flows",        label=i18n("graphs.total_misbehaving_flows")},
      {schema="host:unreachable_flows",      label=i18n("graphs.total_unreachable_flows")},
      {schema="host:contacts",               label=i18n("graphs.active_host_contacts")},
      {schema="host:total_alerts",           label=i18n("details.alerts")},
      {schema="host:engaged_alerts",         label=i18n("show_alerts.engaged_alerts")},
      {schema="host:total_flow_alerts",      label=i18n("show_alerts.flow_alerts")},
      {schema="host:host_unreachable_flows", label=i18n("graphs.host_unreachable_flows")},
      {schema="host:dns_qry_sent_rsp_rcvd",  label=i18n("graphs.dns_qry_sent_rsp_rcvd")},
      {schema="host:dns_qry_rcvd_rsp_sent",  label=i18n("graphs.dns_qry_rcvd_rsp_sent")},
      {schema="host:udp_pkts",               label=i18n("graphs.udp_packets")},
      {schema="host:tcp_rx_stats",           label=i18n("graphs.tcp_rx_stats")},
      {schema="host:tcp_tx_stats",           label=i18n("graphs.tcp_tx_stats")},
      {schema="host:echo_reply_packets",     label=i18n("graphs.echo_reply_packets")},
      {schema="host:echo_packets",           label=i18n("graphs.echo_request_packets")},
      {schema="host:tcp_packets",            label=i18n("graphs.tcp_packets")},
      {schema="host:udp_sent_unicast",       label=i18n("graphs.udp_sent_unicast_vs_non_unicast")},

      {schema="host:1d_delta_traffic_volume",  label="1 Day Traffic Delta"}, -- TODO localize
      {schema="host:1d_delta_flows",           label="1 Day Active Flows Delta"}, -- TODO localize
      {schema="host:1d_delta_contacts",        label="1 Day Active Host Contacts Delta"}, -- TODO localize
   }, graph_utils.getDeviceCommonTimeseries()),
   device_timeseries_mac = host["mac"],
})

elseif(page == "traffic_report") then
   dofile(dirs.installdir .. "/pro/scripts/lua/enterprise/traffic_report.lua")
   end
end

if(not only_historical) and (host ~= nil) then
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
   print("var last_score = " .. host["score"] .. ";\n")
   print("var last_num_flow_alerts = " .. host["active_alerted_flows"] .. ";\n")
   print("var last_active_flows_as_server = " .. host["active_flows.as_server"] .. ";\n")
   print("var last_active_flows_as_client = " .. host["active_flows.as_client"] .. ";\n")
   print("var last_flows_as_server = " .. host["flows.as_server"] .. ";\n")
   print("var last_flows_as_client = " .. host["flows.as_client"] .. ";\n")
   print("var last_active_peers_as_server = " .. host["contacts.as_server"] .. ";\n")
   print("var last_active_peers_as_client = " .. host["contacts.as_client"] .. ";\n")
   print("var last_misbehaving_flows_as_server = " .. host["misbehaving_flows.as_server"] .. ";\n")
   print("var last_misbehaving_flows_as_client = " .. host["misbehaving_flows.as_client"] .. ";\n")
   print("var last_unreachable_flows_as_server = " .. host["unreachable_flows.as_server"] .. ";\n")
   print("var last_unreachable_flows_as_client = " .. host["unreachable_flows.as_client"] .. ";\n")
   print("var last_sent_tcp_retransmissions = " .. host["tcpPacketStats.sent"]["retransmissions"].. ";\n")
   print("var last_sent_tcp_ooo = " .. host["tcpPacketStats.sent"]["out_of_order"] .. ";\n")
   print("var last_sent_tcp_lost = " .. host["tcpPacketStats.sent"]["lost"].. ";\n")
   print("var last_sent_tcp_keep_alive = " .. host["tcpPacketStats.sent"]["keep_alive"] .. ";\n")
   print("var last_rcvd_tcp_retransmissions = " .. host["tcpPacketStats.rcvd"]["retransmissions"].. ";\n")
   print("var last_rcvd_tcp_ooo = " .. host["tcpPacketStats.rcvd"]["out_of_order"] .. ";\n")
   print("var last_rcvd_tcp_lost = " .. host["tcpPacketStats.rcvd"]["lost"].. ";\n")
   print("var last_rcvd_tcp_keep_alive = " .. host["tcpPacketStats.rcvd"]["keep_alive"] .. ";\n")

   if ntop.isnEdge() then
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
         if(content == "\"{}\"") {
             var e = document.getElementById('host_purged');
             e.style.display = "block";
         } else {
   			var host = jQuery.parseJSON(content);
                        var http = host.http;
   			$('#first_seen').html(epoch2Seen(host["seen.first"]));
   			$('#last_seen').html(epoch2Seen(host["seen.last"]));
   			$('#pkts_sent').html(formatPackets(host["packets.sent"]));
   			$('#pkts_rcvd').html(formatPackets(host["packets.rcvd"]));
   			$('#bytes_sent').html(bytesToVolume(host["bytes.sent"]));
   			$('#bytes_rcvd').html(bytesToVolume(host["bytes.rcvd"]));

   			$('#pkt_retransmissions_sent').html(formatPackets(host["tcpPacketStats.sent"]["retransmissions"]));
   			$('#pkt_ooo_sent').html(formatPackets(host["tcpPacketStats.sent"]["out_of_order"]));
   			$('#pkt_lost_sent').html(formatPackets(host["tcpPacketStats.sent"]["lost"]));
   			$('#pkt_keep_alive_sent').html(formatPackets(host["tcpPacketStats.sent"]["keep_alive"]));

   			$('#pkt_retransmissions_rcvd').html(formatPackets(host["tcpPacketStats.rcvd"]["retransmissions"]));
   			$('#pkt_ooo_rcvd').html(formatPackets(host["tcpPacketStats.rcvd"]["out_of_order"]));
   			$('#pkt_lost_rcvd').html(formatPackets(host["tcpPacketStats.rcvd"]["lost"]));
   			$('#pkt_keep_alive_rcvd').html(formatPackets(host["tcpPacketStats.rcvd"]["keep_alive"]));

   			if(!host["name"]) {
   			   $('#name').html(host["ip"]);
   			} else {
   			   $('#name').html(host["name"]);
   			}
   			$('#num_alerts').html(host["num_alerts"]);
   			$('#score').html(host["score"]);
   			$('#num_flow_alerts').html(host["active_alerted_flows"]);
   			$('#active_flows_as_client').html(addCommas(host["active_flows.as_client"]));
   			$('#active_flows_as_server').html(addCommas(host["active_flows.as_server"]));
   			$('#active_peers_as_client').html(addCommas(host["contacts.as_client"]));
   			$('#active_peers_as_server').html(addCommas(host["contacts.as_server"]));
   			$('#flows_as_client').html(addCommas(host["flows.as_client"]));
                        $('#misbehaving_flows_as_client').html(addCommas(host["misbehaving_flows.as_client"]));
                        $('#unreachable_flows_as_client').html(addCommas(host["unreachable_flows.as_client"]));
   			$('#flows_as_server').html(addCommas(host["flows.as_server"]));
                        $('#misbehaving_flows_as_server').html(addCommas(host["misbehaving_flows.as_server"]));
                        $('#unreachable_flows_as_server').html(addCommas(host["unreachable_flows.as_server"]));
   		  }]]

   if ntop.isnEdge() then
print [[
                        if(host["flows.dropped"] > 0) {
                          if(host["flows.dropped"] == last_dropped_flows) {
                            $('#trend_bridge_dropped_flows').html("<i class=\"fas fa-minus\"></i>");
                          } else {
                            $('#trend_bridge_dropped_flows').html("<i class=\"fas fa-arrow-up\"></i>");
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
   			      $('#trend_sent_num_queries').html("<i class=\"fas fa-minus\"></i>");
   			   } else {
   			      last_dns_sent_num_queries = host["dns"]["sent"]["num_queries"];
   			      $('#trend_sent_num_queries').html("<i class=\"fas fa-arrow-up\"></i>");
   			   }

   			   if(host["dns"]["sent"]["num_replies_ok"] == last_dns_sent_num_replies_ok) {
   			      $('#trend_sent_num_replies_ok').html("<i class=\"fas fa-minus\"></i>");
   			   } else {
   			      last_dns_sent_num_replies_ok = host["dns"]["sent"]["num_replies_ok"];
   			      $('#trend_sent_num_replies_ok').html("<i class=\"fas fa-arrow-up\"></i>");
   			   }

   			   if(host["dns"]["sent"]["num_replies_error"] == last_dns_sent_num_replies_error) {
   			      $('#trend_sent_num_replies_error').html("<i class=\"fas fa-minus\"></i>");
   			   } else {
   			      last_dns_sent_num_replies_error = host["dns"]["sent"]["num_replies_error"];
   			      $('#trend_sent_num_replies_error').html("<i class=\"fas fa-arrow-up\"></i>");
   			   }

   			   if(host["dns"]["rcvd"]["num_queries"] == last_dns_rcvd_num_queries) {
   			      $('#trend_rcvd_num_queries').html("<i class=\"fas fa-minus\"></i>");
   			   } else {
   			      last_dns_rcvd_num_queries = host["dns"]["rcvd"]["num_queries"];
   			      $('#trend_rcvd_num_queries').html("<i class=\"fas fa-arrow-up\"></i>");
   			   }

   			   if(host["dns"]["rcvd"]["num_replies_ok"] == last_dns_rcvd_num_replies_ok) {
   			      $('#trend_rcvd_num_replies_ok').html("<i class=\"fas fa-minus\"></i>");
   			   } else {
   			      last_dns_rcvd_num_replies_ok = host["dns"]["rcvd"]["num_replies_ok"];
   			      $('#trend_rcvd_num_replies_ok').html("<i class=\"fas fa-arrow-up\"></i>");
   			   }

   			   if(host["dns"]["rcvd"]["num_replies_error"] == last_dns_rcvd_num_replies_error) {
   			      $('#trend_rcvd_num_replies_error').html("<i class=\"fas fa-minus\"></i>");
   			   } else {
   			      last_dns_rcvd_num_replies_error = host["dns"]["rcvd"]["num_replies_error"];
   			      $('#trend_rcvd_num_replies_error').html("<i class=\"fas fa-arrow-up\"></i>");
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
   		      $('#'+key+'_num_vhost_req_serv').html(addCommas(obj["xs"])+" "+get_trend(obj["http.requests"], last_http_val[key+"_req_serv"]));
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
         print('\tif(http["sender"]["query"]["num_'..method..'"] == last_http_query_num_'..method..') {\n\t$("#trend_http_query_num_'..method..'").html(\'<i class=\"fas fa-minus\"></i>\');\n')
         print('} else {\n\tlast_http_query_num_'..method..' = http["sender"]["query"]["num_'..method..'"];$("#trend_http_query_num_'..method..'").html(\'<i class=\"fas fa-arrow-up\"></i>\'); }\n')
      end

      retcodes = { "1xx", "2xx", "3xx", "4xx", "5xx" }
      for i, retcode in ipairs(retcodes) do
         print('\t$("#http_response_num_'..retcode..'").html(addCommas(http["receiver"]["response"]["num_'..retcode..'"]));\n')
         print('\tif(http["receiver"]["response"]["num_'..retcode..'"] == last_http_response_num_'..retcode..') {\n\t$("#trend_http_response_num_'..retcode..'").html(\'<i class=\"fas fa-minus\"></i>\');\n')
         print('} else {\n\tlast_http_response_num_'..retcode..' = http["receiver"]["response"]["num_'..retcode..'"];$("#trend_http_response_num_'..retcode..'").html(\'<i class=\"fas fa-arrow-up\"></i>\'); }\n')
      end
   end
   end

   print [[
   			/* **************************************** */

			$('#trend_as_active_client').html(drawTrend(host["active_flows.as_client"], last_active_flows_as_client, ""));
			$('#trend_as_active_server').html(drawTrend(host["active_flows.as_server"], last_active_flows_as_server, ""));
			$('#peers_trend_as_active_client').html(drawTrend(host["contacts.as_client"], last_active_peers_as_client, ""));
			$('#peers_trend_as_active_server').html(drawTrend(host["contacts.as_server"], last_active_peers_as_server, ""));
			$('#trend_as_client').html(drawTrend(host["flows.as_client"], last_flows_as_client, ""));
			$('#trend_as_server').html(drawTrend(host["flows.as_server"], last_flows_as_server, ""));
			$('#trend_misbehaving_flows_as_server').html(drawTrend(host["misbehaving_flows.as_server"], last_misbehaving_flows_as_server, " style=\"color: #B94A48;\""));
			$('#trend_misbehaving_flows_as_client').html(drawTrend(host["misbehaving_flows.as_client"], last_misbehaving_flows_as_client, " style=\"color: #B94A48;\""));
			$('#trend_unreachable_flows_as_server').html(drawTrend(host["unreachable_flows.as_server"], last_unreachable_flows_as_server, " style=\"color: #B94A48;\""));
			$('#trend_unreachable_flows_as_client').html(drawTrend(host["unreachable_flows.as_client"], last_unreachable_flows_as_client, " style=\"color: #B94A48;\""));

			$('#alerts_trend').html(drawTrend(host["num_alerts"], last_num_alerts, " style=\"color: #B94A48;\""));
			$('#score_trend').html(drawTrend(host["score"], last_score, " style=\"color: #B94A48;\""));
			$('#flow_alerts_trend').html(drawTrend(host["active_alerted_flows"], last_num_flow_alerts, " style=\"color: #B94A48;\""));
			$('#sent_trend').html(drawTrend(host["packets.sent"], last_pkts_sent, ""));
			$('#rcvd_trend').html(drawTrend(host["packets.rcvd"], last_pkts_rcvd, ""));

			$('#pkt_retransmissions_sent_trend').html(drawTrend(host["tcpPacketStats.sent"]["retransmissions"], last_sent_tcp_retransmissions, ""));
			$('#pkt_ooo_sent_trend').html(drawTrend(host["tcpPacketStats.sent"]["out_of_order"], last_sent_tcp_ooo, ""));
 		        $('#pkt_lost_sent_trend').html(drawTrend(host["tcpPacketStats.sent"]["lost"], last_sent_tcp_lost, ""));
 		        $('#pkt_keep_alive_sent_trend').html(drawTrend(host["tcpPacketStats.sent"]["keep_alive"], last_sent_tcp_keep_alive, ""));

			$('#pkt_retransmissions_rcvd_trend').html(drawTrend(host["tcpPacketStats.rcvd"]["retransmissions"], last_rcvd_tcp_retransmissions, ""));
			$('#pkt_ooo_rcvd_trend').html(drawTrend(host["tcpPacketStats.rcvd"]["out_of_order"], last_rcvd_tcp_ooo, ""));
 		        $('#pkt_lost_rcvd_trend').html(drawTrend(host["tcpPacketStats.rcvd"]["lost"], last_rcvd_tcp_lost, ""));
 		        $('#pkt_keep_alive_rcvd_trend').html(drawTrend(host["tcpPacketStats.rcvd"]["keep_alive"], last_rcvd_tcp_keep_alive, ""));

   			last_num_alerts = host["num_alerts"];
   			last_score = host["score"];
   			last_num_flow_alerts = host["active_alerted_flows"];
   			last_pkts_sent = host["packets.sent"];
   			last_pkts_rcvd = host["packets.rcvd"];
   			last_active_flows_as_client = host["active_flows.as_client"];
   			last_active_flows_as_server = host["active_flows.as_server"];
   			last_active_peers_as_client = host["contacts.as_client"];
   			last_active_peers_as_server = host["contacts.as_server"];
   			last_flows_as_client = host["flows.as_client"];
   			last_misbehaving_flows_as_server = host["misbehaving_flows.as_server"];
   			last_misbehaving_flows_as_client = host["misbehaving_flows.as_client"];
   			last_unreachable_flows_as_server = host["unreachable_flows.as_server"];
   			last_unreachable_flows_as_client = host["unreachable_flows.as_client"];
   			last_flows_as_server = host["flows.as_server"];
   			last_sent_tcp_retransmissions = host["tcpPacketStats.sent"]["retransmissions"];
   			last_sent_tcp_ooo = host["tcpPacketStats.sent"]["out_of_order"];
   			last_sent_tcp_lost = host["tcpPacketStats.sent"]["lost"];
   			last_sent_tcp_keep_alive = host["tcpPacketStats.sent"]["keep_alive"];
   			last_rcvd_tcp_retransmissions = host["tcpPacketStats.rcvd"]["retransmissions"];
   			last_rcvd_tcp_ooo = host["tcpPacketStats.rcvd"]["out_of_order"];
   			last_rcvd_tcp_lost = host["tcpPacketStats.rcvd"]["lost"];
   			last_rcvd_tcp_keep_alive = host["tcpPacketStats.rcvd"]["keep_alive"];
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
