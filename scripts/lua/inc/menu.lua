--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/toasts/?.lua;" .. package.path

if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"

local alerts_api = require("alerts_api")
local recording_utils = require "recording_utils"
local telemetry_utils = require "telemetry_utils"
local ts_utils = require("ts_utils_core")
local page_utils = require("page_utils")
local delete_data_utils = require "delete_data_utils"
local toasts_manager = require("toasts_manager")
local host_pools = require "host_pools"
local auth = require "auth"
local blog_utils = require("blog_utils")
local template_utils = require "template_utils"
local auth = require "auth"

local is_nedge = ntop.isnEdge()
local is_appliance = ntop.isAppliance()
local is_admin = isAdministrator()
local is_windows = ntop.isWindows()
local info = ntop.getInfo()
local updates_supported = (is_admin and ntop.isPackage() and not ntop.isWindows())
local has_local_auth = (ntop.getPref("ntopng.prefs.local.auth_enabled") ~= '0')
local is_system_interface = page_utils.is_system_view()
local behavior_utils = require("behavior_utils")

blog_utils.fetchLatestPosts()

observationPointId = ntop.getUserObservationPointId()

print([[
   <div class='wrapper'>
]])

print[[
<script type='text/javascript'>

   const isAdministrator = ]] print(is_admin) print[[;
   const loggedUser = "]] print(_SESSION['user']) print[[";
   const interfaceID = ]] print(interface.getStats().id) print[[;

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
      "all": "]] print(i18n("all")) print[[",
      "edit": "]] print(i18n("edit")) print[[",
      "remove": "]] print(i18n("remove")) print[[",
      "and": "]] print(i18n("and")) print[[",
      "other": "]] print(i18n("other")) print[[",
      "others": "]] print(i18n("others")) print[[",
      "warning": "]] print(i18n("warning")) print[[",
      "search": "]] print(i18n("search")) print[[",

      "and_x_more": "]] print(i18n("and_x_more", { num = '$num'})) print[[",
      "invalid_input": "]] print(i18n("validation.invalid_input")) print[[",
      "missing_field": "]] print(i18n("validation.missing_field")) print[[",
      "unreachable_host": "]] print(i18n("graphs.unreachable_host")) print[[",
      "NAME_RESOLUTION_FAILED": "]] print(i18n("rest_consts.NAME_RESOLUTION_FAILED")) print[[",
      "FAILED_HTTP_REQUEST": "]] print(i18n("validation.FAILED_HTTP_REQUEST")) print[[",
      "rest_consts": {
         "PARTIAL_IMPORT": "]] print(i18n("rest_consts.PARTIAL_IMPORT")) print[[",
         "CONFIGURATION_FILE_MISMATCH": "]] print(i18n("rest_consts.CONFIGURATION_FILE_MISMATCH")) print[[",
      }
   };
   const systemInterfaceEnabled = ]] print(ternary(is_system_interface, "true", "false")) print[[;
   const http_prefix = "]] print(ntop.getHttpPrefix()) print[[";

   window.unchangable_pool_names = [
      'Jailed hosts pool'
   ]


   window.__IS_PRO__ = ]] print(ntop.isPro()) print[[;
   window.__CSRF_DATATABLE__ = `]] print(ntop.getRandomCSRFValue()) print[[`;
   window.__BLOG_NOTIFICATION_CSRF__ = `]] print(ntop.getRandomCSRFValue()) print[[`;


   if (document.cookie.indexOf("tzoffset=") < 0) {
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
local is_viewed = ifs.isViewed
ifId = ifs.id

-- NOTE: see sidebar.js for the client logic
page_utils.init_menubar()

if is_nedge then
   dofile(dirs.installdir .. "/pro/scripts/lua/nedge/inc/menubar.lua")
else
   -- ##############################################

   -- Shortcuts
   -- The Shortcuts entry are used to go to the System interface pages
   -- without using the Interface dropdown. The section is hidden
   -- in system interface.
   page_utils.add_menubar_section({
      section = page_utils.menu_sections.shortcuts,
      hidden = is_system_interface or not is_admin,
      entries = {
         {
            entry = page_utils.menu_entries.snmp,
            hidden = (not ntop.isEnterpriseM() and not ntop.isnEdgeEnterprise()),
            url = "/lua/pro/enterprise/snmpdevices_stats.lua"
         },
         {
            entry = page_utils.menu_entries.active_monitoring,
            url = "/plugins/active_monitoring_stats.lua"
         },
         {
            entry = page_utils.menu_entries.divider,
            hidden = not ntop.isEnterpriseM(),
         },
         {
            entry = page_utils.menu_entries.manage_pools,
            hidden = not is_admin,
            url = '/lua/admin/manage_pools.lua'
         },
         {
            entry = page_utils.menu_entries.divider,
         },
         {
            entry = page_utils.menu_entries.endpoint_notifications,
            hidden = not is_admin,
            url = '/lua/admin/endpoint_notifications_list.lua',
         },
         {
            entry = page_utils.menu_entries.endpoint_recipients,
            hidden = not is_admin,
            url = '/lua/admin/recipients_list.lua',
         },
      }
   })

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
         entry = page_utils.menu_entries.divider,
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
	       entry = page_utils.menu_entries.db_explorer,
	       hidden = not ntop.isPro() or not prefs.is_dump_flows_to_mysql_enabled or ifs.isViewed,
	       url = "/lua/pro/db_explorer.lua?ifid="..ifId,
	    },
	    {
	       entry = page_utils.menu_entries.db_explorer,
	       hidden = not ntop.isPro() or not prefs.is_nindex_enabled or ifs.isViewed or not auth.has_capability(auth.capabilities.historical_flows),
	       url = "/lua/pro/nindex_query.lua",
	    },
	 },
      }
   )

   -- ##############################################

   -- Alerts
   page_utils.add_menubar_section(
      {
	 section = page_utils.menu_sections.alerts,
	 hidden = not ntop.getPrefs().are_alerts_enabled or not auth.has_capability(auth.capabilities.alerts),
         url = '/lua/alert_stats.lua',
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

   local service_map_available = false
   local periodicity_map_available = false

   service_map_available, periodicity_map_available = behavior_utils.mapsAvailable()

   -- Hosts
   page_utils.add_menubar_section(
      {
	 section = page_utils.menu_sections.hosts,
	 hidden = is_system_interface or is_viewed,
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
	 },
      }
   )

  -- ##############################################

  -- Maps
   page_utils.add_menubar_section({
      section = page_utils.menu_sections.maps,
      hidden = is_system_interface or is_viewed,
      entries = {
         {
            entry = page_utils.menu_entries.service_map,
            hidden = not service_map_available,
            url = '/lua/pro/enterprise/service_map.lua',
          },
          {
            entry = page_utils.menu_entries.periodicity_map,
            hidden = not periodicity_map_available,
            url = '/lua/pro/enterprise/periodicity_map.lua',
          },
          {
             entry = page_utils.menu_entries.geo_map,
             hidden = interface.isLoopback() or not ntop.hasGeoIP(),
             url = '/lua/hosts_geomap.lua',
          },
          {
             entry = page_utils.menu_entries.hosts_map,
             url = '/lua/hosts_map.lua',
          },
      }
   })

   -- ##############################################

   -- Exporters
   page_utils.add_menubar_section(
      {
	 section = page_utils.menu_sections.exporters,
	 hidden = ((ifs.type ~= "zmq" and ifs.type ~= "custom") or not ntop.isEnterpriseM()) or is_system_interface,
	 entries = {
	    {
	       entry = page_utils.menu_entries.event_exporters,
	       hidden = not ifs.has_seen_ebpf_events,
	       url = '/lua/pro/enterprise/event_exporters.lua',
	    },
	    {
	       entry = page_utils.menu_entries.sflow_exporters,
	       hidden = table.len(interface.getSFlowDevices() or {}) == 0,
	       url = '/lua/pro/enterprise/sflowdevices_stats.lua',
	    },
	    {
	       entry = page_utils.menu_entries.flow_exporters,
	       url = '/lua/pro/enterprise/flowdevices_stats.lua',
	    },
       {
          entry = page_utils.menu_entries.observation_points,
          hidden = table.len(interface.getObservationPoints() or {}) == 0,
          url = '/lua/pro/enterprise/observation_points.lua',
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

local health_entries = {
      {
         entry = page_utils.menu_entries.system_status,
         url = '/lua/system_stats.lua',
      },
      {
         entry = page_utils.menu_entries.interfaces_status,
         url = '/lua/system_interfaces_stats.lua',
      },
      {
         entry = page_utils.menu_entries.alerts_status,
         url = '/lua/system_alerts_stats.lua',
      },
   }

-- Add plugin entries relative to system health (e.g., redis) ...
for k, entry in pairsByField(page_utils.plugins_menu, "sort_order", rev) do
   -- NOTE: match on the health key to only pick the right subset of entries
   if entry.menu_entry.section == page_utils.menu_sections.health.key then
      health_entries[#health_entries + 1] = {
	 entry = page_utils.menu_entries[entry.menu_entry.key],
	 url = entry.url,
      }
   end
end

page_utils.add_menubar_section({
   hidden = not is_system_interface,
   section = page_utils.menu_sections.health,
   entries = health_entries
})

-- ##############################################

-- Pollers (e.g., SNMP, active monitoring)

local poller_entries = {
   {
      entry = page_utils.menu_entries.infrastructure_dashboard,
      hidden = not ntop.isEnterpriseL() or not is_admin,
      url = '/lua/pro/enterprise/infrastructure_dashboard.lua'
   }
}

-- Add SNMP to the poller entries
poller_entries[#poller_entries + 1] = {
   entry = page_utils.menu_entries.snmp,
   hidden = not is_system_interface or (not ntop.isEnterpriseM() and not ntop.isnEdgeEnterprise()),
   url = "/lua/pro/enterprise/snmpdevices_stats.lua",
}

-- Add plugin entries relative to pollers (e.g., active monitoring) ...
for k, entry in pairsByField(page_utils.plugins_menu, "sort_order", rev) do
   if entry.menu_entry.section == page_utils.menu_sections.pollers.key then
      poller_entries[#poller_entries + 1] = {
	 entry = page_utils.menu_entries[entry.menu_entry.key],
	 url = entry.url,
      }
   end
end

page_utils.add_menubar_section({
   hidden = not is_system_interface,
   section = page_utils.menu_sections.pollers,
   entries = poller_entries
})

-- ##############################################

-- System

local system_entries = {}

-- Add plugin entries...
for k, entry in pairsByField(page_utils.plugins_menu, "sort_order", rev) do
   -- Skip pollers, they've already been set under pollers section
   if not entry.menu_entry.section == "pollers" then
      system_entries[#system_entries + 1] = {
	 entry = page_utils.menu_entries[entry.menu_entry.key],
	 url = entry.url,
      }
   end
end

-- Possibly add nEdge entries
if is_nedge or is_appliance then
   -- Possibly add a divider if system_entries already contain elements
   if #system_entries > 0 then
      system_entries[#system_entries + 1] = {
	 entry = page_utils.menu_entries.divider,
	 hidden = not is_admin,
      }
   end
end

if is_nedge then
   for _, entry in ipairs(
      {
	 {
	    entry = page_utils.menu_entries.system_setup,
	    hidden = not is_admin,
	    url = '/lua/system_setup_ui/interfaces.lua',
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
   }) do
      system_entries[#system_entries + 1] = entry
   end
end

if is_appliance then
   for _, entry in ipairs(
      {
	 {
	    entry = page_utils.menu_entries.system_setup,
	    hidden = not is_admin,
	    url = '/lua/system_setup_ui/mode.lua',
	 },
   }) do
      system_entries[#system_entries + 1] = entry
   end
end

if #system_entries > 0 then
   page_utils.add_menubar_section(
      {
	 section = page_utils.menu_sections.system_stats,
	 hidden = not isAllowedSystemInterface() or not is_system_interface,
	 entries = system_entries,
      }
   )
end

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
         hidden = not is_admin,
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
         url = '/lua/admin/recipients_list.lua',
      }
   }
})

-- ##############################################
-- Admin
page_utils.add_menubar_section(
   {
      section = page_utils.menu_sections.admin,
      hidden = not is_admin,
      entries = {
	 {
	    entry = page_utils.menu_entries.nedge_users,
	    hidden = not is_admin or not is_nedge,
	    url = '/lua/pro/nedge/admin/nf_list_users.lua',
	 },
	 {
	    entry = page_utils.menu_entries.manage_users,
            -- Note: 'not _SESSION["localuser"]' indicates that this is an external
            -- user (e.g. LDAP), in that case allow users management if fallback is enabled.
	    hidden = not is_admin or (not _SESSION["localuser"] and not has_local_auth),
	    url = '/lua/admin/users.lua',
	 },
	 {
	    entry = page_utils.menu_entries.preferences,
	    hidden = not is_admin,
	    url = '/lua/admin/prefs.lua',
	 },
         {
            entry = page_utils.menu_entries.license,
            hidden = info["pro.forced_community"],
            url = '/lua/license.lua',
         },
	 {
	    entry = page_utils.menu_entries.divider,
	 },
	 {
	    entry = page_utils.menu_entries.scripts_config,
	    section = page_utils.menu_sections.checks,
	    hidden = not is_admin or not auth.has_capability(auth.capabilities.checks),
	    url = '/lua/admin/edit_configset.lua?subdir=host',
	 },
	 {
	    entry = page_utils.menu_entries.alert_exclusions,
	    section = page_utils.menu_sections.checks,
	    hidden = not is_admin or not auth.has_capability(auth.capabilities.checks) or not ntop.isEnterpriseM(),
	    url = '/lua/pro/admin/edit_alert_exclusions.lua?subdir=host',
	 },
	 {
	    entry = page_utils.menu_entries.divider,
	 },
	 {
	    entry = page_utils.menu_entries.manage_configurations,
	    hidden = not is_admin or is_windows,
	    url = '/lua/admin/manage_configurations.lua',
	 },
	 {
	    entry = page_utils.menu_entries.manage_data,
	    hidden = not is_admin,
	    url = '/lua/manage_data.lua',
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


if not info.oem and auth.has_capability(auth.capabilities.developer) then
   page_utils.add_menubar_section(
      {
	 section = page_utils.menu_sections.dev,
	 entries = {
	    {
	       entry = page_utils.menu_entries.plugins,
	       url = '/lua/plugins_overview.lua',
	    },
	    {
	       entry = page_utils.menu_entries.checks_dev,
	       url = '/lua/checks_overview.lua',
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
              $('#updates-info-li').attr('title', '');
              $('#updates-install-li').hide();
              $('#admin-badge').hide();

            } else if (rsp.status == 'checking') {
              $('#updates-info-li').html(']] print(i18n("updates.checking")) print[[');
              $('#updates-info-li').attr('title', '');
              $('#updates-install-li').hide();
              $('#admin-badge').hide();

            } else if (rsp.status == 'update-avail' || rsp.status == 'upgrade-failure') {

              $('#updates-info-li').html('<span class="badge bg-pill bg-danger">]] print(i18n("updates.available")) print[[</span> ]] print(info["product"]) print[[ ' + rsp.version);
              $('#updates-info-li').attr('title', '');

              var icon = '<i class="fas fa-download"></i>';
              $('#updates-install-li').attr('title', '');
              if (rsp.status !== 'update-avail') {
                icon = '<i class="fas fa-exclamation-triangle text-danger"></i>';
                $('#updates-install-li').attr('title', "]] print(i18n("updates.update_failure_message")) print [[: " + rsp.status);
              }
              $('#updates-install-li').html(icon + " ]] print(i18n("updates.install")) print[[");
              $('#updates-install-li').show();
              $('#updates-install-li').off("click");
              $('#updates-install-li').click(installUpdate);

              if (rsp.status !== 'update-avail') $('#admin-badge').html('!');
              else $('#admin-badge').html('1');
              $('#admin-badge').show();

            } else /* (rsp.status == 'not-avail' || rsp.status == 'update-failure' || rsp.status == <other errors>) */ {

              var icon = '';
              $('#updates-info-li').attr('title', '');
              if (rsp.status !== 'not-avail') {
                icon = '<i class="fas fa-exclamation-triangle text-danger"></i> ';
                $('#updates-info-li').attr('title', "]] print(i18n("updates.update_failure_message")) print [[: " + rsp.status);
              }
              $('#updates-info-li').html(icon + ']] print(i18n("updates.no_updates")) print[[');

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
   <nav class="navbar navbar-expand-lg navbar-light fixed-top px-2" id='n-navbar'>
      <ul class='navbar-nav flex-row flex-wrap'>
         <li class='nav-item'>
            <button class='btn btn-outline-dark border-0 btn-sidebar' data-bs-toggle='sidebar'>
               <i class="fas fa-bars"></i>
            </button>
         </li>
 ]])

-- ##############################################
-- Interfaces Selector

local views = {}
local drops = {}
local recording = {}
local packetinterfaces = {}
local pcapdump = {}
local ifnames = {}
local iftype = {}
local ifHdescr = {}
local observationPoints = {}
local ifCustom = {}
local dynamic = {}
local action_urls = {}

for v,k in pairs(iface_names) do
   interface.select(k)
   local _ifstats = interface.getStats()
   ifnames[_ifstats.id] = k
   action_urls[_ifstats.id] = page_utils.switch_interface_form_action_url(ifId, _ifstats.id, _ifstats.type)
   --io.write("["..k.."/"..v.."][".._ifstats.id.."] "..ifnames[_ifstats.id].."=".._ifstats.id.."\n")
   if interface.isPcapDumpInterface() then pcapdump[k] = true end
   if(_ifstats.isView == true) then views[k] = true end
   if(_ifstats.isDynamic == true) then dynamic[k] = true end
   if(recording_utils.isEnabled(_ifstats.id)) then recording[k] = true end
   if(interface.isPacketInterface()) then packetinterfaces[k] = true end
   if(_ifstats.stats_since_reset.drops * 100 > _ifstats.stats_since_reset.packets) then
      drops[k] = true
   end
   ifCustom[_ifstats.id] = _ifstats.customIftype

   local descr = getHumanReadableInterfaceName(v)

   if ntop.isWindows() and string.contains(descr, "{") then -- Windows
      descr = _ifstats.description
   elseif ntop.isEnterpriseM() and _ifstats.isDynamic and _ifstats.dynamic_interface_probe_ip then
      -- Attempt at printing SNMP information rather than plain disaggregated IPs
      local snmp_utils = require "snmp_utils"
      local snmp_cached_dev = require "snmp_cached_dev"
      local cached_device = snmp_cached_dev:create(_ifstats.dynamic_interface_probe_ip)
      local snmp_name, snmp_if_name

      if cached_device then
	 -- See if there is a name for this exporter in SNMP
	 if cached_device.system and cached_device.system.name then
	    snmp_name = cached_device.system.name

	    -- Now check for the existance of the interface name
	    if _ifstats.dynamic_interface_inifidx then
	       if cached_device.interfaces and cached_device.interfaces[tostring(_ifstats.dynamic_interface_inifidx)] then
		  snmp_if_name = snmp_utils.get_snmp_interface_label(cached_device.interfaces[tostring(_ifstats.dynamic_interface_inifidx)], true)
	       else
		  snmp_if_name = _ifstats.dynamic_interface_inifidx
	       end
	    end
	 end
      end

      if snmp_name then
	 -- Something has been found in SNMP
	 local fmt = ""

	 if snmp_if_name then
	    -- There's the interface name as well
	    fmt = string.format("%s [%s]", snmp_name, snmp_if_name)
	 else
	    -- Only the device name
	    fmt = string.format("%s", snmp_name)
	 end

	 if descr ~= _ifstats.description then
	    -- There's a custom alias
	    descr = string.format("%s (%s)", descr, fmt)
	 else
	    descr = fmt
	 end
      end
   else
      if descr ~= _ifstats.description and not views[k] and not pcapdump[k] then
      	 if descr == shortenCollapse(_ifstats.description) then
      	    descr = _ifstats.description
      	 else
      	    descr = descr .. " (".. _ifstats.description ..")" -- Add description
      	 end
      end
   end

--   tprint({k, dynamic[k], _ifstats.dynamic_interface_probe_ip, _ifstats.dynamic_interface_inifidx})

    ifHdescr[_ifstats.id] = descr

    if(ifs.id == _ifstats.id) then
      observationPoints = interface.getObservationPoints()
   end
end

if((observationPoints == nil) or (table.len(observationPoints) == 0)) then
  -- read the validated observation point
  observationPoints = nil
  observationPointId = nil
end

interface.select(ifs.id.."")

local infrastructures = {}

if ntop.isEnterpriseM() then
   local infrastructure_utils = require("infrastructure_utils")
   if ntop.isPro() then
      for _, v in pairs(infrastructure_utils.get_all_instances()) do
         infrastructures[v.alias] = v.url
      end
   end
end



local context = {
   ifnames = ifnames,
   infrastructures = infrastructures, 
   views = views,
   dynamic = dynamic,
   recording = recording,
   pcapdump = pcapdump,
   packetinterfaces = packetinterfaces,
   drops = drops,
   ifHdescr = ifHdescr,
   ifCustom = ifCustom,
   action_urls = action_urls,
   is_system_interface = is_system_interface,
   currentIfaceId = ifs.id,
   observationPoints = observationPoints,
   observationPointId = observationPointId
}

print(template_utils.gen("pages/components/ifaces-dropdown.template", context))

-- ##############################################
-- Up/Down info
if not is_pcap_dump and not is_system_interface then

   print([[
      <li class='nav-item d-none d-sm-done d-md-flex d-lg-flex ms-2'>
         <div class='info-stats'>
            ]].. page_utils.generate_info_stats() ..[[
         </div>
      </li>
   ]])

end

-- License Badge
local info = ntop.getInfo(true)

if (_POST["ntopng_license"] == nil) and (info["pro.systemid"] and (info["pro.systemid"] ~= "")) then

   if (info["pro.release"]) then

      if (info["pro.demo_ends_at"] ~= nil) then

         local rest = info["pro.demo_ends_at"] - os.time()

         if (rest > 0) then
            print('<li class="nav-item nav-link"><a href="https://shop.ntop.org"><span class="badge bg-warning">')
            print(" " .. i18n("about.licence_expires_in", {time=secondsToTime(rest)}))
            print('</span></a></li>')
         end
      end

   else
      if(not(ntop.getInfo()["pro.forced_community"])) then
         print('<li class="nav-item nav-link"><a href="https://shop.ntop.org"><span class="badge bg-warning">')
         print(i18n("about.upgrade_to_professional")..' <i class="fas fa-external-link-alt"></i>')
         print('</span></a></li>')
      end
   end
end

-- ########################################
-- Network Load
print([[
   <li class="network-load d-none d-lg-inline"></li>
]])


-- ########################################
-- end of navbar-nav
print('</ul>')

print([[
<ul class='navbar-nav flex-row ms-auto'>
]])

-- ########################################
-- Searchbox hosts
-- append searchbox


if (not is_system_interface) then
   print("<li class='nav-item'>")
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
               before_submit = [[NtopUtils.makeFindHostBeforeSubmitCallback("]] .. ntop.getHttpPrefix() .. [[")]],
               max_items   = "'all'" --[[ let source script decide ]],
               parameters  = { ifid = ternary(is_system_interface, getSystemInterfaceId(), ifId) },
            }
      })
   )
   print("</li>")
end

-- #########################################
-- User Navbar Menu

-- Render Blog Notifications
if (not info.oem) then

   local username = _SESSION["user"] or ''
   if (isNoLoginUser()) then username = 'no_login' end

   local posts, new_posts_counter = blog_utils.readPostsFromRedis(username)
   template_utils.render("pages/components/blog-dropdown.template", {
      posts = posts,
      new_posts_counter = new_posts_counter,
      username = username
   })
end

local session_user = _SESSION['user']
local is_no_login_user = isNoLoginUser()

print([[
   <li class="nav-item dropdown">
      <a href='#' class="nav-link dropdown-toggle mx-2 dark-gray" id='navbar-user-dropdown-link' role="button" data-bs-reference="parent" data-bs-toggle="dropdown" aria-expanded="false">
         <i class='fas fa-user'></i>
      </a>
      <ul class="dropdown-menu dropdown-menu-lg-end" aria-labelledby='navbar-user-dropdown-link'>]])

if (not _SESSION["localuser"] or not is_admin) and (not is_no_login_user) then
   print[[
      <li>
         <a class="dropdown-item" href='#password_dialog' data-bs-toggle='modal'>
            <i class='fas fa-user'></i> ]] print(i18n("manage_users.manage_user_x", {user = _SESSION["user"]})) print[[
         </a>
      </li>
   ]]
else

   if (not is_no_login_user) then
      print([[<li><a class="dropdown-item" href=']].. ntop.getHttpPrefix() ..[[/lua/admin/users.lua?user=]].. session_user:gsub("%.", "\\\\\\\\.") ..[['><i class='fas fa-user'></i> ]].. session_user ..[[</a></li>]])
   else
      print([[<li class='dropdown-item disabled'>]])
      print([[<i class='fas fa-user'></i> ]].. session_user ..[[]])
      print([[</li>]])
   end

end

-- Render nendge services
if is_nedge and is_admin then
print([[
   <li class="dropdown-divider"></li>
   <li class="dropdown-header">]] .. i18n("nedge.product_status", {product=info.product}) .. [[</li>
   <li>
      <a class="dropdown-item" href="#poweroff_dialog" data-bs-toggle="modal">
         <i class="fas fa-power-off"></i> ]]..i18n("nedge.power_off")..[[
      </a>
   </li>
   <li>
      <a class="dropdown-item" href="#reboot_dialog" data-bs-toggle="dropdown"e="modal">
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
   <li><a class='dropdown-item' href='#' id="updates-install-li"><i class="fas fa-sync"></i> ]] .. (i18n("updates.check"))  ..[[</a></li>
]])
end

-- Rende Toggle Dark theme menu button

local theme_selector = ntop.getPref("ntopng.user." .. session_user .. ".theme")
local theme_selected = i18n("toggle_dark_theme")

if(theme_selector == 'dark') then
   theme_selected = i18n("toggle_white_theme")
end

print([[
   <li class='dropdown-divider'></li>
   <li>
      <a class='dropdown-item toggle-dark-theme' href='#'><i class="fas fa-adjust"></i> ]].. theme_selected ..[[</a>
   </li>
]])

-- Logout

if(not is_no_login_user) then
   print[[

 <li class='dropdown-divider'></li>
 <li>
   <a class="dropdown-item" href="]]
   print(ntop.getHttpPrefix())
   print [[/lua/logout.lua" onclick="return confirm(']] print(i18n("login.logout_message")) print [[')"><i class="fas fa-sign-out-alt"></i> ]] print(i18n("login.logout")) print[[</a></li>]]
 end

 -- Restart menu, the restart JS code can be found inside footer.lua
if(is_admin and ntop.isPackage() and not ntop.isWindows()) then
   print [[
       <li class="dropdown-divider"></li>
       <li><a class="dropdown-item restart-service" href="#"><i class="fas fa-redo-alt"></i> ]] print(i18n("restart.restart")) print[[</a></li>
   ]]
end

print([[
      </ul>
   </li>
</ul>

   </nav>
]])

-- begging of #n-container
print([[<main id='n-container' class='px-md-4 px-sm-1'>]])

-- ###################################################
-- Render toasts
toasts_manager.render_toasts("main-container", toasts_manager.load_main_toasts())
-- ###################################################

print("<div class='main-alerts'>")

-- Hidden by default, will be shown by the footer if necessary
print('<div id="influxdb-error-msg" class="alert alert-danger alert-dismissable" style="display:none" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> <span id="influxdb-error-msg-text"></span>')
print[[<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>]]
print('</div>')

-- Hidden by default, will be shown by the footer if necessary
print('<div id="major-release-alert" class="alert alert-info" style="display:none" role="alert"><i class="fas fa-cloud-download-alt" id="alerts-menu-triangle"></i> <span id="ntopng_update_available"></span>')
print('</div>')

if(_SESSION["INVALID_CSRF"]) then
  print('<div class="alert alert-warning alert-dismissable" role="alert"><i class="fas fa-exclamation-triangle fa-lg" id="alerts-menu-triangle"></i> ')
  print(i18n("expired_csrf"))
  print[[<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>]]
  print('</div>')
end

-- end of main alerts
print("</div>")

-- append password change modal
if(not is_admin) then
   dofile(dirs.installdir .. "/scripts/lua/inc/password_dialog.lua")
end
