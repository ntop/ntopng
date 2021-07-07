--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
local info = ntop.getInfo()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local plugins_utils = require("plugins_utils")
local template_utils = require("template_utils")
local recording_utils = require("recording_utils")
local alert_entities = require("alert_entities")

local page_utils = {}

local is_nedge = ntop.isnEdge()

-- #################################

local active_section = nil
local active_entry = nil
local active_sub_entry = nil

-- #################################

page_utils.menu_sections = {
   shortcuts     = {key = "shortcut", i18n_title = "shortcuts", icon = "fas fa-fast-forward"},
   dashboard     = {key = "dashboard", i18n_title = "index_page.dashboard", icon = "fas fa-tachometer-alt"},
   alerts        = {key = "alerts", i18n_title = "details.alerts", icon = "fas fa-exclamation-triangle"},
   flows         = {key = "flows", i18n_title = "flows", icon = "fas fa-stream"},
   hosts         = {key = "hosts", i18n_title = "hosts", icon = "fas fa-laptop"},
   maps          = {key = "maps", i18n_title = "maps", icon = "fas fa-map"},
   exporters     = {key = "exporters", i18n_title = "flow_devices.exporters", icon = "fas fa-file-export", zmq_only = true --[[ only for non-packet ZMQ interfaces --]] },
   if_stats      = {key = "if_stats", i18n_title = "interface", icon = "fas fa-ethernet"},
   system_stats  = {key = "system_stats", i18n_title = "system", icon = "fas fa-desktop"},
   admin         = {key = "admin", i18n_title = "settings", icon = "fas fa-cog"},
   alert_exclusions = {key = "alert_exclusions", i18n_title = "edit_check.exclusion_list", icon = "fas fa-bell-slash"},
   dev           = {key = "dev", i18n_title = "developer", icon = "fas fa-code"},
   about         = {key = "about", i18n_title = "help", icon = "fas fa-life-ring"},
   health        = {key = "health", i18n_title = "health", icon = "fas fa-laptop-medical"},
   pollers       = {key = "pollers", i18n_title = "pollers", icon = "fas fa-heartbeat"},
   tools         = {key = "tools", i18n_title = "tools", icon = "fas fa-cogs"},
   pools         = {key = "pools", i18n_title = "pools.pools", icon = "fas fa-users"},
   notifications = {key = "notifications", i18n_title = "endpoint_notifications.notifications", icon = "fas fa-bell"},
   checks  = {key = "checks", i18n_title = "about.checks" },
   -- nEdge
   views         = {key = "hosts", i18n_title = "views", icon = "fas fa-bars"},
}

-- #################################

-- help_link: this variable contains the contextual link to the documentation

page_utils.menu_entries = {
   -- Shortcuts
   active_monitoring = {key = "active_monitor", i18n_title = "active_monitoring_stats.active_monitoring"},

   -- Dashboard
    traffic_dashboard     = {key = "traffic_dashboard", i18n_title = "dashboard.traffic_dashboard", section = "dashboard", help_link = "https://www.ntop.org/guides/ntopng/web_gui/dashboard.html"},
    network_discovery     = {key = "network_discovery", i18n_title = "discover.network_discovery",  section = "dashboard"},
    traffic_report        = {key = "traffic_report",    i18n_title = "report.traffic_report",    section = "dashboard", help_link = "https://www.ntop.org/guides/ntopng/web_gui/report.html"},
    db_explorer           = {key = "db_explorer", i18n_title = "db_explorer.historical_data_explorer", section = "dashboard"},

    -- Alerts
    detected_alerts       = {key = "detected_alerts", i18n_title = "show_alerts.detected_alerts", section = "alerts", help_link = "https://www.ntop.org/guides/ntopng/web_gui/alerts.html"},
    alerts_dashboard      = {key = "alerts_dashboard", i18n_title = "alerts_dashboard.alerts_dashboard", section = "alerts"},
    flow_alerts_explorer  = {key = "flow_alerts_explorer", i18n_title = "flow_alerts_explorer.label", section = "alerts"},

    -- Flows
    flows                 = {key = "flows", i18n_title = "flows", section = "flows", help_link = "https://www.ntop.org/guides/ntopng/web_gui/flows.html"},
    flow_details          = {key = "flow_details", i18n_title = "flow_details.flow_details", section = "flows"},

    -- Hosts
    hosts                 = {key = "hosts", i18n_title = "hosts", section = "hosts", help_link = "https://www.ntop.org/guides/ntopng/web_gui/hosts.html#"},
    devices               = {key = "devices", i18n_title = "layer_2", section = "hosts"},
    networks              = {key = "networks", i18n_title = "networks", section = "hosts", help_link = "https://www.ntop.org/guides/ntopng/web_gui/hosts.html?#networks"},
    vlans                 = {key = "vlans", i18n_title = "vlan_stats.vlans", section = "hosts"},
    host_pools            = {key = "host_pools", i18n_title = "host_pools.host_pools", section = "hosts"},
    autonomous_systems    = {key = "autonomous_systems", i18n_title = "as_stats.autonomous_systems", section = "hosts", help_link = "https://www.ntop.org/guides/ntopng/web_gui/hosts.html?#autonomous-systems"},
    countries             = {key = "countries", i18n_title = "countries", section = "hosts", help_link = "https://www.ntop.org/guides/ntopng/web_gui/hosts.html?#countries"},
    operating_systems     = {key = "operating_systems", i18n_title = "operating_systems", section = "hosts", help_link = "https://www.ntop.org/guides/ntopng/web_gui/hosts.html?#operating-systems"},
    http_servers          = {key = "http_servers", i18n_title = "http_servers_stats.http_servers", section = "hosts", help_link = "https://www.ntop.org/guides/ntopng/web_gui/hosts.html?#http-servers-local"},
    top_hosts             = {key = "top_hosts", i18n_title = "processes_stats.top_hosts", section = "hosts", help_link = "https://www.ntop.org/guides/ntopng/web_gui/hosts.html?#top-hosts-local"},
    hosts_treemap         = {key = "hosts_treemap", i18n_title = "tree_map.hosts_treemap", section = "hosts"},
    containers            = {key = "containers", i18n_title = "containers_stats.containers", section = "hosts"},
    pods                  = {key = "pods", i18n_title = "containers_stats.pods", section = "hosts"},

    -- Interface
    interface             = {key = "interface", i18n_title = "interface_ifname", section = "if_stats"},

    -- Pollers
    snmp                  = {key = "snmp", i18n_title = "prefs.snmp", section = "pollers"},
    infrastructure_dashboard = {key = "infrastructure_dashboard", i18n_title = "infrastructure_dashboard.infrastructure_dashboard", section = "pollers"},

    -- Status (Health)
    system_status         = {key = "system_status", i18n_title = "system_status", section = "health"},
    interfaces_status     = {key = "interfaces_status", i18n_title = "system_interfaces_status", section = "health"},
    alerts_status         = {key = "alerts_status", i18n_title = "system_alerts_status", section = "health"},

    -- Exporters
    event_exporters       = {key = "event_exporters", i18n_title = "event_exporters.event_exporters", section = "exporters"},
    sflow_exporters       = {key = "sflow_exporters", i18n_title = "flows_page.sflow_devices", section = "exporters"},
    flow_exporters        = {key = "flow_exporters", i18n_title = "flow_devices.probe_exporters", section = "exporters", help_link = "https://www.ntop.org"},
    observation_points    = {key = "observation_points", i18n_title = "flow_devices.observation_points", section = "exporters", help_link = "https://www.ntop.org"},

   -- Map
   service_map            = {key = "service_map", i18n_title="service", section = "maps"},
   periodicity_map        = {key = "periodicity_map", i18n_title="periodicity", section = "maps"},
   geo_map                = {key = "geo_map", i18n_title = "geo_map.geo_map", section = "maps", help_link = "https://www.ntop.org/guides/ntopng/web_gui/hosts.html?#geo-map"},
   hosts_map              = {key = "hosts_map", i18n_title = "flows_page.hosts", section = "maps"},
   
   -- Settings
   nedge_users            = {key = "nedge_users", i18n_title = "manage_users.manage_users", section = "admin", help_link = "https://www.ntop.org/guides/nedge/users.html#"},
   manage_users           = {key = "manage_users", i18n_title = ternary(is_nedge, "nedge.system_users", "manage_users.manage_users"), section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/settings.html#manage-users"},
   preferences            = {key = "preferences", i18n_title = "prefs.preferences", section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/settings.html#preferences"},
   scripts_config         = {key = "scripts_config", i18n_title = "about.checks", section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   scripts_config_hosts   = {key = "scripts_config", subkey="hosts", i18n_title = alert_entities.host.i18n_label, section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   scripts_config_interfaces = {key = "scripts_config", subkey="interfaces", i18n_title = alert_entities.interface.i18n_label, section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   scripts_config_networks = {key = "scripts_config", subkey="networks", i18n_title = alert_entities.network.i18n_label, section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   scripts_config_snmp_devices = {key = "scripts_config", subkey="snmp_devices", i18n_title = alert_entities.snmp_device.i18n_label, section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   scripts_config_flows   = {key = "scripts_config", subkey="flows", i18n_title = alert_entities.flow.i18n_label, section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   scripts_config_system  = {key = "scripts_config", subkey="system", i18n_title = alert_entities.system.i18n_label, section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   scripts_config_syslog  = {key = "scripts_config", subkey="syslog", i18n_title = "syslog.syslog", section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   alert_exclusions       = {key = "alert_exclusions", i18n_title = "edit_check.exclusion_list", section = "alert_exclusions", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   alert_exclusions_hosts = {key = "alert_exclusions", subkey="hosts", i18n_title = alert_entities.host.i18n_label, section = "alert_exclusions", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   alert_exclusions_flows = {key = "alert_exclusions", subkey="flows", i18n_title = alert_entities.flow.i18n_label, section = "alert_exclusions", help_link = "https://www.ntop.org/guides/ntopng/web_gui/checks.html"},
   license                = {key = "license", i18n_title = "license_page.license", section = "admin"},
   profiles               = {key = "profiles", i18n_title = "traffic_profiles.traffic_profiles", section = "admin", help_link = "https://www.ntop.org/guides/ntopng/advanced_features/traffic_profiles.html"},
   categories             = {key = "categories", i18n_title = "custom_categories.apps_and_categories", section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/categories.html#custom-applications"},
   category_lists         = {key = "category_lists", i18n_title = "category_lists.category_lists", section = "admin"},
   device_protocols       = {key = "device_protocols", i18n_title = "device_protocols.device_protocols", section = "admin"},
   conf_backup            = {key = "conf_backup", i18n_title = "conf_backup.conf_backup", section = "admin"},
   conf_restore           = {key = "conf_restore", i18n_title = "conf_backup.conf_restore", section = "admin"},
   manage_data            = {key = "manage_data", i18n_title = "manage_data.manage_data", section = "admin", help_link = "https://www.ntop.org/guides/ntopng/web_gui/settings.html#manage-data"},
   manage_configurations  = {key = "manage_configurations", i18n_title = "manage_configurations.manage_configurations", section = "admin"},

   -- Notifications
   endpoint_notifications = {key = "endpoint_notifications", i18n_title = "endpoint_notifications.endpoint_list", section="notifications", help_link = "https://www.ntop.org/guides/ntopng/plugins/alert_endpoints.html"},
   endpoint_recipients    = {key = "endpoint_recipients", i18n_title = "endpoint_notifications.enpoint_recipients_list", section="notifications", help_link = "https://www.ntop.org/guides/ntopng/plugins/alert_endpoints.html"},

   -- Tools
   export_data            = {key = "export_data", i18n_title = "manage_data.export", section = "tools"},

   -- Pools
   host_members           = {key = "host_members", i18n_title = "host_pools.host_members", section = "pools"},
   manage_pools           = {key = "manage_pools", i18n_title = "pools.pools", section = "pools"},

   -- Home
   live_capture           = {key = "live_capture", i18n_title = "live_capture.active_live_captures", section = "home"},

   -- Developer
   directories            = {key = "directories", i18n_title = "about.directories", section = "dev", help_link = "https://www.ntop.org/guides/ntopng/plugins/distributing_plugins.html"},
   plugins                = {key = "plugins", i18n_title = "plugins", section = "dev", help_link = "https://www.ntop.org/guides/ntopng/basic_concepts/plugins.html"},
   checks_dev       = {key = "checks_dev", i18n_title = "about.checks", section = "dev", help_link = "https://www.ntop.org/guides/ntopng/plugins/checks.html"},
   plugin_browser         = {key = "plugin_browser", i18n_title = "plugin_browser", section = "dev"},
   alert_definitions      = {key = "alert_definitions", i18n_title = "about.alert_defines", section = "dev", help_link = "https://www.ntop.org/guides/ntopng/plugins/alert_definitions.html"},
   api                    = {key = "api", i18n_title = "lua_c_api", section = "dev"},
   
   -- Help
   about                  = {key = "about", i18n_title = "about.about", section = "about", help_link = "https://www.ntop.org/guides/ntopng/web_gui/help_menu.html?#about"},
   telemetry              = {key = "telemetry", i18n_title = "telemetry", section = "about"},
   blog                   = {key = "blog", i18n_title = "about.ntop_blog", section = "about"},
   telegram               = {key = "telegram", i18n_title = "about.telegram", section = "about"},
   report_issue           = {key = "report_issue", i18n_title = "about.report_issue", section = "about"},
   manual                 = {key = "manual", i18n_title = "about.readme_and_manual", section = "about"},
   suggest_feature        = {key = "suggest_feature", i18n_title = "about.suggest_feature", section = "about"},

   -- Just a divider for horizontal rows in the menu
   divider                = {key = "divider"},

   -- nEdge
   gateways_users         = {key = "gateways_users", i18n_title = "dashboard.gateways_users", section = "dashboard"},
   nedge_flows            = {key = "nedge_flows", i18n_title = "flows", section = "hosts"},
   users                  = {key = "users", i18n_title = "users.users", section = "hosts", help_link = "https://www.ntop.org/guides/ntopng/advanced_features/authentication.html"},
   system_setup           = {key = "system_setup", i18n_title = "nedge.system_setup", section = "system_stats", help_link = "https://www.ntop.org/guides/nedge/get_started.html"},
   dhcp_leases            = {key = "dhcp_leases", i18n_title = "nedge.dhcp_leases", section = "system_stats"},
   port_forwarding        = {key = "port_forwarding", i18n_title = "nedge.port_forwarding", section = "system_stats"},
}

-- Extend the menu entries with the plugins
local menu, entries_data = plugins_utils.getMenuEntries()
page_utils.plugins_menu = menu or {}

if entries_data then
    for k, v in pairs(entries_data) do
       page_utils.menu_entries[k] = v
    end
end

-- #################################

-- NOTE: this function must be called after page_utils.set_active_menu_entry
function page_utils.print_page_title(title)
   local help_link = page_utils.menu_entries[active_entry].help_link or ""
   print("<header class='mb-3 d-flex align-items-center'>")
   print("<h2 class='d-inline-block'>".. title .."</h2>")
   if (not isEmptyString(help_link)) then
      print("<a data-bs-toggle='tooltip' title='".. i18n("open_documentation") .."' target='_newtab' href='".. help_link .."' class='text-muted ms-auto'><i class='fas fa-question-circle'></i></a>")
   end
   print("</header>")

end

-- #################################

-- NOTE: this function is called by the web pages in order to
-- set the active entry and section and highlight it into the menu
function page_utils.set_active_menu_entry(entry, i18n_params, alt_title)
   entry = entry or page_utils.menu_entries.traffic_dashboard

   active_section = entry.section
   active_entry = entry.key
   if entry.subkey then
      active_sub_entry = entry.subkey
   end

   page_utils.print_header(alt_title or i18n(entry.i18n_title, i18n_params) or entry.i18n_title)
end

-- #################################

function page_utils.get_active_section()
    return(active_section)
end

function page_utils.get_active_entry()
    return(active_entry)
end

function page_utils.get_active_sub_entry()
    return(active_sub_entry)
end

-- #################################

-- @brief Encode the HTML entities in a string.
--        Useful when printing dissected data which may result in XSS
--        e.g., curl -u admin:admin1 "http://devel:3000/</a><script>alert(1);</script><a>"
-- @param s The string to escape.
-- @return The string with HTML entities properly escaped
function page_utils.safe_html(s)
   if not s then
      return ''
   end

   ret = string.gsub(s, "[}{\">/<'&]", {
            ["&"] = "&amp;",
            ["<"] = "&lt;",
            [">"] = "&gt;",
            ['"'] = "&quot;",
            ["'"] = "&#39;",
            ["/"] = "&#47;"
   })

   return(ret)
end

-- #################################

function page_utils.is_dark_mode_enabled(theme)

   local dark_mode
   local theme = theme or ntop.getPref("ntopng.user." .. _SESSION["user"] .. ".theme")

   if (isEmptyString(theme)) then
      dark_mode = false
   else
      dark_mode = (theme == "dark")
   end

   return dark_mode
end

-- #################################

function page_utils.print_header(title)
  local http_prefix = ntop.getHttpPrefix()
  local static_file_epoch = ntop.getStaticFileEpoch()..""

  local dark_mode = page_utils.is_dark_mode_enabled(_POST["toggle_theme"])

  local page_title = i18n("welcome_to", { product=info.product })
  if title ~= nil then
    page_title = info.product .. " - " .. title
  end

  print [[
   <!DOCTYPE html>
   <html>
   <head>
    <title>]] print(page_title) print[[</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">

    <link href="]] print(http_prefix) print[[/bootstrap/css/bootstrap.min.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/minified/ntopng.min.css?]] print(static_file_epoch) print[[" rel="stylesheet"> ]]

    if (dark_mode) then
      print[[<link href="]] print(http_prefix) print[[/css/minified/dark-mode.min.css?]] print(static_file_epoch) print[[" rel="stylesheet">]]
    end

    print[[
    <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/all.min.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/minified/tempusdominus.min.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/minified/heatmap.min.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/minified/rickshaw.min.css" type="text/css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/dc.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/selectpicker/css/bootstrap-select.min.css" rel="stylesheet">

   <style>
      .flag {
         width: 16px;
         height: 11px;
         margin-top: -5px;
         background:url(]] print(http_prefix) print[[/img/flags.png) no-repeat
      }
   </style>
    <link href="]] print(http_prefix) print[[/css/flags.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/pie-chart.css" rel="stylesheet">
    <!-- http://kamisama.github.io/cal-heatmap/v2/ -->
    <link href="]] print(http_prefix) print[[/css/nv.d3.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/custom_theme.css?]] print(static_file_epoch) print[[" rel="stylesheet">
    <!--[if lt IE 9]>
      <script src="]] print(http_prefix) print[[/js/html5shiv.js"></script>
    <![endif]-->
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/jquery_bootstrap.min.js?]] print(static_file_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/popper/popper.min.js" crossorigin="anonymous"></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/deps.min.js?]] print(static_file_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/ntop.min.js?]] print(static_file_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/tempusdominus.min.js?]] print(static_file_epoch) print[["></script>
  </head>]]
  print([[
     <body class="body ]].. (dark_mode and "dark" or "") ..[[">
  ]])
end

-- #################################

function page_utils.print_header_minimal(title)
  local http_prefix = ntop.getHttpPrefix()

  local page_title = i18n("welcome_to", { product=info.product })
  if title ~= nil then
    page_title = info.product .. " - " .. title
  end

  print [[
    <!DOCTYPE html>
    <html>
      <head>
        <title>]] print(page_title) print[[</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <link href="]] print(http_prefix) print[[/bootstrap/css/bootstrap.min.css" rel="stylesheet">
        <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/fontawesome.css" rel="stylesheet">
        <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/brands.css" rel="stylesheet">
        <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/solid.css" rel="stylesheet">
        <script type="text/javascript" src="]] print(http_prefix) print[[/js/jquery_bootstrap.min.js?]] print(static_file_epoch) print[["></script>
        <link type="text/css" rel="stylesheet" href="]] print(http_prefix) print[[/css/rickshaw.css">
        <script src="]] print(http_prefix) print[[/js/validator.js"></script>
        <style>
        .flag {
          width: 16px;
          height: 11px;
          margin-top: -5px;
          background:url(]] print(http_prefix) print[[/img/flags.png) no-repeat
        }
        </style>
        <link href="]] print(http_prefix) print[[/css/ntopng.css" rel="stylesheet">
      </head>
      <body>

]]
end

-- #################################

function page_utils.print_navbar(title, base_url, items_table, label_url)

   local help_link = page_utils.menu_entries[active_entry].help_link or nil
   local icon = page_utils.menu_sections[active_section].icon or ""

   local context = {
      navbar = {
         title = "<i class='".. icon .. "'></i>" .. " " .. title,
         base_url = base_url,
         items_table = items_table,
         label_url = label_url,
         help_link = help_link
      }
   }
   print(template_utils.gen("pages/components/page-navbar.template", context))
end

-- #################################
local menubar_structure = {}

function page_utils.init_menubar()
   menubar_structure = {}
end

-- #################################

function page_utils.add_menubar_section(section)
   menubar_structure[#menubar_structure + 1] = section
end

-- #################################

local function print_submenu(section, container_list_name)
   local active_subpage = page_utils.get_active_entry()
   local active_subsubpage = page_utils.get_active_sub_entry()
   local section_key = section.section.key
   local section_id = section_key.."-submenu"
   local list_name = section_id.."-list"

   print[[<div data-parent='#]] print(container_list_name) print [[' class='collapse side-collapse' id=']] print(section_id) print[['>
          <ul class='nav flex-column' id=']] print(list_name) print[['>
            ]]

   for _, section_entry in ipairs(section.entries) do
      if not section_entry.hidden then
         if section_entry.custom then
            print(section_entry.custom)
         elseif section_entry.entry.key == "divider" then
            print[[
           <li class="dropdown-divider"></li>
                  ]]
         else
            local external_link = false
            local section_has_submenu = section_entry.entries
	    local active = false

            if section_entry.entry and 
	       (section_entry.entry.key == active_subpage and 
	        (not section_entry.entry.subkey or section_entry.entry.subkey == active_subsubpage)) then
	       active = true
	    end

            print[[
         <li class=']]
	    if active then
               print("active")
            end
            print[['>

             <a class="]]
            if section_has_submenu then
               print[[submenu ]]
            end
	    if active then
               print[[active ]]
            end
	    print[["]]

            if section_has_submenu then
               print[[ data-bs-toggle="collapse" ]]
            end

            print[[ href="]]
	    if section_has_submenu then
	       local submenu_section_key = section_entry.section.key
	       local submenu_section_id = submenu_section_key.."-submenu"
               print("#"..submenu_section_id)
	    else 
               if section_entry.url:starts("http") then
                  -- Absolute (external) url
                  print(section_entry.url)
                  external_link = true
               else
                  -- Url relative to ntopng
                  print(ntop.getHttpPrefix()..section_entry.url)
               end
	    end
            print[["]]

            if section_entry.entry.is_modal then
               print(' data-bs-toggle="modal"')
            end

            if external_link then
               -- Open in a new page
               print(' target="_blank"')
            end

            print[[>]]
            print(i18n(section_entry.entry.i18n_title) or section_entry.entry.i18n_title)
            if section_entry.suffix then
               print(section_entry.suffix)
            end
            if external_link then
               print(" <i class='fas fa-external-link-alt'></i>")
            end

            print[[</a>]]
            
	    if section_has_submenu then
	       print_submenu(section_entry, list_name)
            end

            print[[</li>
   ]]
         end
      end
   end

   print[[
          </ul>
        </div>
   ]]
end

-- #################################

local function print_section(section, list_name)
   local active_page = page_utils.get_active_section()
   local show_section = false
   local section_has_submenu = (section.entries and #section.entries > 0)

   if(not section.hidden) then
      if not section_has_submenu then
         show_section = true
      else
         -- The section is shown only if at least one of its sub entries
         -- is shown
         for _, section_entry in pairs(section.entries or {}) do
            if not section_entry.hidden then
               show_section = true
               break
            end
     end
      end
   end

   if show_section then
      local section_key = section.section.key
      local section_id = section_key.."-submenu"

      print[[
      <li class="nav-item ]] print(active_page == section_key and 'active' or '') print[[">
    <a class="]]

      if section_has_submenu then
         print[[submenu ]]
      end

      if active_page == section_key then
         print[[active ]]
      end

      print[[" ]]

     if section_has_submenu then
        print[[ data-bs-toggle="collapse" ]]
     end

     print[[href="]]

     if section.url then
        print(ntop.getHttpPrefix()..section.url)
     else
        print("#"..section_id)
     end

     print[[">
      <span class="]] print(section.section.icon) print[["></span> ]] print(i18n(section.section.i18n_title)) print[[
    </a>]]

     if section_has_submenu then
        print_submenu(section, list_name)
     end
   end
end

-- #################################

function page_utils.print_menubar()
   local is_system_interface = page_utils.is_system_view()
   local logo_path = nil
   local list_name = "sidebar"

   if (ntop.isPro() or ntop.isnEdge()) and ntop.exists(dirs.installdir .. "/httpdocs/img/custom_logo.png") then
      logo_path = ntop.getHttpPrefix().."/img/custom_logo.png"
   end

   local navbar_style = _POST["toggle_theme"] or ntop.getPref("ntopng.user." .. _SESSION["user"] .. ".theme")

   if ((navbar_style == nil) or (navbar_style == "white") or (navbar_style == "")) then
      navbar_style = "default"
   end

   if (navbar_style == "default") then
      navbar_style = "dark"
   end

   print('<nav id="n-sidebar" class="bg-'.. navbar_style ..' py-0 px-2">')
   print([[
      <div class="mobile-menu-button d-flex">
            <form class='w-100' method='post' action="/?">
               <input hidden name='switch_interface' value='1' />
               <input hidden name='csrf' value=']].. ntop.getRandomCSRFValue() ..[[' />
               ]]
               .. template_utils.gen("pages/components/ifaces-select.template", {
                  ifaces = page_utils.get_interface_list(),
                  is_sys_iface = is_system_interface
               })
               ..[[
            </form>
            <button data-bs-toggle="]] .. list_name .. [[" class='ms-5 my-auto btn btn-close'></button>
      </div>
      <div class="mobile-menu-stats">
      ]])

      -- the network load will not be displayed in system view mode
      if not is_system_interface then
         print([[<div class="network-load mb-2 w-100"></div>]])
      end

      print([[
         <div class="info-stats w-100">]].. page_utils.generate_info_stats() ..[[</div>
      </div>
   ]])
   print("<h3 class='muted'><a href='"..ntop.getHttpPrefix().."/'>")

   if (logo_path ~= nil) then
      print("<img class=\"logo-brand\" height=\"52px\" src=\""..logo_path.."\" alt='Custom Logo' />")
   else
      print(addLogoSvg())
   end

   print([[
           </a>
     </h3>

     <ul class="nav-side mb-4" id=']] .. list_name .. [['>
]])

   for _, section in ipairs(menubar_structure) do
     print_section(section, list_name)
   end

   print([[
     </ul>
   </nav>
]])
end

-- ##############################################

function page_utils.get_interface_list()
   local interfaces = {}
   local iface_names = interface.getIfNames()
   local is_system_interface = page_utils.is_system_view()

   local num_ifaces = 0
   for k,v in pairs(iface_names) do
      num_ifaces = num_ifaces+1
   end

   local ifs = interface.getStats()
   local is_pcap_dump = interface.isPcapDumpInterface()
   local is_packet_interface = interface.isPacketInterface()
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

         if ((round == 1) and (ifCustom[k] ~= nil)) or (((round == 2) and (ifCustom[k] == nil))) then
            goto continue
         end

         local v = ifnames[k]

         -- table.clone needed to modify some parameters while keeping the original unchanged
         local page_params = table.clone(_GET)
         page_params.ifid = k

         local url_query = getPageUrl("", page_params)

         -- NOTE: the actual interface switching is performed in C in LuaEngine::handle_script_request
         local action_url = ""

         if(is_system_interface) then
            action_url = ntop.getHttpPrefix() .. '/' .. url_query
         else
            action_url = url_query
         end

         local descr = getHumanReadableInterfaceName(v.."")

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

         interfaces[#interfaces+1] = {
            is_virtual = (round == 2),                                     -- Is the interface virtual or physical?
            is_paused = isPausedInterface(v),                              -- Is the interfaces paused?
            is_selected = (v == ifname) and not is_system_interface,        -- Is the in
            is_dynamic = (dynamic[v]),
            is_recording = (recording[v]),
            has_drops = (drops[v]),
            has_views = (views[v]),
            ifid = k,
            action_url = action_url,
            human_name = descr
         }

         ::continue::
      end
   end

   interface.select(ifs.id.."")

   return interfaces
end

function page_utils.generate_info_stats()

   local _ifstats = interface.getStats()

   if _ifstats.has_traffic_directions then
      return ([[
         <a href=']].. ntop.getHttpPrefix() ..[[/lua/if_stats.lua'>
            <div class='up'>
               <i class="fas fa-arrow-up"></i>
               <span style='display: none;' class="network-load-chart-upload">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>
               <span class="text-end chart-upload-text"></span>
            </div>
            <div class='down'>
               <i class="fas fa-arrow-down"></i>
               <span style='display: none;' class="network-load-chart-download">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>
               <span class="text-end chart-download-text"></span>
            </div>
         </a>
      ]])
   else
      return ([[
         <a href=']].. ntop.getHttpPrefix() ..[[/lua/if_stats.lua'>
            <span style='display: none;' class="network-load-chart-total">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</span>
            <span class="text-end chart-total-text"></span>
         </a>
      ]])
   end

end

-- ##############################################

function page_utils.is_system_view()
   return interface.getId() == tonumber(getSystemInterfaceId()) and isAdministrator()
end

-- ##############################################

--- Check if the current page is valid
--- @return boolean True if the current page is in available_pages, false otherwise
function page_utils.is_valid_page(selected_page, available_pages)

   if selected_page == nil then
      traceError(TRACE_WARNING, TRACE_DEBUG, "selected_pages is nil!")
      return false
   end
   if available_pages == nil then
      traceError(TRACE_WARNING, TRACE_DEBUG, "available_pages is nil!")
      return false
   end
   if type(available_pages) ~= 'table' then
      traceError(TRACE_WARNING, TRACE_DEBUG, "available_pages is not a table!")
      return false
   end

   -- do a linear search
   for _, page in ipairs(available_pages) do
      if (page == selected_page) then return true end
   end

   return false

end

-- ##############################################

-- @brief Prepares the URL which will be used for the redirect after interface switch
-- @param ifid The interface identifier of the interface that will be switched
-- @param if_type The type of the interface that will be switched
-- @return The URL
function page_utils.switch_interface_form_action_url(active_ifid, switch_ifid, switch_if_type)
   local action_url = ""
   local page_params = table.clone(_GET)

   -- Read the currently active page
   local active_page = page_utils.get_active_section()

   if active_ifid == tonumber(getSystemInterfaceId()) then
      -- If the switch is between the system interface and a non-system interface
      -- the URL is just the home
      action_url = ntop.getHttpPrefix() .. '/'
   elseif page_utils.menu_sections[active_page] and page_utils.menu_sections[active_page]["zmq_only"] and switch_if_type ~= "zmq" and switch_if_type ~= "custom" then
      -- If the interface that will be switched is non-ZMQ, and the currently
      -- selected page is for ZMQ-only interfaces, then a redirection to root
      -- is performed, rather than preserving the current page
      action_url = ntop.getHttpPrefix() .. '/'
   end

   -- Attach the interface id of the interface that will be switched
   page_params.ifid = switch_ifid

   -- Return the url, preserving all existing page parameters (e.g., host=xx)
   local res = getPageUrl(action_url, page_params)

   return res
end

-- ##############################################

return page_utils

