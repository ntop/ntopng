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
local blog_utils = require("blog_utils")
local page_utils = require("page_utils")
local delete_data_utils = require "delete_data_utils"
local menu_alert_notifications = require("menu_alert_notifications")
local host_pools = require "host_pools"

local is_nedge = ntop.isnEdge()
local is_admin = isAdministrator()
local is_windows = ntop.isWindows()
local info = ntop.getInfo()
local updates_supported = (is_admin and ntop.isPackage() and not ntop.isWindows())

-- this is a global variable
local is_system_interface = page_utils.is_system_view()

print([[
   <div id='wrapper'>
]])

print[[
<script type='text/javascript'>
   /* Some localization strings to pass from lua to javascript */
   const i18n = {
      "no_results_found": "]] print(i18n("no_results_found")) print[[",
      "are_you_sure": "]] print(i18n("scripts_list.are_you_sure")) print[[",
      "change_number_of_rows": "]] print(i18n("change_number_of_rows")) print[[",
      "no_data_available": "]] print(i18n("no_data_available")) print[[",
      "showing_x_to_y_rows": "]] print(i18n("showing_x_to_y_rows", {x="{0}", y="{1}", tot="{2}"})) print[[",
      "actions": "]] print(i18n("actions")) print[[",
      "query_was_aborted": "]] print(i18n("graphs.query_was_aborted")) print[[",
      "exports": "]] print(i18n("system_stats.exports_label")) print[[",
      "no_file": "]] print(i18n("config_scripts.no_file")) print[[",
      "invalid_file": "]] print(i18n("config_scripts.invalid_file")) print[[",
      "request_failed_message": "]] print(i18n("request_failed_message")) print[[",
      "unreachable_host": "]] print(i18n("graphs.unreachable_host")) print[[",
   };
   const systemInterfaceEnabled = ]] print(ternary(is_system_interface, "true", "false")) print[[;
   const http_prefix = "]] print(ntop.getHttpPrefix()) print[[";

   if(document.cookie.indexOf("tzoffset=") < 0) {
      // Tell the server the client timezone
      document.cookie = "tzoffset=" + (new Date().getTimezoneOffset() * 60 * -1);
   }
</script>]]

local template = require "template_utils"


prefs = ntop.getPrefs()
local iface_names = interface.getIfNames()

-- tprint(prefs)
-- tprint(iface_names)

num_ifaces = 0
for k,v in pairs(iface_names) do
   num_ifaces = num_ifaces+1
end


interface.select(ifname)
local ifs = interface.getStats()
local is_pcap_dump = interface.isPcapDumpInterface()
local is_packet_interface = interface.isPacketInterface()
ifId = ifs.id

-- NOTE: see sidebar.js for the client logic
page_utils.init_menubar()

if is_nedge then
   dofile(dirs.installdir .. "/pro/scripts/lua/nedge/inc/menubar.lua")
else
   -- ##############################################

   -- Dashboard
   page_utils.add_menubar_section(
      {
	 section = page_utils.menu_sections.dashboard,
	 hidden = is_pcap_dump or is_system_interface,
	 entries = {
	    {
	       entry = page_utils.menu_entries.traffic_dashboard,
	       url = ntop.isPro() and '/lua/pro/dashboard.lua' or '/lua/index.lua',
	    },
	    {
	       entry = page_utils.menu_entries.network_discovery,
	       hidden = not interface.isDiscoverableInterface() or interface.isLoopback(),
	       url = "/lua/discover.lua",
	    },
	    {
	       entry = page_utils.menu_entries.traffic_report,
	       hidden = not ntop.isPro(),
	       url = "/lua/pro/report.lua",
	    },
	    {
	       entry = page_utils.menu_entries.divider,
	       hidden = not ntop.isPro() or not prefs.is_dump_flows_to_mysql_enabled or ifs.isViewed,
	    },
	    {
	       entry = page_utils.menu_entries.db_explorer,
	       hidden = not ntop.isPro() or not prefs.is_dump_flows_to_mysql_enabled or ifs.isViewed,
	       url = "/lua/pro/db_explorer.lua?ifid="..ifId,
	    },
	 },
      }
   )

   -- ##############################################

   -- Alerts
   page_utils.add_menubar_section(
      {
	 section = page_utils.menu_sections.alerts,
	 hidden = not ntop.getPrefs().are_alerts_enabled or is_system_interface,
	 entries = {
	    {
	       entry = page_utils.menu_entries.detected_alerts,
	       url = '/lua/show_alerts.lua',
	    },
	    {
	       entry = page_utils.menu_entries.alerts_dashboard,
	       hidden = not ntop.isEnterpriseM(),
	       url = '/lua/pro/enterprise/alerts_dashboard.lua',
	    },
	    {
	       entry = page_utils.menu_entries.divider,
	       hidden = not ntop.isEnterpriseM(),
	    },
	    {
	       entry = page_utils.menu_entries.flow_alerts_explorer,
	       hidden = not ntop.isEnterpriseM(),
	       url = '/lua/pro/enterprise/flow_alerts_explorer.lua',
	    },
	 },
      }
   )

   -- ##############################################

   -- Flows
   page_utils.add_menubar_section(
      {
         hidden = is_system_interface,
	 section = page_utils.menu_sections.flows,
	 url = "/lua/flows_stats.lua",
      }
   )

   -- ##############################################

   -- Hosts
   page_utils.add_menubar_section(
      {
	 section = page_utils.menu_sections.hosts,
	 hidden = ifs.isViewed or is_system_interface,
	 entries = {
	    {
	       entry = page_utils.menu_entries.hosts,
	       url = '/lua/hosts_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.devices,
	       hidden = not ifs.has_macs,
	       url = '/lua/macs_stats.lua?devices_mode=source_macs_only',
	    },
	    {
	       entry = page_utils.menu_entries.networks,
	       url = '/lua/network_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.host_pools,
	       url = '/lua/pool_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.autonomous_systems,
	       hidden = not ntop.hasGeoIP(),
	       url = '/lua/as_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.countries,
	       hidden = not ntop.hasGeoIP(),
	       url = '/lua/country_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.operating_systems,
	       url = '/lua/os_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.vlans,
	       hidden = not interface.hasVLANs(),
	       url = '/lua/vlan_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.pods,
	       hidden = not ifs.has_seen_pods,
	       url = '/lua/pods_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.containers,
	       hidden = not ifs.has_seen_containers,
	       url = '/lua/containers_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.divider,
	    },
	    {
	       entry = page_utils.menu_entries.http_servers,
	       url = '/lua/http_servers_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.top_hosts,
	       hidden = is_pcap_dump,
	       url = '/lua/top_hosts.lua',
	    },
	    {
	       entry = page_utils.menu_entries.divider,
	    },
	    {
	       entry = page_utils.menu_entries.geo_map,
	       hidden = interface.isLoopback() or not ntop.hasGeoIP(),
	       url = '/lua/hosts_geomap.lua',
	    },
	    {
	       entry = page_utils.menu_entries.host_explorer,
	       url = '/lua/bubble.lua',
	    },
	 },
      }
   )

   -- ##############################################

   -- Exporters
   page_utils.add_menubar_section(
      {
	 section = page_utils.menu_sections.exporters,
	 hidden = (ifs.type ~= "zmq" or not ntop.isEnterpriseM()) or is_system_interface,
	 entries = {
	    {
	       entry = page_utils.menu_entries.event_exporters,
	       hidden = not ifs.has_seen_ebpf_events,
	       url = '/lua/pro/enterprise/event_exporters.lua',
	    },
	    {
	       entry = page_utils.menu_entries.sflow_exporters,
	       hidden = table.len(interface.getSFlowDevices() or {}) == 0,
	       url = '/lua/pro/enterprise/flowdevices_stats.lua?sflow_filter=All',
	    },
	    {
	       entry = page_utils.menu_entries.flow_exporters,
	       url = '/lua/pro/enterprise/flowdevices_stats.lua',
	    },
	 },
      }
   )

end

-- ##############################################

-- Interface
page_utils.add_menubar_section(
   {
      section = page_utils.menu_sections.if_stats,
      hidden = is_system_interface,
      url = "/lua/if_stats.lua",
   }
)


-- ##############################################

-- System Health

page_utils.add_menubar_section({
   hidden = not is_system_interface,
   section = page_utils.menu_sections.health,
   entries = {
      {
         entry = page_utils.menu_entries.system_status,
         url = '/lua/system_stats.lua',
      },
      {
         entry = page_utils.menu_entries.interfaces_status,
         url = '/lua/system_interfaces_stats.lua',
      },
   }
})

-- ##############################################

-- SNMP

page_utils.add_menubar_section({
   hidden = not is_system_interface or not ntop.isEnterpriseM(),
   url = "/lua/pro/enterprise/snmpdevices_stats.lua",
   section = page_utils.menu_sections.snmp
})


-- ##############################################

-- System

local system_entries = {}

-- Add plugin entries...
for k, entry in pairsByField(page_utils.plugins_menu, "sort_order", rev) do
   system_entries[#system_entries + 1] = {
      entry = page_utils.menu_entries[entry.menu_entry.key],
      url = entry.url,
   }
end

-- Possibly add nEdge entries
if is_nedge then
   for _, entry in ipairs(
      {
	 {
	    entry = page_utils.menu_entries.divider,
	    hidden = not is_admin,
	 },
	 {
	    entry = page_utils.menu_entries.system_setup,
	    hidden = not is_admin,
	    url = '/lua/pro/nedge/system_setup/interfaces.lua',
	 },
	 {
	    entry = page_utils.menu_entries.dhcp_leases,
	    hidden = not is_admin or not ntop.isRoutingMode(),
	    url = '/lua/pro/nedge/admin/dhcp_leases.lua',
	 },
	 {
	    entry = page_utils.menu_entries.port_forwarding,
	    hidden = not is_admin or not ntop.isRoutingMode(),
	    url = '/lua/pro/nedge/admin/port_forwarding.lua',
	 },
	 {
	    entry = page_utils.menu_entries.nedge_users,
	    hidden = not is_admin or not is_system_interface,
	    url = '/lua/pro/nedge/admin/nf_list_users.lua',
	 },
   }) do
      system_entries[#system_entries + 1] = entry
   end
end

page_utils.add_menubar_section(
   {
      section = page_utils.menu_sections.system_stats,
      hidden = not isAllowedSystemInterface() or not is_system_interface,
      entries = system_entries,
   }
)

-- ##############################################

-- Tools

page_utils.add_menubar_section({
   hidden = not is_system_interface,
   section = page_utils.menu_sections.tools,
   entries = {
      {
         entry = page_utils.menu_entries.remote_assistance,
         hidden = not is_admin or not remote_assistance.isAvailable(),
         url = '/lua/admin/remote_assistance.lua',
      },
      {
         entry = page_utils.menu_entries.conf_backup,
         hidden = not is_admin or is_windows,
         url = '/lua/get_config.lua',
      },
      {
         entry = page_utils.menu_entries.conf_restore,
         hidden = not is_admin or is_windows,
         url = 'https://www.ntop.org/guides/ntopng/web_gui/settings.html#restore-configuration',
      },
   }
})

-- ##############################################

-- Pools

page_utils.add_menubar_section({
   hidden = not is_system_interface,
   section = page_utils.menu_sections.pools,
   entries = {
      {
         entry = page_utils.menu_entries.manage_pools,
         hidden = not is_admin,
         url = '/lua/admin/manage_pools.lua'
      },
      {
         entry = page_utils.menu_entries.host_members,
         hidden = not is_admin or is_nedge,
         url = '/lua/admin/manage_host_members.lua',
      }
   }
})

-- ##############################################

page_utils.add_menubar_section({
   section = page_utils.menu_sections.notifications,
   hidden = not is_system_interface,
   entries = {
      {
         entry = page_utils.menu_entries.endpoint_notifications,
         hidden = not is_admin,
         url = '/lua/admin/endpoint_notifications_list.lua',
      },
      {
         entry = page_utils.menu_entries.endpoint_recipients,
         hidden = not is_admin,
         url = '/lua/admin/endpoint_recipients_list.lua',
      }
   }
})

-- ##############################################

local inactive_interfaces = delete_data_utils.list_inactive_interfaces()
local num_inactive_interfaces = ternary(not ntop.isnEdge(), table.len(inactive_interfaces or {}), 0)
local delete_active_interface_requested_system = delete_data_utils.delete_active_interface_data_requested(getSystemInterfaceId())

-- Admin
page_utils.add_menubar_section(
   {
      section = page_utils.menu_sections.admin,
      hidden = not is_admin,
      entries = {
	 {
	    entry = page_utils.menu_entries.manage_users,
	    hidden = not _SESSION["localuser"] or not is_admin,
	    url = '/lua/admin/users.lua',
	 },
	 {
	    entry = page_utils.menu_entries.preferences,
	    hidden = not is_admin,
	    url = '/lua/admin/prefs.lua',
	 },
	 {
	    entry = page_utils.menu_entries.scripts_config,
	    hidden = not is_admin,
	    url = '/lua/admin/scripts_config.lua',
    },
	 {
	    entry = page_utils.menu_entries.divider,
	    hidden = not is_admin,
    },
    {
      entry = page_utils.menu_entries.manage_data,
      hidden = not is_admin or is_system_interface,
      url = '/lua/manage_data.lua',
   },
   {
      hidden = (not is_system_interface or delete_active_interface_requested_system),
      custom = ([[
         <form class="interface_data_form" method="POST">
            <li>
               <a id='delete-system-interface' data-toggle='modal' href='#delete_active_interface_data_system'>]].. i18n("manage_data.delete_system_interface_data") ..[[</a>
            </li>
         </form>
      ]])
   },
   {
      hidden = (num_inactive_interfaces <= 0 or not is_system_interface) ,
      custom = ([[
         <form class="interface_data_form" id='form_delete_inactive_interfaces' method="POST">
            <li>
               <a id='delete-system-inactive' data-toggle='modal' href='#delete_inactive_interfaces_data_system'>]].. i18n("manage_data.delete_inactive_interfaces") ..[[</a>
            </li>
         </form>
      ]])
   },
   {
      entry = page_utils.menu_entries.divider,
   },
	 {
	    entry = page_utils.menu_entries.profiles,
	    hidden = not is_admin or not ntop.isPro() or is_nedge,
	    url = '/lua/pro/admin/edit_profiles.lua',
	 },
	 {
	    entry = page_utils.menu_entries.categories,
	    hidden = not is_admin,
	    url = '/lua/admin/edit_categories.lua',
	 },
	 {
	    entry = page_utils.menu_entries.category_lists,
	    hidden = not is_admin,
	    url = '/lua/admin/edit_category_lists.lua',
	 },
	 {
	    entry = page_utils.menu_entries.device_protocols,
	    hidden = not is_admin,
	    url = '/lua/admin/edit_device_protocols.lua',
	 },
      },
   }
)

-- ##############################################

-- Developer


if not info.oem then
   page_utils.add_menubar_section(
      {
	 section = page_utils.menu_sections.dev,
	 entries = {
	    {
	       entry = page_utils.menu_entries.plugins,
	       url = '/lua/plugins_overview.lua',
	    },
	    {
	       entry = page_utils.menu_entries.user_scripts_dev,
	       url = '/lua/user_scripts_overview.lua',
	    },
	    {
	       entry = page_utils.menu_entries.alert_definitions,
	       url = '/lua/defs_overview.lua',
	    },
	    {
	       entry = page_utils.menu_entries.directories,
	       url = '/lua/directories.lua',
	    },
	    {
	       entry = page_utils.menu_entries.api,
	       url = 'https://www.ntop.org/guides/ntopng/api/',
	    },
	    {
	       entry = page_utils.menu_entries.divider,
	       hidden = not is_admin,
	    },
	    {
	       entry = page_utils.menu_entries.widgets_list,
	       hidden = not is_admin,
	       url = '/lua/widgets_list.lua',
	    },
	    {
	       entry = page_utils.menu_entries.datasources_list,
	       hidden = not is_admin,
	       url = '/lua/datasources_list.lua',
	    },
	 },
      }
   )
end

-- ##############################################

-- About
page_utils.add_menubar_section(
   {
      section = page_utils.menu_sections.about,
      hidden = info.oem,
      entries = {
         {
            entry = page_utils.menu_entries.about,
            url = '/lua/about.lua',
         },
         {
            entry = page_utils.menu_entries.telemetry,
            url = '/lua/telemetry.lua',
         },
         {
            entry = page_utils.menu_entries.blog,
            url = 'http://blog.ntop.org/',
         },
         {
            entry = page_utils.menu_entries.telegram,
            url = 'https://t.me/ntop_community',
         },

         {
            entry = page_utils.menu_entries.manual,
            url = 'https://www.ntop.org/guides/ntopng/',
         },
         {
            entry = page_utils.menu_entries.divider
         },
         {
            entry = page_utils.menu_entries.report_issue,
            url = 'https://github.com/ntop/ntopng/issues',
         },
         {
            entry = page_utils.menu_entries.suggest_feature,
            url = 'https://www.ntop.org/support/need-help-2/contact-us/',
         }
      },
   }
)


-- ##############################################

page_utils.print_menubar()

-- ##############################################
-- Interface

if(num_ifaces > 0) then

url = ntop.getHttpPrefix().."/lua/if_stats.lua"

-- ##############################################

-- Updates submenu
if updates_supported then

-- Updates check
print[[
<script type='text/javascript'>
  $('#updates-info-li').html(']] print(i18n("updates.checking")) print[[');
  $('#updates-install-li').hide();

  const updates_csrf = ']] print(ntop.getRandomCSRFValue()) print[[';

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
              $('#updates-info-li').html('<span class="badge badge-pill badge-danger">]] print(i18n("updates.available")) print[[</span> ]] print(info["product"]) print[[ ' + rsp.version + '!');
              var icon = '<i class="fas fa-download"></i>';
              $('#updates-install-li').attr('title', '');
              if (rsp.status == 'upgrade-failure') {
                icon = '<i class="fas fa-exclamation-triangle"></i>';
                $('#updates-install-li').attr('title', "]] print(i18n("updates.upgrade_failure_message")) print [[");
              }
              $('#updates-install-li').html(icon + " ]] print(i18n("updates.install")) print[[");
              $('#updates-install-li').show();
              $('#updates-install-li').off("click");
              $('#updates-install-li').click(installUpdate);
              if (rsp.status == 'upgrade-failure') $('#admin-badge').html('!');
              else $('#admin-badge').html('1');
              $('#admin-badge').show();

            } else /* (rsp.status == 'not-avail') */ {
              $('#updates-info-li').html(']] print(i18n("updates.no_updates")) print[[');
              $('#updates-install-li').html("<i class='fas fa-sync'></i> ]] print(i18n("updates.check")) print[[");
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

print([[
   <nav class="navbar extended navbar-expand-lg fixed-top justify-content-start bg-light navbar-light" id='n-navbar'>
      <ul class='navbar-nav mr-auto'>
         <li class='nav-item'>
            <button class='btn btn-outline-dark border-0 btn-sidebar' data-toggle='sidebar'>
               <i class="fas fa-bars"></i>
            </button>
         </li>
         <li id="button-switch-interface" class='nav-item d-flex align-items-center dropdown'>
            <a class="btn border-dark dropdown-toggle" data-toggle="dropdown" href="#">
               ]] .. (is_system_interface and i18n("system") or '<i class="fas fa-ethernet"></i> ' .. getHumanReadableInterfaceName(ifname)) .. [[
            </a>
            <ul class='dropdown-menu'>
]])

if ntop.isAdministrator() then
   print([[
               <li>
                  <button id="btn-trigger-system-mode" class="dropdown-item ]].. (is_system_interface and "active" or "") ..[[">
                     ]].. (is_system_interface and "<i class='fas fa-check'></i>" or "") ..[[ ]] .. i18n("system") .. [[
                  </button>
               </li>
               <li class='dropdown-divider'></li>
   ]])
end

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

	 -- table.clone needed to modify some parameters while keeping the original unchanged
         local page_params = table.clone(_GET)
         page_params.ifid = k
         -- ntop.g`tHttpPrefix()
         local url_query = getPageUrl("", page_params)

         print([[<li class="nav-item">]])

         if(v == ifname and not is_system_interface) then
            print("<a class=\"dropdown-item active\" href=\"#\">")
         else
            -- NOTE: the actual interface switching is performed in C in LuaEngine::handle_script_request
            local action_url = ""
            if(is_system_interface) then
               action_url = ntop.getHttpPrefix() .. '/' .. url_query
            else
               action_url = url_query
            end

            print[[<form id="switch_interface_form_]] print(tostring(k)) print([[" method="post" action="]].. action_url ..[[]]) print[[">]]
            print[[<input name="switch_interface" type="hidden" value="1" />]]
            print[[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />]]
            print[[</form>]]

            print([[<a class="dropdown-item" href="javascript:void(0);" onclick="toggleSystemInterface(false, $('#switch_interface_form_]]) print(tostring(k)) print[['));">]]
         end

         if((v == ifname) and not is_system_interface) then print("<i class=\"fas fa-check\"></i> ") end
         if(isPausedInterface(v)) then  print('<i class="fas fa-pause"></i> ') end

         if(views[v] == true) then
            print(' <i class="fas fa-eye" aria-hidden="true"></i> ')
         end

         if(dynamic[v] == true) then
            print('<i class="fas fa-code-branch" aria-hidden="true"></i> ')
         end

         if(drops[v] == true) then
            print('<i class="fas fa-tint" aria-hidden="true"></i> ')
         end

         if(recording[v] == true) then
            print('<i class="fas fa-hdd" aria-hidden="true"></i> ')
         end

         descr = getHumanReadableInterfaceName(v.."")

         if(string.contains(descr, "{")) then -- Windows
            descr = ifdescr[k]
         else
	         if(descr ~= ifdescr[k]) and (not views[v]) then
	            if(descr == shortenCollapse(ifdescr[k])) then
		            descr = ifdescr[k]
	            else
		            descr = descr .. " (".. ifdescr[k] ..")" -- Add description
	            end
	         end
         end

         print(descr)
         print("</a>")
         print("</li>")
      end
   end
end

interface.select(ifs.id.."")

print([[
         </ul>
      </li>
]])

-- ##############################################
-- Up/Down info
if not is_pcap_dump and not is_system_interface then

   print([[
      <li class='nav-item d-none d-md-flex d-lg-flex ml-2'>
         <div class='info-stats'>
            ]].. page_utils.generate_info_stats() ..[[
         </div>
      </li>
   ]])

end

-- License Badge
local info = ntop.getInfo(true)

if (info["pro.systemid"] and (info["pro.systemid"] ~= "")) then

   if (info["pro.release"]) then

      if (info["pro.demo_ends_at"] ~= nil) then

         local rest = info["pro.demo_ends_at"] - os.time()

         if (rest > 0) then
            print('<li class="nav-item nav-link"><a href="https://shop.ntop.org"><span class="badge badge-warning">')
            print(" " .. i18n("about.licence_expires_in", {time=secondsToTime(rest)}))
            print('</span></a></li>')
         end
      end

   else
      print('<li class="nav-item nav-link"><a href="https://shop.ntop.org"><span class="badge badge-warning">')
      print(i18n("about.upgrade_to_professional")..' <i class="fas fa-external-link-alt"></i>')
      print('</span></a></li>')
   end
end

-- ########################################
-- Network Load
print([[
   <li class="network-load d-none d-md-block d-lg-block"></li>
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
		      parameters  = { ifid = ternary(is_system_interface, getSystemInterfaceId(), ifId) },
		   }
   })
)

-- #########################################
-- User Navbar Menu

print([[
<ul class='navbar-nav'>
]])

-- Render Blog Notifications
if (not info.oem) then

   local username = _SESSION["user"] or ''
   if (isNoLoginUser()) then username = 'no_login' end

   local posts, new_posts_counter = blog_utils.readPostsFromRedis(username)

   print([[
   <li class="nav-item">
      <a id="notification-list" href="#" class="nav-link dropdown-toggle mx-2 dark-gray position-relative" data-toggle="dropdown">
         <i class='fas fa-bell'></i>
         ]])

   if (new_posts_counter > 0) then
      print([[<span class="badge notification-bell badge-pill badge-danger">]].. new_posts_counter ..[[</span>]])
   end

   print([[
      </a>
      <div class="dropdown-menu dropdown-menu-right p-1">
         <div class="blog-section">
            <span class="dropdown-header p-2 mb-0">]].. i18n("blog_feed.news_from_blog") ..[[</span>
            <ul class="list-unstyled">]])

   if (posts ~= nil) then

      for _, p in pairs(posts) do

         local user_has_read_post = not (p.users_read[username] == nil)
         local post_date = os.date("%x", p.epoch)

         local post_title = p.title or ''
         if (string.len(post_title)) then
            post_title = string.sub(p.title, 1, 48) .. "..."
         end

         print([[
            <li class='media-body pt-2 pr-2 pl-2 pb-1'>
               <a target="_about"
                  class="blog-notification text-dark"
                  data-read="]].. (user_has_read_post and "true" or "false") ..[["
                  data-id="]].. p.id ..[["
                  class='text-dark'
                  href="]].. (p.link or '/') ..[[">
                     <h6 class='mt-0 mb-1'>
                        ]].. ((not user_has_read_post) and "<span class='badge badge-primary'>".. i18n('new') .."</span>" or '') ..[[
                        ]].. post_title ..[[
                        <i class='fas fa-external-link-alt float-right ml-1'></i>
                     </h6>
                     <p class='mb-0'>
                        ]].. (p.shortDesc) ..[[]
                     </p>
                     <small>
                        ]].. i18n('posted') .. " " .. post_date ..[[
                     </small>
               </a>
            </li>
         ]])
      end

   else
      print([[<li class="text-muted p-2">]].. i18n("blog_feed.nothing_to_show") ..[[</li>]])
   end

   print([[
            </ul>
         </div>
      </div>
   </li>]])
end

print([[
   <li class="nav-item">
      <a href='#' class="nav-link dropdown-toggle mx-2 dark-gray" data-toggle="dropdown">
         <i class='fas fa-user'></i>
      </a>
      <ul class="dropdown-menu dropdown-menu-right">
         <li class='dropdown-item disabled'>
            <i class='fas fa-user'></i> ]].. _SESSION['user'] ..[[
         </li>
      ]])

if (not _SESSION["localuser"] or not is_admin) and (not isNoLoginUser()) then
   print[[
         <li>
           <a class="dropdown-item" href='#password_dialog' data-toggle='modal'>
             ]] print(i18n("login.change_password")) print[[
           </a>
         </li>
   ]]
end


-- Render nendge services
if is_nedge and is_admin then
print([[
   <li class="dropdown-divider"></li>
   <li class="dropdown-header">]] .. i18n("nedge.product_status", {product=info.product}) .. [[</li>
   <li>
      <a class="dropdown-item" href="#poweroff_dialog" data-toggle="modal">
         <i class="fas fa-power-off"></i> ]]..i18n("nedge.power_off")..[[
      </a>
   </li>
   <li>
      <a class="dropdown-item" href="#reboot_dialog" data-toggle="modal">
         <i class="fas fa-redo"></i> ]]..i18n("nedge.reboot")..[[
      </a>
   </li>
]])
end

-- Render Update Menu
if updates_supported then
print([[
   <li class="dropdown-divider"></li>
   <li class="dropdown-header" id="updates-info-li">]] .. i18n("updates.no_updates") .. [[.</li>
   <li><button class="dropdown-item" id="updates-install-li"><i class="fas fa-sync"></i> ]] .. (i18n("updates.check"))  ..[[</button></li>
]])
end

-- Logout

if(_SESSION["user"] ~= nil and (not isNoLoginUser())) then
   print[[

 <li class='dropdown-divider'></li>
 <li class="nav-item">
   <a class="dropdown-item" href="]]
   print(ntop.getHttpPrefix())
   print [[/lua/logout.lua" onclick="return confirm(']] print(i18n("login.logout_message")) print [[')"><i class="fas fa-sign-out-alt"></i> ]] print(i18n("login.logout")) print[[</a></li>]]
 end

 -- Restart
if(is_admin and ntop.isPackage() and not ntop.isWindows()) then
   print [[
       <li class="dropdown-divider"></li>
       <li class="nav-item"><a class="dropdown-item" id="restart-service-li" href="#"><i class="fas fa-redo-alt"></i> ]] print(i18n("restart.restart")) print[[</a></li>
   ]]

 print[[
  <script type="text/javascript">
   const restart_csrf = ']] print(ntop.getRandomCSRFValue()) print[[';
   let restartService = function() {
     if (confirm(']] print(i18n("restart.confirm", {product=info.product})) print[[')) {
       $.ajax({
         type: 'POST',
         url: ']] print (ntop.getHttpPrefix()) print [[/lua/admin/service_restart.lua',
         data: {
           csrf: restart_csrf
         },
         success: function(rsp) {
           alert("]] print(i18n("restart.restarting", {product=info.product})) print[[");
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

-- begging of #n-container
print([[<div id='n-container' class='p-md-4 extended p-xs-1 mt-5 p-sm-2'>]])

-- ###################################################
-- Render main alert notifications
menu_alert_notifications.render_notifications("main-container", menu_alert_notifications.load_main_notifications())
-- ###################################################

print("<div class='main-alerts'>")

local lbd_serialize_by_mac = (_POST["lbd_hosts_as_macs"] == "1") or (ntop.getPref(string.format("ntopng.prefs.ifid_%u.serialize_local_broadcast_hosts_as_macs", ifs.id)) == "1")

if(ifs.has_seen_dhcp_addresses and is_admin and (not is_pcap_dump) and is_packet_interface) then
   if(not lbd_serialize_by_mac) then
      if(ntop.getPref(string.format("ntopng.prefs.ifid_%u.disable_host_identifier_message", ifs.id)) ~= "1") then
	 print('<div id="host-id-message-warning" class="alert alert-warning" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> ')
	 print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
	 print(i18n("about.host_identifier_warning", {name=i18n("prefs.toggle_host_tskey_title"), url = ntop.getHttpPrefix().."/lua/if_stats.lua?page=config"}))
	 print('</a></div>')
      end
   elseif isEmptyString(_POST["dhcp_ranges"]) then
      local dhcp_utils = require("dhcp_utils")
      local ranges = dhcp_utils.listRanges(ifs.id)

      if(table.empty(ranges)) then
	 print('<div class="alert alert-warning" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> ')
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
print('<div id="major-release-alert" class="alert alert-info" style="display:none" role="alert"><i class="fas fa-cloud-download-alt" id="alerts-menu-triangle"></i> <span id="ntopng_update_available"></span>')
print('</div>')

-- Hidden by default, will be shown by the footer if necessary
print('<div id="move-rrd-to-influxdb" class="alert alert-warning" style="display:none" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> ')
print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
print(i18n("alert_messages.influxdb_migration_msg", {url="https://www.ntop.org/ntopng/ntopng-and-time-series-from-rrd-to-influxdb-new-charts-with-time-shift/"}))
print('</div>')

if(_SESSION["INVALID_CSRF"]) then
  print('<div id="move-rrd-to-influxdb" class="alert alert-warning" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> ')
  print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
  print(i18n("expired_csrf"))
  print('</div>')
end

-- end of main alerts
print("</div>")


dofile(dirs.installdir .. "/scripts/lua/inc/manage_data.lua")

-- append password change modal
if(not is_admin) then
   dofile(dirs.installdir .. "/scripts/lua/inc/password_dialog.lua")
end

