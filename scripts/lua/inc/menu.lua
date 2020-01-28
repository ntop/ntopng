--
-- (C) 2013-20 - ntop.org
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

local collapsed_sidebar = ntop.getPref('ntopng.prefs.sidebar_collapsed')
local bool_collapsed_sidebar = (collapsed_sidebar == "1") and true or false

-- tprint(collapsed_sidebar)
-- <script type="text/javascript" src="/js/sidebar.js"></script>
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
      <div id='n-sidebar' class="bg-dark ]].. (collapsed_sidebar == "1" and '' or 'active') ..[[ py-0 px-2">
         <h3 class='muted'>
            <div class='d-flex'>
               <a href='/'>
                  ]].. addLogoSvg(collapsed_sidebar) ..[[
               </a>              
            </div>
         </h3>

	      <ul class="nav-side mb-4" id='sidebar'>
]])



interface.select(ifname)
local ifs = interface.getStats()
local is_pcap_dump = interface.isPcapDumpInterface()
local is_packet_interface = interface.isPacketInterface()
ifId = ifs.id

-- ##############################################
-- Dashboard

if not is_pcap_dump then

   local show_submenu = (active_page == "dashboard" and not bool_collapsed_sidebar)

   print ([[ 
      <li class="nav-item ]].. (active_page == "dashboard" and 'active' or '') ..[[">
	      <a class="submenu ]].. (active_page == "dashboard" and 'active' or '') ..[[" data-toggle="collapse" href="#dashboard-submenu">
	         <span class="fas fa-tachometer-alt"></span> Dashboard
         </a>
         <div data-parent='#sidebar' class='collapse ]].. (show_submenu and 'show' or '') ..[[' id='dashboard-submenu'>
            <ul class='nav flex-column'>
               <li>
                  <a href="]].. ntop.getHttpPrefix() .. (ntop.isPro() and '/lua/pro/dashboard.lua' or '/lua/index.lua') .. [[">
                     ]].. i18n("dashboard.traffic_dashboard") ..[[
                  </a>
               </li>
               ]]..
               (function()
                  if interface.isDiscoverableInterface() and not interface.isLoopback() then
                     return ([[
                        <li>
                           <a href=']].. ntop.getHttpPrefix() ..[[/lua/discover.lua'>
                              ]] .. i18n("prefs.network_discovery") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return ([[]])
                  end
               end)()
               ..[[
               ]]..
               (function()
                  if ntop.isPro() then
                     return ([[
                        <li>
                           <a href=']].. ntop.getHttpPrefix() ..[[/lua/pro/report.lua'>
                              ]].. i18n("report.traffic_report") ..[[
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
                  if ntop.isPro() and prefs.is_dump_flows_to_mysql_enabled and not ifs.isViewed then
                     return ([[
                        <li class="dropdown-divider"></li>
                        <li>
                           <a href=']].. ntop.getHttpPrefix() ..[[/lua/pro/db_explorer.lua?ifid=]]..ifId..[['>
                              ]].. i18n("db_explorer.historical_data_explorer") ..[[
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
   ]])

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
   local show_submenu = (active_page == "alerts" and not bool_collapsed_sidebar)


   print([[
      <li class='nav-item ]].. (active_page == 'alerts' and 'active' or '') ..[[ ]].. (is_shown and 'd-none' or '') ..[[' id='alerts-id'>
         <a data-toggle='collapse' class=']].. (active_page == 'alerts' and 'active' or '') ..[[ submenu' href='#alerts-submenu'>
            <span class='fas fa-exclamation-triangle'></span> Alerts
         </a>
         <div data-parent='#sidebar' class='collapse ]].. (show_submenu and 'show' or '') ..[[' id='alerts-submenu'>
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
   <li class=']].. (active_page == 'flows' and 'active' or '') ..[[ nav-item'>
      <a class=']].. (active_page == 'flows' and 'active' or '') ..[[' href=']].. url ..[['>
         <span class='fas fa-stream '></span> ]].. i18n("flows") ..[[
      </a>
   </li> 
]])

-- ##############################################
-- Hosts

if not ifs.isViewed then -- Currently, hosts are not kept for viewed interfaces, only for their view

   local show_submenu = (active_page == "hosts" and not bool_collapsed_sidebar)

   print([[
      <li class='nav-item ]].. (active_page == 'hosts' and 'active' or '') ..[['>
         <a data-toggle='collapse' class=']].. (active_page == 'hosts' and 'active' or '') ..[[ submenu' href='#hosts-submenu'>
            <span class='fas fa-server '></span> ]].. i18n("flows_page.hosts") ..[[
         </a>
         <div data-parent='#sidebar' class='collapse ]].. (show_submenu and 'show' or '') ..[[' id='hosts-submenu'>
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
local show_submenu = (active_page == "exporters" and not bool_collapsed_sidebar)

if ((ifs["type"] == "zmq") and ntop.isEnterprise()) then
   print ([[ 
      <li class="nav-item dropdown ]].. (active_page == "exporters" and 'active' or '') ..[[">
         <a class="submenu ]].. (active_page == "exporters" and 'active' or '') ..[[" data-toggle="collapse" href="#exporters-submenu">
            <span class='fas fa-file-export'></span> ]].. i18n("flow_devices.exporters") ..[[
         </a>
         <div data-parent='#sidebar' id='exporters-submenu' class="collapse ]].. (show_submenu and 'show' or '') ..[[">
            <ul class='nav flex-column'>
               ]]..
               (function()

                  local elements = [[]]
                  local has_ebpf_events, has_sflow_devs = false, false

                  if ifs.has_seen_ebpf_events then
                     has_ebpf_events = true
                     elements = [[
                        <li>
                           <a href="]].. ntop.getHttpPrefix()..[[/lua/pro/enterprise/event_exporters.lua">
                           ]] .. i18n("event_exporters.event_exporters") ..[[
                           </a>
                        </li>
                     ]] .. elements
                  elseif table.len(interface.getSFlowDevices() or {}) > 0 then
                     has_sflow_devs = true
                     elements = [[
                        <li>
                           <a href="]].. ntop.getHttpPrefix()..[[/lua/pro/enterprise/flowdevices_stats.lua?sflow_filter=All">
                           ]] .. i18n("flows_page.sflow_devices") ..[[
                           </a>
                        </li>
                     ]] .. elements
                  end
                  
                  return elements

               end)()
               ..[[
                  <li>
                     <a href="]].. ntop.getHttpPrefix()..[[/lua/pro/enterprise/flowdevices_stats.lua">
                        ]] .. i18n("flows_page.flow_exporters") ..[[
                     </a>
                  </li>
               </ul>
         </div>
      </li>
]])

  
end

-- ##############################################
-- Interface

if(num_ifaces > 0) then

url = ntop.getHttpPrefix().."/lua/if_stats.lua"

print([[
   <li class='nav-item'>
      <a class=']].. (active_page == 'if_stats' and 'active' or '') ..[[' href=']].. url ..[['>
         <span class='fas fa-ethernet '></span> ]].. i18n("interface") ..[[
      </a>
   </li> 
]])

-- ##############################################
-- System

if isAllowedSystemInterface() then
   
   local plugins_utils = require("plugins_utils")
   local show_submenu = ((active_page == "system_stats" or active_page == "system_interfaces_stats") and not bool_collapsed_sidebar)

   print ([[ 
      <li class="nav-item ]].. ((active_page == "system_stats" or active_page == "system_interfaces_stats") and 'active' or '') ..[[">
         <a  class="submenu ]]..((active_page == "system_stats" or active_page == "system_interfaces_stats") and 'active' or '') ..[[" data-toggle="collapse" href="#system-submenu">
            <span class='fas fa-desktop'></span> ]].. i18n("system") ..[[
         </a>
         <div data-parent='#sidebar' class="collapse ]].. (show_submenu and 'show' or '') ..[[" id='system-submenu'>
            <ul class='nav flex-column'>
               ]]..
               (function()
                  if ntop.isEnterprise() then
                     return ([[
                        <li>
                           <a href=']].. ntop.getHttpPrefix()  ..[[/lua/pro/enterprise/snmpdevices_stats.lua'>
                              ]].. i18n("prefs.snmp") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return [[]]
                  end
               end)()
               ..[[
               <li>
                  <a href=']].. ntop.getHttpPrefix() ..[[/lua/system_stats.lua'>
                     ]].. i18n("system_status") ..[[
                  </a>
               </li>
               ]]..
               (function()
                  if num_ifaces > 1 then
                     return ([[
                        <li>
                           <a href=']].. ntop.getHttpPrefix()  ..[[/lua/system_interfaces_stats.lua'>
                              ]].. i18n("system_interfaces_status") ..[[
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
                 
                  local menu = plugins_utils.getMenuEntries() or {}

                  if not table.empty(menu) then

                     local elements = ""

                     for _, entry in pairsByField(menu, "sort_order", rev) do

                        elements = ([[
                           <li>
                              <a href=']].. entry.url ..[['>
                                 ]].. (i18n(entry.label) or entry.label) ..[[
                              </a>
                           </li>
                        ]]) .. elements
                     end

                     return elements
                  else 
                     return ""
                  end

               end)()
               ..[[
            </ul>
         </div>  
   ]])

end

-- ##############################################
-- Admin
local show_submenu = (active_page == "admin" and not bool_collapsed_sidebar)

print ([[ 
   <li class="nav-item ]].. (active_page == "admin" and 'active' or '') ..[[">
      <a class="submenu ]].. (active_page == "admin" and 'active' or '') ..[[" data-toggle="collapse" href="#admin-submenu">
         <span class="fas fa-cog"></span> Settings
      </a>
      <div data-parent='#sidebar' class="collapse ]].. (show_submenu and 'show' or '' ) ..[[" id='admin-submenu'>
         <ul class='nav flex-column'>
            ]]..
            (function()
               if _SESSION["localuser"] then
                  if is_admin then
                     return ([[
                        <li>
                           <a href=']].. ntop.getHttpPrefix() ..[[/lua/admin/users.lua'>
                              ]].. i18n("manage_users.manage_users") ..[[
                           </a>
                        </li>
                     ]])
                  else
                     return ([[
                        <li>
                           <a href='#password_dialog' data-toggle='modal'>
                              ]].. i18n("login.change_password") ..[[
                           </a>
                        </li>
                     ]])
                  end

               end

               return [[]]
            end)()
            ..[[
            ]]..
            (function()
               if is_admin then

                  local elements = [[]]
                  elements = [[
                     <li>
                        <a href=']].. ntop.getHttpPrefix() ..[[/lua/admin/prefs.lua'>
                           ]] .. i18n("prefs.preferences") .. [[
                        </a>
                     </li>
                  ]] .. elements

                  if remote_assistance.isAvailable() then
                     elements = [[
                        <li>
                           <a href=']].. ntop.getHttpPrefix() ..[[/lua/admin/remote_assistance.lua'>
                              ]] .. i18n("remote_assistance.remote_assistance") .. [[
                           </a>
                        </li>
                     ]] .. elements
                  end

                  if ntop.isPro() then
                     elements = [[
                        <li>
                           <a href=']].. ntop.getHttpPrefix() ..[[/lua/pro/admin/edit_profiles.lua'>
                              ]] .. i18n("traffic_profiles.traffic_profiles") .. [[
                           </a>
                        </li>
                     ]] .. elements
                  end

                  elements = [[
                     <li>
                        <a href=']].. ntop.getHttpPrefix() ..[[/lua/admin/edit_categories.lua'>
                           ]] .. i18n("custom_categories.apps_and_categories") .. [[
                        </a>
                     </li>
                     <li>
                        <a href=']].. ntop.getHttpPrefix() ..[[/lua/admin/edit_category_lists.lua'>
                           ]] .. i18n("category_lists.category_lists") .. [[
                        </a>
                     </li>
                     <li>
                        <a href=']].. ntop.getHttpPrefix() ..[[/lua/admin/edit_device_protocols.lua'>
                           ]] .. i18n("device_protocols.device_protocols") .. [[
                        </a>
                     </li>
                     <li>
                        <a href=']].. ntop.getHttpPrefix() ..[[/lua/admin/scripts_config.lua'>
                           ]] .. i18n("about.user_scripts") .. [[
                        </a>
                     </li>
                  ]] .. elements

                  return elements
               end

               return [[]]
            end)()
            ..[[
            <li>
               <a href=']].. ntop.getHttpPrefix() ..[[/lua/manage_data.lua'>
                  ]] .. i18n("manage_data.manage_data") .. [[
               </a>
            </li>
            ]]..
            (function()
               if is_admin then
                  return ([[
                     <li>
                        <a href=']].. ntop.getHttpPrefix() ..[[/lua/get_config.lua'>
                           ]] .. i18n("conf_backup.conf_backup") .. [[
                        </a>
                     </li>
                     <li>
                        <a target='_blank' href='https://www.ntop.org/guides/ntopng/web_gui/settings.html#restore-configuration'>
                           ]] .. i18n("conf_backup.conf_restore") .. [[
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

               if (is_admin and ntop.isPackage() and not ntop.isWindows()) then
                  return ([[
                     <li class="dropdown-header" id="updates-info-li"></li>
                     <li><a id="updates-install-li" href="#"></a></li>
                  ]])
               end

               return [[]]
            end)()
            
            ..[[

         </ul>
      </div>
   </li>
]])


-- Updates submenu
if (is_admin and ntop.isPackage() and not ntop.isWindows()) then

-- Updates check
print[[
<script type='text/javascript'>
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

end -- num_ifaces > 0

-- ##############################################
-- Info

local is_help_Page = (active_page == "home" or active_page == "about" or active_page == "telemetry" or active_page == "directories")

print ([[ 
   <li class="nav-item ]].. (is_help_page and 'active' or '' ) ..[[">
      <a class="]].. (is_help_page and 'active' or '' ) ..[[ submenu" data-toggle="collapse" href="#help-submenu">
         <span class='fas fa-life-ring'></span> Help
      </a>   
   <div data-parent='#sidebar' class='collapse ]].. ((is_help_page and not collapsed_sidebar) and 'active' or '' ) ..[[' id='help-submenu'>
      <ul class='nav flex-column'>

         <li>
            <a href="]].. ntop.getHttpPrefix() ..[[/lua/about.lua">
               ]].. i18n("about.about_ntopng") ..[[
            </a>
         </li>
         <li>
            <a href="]].. ntop.getHttpPrefix() ..[[/lua/telemetry.lua">
               ]].. i18n("telemetry") ..[[
            </a>
         </li>
         <li>
            <a href="http://blog.ntop.org/" target="_blank">
               ]].. i18n("about.ntop_blog") ..[[ <i class="fas fa-external-link-alt"></i>
            </a>
         </li>
         <li>
            <a href="https://t.me/ntop_community" target="_blank">
               ]].. i18n("about.telegram") ..[[ <i class="fas fa-external-link-alt"></i>
            </a>
         </li>
         <li>
            <a  href="https://github.com/ntop/ntopng/issues" target="_blank">
               ]].. i18n("about.report_issue") ..[[ <i class="fas fa-external-link-alt"></i>
            </a>
         </li>
         <li class="dropdown-divider"></li>

         <li>
            <a href="]].. ntop.getHttpPrefix() ..[[/lua/directories.lua">
               ]].. i18n("about.directories") ..[[
            </a>
         </li>
         <li>
            <a href="]].. ntop.getHttpPrefix() ..[[/lua/plugins_overview.lua">
               ]].. i18n("plugins") ..[[
            </a>
         </li>
         <li>
            <a href="]].. ntop.getHttpPrefix() ..[[/lua/user_scripts_overview.lua">
               ]].. i18n("about.user_scripts") ..[[
            </a>
         </li>
         <li>
            <a href="]].. ntop.getHttpPrefix() ..[[/lua/defs_overview.lua">
               ]].. i18n("about.alert_defines") ..[[
            </a>
         </li>
         <li>
            <a href="https://www.ntop.org/guides/ntopng/" target="_blank">
               ]].. i18n("about.readme_and_manual") ..[[ <i class="fas fa-external-link-alt"></i>
            </a>
         </li>
         <li>
            <a href="https://www.ntop.org/guides/ntopng/api/" target="_blank">
               Lua/C API <i class="fas fa-external-link-alt"></i>
            </a>
         </li>
      </ul>
   </div>
</li>
]])


print([[
   </ul>
   
   <div class='sidebar-info'>
      <a id='collapse-sidebar' href='#' data-toggle='sidebar' class='btn-collapse'>
        <i class='fas fa-bars'></i><span ]].. (collapsed_sidebar == "1" and 'style="display: none"' or '') ..[[>Collapse</span>
      </a>
   </div>

   </div>
]])

-- end of n-sidebar


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
 
print([[
   <nav class="navbar ]].. (collapsed_sidebar == "1" and 'extended' or '') ..[[ navbar-expand-lg fixed-top justify-content-start bg-light navbar-light" id='n-navbar'>
      <button data-toggle='sidebar' class='btn d-sm-none d-md-none d-lg-none'>
        <i class='fas fa-bars'></i>
      </button>
      <ul class='navbar-nav mr-auto'>    
         <li class='nav-item dropdown'>
            <a class="btn btn-outline-dark dropdown-toggle" data-toggle="dropdown" href="#">
                  <i class='fas fa-ethernet '></i> ]] .. (getHumanReadableInterfaceName(ifname)) .. [[
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
	 -- ntop.g`tHttpPrefix()
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
      </li>
]])

-- ##############################################
-- Up/Down info
if not interface.isPcapDumpInterface() then

   print([[
      <li class='nav-item mx-2'>
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
      </li>
   ]])

end


-- ########################################
-- Network Load 

print([[
   <div id="network-load"></div>
]])


-- ########################################
-- end of navbar-nav
print('</ul>')

-- ########################################
-- Searchbox hosts
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

-- #########################################
-- User Navbar Menu

print([[
<ul class='navbar-nav'>
   <li class="nav-item">
      <a href='#' class="nav-link dropdown-toggle dark-gray" data-toggle="dropdown">
         <i class='fas fa-user'></i>
      </a>
      <ul class="dropdown-menu dropdown-menu-right">
         <li class='dropdown-item disabled'>
            <i class='fas fa-user'></i> ]].. _SESSION['user'] ..[[
         </li>
         <li class="dropdown-divider"></li>
         <a class='dropdown-item dark-gray' href=']].. ntop.getHttpPrefix() ..[[/lua/admin/users.lua'>
            ]]..i18n("login.web_users")..[[
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
   </li>
</ul>
   
   </nav>
]])

print([[<div class='p-md-4 p-xs-1 mt-5 p-sm-2 ]].. (collapsed_sidebar == "1" and 'extended' or '') ..[[' id='n-container'>]])



-- append password change modal
if(not is_admin) then
   dofile(dirs.installdir .. "/scripts/lua/inc/password_dialog.lua")
end

telemetry_utils.show_notice()
