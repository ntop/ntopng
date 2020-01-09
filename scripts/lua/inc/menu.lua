--
-- (C) 2013-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
local alerts_api = require("alerts_api")
local recording_utils = require "recording_utils"
local remote_assistance = require "remote_assistance"
local telemetry_utils = require "telemetry_utils"
local ts_utils = require("ts_utils_core")

local is_admin = isAdministrator()

print[[
<script type='text/javascript'>
   /* Some localization strings to pass from lua to javacript */
   let i18n = {
      "no_results_found": "]] print(i18n("no_results_found")) print[[",
      "change_number_of_rows": "]] print(i18n("change_number_of_rows")) print[[",
      "no_data_available": "]] print(i18n("no_data_available")) print[[",
      "showing_x_to_y_rows": "]] print(i18n("showing_x_to_y_rows", {x="{0}", y="{1}", tot="{2}"})) print[[",
      "actions": "]] print(i18n("actions")) print[[",
      "query_was_aborted": "]] print(i18n("graphs.query_was_aborted")) print[[",
      "exports": "]] print(i18n("system_stats.exports_label")) print[[",
   };

   let http_prefix = "]] print(ntop.getHttpPrefix()) print[[";
</script>]]

if ntop.isnEdge() then
   dofile(dirs.installdir .. "/pro/scripts/lua/nedge/inc/menu.lua")
   return
end

local template = require "template_utils"

prefs = ntop.getPrefs()
local iface_names = interface.getIfNames()

-- tprint(iface_names)

num_ifaces = 0
for k,v in pairs(iface_names) do
   num_ifaces = num_ifaces+1
end

-- Adding main container div for the time being
--print("<div class=\"container\">")
print ([[
      <div id='n-sidebar' class="bg-light active p-2">

         <h3 class='muted'>
            <a href='/'>
               ]].. addLogoSvg() ..[[
               ]].. addSquaredLogo() .. [[   
            </a>
         </h3>

         <button data-toggle='sidebar' class='btn float-right d-md-none d-lg-none d-xs-block d-sm-block'>
            <i class='fas fa-times'></i>
         </button>
        
         <script type="text/javascript" src="/js/sidebar.js"></script>

	      <ul class="nav flex-column">
]])



interface.select(ifname)
local ifs = interface.getStats()
local is_pcap_dump = interface.isPcapDumpInterface()
local is_packet_interface = interface.isPacketInterface()
ifId = ifs.id

-- ##############################################
-- Dashboard

if not is_pcap_dump then
   if(active_page == "dashboard") then
      print [[ <li class="nav-item dropdown active">
	       <a class="nav-link dropdown-toggle active" data-toggle="dropdown" href="#">
]]
   else
      print [[ <li class="dropdown">
	       <a class="nav-link dropdown-toggle" data-toggle="dropdown" href="#">
]]
   end

   print [[
	<i class="fas fa-tachometer-alt fa-lg"></i> Dashboard
      </a>

    <ul class="dropdown-menu">
<li class="nav-item"><a class="dropdown-item" href="]]

print(ntop.getHttpPrefix())
if ntop.isPro() then
   print("/lua/pro/dashboard.lua")
else
   print("/lua/index.lua")
end

print [["><i class="fas fa-tachometer-alt"></i> ]] print(i18n("dashboard.traffic_dashboard")) print[[</a></li>]]

if interface.isDiscoverableInterface() and not interface.isLoopback() then
    print('<li class="nav-item"><a class="dropdown-item" href="'..ntop.getHttpPrefix()..'/lua/discover.lua"><i class="fas fa-lightbulb"></i> ') print(i18n("prefs.network_discovery")) print('</a></li>')
  end

if(ntop.isPro()) then
  print('<li class="nav-item"><a class="dropdown-item" href="'..ntop.getHttpPrefix()..'/lua/pro/report.lua"><i class="fas fa-chart-area"></i> ') print(i18n("report.traffic_report")) print('</a></li>')
end

if ntop.isPro() and prefs.is_dump_flows_to_mysql_enabled and not ifs.isViewed then
  print('<li class="dropdown-divider"></li>')
  print('<li class="nav-item"><a class="dropdown-item" href="'..ntop.getHttpPrefix()..'/lua/pro/db_explorer.lua?ifid='..ifId..'"><i class="fas fa-history"></i> ') print(i18n("db_explorer.historical_data_explorer")) print('</a></li>')
end


print [[
    </ul>
   ]]
end

-- ##############################################
-- Alerts

if ntop.getPrefs().are_alerts_enabled == true then

   local active = ""
   local is_shown = not ifs["has_alerts"] and not alerts_api.hasEntitiesWithAlertsDisabled(ifId)
   local color = ""

   -- if alert_cache["num_alerts_engaged"] > 0 then
   -- color = 'style="color: #B94A48;"' -- bootstrap danger red
   -- end

   print([[
      <li class='nav-item ]].. (is_shown and 'd-none' or '') ..[[' id='alerts-id'>
         <a data-toggle='collapse' class=']].. (active_page == 'alerts' and 'active' or '') ..[[ submenu' href='#alerts-submenu'>
            <i class='fas  fa-exclamation-triangle'></i> <span class='title'>Alerts</span>
         </a>
         <div class='collapse' id='alerts-submenu'>
            <ul class='nav flex-column'>
               <li>
                  <a href=']].. ntop.getHttpPrefix() ..[[/lua/show_alerts.lua'>
                     <i class="fas fa-exclamation-triangle" id="alerts-menu-triangle"></i> ]].. i18n("show_alerts.detected_alerts") ..[[
                  </a>
               </li>
               ]]..
               (function()

                  if ntop.isEnterprise() then
                     return ([[
                        <li>
                           <a href=']].. ntop.getHttpPrefix() ..[[/lua/pro/enterprise/alerts_dashboard.lua'>
                              ]].. i18n("alerts_dashboard.alerts_dashboard") ..[[
                           </a>
                        </li>
                        <li class="dropdown-divider"></li>
                        <li>
                           <a href=']].. ntop.getHttpPrefix() ..[[/lua/pro/enterprise/flow_alerts_explorer.lua'>
                              ]].. i18n("flow_alerts_explorer.label") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return [[]]
                  end
               end)()
               ..[[
            </ul>
         </div>
      </li>
   ]])
end

-- ##############################################
-- Flows

url = ntop.getHttpPrefix().."/lua/flows_stats.lua"

print([[
   <li class='nav-item'>
      <a class=']].. (active_page == 'flows' and 'active' or '') ..[[' href=']].. url ..[['>
         <i class='fas fa-stream '></i> <span class='title'>]].. i18n("flows") ..[[</span>
      </a>
   </li> 
]])

-- ##############################################
-- Hosts

if not ifs.isViewed then -- Currently, hosts are not kept for viewed interfaces, only for their view

   print([[
      <li class='nav-item'>
         <a data-toggle='collapse' class=']].. (active_page == 'hosts' and 'active' or '') ..[[ submenu' href='#hosts-submenu'>
            <i class='fas fa-server '></i> <span class='title'>]].. i18n("flows_page.hosts") ..[[</span>
         </a>
         <div class='collapse' id='hosts-submenu'>
            <ul class='nav flex-column'>
               <li>
                  <a href=']].. ntop.getHttpPrefix() ..[[/lua/hosts_stats.lua'>
                     ]].. i18n("flows_page.hosts") ..[[
                  </a>
               </li>
               ]].. 
               (function()
                  if ifs.has_macs then
                     return ([[
                        <li>
                           <a href="]]..ntop.getHttpPrefix()..[[/lua/macs_stats.lua?devices_mode=source_macs_only">
                              ]].. i18n("users.devices") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return [[]]
                  end
               end)()
               ..[[
               <li>
                  <a href="]].. ntop.getHttpPrefix() ..[[/lua/network_stats.lua">
                     ]] .. i18n("networks") ..[[
                  </a>
               </li>
               <li>
                  <a href="]] ..ntop.getHttpPrefix()..[[/lua/pool_stats.lua">
                     ]].. i18n("host_pools.host_pools") ..[[
                  </a>
               </li>
               <li>
                  <a href="]] ..ntop.getHttpPrefix()..[[/lua/as_stats.lua">
                     ]].. i18n("prefs.toggle_asn_rrds_title") ..[[
                  </a>
               </li>
               <li>
                  <a href="]] ..ntop.getHttpPrefix()..[[/lua/country_stats.lua">
                     ]].. i18n("countries") ..[[
                  </a>
               </li>
               <li>
                  <a href="]] ..ntop.getHttpPrefix()..[[/lua/os_stats.lua.lua">
                     ]].. i18n("operating_systems") ..[[
                  </a>
               </li>

               ]].. 
               (function()
                  if interface.hasVLANs() then
                     return ([[
                        <li>
                           <a href="]]..ntop.getHttpPrefix()..[[/lua/vlan_stats.lua">
                              ]].. i18n("vlan_stats.vlans") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return [[]]
                  end
               end)()
               ..[[
               ]].. 
               (function()
                  if ifs.has_seen_pods then
                     return ([[
                        <li>
                           <a href="]]..ntop.getHttpPrefix()..[[/lua/pods_stats.lua">
                              ]].. i18n("containers_stats.pods") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return [[]]
                  end
               end)()
               ..[[
               ]].. 
               (function()
                  if ifs.has_seen_containers then
                     return ([[
                        <li>
                           <a href="]]..ntop.getHttpPrefix()..[[/lua/containers_stats.lua">
                              ]].. i18n("containers_stats.containers") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return [[]]
                  end
               end)()
               ..[[
               
               <li class="dropdown-divider"></li>
               
               <li>
                  <a href="]]..ntop.getHttpPrefix()..[[/lua/http_servers_stats.lua">
                     ]].. i18n("http_servers_stats.http_servers") ..[[
                  </a>
               </li>
               ]].. 
               (function()
                  if not is_pcap_dump then
                     return ([[
                        <li>
                           <a href="]]..ntop.getHttpPrefix()..[[/lua/top_hosts.lua">
                              ]].. i18n("processes_stats.top_hosts") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return [[]]
                  end
               end)()
               ..[[

               <li class="dropdown-divider"></li>

               ]].. 
               (function()
                  if not interface.isLoopback() then
                     return ([[
                        <li>
                           <a href="]]..ntop.getHttpPrefix()..[[/lua/hosts_geomap.lua">
                              ]].. i18n("geo_map.geo_map") ..[[
                           </a>
                        </li>
                        <li>
                           <a href="]]..ntop.getHttpPrefix()..[[/lua/hosts_treemap.lua">
                              ]].. i18n("tree_map.hosts_treemap") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return [[]]
                  end
               end)()
               ..[[
               ]].. 
               (function()
                  if ntop.getPrefs().is_arp_matrix_generation_enabled then
                     return ([[
                        <li>
                           <a href="]]..ntop.getHttpPrefix()..[[/lua/arp_matrix_graph.lua.lua">
                              ]].. i18n("arp_top_talkers") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return [[]]
                  end
               end)()
               ..[[
               <li>
                  <a href="]].. ntop.getHttpPrefix() ..[[/lua/bubble.lua">
                     </i> Host Explorer
                  </a>
               </li>
            </ul>
         </div>
      </li> 
   ]])


end -- closes not ifs.isViewed

-- ##############################################
-- Exporters

local info = ntop.getInfo()

if((ifs["type"] == "zmq") and ntop.isEnterprise()) then
  if active_page == "exporters" then
    print [[ <li class="nav-item dropdown active">
   <a class="nav-link dropdown-toggle active" data-toggle="dropdown" href="#">
]]
  else
    print [[ <li class="nav-item dropdown">
   <a class="nav-link dropdown-toggle" data-toggle="dropdown" href="#">
]]
  end

   print(i18n("flow_devices.exporters")) print[[ <b class="caret"></b>
      </a>
      <ul class="dropdown-menu">
]]

   local has_ebpf_events, has_sflow_devs = false, false
   if ifs.has_seen_ebpf_events then
      has_ebpf_events = true
      print('<li class="nav-item"><a class="dropdown-item" href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/event_exporters.lua ">') print(i18n("event_exporters.event_exporters")) print('</a></li>')
   elseif table.len(interface.getSFlowDevices() or {}) > 0 then
      has_sflow_devs = true
      print('<li class="nav-item"><a class="dropdown-item" href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/flowdevices_stats.lua?sflow_filter=All">') print(i18n("flows_page.sflow_devices")) print('</a></li>')

   end

   if has_ebpf_events or has_sflow_devs then
      print('<li class="dropdown-divider"></li>')
      print('<li class="nav-item" class="dropdown-header">') print(i18n("flows")) print('</li>')
   end

   print('<li class="nav-item"><a class="dropdown-item" href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/flowdevices_stats.lua">') print(i18n("flows_page.flow_exporters")) print('</a></li>')

  print [[

      </ul>
    </li>]]
end

-- ##############################################
-- Interface

if(num_ifaces > 0) then

url = ntop.getHttpPrefix().."/lua/if_stats.lua"

print([[
   <li class='nav-item'>
      <a class=']].. (active_page == 'if_stats' and 'active' or '') ..[[' href=']].. url ..[['>
         <i class='fas fa-ethernet '></i> <span class='title'>]].. i18n("interface") ..[[</span>
      </a>
   </li> 
]])

-- ##############################################
-- System

if isAllowedSystemInterface() then
   local plugins_utils = require("plugins_utils")

   if active_page == "system_stats" or active_page == "system_interfaces_stats" then
     print [[ <li class="nav-item dropdown active">
      <a class="nav-link dropdown-toggle active" data-toggle="dropdown" href="#">
]]
   else
     print [[ <li class="nav-item dropdown">
      <a class="nav-link dropdown-toggle" data-toggle="dropdown" href="#">
]]
   end
   print(i18n("system")) print[[ <b class="caret"></b>
	 </a>
       <ul class="dropdown-menu">]]

   if ntop.isEnterprise() then
      print('<li class="nav-item"><a class="dropdown-item" href="'..ntop.getHttpPrefix()..'/lua/pro/enterprise/snmpdevices_stats.lua">') print(i18n("prefs.snmp")) print('</a></li>')
   end

   print[[<li class="nav-item"><a class="dropdown-item" href="]] print(ntop.getHttpPrefix()) print[[/lua/system_stats.lua">]] print(i18n("system_status")) print[[</a></li>]]

   if num_ifaces > 1 then
      print[[<li class="nav-item"><a class="dropdown-item" href="]] print(ntop.getHttpPrefix()) print[[/lua/system_interfaces_stats.lua">]] print(i18n("system_interfaces_status")) print[[</a></li>]]
   end

   local menu = plugins_utils.getMenuEntries() or {}

   if not table.empty(menu) then
      print('<li class="divider"></li>')

      for _, entry in pairsByField(menu, "sort_order", rev) do
         print[[<li class="nav-item"><a class="dropdown-item" href="]] print(entry.url) print[[">]] print(i18n(entry.label) or entry.label) print[[</a></li>]]
      end
   end

   print[[</ul>]]
end

-- ##############################################
-- Admin

if active_page == "admin" then
  print [[ <li class="nav-item dropdown active">
      <a class="nav-link dropdown-toggle active" data-toggle="dropdown" href="#">
]]
else
  print [[ <li class="nav-item dropdown">
      <span class="badge badge-pill badge-danger" id="admin-badge" style="float:right;margin-right:20px;display:none"></span>
      <a class="nav-link dropdown-toggle" data-toggle="dropdown" href="#">
]]
end

print [[
	<i class="fas fa-cog fa-lg"></i> Settings
      </a>
    <ul class="dropdown-menu">]]

if _SESSION["localuser"] then
   if(is_admin) then
     print[[<li class="nav-item"><a class="dropdown-item" href="]] print(ntop.getHttpPrefix())
     print[[/lua/admin/users.lua"><i class="fas fa-user"></i> ]] print(i18n("manage_users.manage_users")) print[[</a></li>]]
   else
     print [[<li class="nav-item"><a class="dropdown-item" href="#password_dialog"  data-toggle="modal"><i class="fas fa-user"></i> ]] print(i18n("login.change_password")) print[[</a></li>]]
   end
end

if(is_admin) then
   print("<li class=\"nav-item\"><a class=\"dropdown-item\" href=\""..ntop.getHttpPrefix().."/lua/admin/prefs.lua\"><i class=\"fas fa-flask\"></i> ") print(i18n("prefs.preferences")) print("</a></li>\n")

   if remote_assistance.isAvailable() then
      print("<li class=\"nav-item\"><a class=\"dropdown-item\" href=\""..ntop.getHttpPrefix().."/lua/admin/remote_assistance.lua\"><i class=\"fas fa-comment-dots\"></i> ") print(i18n("remote_assistance.remote_assistance")) print("</a></li>\n")
   end

   if(ntop.isPro()) then
      print("<li class=\"nav-item\"><a class=\"dropdown-item\" href=\""..ntop.getHttpPrefix().."/lua/pro/admin/edit_profiles.lua\"><i class=\"fas fa-user-md\"></i> ") print(i18n("traffic_profiles.traffic_profiles")) print("</a></li>\n")
      if(false) then
	 print("<li class=\"nav-item\"><a class=\"dropdown-item\" href=\""..ntop.getHttpPrefix().."/lua/pro/admin/list_reports.lua\"><i class=\"fas fa-archive\"></i> Reports Archive</a></li>\n")
      end
   end

   print("<li class=\"nav-item\"><a class=\"dropdown-item\" href=\""..ntop.getHttpPrefix().."/lua/admin/edit_categories.lua\"><i class=\"fas fa-tags\"></i> ") print(i18n("custom_categories.apps_and_categories")) print("</a></li>\n")
   print("<li class=\"nav-item\"><a class=\"dropdown-item\" href=\""..ntop.getHttpPrefix().."/lua/admin/edit_category_lists.lua\"><i class=\"fas fa-sticky-note\"></i> ") print(i18n("category_lists.category_lists")) print("</a></li>\n")


   print("<li class=\"nav-item\"><a class=\"dropdown-item\" href=\""..ntop.getHttpPrefix().."/lua/admin/edit_device_protocols.lua\"><i class=\"fas fa-tablet\"></i> ") print(i18n("device_protocols.device_protocols")) print("</a></li>\n")
   print("<li class=\"nav-item\"><a class=\"dropdown-item\" href=\""..ntop.getHttpPrefix().."/lua/admin/scripts_config.lua\"><i class=\"fab fa-superpowers\"></i> ") print(i18n("about.user_scripts")) print("</a></li>\n")
end

if _SESSION["localuser"] or is_admin then
   print [[
      <li class="dropdown-divider"></li>]]
end

print [[
      <li class="nav-item"><a class="dropdown-item" href="]]
print(ntop.getHttpPrefix())
print [[/lua/manage_data.lua"><i class="fas fa-hdd"></i> ]] print(i18n("manage_data.manage_data")) print[[</a></li>]]

if(is_admin) then
  print [[
      <li class="nav-item"><a class="dropdown-item" href="]]
  print(ntop.getHttpPrefix())
  print [[/lua/get_config.lua"><i class="fas fa-download"></i> ]] print(i18n("conf_backup.conf_backup")) print[[</a></li>]]

  print[[ <li class="nav-item"><a class="dropdown-item" href="https://www.ntop.org/guides/ntopng/web_gui/settings.html#restore-configuration" target="_blank"><i class="fas fa-upload"></i> ]] print(i18n("conf_backup.conf_restore")) print[[ <i class="fas fa-external-link-alt"></i></a></li>]]
end

-- Updates submenu
if(is_admin and ntop.isPackage() and not ntop.isWindows()) then
  print [[
      <li class="dropdown-divider"></li>
      <li class="dropdown-header" id="updates-info-li"></li>
      <li class="nav-item"><a class="dropdown-item" id="updates-install-li" href="#"></a></li>
  ]]

-- Updates check
print[[
<script>
  $('#updates-info-li').html(']] print(i18n("updates.checking")) print[[');
  $('#updates-install-li').hide();

  var updates_csrf = ']] print(ntop.getRandomCSRFValue()) print[[';

  /* Install latest update */
  var installUpdate = function() {
    if (confirm(']] print(i18n("updates.install_confirm")) 
      if info["pro.license_days_left"] ~= nil and info["pro.license_days_left"] <= 0 then
        -- License is valid, however maintenance is expired: warning the user
        print(" "..i18n("updates.maintenance_expired"))
      end
      print[[')) {
      $.ajax({
        type: 'POST',
        url: ']] print (ntop.getHttpPrefix()) print [[/lua/install_update.lua',
        data: {
          csrf: updates_csrf
        },
        success: function(rsp) {
          updates_csrf = rsp.csrf;
          $('#updates-info-li').html(']] print(i18n("updates.installing")) print[[')
          $('#updates-install-li').hide();
          $('#admin-badge').hide();
        }
      });
    }
  }

  /* Check for new updates */
  var checkForUpdates = function() {
    $.ajax({
      type: 'POST',
      url: ']] print (ntop.getHttpPrefix()) print [[/lua/check_update.lua',
      data: {
        csrf: updates_csrf,
        search: 'true'
      },
      success: function(rsp) {
        updates_csrf = rsp.csrf;
        $('#updates-info-li').html(']] print(i18n("updates.checking")) print[[');
        $('#updates-install-li').hide();
        $('#admin-badge').hide();
      }
    });
  }

  /* Update the menu with the current updates status */
  var updatesRefresh = function() {
    $.ajax({
      type: 'GET',
        url: ']] print (ntop.getHttpPrefix()) print [[/lua/check_update.lua',
        data: {},
        success: function(rsp) {
          if(rsp && rsp.status) {

            if (rsp.status == 'installing') {
              $('#updates-info-li').html(']] print(i18n("updates.installing")) print[[')
              $('#updates-install-li').hide();
              $('#admin-badge').hide();

            } else if (rsp.status == 'checking') {
              $('#updates-info-li').html(']] print(i18n("updates.checking")) print[[');
              $('#updates-install-li').hide();
              $('#admin-badge').hide();

            } else if (rsp.status == 'update-avail' || rsp.status == 'upgrade-failure') { 
              $('#updates-info-li').html('<span class="badge badge-pill badge-danger">]] print(i18n("updates.available")) print[[</span> ntopng ' + rsp.version + '!');
              var icon = '<i class="fas fa-download"></i>';
              $('#updates-install-li').attr('title', '');
              if (rsp.status == 'upgrade-failure') {
                icon = '<i class="fas fa-exclamation-triangle"></i>';
                $('#updates-install-li').attr('title', ']] print(i18n("updates.upgrade_failure_message")) print [[');
              }
              $('#updates-install-li').html(icon + ' ]] print(i18n("updates.install")) print[[');
              $('#updates-install-li').show();
              $('#updates-install-li').off("click");
              $('#updates-install-li').click(installUpdate);
              if (rsp.status == 'upgrade-failure') $('#admin-badge').html('!');
              else $('#admin-badge').html('1');
              $('#admin-badge').show();

            } else /* (rsp.status == 'not-avail') */ {
              $('#updates-info-li').html(']] print(i18n("updates.no_updates")) print[[');
              $('#updates-install-li').html('<i class="fas fa-sync"></i> ]] print(i18n("updates.check")) print[[');
              $('#updates-install-li').show();
              $('#updates-install-li').off("click");
              $('#updates-install-li').click(checkForUpdates);
              $('#admin-badge').hide();
            }
          }
        }
    });
  }
  updatesRefresh();
  setInterval(updatesRefresh, 10000);
</script>
]]
end

print[[
    </ul>
  </li>]]

end -- num_ifaces > 0


-- CLOSE NEW SIDEBAR

print([[
   </ul>
   
   <div class='sidebar-info'>
      <small>
         ]].. info.product .. ' ' .. getNtopngRelease() ..[[ Edition v.]].. info.version ..[[
      </small>
   </div>

   </div>
]])


-- select the original interface back to prevent possible issues
interface.select(ifname)

if(dirs.workingdir == "/var/tmp/ntopng") then
   print('<br><div class="alert alert-danger" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> <A HREF="https://www.ntop.org/support/faq/migrate-the-data-directory-in-ntopng/">')
   print(i18n("about.datadir_warning"))
   print('</a></div>')
end

local lbd_serialize_by_mac = (_POST["lbd_hosts_as_macs"] == "1") or (ntop.getPref(string.format("ntopng.prefs.ifid_%u.serialize_local_broadcast_hosts_as_macs", ifs.id)) == "1")

if(ifs.has_seen_dhcp_addresses and is_admin and (not is_pcap_dump) and is_packet_interface) then
   if(not lbd_serialize_by_mac) then
      if(ntop.getPref(string.format("ntopng.prefs.ifid_%u.disable_host_identifier_message", ifs.id)) ~= "1") then
	 print('<br><div id="host-id-message-warning" class="alert alert-warning" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> ')
	 print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
	 print(i18n("about.host_identifier_warning", {name=i18n("prefs.toggle_host_tskey_title"), url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=config"}))
	 print('</a></div>')
      end
   elseif isEmptyString(_POST["dhcp_ranges"]) then
      local dhcp_utils = require("dhcp_utils")
      local ranges = dhcp_utils.listRanges(ifs.id)

      if(table.empty(ranges)) then
	 print('<br><div class="alert alert-warning" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> ')
	 print(i18n("about.dhcp_range_missing_warning", {
	    name = i18n("prefs.toggle_host_tskey_title"),
	    url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=config",
	    dhcp_url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=dhcp"}))
	 print('</a></div>')
      end
   end
end

-- Hidden by default, will be shown by the footer if necessary
print('<div id="influxdb-error-msg" class="alert alert-danger" style="display:none" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> <span id="influxdb-error-msg-text"></span>')
print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
print('</div>')

-- Hidden by default, will be shown by the footer if necessary
print('<div id="move-rrd-to-influxdb" class="alert alert-warning" style="display:none" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> ')
print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
print(i18n("about.influxdb_migration_msg", {url="https://www.ntop.org/ntopng/ntopng-and-time-series-from-rrd-to-influxdb-new-charts-with-time-shift/"}))
print('</div>')

if(_SESSION["INVALID_CSRF"]) then
  print('<div id="move-rrd-to-influxdb" class="alert alert-warning" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> ')
  print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
  print(i18n("expired_csrf"))
  print('</div>')
end

------ NEW SIDEBAR ------



print("<div class='p-md-4 p-xs-1 p-sm-2' id='n-container'>")

print([[
   <nav class="navbar justify-content-start navbar-light">
      <button data-toggle='sidebar' class='btn'>
         <i class='fas fa-bars'></i>
      </button>
      <div class='dropdown mr-2'>
         <a class="btn btn-secondary dropdown-toggle" data-toggle="dropdown" href="#">
            { ]] .. (getHumanReadableInterfaceName(ifname)) .. [[ }
         </a>
         <ul class='dropdown-menu'>
]])
       
-- ##############################################
-- Interfaces Selector

local views = {}
local drops = {}
local recording = {}
local packetinterfaces = {}
local ifnames = {}
local ifdescr = {}
local ifHdescr = {}
local ifCustom = {}
local dynamic = {}

for v,k in pairs(iface_names) do
   interface.select(k)
   local _ifstats = interface.getStats()
   ifnames[_ifstats.id] = k
   ifdescr[_ifstats.id] = _ifstats.description
   --io.write("["..k.."/"..v.."][".._ifstats.id.."] "..ifnames[_ifstats.id].."=".._ifstats.id.."\n")
   if(_ifstats.isView == true) then views[k] = true end
   if(_ifstats.isDynamic == true) then dynamic[k] = true end
   if(recording_utils.isEnabled(_ifstats.id)) then recording[k] = true end
   if(interface.isPacketInterface()) then packetinterfaces[k] = true end
   if(_ifstats.stats_since_reset.drops * 100 > _ifstats.stats_since_reset.packets) then
      drops[k] = true
   end
   ifHdescr[_ifstats.id] = getHumanReadableInterfaceName(_ifstats.description.."")
   ifCustom[_ifstats.id] = _ifstats.customIftype
end

-- First round: only physical interfaces
-- Second round: only virtual interfaces

for round = 1, 2 do

   for k,_ in pairsByValues(ifHdescr, asc) do
      local descr

      if((round == 1) and (ifCustom[k] ~= nil)) then
	 -- do nothing
      elseif((round == 2) and (ifCustom[k] == nil)) then
	 -- do nothing
      else
	 v = ifnames[k]

	 local page_params = table.clone(_GET)
	 page_params.ifid = k
	 -- ntop.getHttpPrefix()
	 local url = getPageUrl("", page_params)

	 print("      <li class=\"nav-item\">")

	 if(v == ifname) then
	    print("<a class=\"dropdown-item\" href=\""..url.."\">")
	 else
	    -- NOTE: the actual interface switching is performed in C in LuaEngine::handle_script_request
	    print[[<form id="switch_interface_form_]] print(tostring(k)) print[[" method="post" action="]] print(url) print[[">]]
	    print[[<input name="switch_interface" type="hidden" value="1" />]]
	    print[[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />]]
	    print[[</form>]]
	    print[[<a class="dropdown-item" href="javascript:void(0);" onclick="$('#switch_interface_form_]] print(tostring(k)) print[[').submit();">]]
	 end

	 if(v == ifname) then print("<i class=\"fas fa-check\"></i> ") end
	 if(isPausedInterface(v)) then  print('<i class="fas fa-pause"></i> ') end

	 descr = getHumanReadableInterfaceName(v.."")

	 if(string.contains(descr, "{")) then -- Windows
	    descr = ifdescr[k]
	 else
	    if(v ~= ifdescr[k]) then
	       descr = descr .. " (".. ifdescr[k] ..")"
	    end
	 end

	 print(descr)

	 if(views[v] == true) then
	    print(' <i class="fas fa-eye" aria-hidden="true"></i> ')
	 end

	 if(dynamic[v] == true) then
	    print(' <i class="fas fa-code-branch" aria-hidden="true"></i> ')
	 end

	 if(drops[v] == true) then
	    print('&nbsp;<span><i class="fas fa-tint" aria-hidden="true"></i></span>')
	 end

	 if(recording[v] == true) then
	    print(' <i class="fas fa-hdd" aria-hidden="true"></i> ')
	 end

	 print("</a>")
	 print("</li>\n")
      end
   end
end


print([[
         </ul>
         </div>
         
]])

-- append searchbox

print(
  template.gen("typeahead_input.html", {
    typeahead={
      base_id     = "host_search",
      action      = "", -- see makeFindHostBeforeSubmitCallback
      json_key    = "ip",
      query_field = "host",
      class       = "typeahead-dropdown-right",
      query_url   = ntop.getHttpPrefix() .. "/lua/find_host.lua",
      query_title = i18n("search_host"),
      style       = "width: 16em;",
      before_submit = [[makeFindHostBeforeSubmitCallback("]] .. ntop.getHttpPrefix() .. [[")]],
      max_items   = "'all'" --[[ let source script decide ]],
    }
  })
)

-- ##############################################
-- Up/Down info
if not interface.isPcapDumpInterface() then

   print([[
      <div class='info-stats'>
         ]].. 
         (function()
            
            local _ifstats = interface.getStats()

            if _ifstats.has_traffic_directions then
               return ([[
                  <a href=']].. ntop.getHttpPrefix() ..[[/lua/if_stats.lua'>
                     <div class='up'>
                        <i class="fas fa-arrow-up"></i>
                        <span class="network-load-chart-upload">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>
                        <span class="text-right" id="chart-upload-text"></span>
                     </div>
                     <div class='down'>
                        <i class="fas fa-arrow-down"></i>
                        <span class="network-load-chart-download">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>
                        <span class="text-right" id="chart-download-text"></span>
                     </div>
                  </a>
               ]])
            else
               return ([[
                  <a href=']].. ntop.getHttpPrefix() ..[[/lua/if_stats.lua'>
                     <span class="network-load-chart-total">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>
                     <span class="text-right" id="chart-total-text"></span>
                  </a>
               ]])
            end

         end)() ..[[
      </div>
   ]])

end


-- ##############################################
-- Info

if active_page == "home" or active_page == "about" or active_page == "telemetry" or active_page == "directories" then
   print [[ <div class="dropdown ml-auto">
	    <a class="dark-gray nav-link dropdown-toggle" data-toggle="dropdown" href="#">
]]
else
   print [[ <div class="dropdown ml-auto">
	    <a class="dark-gray nav-link dropdown-toggle" data data-toggle="dropdown" href="#">
]]
end

print [[
	   <i class="fas fa-life-ring fa-lg"></i>
      </a>
    <ul class="dropdown-menu dropdown-menu-right">
      <li class="nav-item"><a class="dropdown-item" href="]] print(ntop.getHttpPrefix()) print [[/lua/about.lua"><i class="fas fa-question-circle"></i> ]] print(i18n("about.about_ntopng")) print[[</a></li>
      <li class="nav-item"><a class="dropdown-item" href="]] print(ntop.getHttpPrefix()) print[[/lua/telemetry.lua"><i class="fas fa-rss"></i> ]] print(i18n("telemetry")) print[[</a></li>
      <li class="nav-item"><a class="dropdown-item" href="http://blog.ntop.org/" target="_blank"><i class="fas fa-bullhorn"></i> ]] print(i18n("about.ntop_blog")) print[[ <i class="fas fa-external-link-alt"></i></a></li>
      <li class="nav-item"><a class="dropdown-item" href="https://t.me/ntop_community" target="_blank"><i class="fab fa-telegram"></i> ]] print(i18n("about.telegram")) print[[ <i class="fas fa-external-link-alt"></i></a></li>
      <li class="nav-item"><a class="dropdown-item" href="https://github.com/ntop/ntopng/issues" target="_blank"><i class="fas fa-bug"></i> ]] print(i18n("about.report_issue")) print[[ <i class="fas fa-external-link-alt"></i></a></li>

      <li class="dropdown-divider"></li>
      <li class="nav-item"><a class="dropdown-item" href="]] print(ntop.getHttpPrefix()) print [[/lua/directories.lua"><i class="fas fa-folder"></i> ]] print(i18n("about.directories")) print[[</a></li>
      <li class="nav-item"><a class="dropdown-item" href="]] print(ntop.getHttpPrefix()) print[[/lua/plugins_overview.lua"><i class="fas fa-puzzle-piece"></i> ]] print(i18n("plugins")) print[[</a></li>
      <li class="nav-item"><a class="dropdown-item" href="]] print(ntop.getHttpPrefix()) print[[/lua/user_scripts_overview.lua"><i class="fab fa-superpowers"></i> ]] print(i18n("about.user_scripts")) print[[</a></li>
      <li class="nav-item"><a class="dropdown-item" href="]] print(ntop.getHttpPrefix()) print[[/lua/defs_overview.lua"><i class="fas fa-exclamation-triangle"></i> ]] print(i18n("about.alert_defines")) print[[</a></li>
      <li class="nav-item"><a class="dropdown-item" href="https://www.ntop.org/guides/ntopng/" target="_blank"><i class="fas fa-book"></i> ]] print(i18n("about.readme_and_manual")) print[[ <i class="fas fa-external-link-alt"></i></a></li>
      <li class="nav-item"><a class="dropdown-item" href="https://www.ntop.org/guides/ntopng/api/" target="_blank"><i class="fas fa-book"></i> ]] print("Lua/C API") print[[ <i class="fas fa-external-link-alt"></i></a></li>
]]

print [[
</ul>
</div>
]]

-- add logout button

print([[

   <div class="dropdown">
      <a href='#' class="nav-link dropdown-toggle dark-gray" data-toggle="dropdown">
         <i class='fas fa-user'></i> ]].. _SESSION["user"] ..[[
      </a>
      <ul class="dropdown-menu dropdown-menu-right">
         <a class='dropdown-item' href=']].. ntop.getHttpPrefix() ..[[/lua/admin/users.lua'>
            Web Users
         </a>
      
      ]])
-- Logout

if(_SESSION["user"] ~= nil and _SESSION["user"] ~= ntop.getNologinUser()) then
   print[[
 
 <li class="nav-item">
   <a class="dropdown-item" href="]]
   print(ntop.getHttpPrefix())
   print [[/lua/logout.lua" onclick="return confirm(']] print(i18n("login.logout_message")) print [[')"><i class="fas fa-sign-out-alt fa-lg"></i> ]] print(i18n("login.logout")) print[[</a></li>]]
 end
 
if(not is_admin) then
   dofile(dirs.installdir .. "/scripts/lua/inc/password_dialog.lua")
end
 
 -- Restart
if(is_admin and ntop.isPackage() and not ntop.isWindows()) then
   print [[
       <li class="dropdown-divider"></li>
       <li class="nav-item"><a class="dropdown-item" id="restart-service-li" href="#"><i class="fas fa-redo-alt"></i> ]] print(i18n("restart.restart")) print[[</a></li>
   ]]
 
 print[[
  <script>
   let restart_csrf = ']] print(ntop.getRandomCSRFValue()) print[[';
   let restartService = function() {
     if (confirm(']] print(i18n("restart.confirm")) print[[')) {
       $.ajax({
         type: 'POST',
         url: ']] print (ntop.getHttpPrefix()) print [[/lua/admin/service_restart.lua',
         data: {
           csrf: restart_csrf
         },
         success: function(rsp) {
           restart_csrf = rsp.csrf;
           alert("]] print(i18n("restart.restarting")) print[[");
         }
       });
     }
   }
   $('#restart-service-li').click(restartService);
 </script>
 ]]
end
 
print([[
      </ul>
   </div>
   
   </nav>
]])


telemetry_utils.show_notice()
