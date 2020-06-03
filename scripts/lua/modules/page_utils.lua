--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
local info = ntop.getInfo()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local plugins_utils = require("plugins_utils")
local is_nedge = ntop.isnEdge()

local page_utils = {}

-- #################################

local active_section = nil
local active_entry = nil

-- #################################

page_utils.menu_sections = {
   dashboard    = {key = "dashboard", i18n_title = "index_page.dashboard", icon = "fas fa-tachometer-alt"},
   alerts       = {key = "alerts", i18n_title = "details.alerts", icon = "fas fa-exclamation-triangle"},
   flows        = {key = "flows", i18n_title = "flows", icon = "fas fa-stream"},
   hosts        = {key = "hosts", i18n_title = "hosts", icon = "fas fa-laptop"},
   exporters    = {key = "exporters", i18n_title = "flow_devices.exporters", icon = "fas fa-file-export"},
   if_stats     = {key = "if_stats", i18n_title = "interface", icon = "fas fa-ethernet"},
   system_stats = {key = "system_stats", i18n_title = "system", icon = "fas fa-desktop"},
   admin        = {key = "admin", i18n_title = "settings", icon = "fas fa-cog"},
   dev   	    = {key = "dev", i18n_title = "developer", icon = "fas fa-code"},
   about	       = {key = "about", i18n_title = "help", icon = "fas fa-life-ring"},
   snmp         = {key = "snmp", i18n_title = "prefs.snmp", icon = "fas fa-tablet"},
   health       = {key = "system_health", i18n_title = "health", icon = "fas fa-heartbeat"},
   tools        = {key = "tools", i18n_title = "tools", icon = "fas fa-cogs"},

   -- nEdge
   views	= {key = "hosts", i18n_title = "views", icon = "fas fa-bars"},
}

-- #################################

-- visible_iface: this flag is true when the page belong to interface view
-- visible_system: this flags is true when the page belong to system view
-- if both flags are true it means the pages are shared between views

page_utils.menu_entries = {
    -- Dashboard
    traffic_dashboard 	= {key = "traffic_dashboard", i18n_title = "dashboard.traffic_dashboard", section = "dashboard", visible_iface = true},
    network_discovery 	= {key = "network_discovery", i18n_title = "discover.network_discovery",  section = "dashboard", visible_iface = true},
    traffic_report    	= {key = "traffic_report",    i18n_title = "report.traffic_report",	section = "dashboard", visible_iface = true},
    db_explorer    	= {key = "db_explorer", i18n_title = "db_explorer.historical_data_explorer", section = "dashboard", visible_iface = true},

    -- Alerts
    detected_alerts  	 = {key = "detected_alerts", i18n_title = "show_alerts.detected_alerts", section = "alerts", visible_iface = true},
    alerts_dashboard  	 = {key = "alerts_dashboard", i18n_title = "alerts_dashboard.alerts_dashboard", section = "alerts", visible_iface = true},
    flow_alerts_explorer = {key = "flow_alerts_explorer", i18n_title = "flow_alerts_explorer.label", section = "alerts", visible_iface = true},

    -- Flows
    flows 	     	 = {key = "flows", i18n_title = "flows", section = "flows", visible_iface = true},
    flow_details 	 = {key = "flow_details", i18n_title = "flow_details.flow_details", section = "flows", visible_iface = true},

    -- Hosts
    hosts 	     	 = {key = "hosts", i18n_title = "hosts", section = "hosts", visible_iface = true},
    devices	     	 = {key = "devices", i18n_title = "layer_2", section = "hosts", visible_iface = true},
    networks	     	 = {key = "networks", i18n_title = "networks", section = "hosts", visible_iface = true},
    vlans	     	 = {key = "vlans", i18n_title = "vlan_stats.vlans", section = "hosts", visible_iface = true},
    host_pools	     	 = {key = "host_pools", i18n_title = "host_pools.host_pools", section = "hosts", visible_iface = true},
    autonomous_systems	 = {key = "autonomous_systems", i18n_title = "as_stats.autonomous_systems", section = "hosts", visible_iface = true},
    countries	    	 = {key = "countries", i18n_title = "countries", section = "hosts", visible_iface = true},
    operating_systems	 = {key = "operating_systems", i18n_title = "operating_systems", section = "hosts", visible_iface = true},
    http_servers	 = {key = "http_servers", i18n_title = "http_servers_stats.http_servers", section = "hosts", visible_iface = true},
    top_hosts	      	 = {key = "top_hosts", i18n_title = "processes_stats.top_hosts", section = "hosts", visible_iface = true},
    geo_map	      	 = {key = "geo_map", i18n_title = "geo_map.geo_map", section = "hosts", visible_iface = true},
    hosts_treemap	 = {key = "hosts_treemap", i18n_title = "tree_map.hosts_treemap", section = "hosts", visible_iface = true},
    host_explorer	 = {key = "host_explorer", i18n_title = "host_explorer", section = "hosts", visible_iface = true},
    containers	      	 = {key = "containers", i18n_title = "containers_stats.containers", section = "hosts", visible_iface = true},
    pods	      	 = {key = "pods", i18n_title = "containers_stats.pods", section = "hosts", visible_iface = true},

    -- Interface
    interface	      	 = {key = "interface", i18n_title = "interface_ifname", section = "if_stats", visible_iface = true},

    -- SNMP
    snmp	      	 = {key = "snmp", i18n_title = "prefs.snmp", section = "snmp", visible_system = true},

    -- System
    rtt_monitor_enable   = {key = "rtt_monitor_enable", i18n_title = "host_config.rtt_monitor", section = "system", is_modal = true},

    -- Status (Health)
    system_status	 = {key = "status", i18n_title = "system_status", section = "system_health", visible_system = true},
    interfaces_status	 = {key = "interfaces_status", i18n_title = "system_interfaces_status", section = "system_health", visible_system = true},

    -- Exporters
    event_exporters   	 = {key = "event_exporters", i18n_title = "event_exporters.event_exporters", section = "exporters"},
    sflow_exporters   	 = {key = "sflow_exporters", i18n_title = "flows_page.sflow_devices", section = "exporters"},
    flow_exporters   	 = {key = "flow_exporters", i18n_title = "flow_devices.exporters", section = "exporters"},

    -- Settings
    manage_users	 = {key = "manage_users", i18n_title = ternary(is_nedge, "nedge.system_users", "manage_users.manage_users"), section = "admin", visible_iface = true, visible_system = true},
    preferences	     	 = {key = "preferences", i18n_title = "prefs.preferences", section = "admin", visible_iface = true, visible_system = true},
    scripts_config	 = {key = "scripts_config", i18n_title = "about.user_scripts", section = "admin", visible_iface = true, visible_system = true},
    profiles	      	 = {key = "profiles", i18n_title = "traffic_profiles.traffic_profiles", section = "admin", visible_iface = true, visible_system = true},
    categories	      	 = {key = "categories", i18n_title = "custom_categories.apps_and_categories", section = "admin", visible_iface = true, visible_system = true},
    category_lists    	 = {key = "category_lists", i18n_title = "category_lists.category_lists", section = "admin", visible_iface = true, visible_system = true},
    device_protocols   	 = {key = "device_protocols", i18n_title = "device_protocols.device_protocols", section = "admin", visible_iface = true, visible_system = true},
    conf_backup          = {key = "conf_backup", i18n_title = "conf_backup.conf_backup", section = "admin", visible_iface = true, visible_system = true},
    conf_restore         = {key = "conf_restore", i18n_title = "conf_backup.conf_restore", section = "admin", visible_iface = true, visible_system = true},
    manage_data    	 = {key = "manage_data", i18n_title = "manage_data.manage_data", section = "admin", visible_iface = true, visible_system = false},

    -- Tools
    export_data    	 = {key = "export_data", i18n_title = "manage_data.export", section = "tools"},
    remote_assistance    = {key = "remote_assistance", i18n_title = "remote_assistance.remote_assistance", section = "tools"},

    -- Home
    live_capture   	 = {key = "live_capture", i18n_title = "live_capture.active_live_captures", section = "home"},

    -- Developer
    directories    	 = {key = "directories", i18n_title = "about.directories", section = "dev", visible_iface = true, visible_system = true},
    plugins    		 = {key = "plugins", i18n_title = "plugins", section = "dev", visible_iface = true, visible_system = true},
    user_scripts_dev 	 = {key = "user_scripts_dev", i18n_title = "about.user_scripts", section = "dev", visible_iface = true, visible_system = true},
    plugin_browser 	 = {key = "plugin_browser", i18n_title = "plugin_browser", section = "dev", visible_iface = true, visible_system = true},
    alert_definitions 	 = {key = "alert_definitions", i18n_title = "about.alert_defines", section = "dev", visible_iface = true, visible_system = true},
    api 	         = {key = "api", i18n_title = "lua_c_api", section = "dev"},

    -- Help
    about   		 = {key = "about", i18n_title = "about.about", section = "about", visible_iface = true, visible_system = true},
    telemetry    	 = {key = "telemetry", i18n_title = "telemetry", section = "about", visible_iface = true, visible_system = true},
    blog         	 = {key = "blog", i18n_title = "about.ntop_blog", section = "about"},
    telegram         	 = {key = "telegram", i18n_title = "about.telegram", section = "about"},
    report_issue         = {key = "report_issue", i18n_title = "about.report_issue", section = "about"},
    manual 	         = {key = "manual", i18n_title = "about.readme_and_manual", section = "about"},
    suggest_feature = {key = "suggest_feature", i18n_title = "about.suggest_feature", section = "about"},

    -- Just a divider for horizontal rows in the menu
    divider = {key = "divider"},

    -- nEdge
    gateways_users       = {key = "gateways_users", i18n_title = "dashboard.gateways_users", section = "dashboard"},
    nedge_flows    	 = {key = "nedge_flows", i18n_title = "flows", section = "hosts"},
    users	     	 = {key = "users", i18n_title = "users.users", section = "hosts"},
    system_setup         = {key = "system_setup", i18n_title = "nedge.system_setup", section = "system_stats"},
    dhcp_leases          = {key = "dhcp_leases", i18n_title = "nedge.dhcp_leases", section = "system_stats"},
    port_forwarding      = {key = "port_forwarding", i18n_title = "nedge.port_forwarding", section = "system_stats"},
    nedge_users          = {key = "nedge_users", i18n_title = "manage_users.manage_users", section = "system_stats"},
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

-- NOTE: this function is called by the web pages in order to
-- set the active entry and section and highlight it into the menu
function page_utils.set_active_menu_entry(entry, i18n_params, alt_title)

   active_section = entry.section
   active_entry = entry.key

   -- check if the page belong to system view
   -- or if the page belong to interface view
   -- if both flags are true then it means the page
   -- is visible in system view and interface view
   local visible_iface = entry.visible_iface or false
   local visible_system = entry.visible_system or false

   if (visible_system and visible_iface) then
      -- do nothing
   elseif (visible_system and not page_utils.is_system_view()) then
      page_utils.set_system_view(true)
   elseif (visible_iface and page_utils.is_system_view()) then
      page_utils.set_system_view(false)
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

-- #################################

-- @brief Encode the HTML entities in a string.
--        Useful when printing dissected data which may result in XSS
--        e.g., curl -u admin:admin1 "http://devel:3000/</a><script>alert(1);</script><a>"
-- @param s The string to escape.
-- @return The string with HTML entities properly escaped
function page_utils.safe_html(s)
   if not s then
      tprint(debug.traceback())
   end
   return string.gsub(s, "[}{\">/<'&]", {
			 ["&"] = "&amp;",
			 ["<"] = "&lt;",
			 [">"] = "&gt;",
			 ['"'] = "&quot;",
			 ["'"] = "&#39;",
			 ["/"] = "&#47;"
   })
end

-- #################################

function page_utils.print_header(title)
  local http_prefix = ntop.getHttpPrefix()
  local startup_epoch = ntop.getStartupEpoch()

  local theme = _POST["toggle_theme"] or ntop.getPref("ntopng.prefs.theme")

  local dark_mode = false

  if((theme == nil) or (theme == "")) then
    dark_mode = false
  end

  if (theme == "dark") then
    dark_mode = true
  end

  local page_title = i18n("welcome_to", { product=info.product })
  if title ~= nil then
    page_title = info.product .. " - " .. title
  end

  print [[<!DOCTYPE html>
<html>
  <head>
    <title>]] print(page_title) print[[</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">

    <link href="]] print(http_prefix) print[[/bootstrap-4.4.0-dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-SI27wrMjH3ZZ89r4o+fGIJtnzkAnFs3E4qz9DIYioCQ5l9Rd/7UAa8DHcaL8jkWt" crossorigin="anonymous">
    <link href="]] print(http_prefix) print[[/css/minified/ntopng.min.css?]] print(startup_epoch) print[[" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/minified/fontawesome-custom.min.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/minified/tempusdominus.min.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/minified/heatmap.min.css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/minified/rickshaw.min.css" type="text/css" rel="stylesheet">
    <link href="]] print(http_prefix) print[[/css/dc.css" rel="stylesheet">
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
    <link href="]] print(http_prefix) print[[/css/custom_theme.css?]] print(startup_epoch) print[[" rel="stylesheet">
    ]]
    if (dark_mode) then
      print[[<link href="]] print(http_prefix) print[[/css/dark-mode.css" rel="stylesheet">]]
    end
    print[[
    <!--[if lt IE 9]>
      <script src="]] print(http_prefix) print[[/js/html5shiv.js"></script>
    <![endif]-->
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/jquery_bootstrap.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/popper-1.12.9/js/popper.min.js" crossorigin="anonymous"></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/bootstrap-4.4.0-dist/js/bootstrap.min.js?]] print(startup_epoch) print[[" integrity="sha384-3qaqj0lc6sV/qpzrc1N5DC6i1VRn/HyX4qdPaiEFbn54VjQBEU341pvjz7Dv3n6P" crossorigin="anonymous"></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/deps.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/ntop.min.js?]] print(startup_epoch) print[["></script>
    <script type="text/javascript" src="]] print(http_prefix) print[[/js/tempusdominus.min.js?]] print(startup_epoch) print[["></script>
  </head>
  <body>

  ]]
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
        <link href="]] print(http_prefix) print[[/bootstrap-4.4.0-dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-SI27wrMjH3ZZ89r4o+fGIJtnzkAnFs3E4qz9DIYioCQ5l9Rd/7UAa8DHcaL8jkWt" crossorigin="anonymous">
        <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/fontawesome.css" rel="stylesheet">
        <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/brands.css" rel="stylesheet">
        <link href="]] print(http_prefix) print[[/fontawesome-free-5.11.2-web/css/solid.css" rel="stylesheet">
        <script type="text/javascript" src="]] print(http_prefix) print[[/js/jquery_bootstrap.min.js?]] print(startup_epoch) print[["></script>
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
   -- label_url: is the link for navabr-brand, the default link is #

   print[[

<nav class="navbar navbar-expand-lg navbar-light bg-light mb-4">
  <a class="navbar-brand" href="]] print((label_url and label_url or '#')) print[["><small>]] print(title) print[[</small></a>
  <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
    <span class="navbar-toggler-icon"></span>
  </button>
  <div class="collapse navbar-collapse scroll-x" id="navbarNav">
    <ul class="navbar-nav">]]

   for _, item in ipairs(items_table) do
      if not item["hidden"] then
	 local badge = ''
	 if tonumber(item["badge_num"]) and tonumber(item["badge_num"]) > 0 then
	    badge = string.format(' <span class="badge badge-pill badge-secondary" style="float:right;margin-bottom:-10px;">%u</span>', tonumber(item["badge_num"]))
	 end

	 if item["active"] then
	    print(string.format("<li class=\"nav-item active\">%s<a class=\"nav-link active\" href=\"#\">%s</a></li>", badge, item["label"]))
	 else
	    local url

	    if(not isEmptyString(item["url"])) then
		   url = item["url"]
	    else
		   url = base_url .. "&page=" .. item["page_name"]
	    end

	    print(string.format("<li class=\"nav-item\">%s<a class=\"nav-link\" href=\"%s\">%s</a></li>", badge, url, item["label"]))
	 end
      end
   end
   print[[
    </ul>
  </div>
</nav>
]]
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

function page_utils.print_menubar()
   local logo_path = nil

   if (ntop.isPro() or ntop.isnEdge()) and ntop.exists(dirs.installdir .. "/httpdocs/img/custom_logo.png") then
      logo_path = ntop.getHttpPrefix().."/img/custom_logo.png"
   end

   local navbar_style = _POST["toggle_theme"] or ntop.getPref("ntopng.prefs.theme")
   local active_page = page_utils.get_active_section()
   local active_subpage = page_utils.get_active_entry()

   if ((navbar_style == nil) or (navbar_style == "")) then
      navbar_style = "default"
   end

   if (navbar_style == "default") then
      navbar_style = "dark"
   end

   print('<div id="n-sidebar" class="bg-'.. navbar_style ..' py-0 px-2">')

   print("<h3 class='muted'><a href='"..ntop.getHttpPrefix().."/'>")	

   if (logo_path ~= nil) then
      print("<img class=\"logo-brand\" height=\"52px\" src=\""..logo_path.."\" alt='Custom Logo' />")
   else
      print(addLogoSvg())
   end


   print([[
	       </a>
	 </h3>

	 <ul class="nav-side mb-4" id='sidebar'>
]])

   for _, section in ipairs(menubar_structure) do
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
	    print[[ data-toggle="collapse" ]]
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
	    print[[<div data-parent='#sidebar' class='collapse side-collapse' id=']] print(section_id) print[['>
		  <ul class='nav flex-column'>
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

		     print[[
		   <li>
		     <a class="]]
		     if section_entry.entry and section_entry.entry.key == active_subpage then
			print("active")
		     end
		     print[[" href="]]
		     if section_entry.url:starts("http") then
			-- Absolute (external) url
			print(section_entry.url)
			external_link = true
		     else
			-- Url relative to ntopng
			print(ntop.getHttpPrefix()..section_entry.url)
		     end
		     print[["]]

		     if section_entry.entry.is_modal then
			print(' data-toggle="modal"')
		     end

		     if external_link then
			-- Open in a new page
			print(' target="_blank"')
		     end

		     print[[>]]
		     print(i18n(section_entry.entry.i18n_title) or section_entry.entry.i18n_title)
		     if external_link then
			print(" <i class='fas fa-external-link-alt'></i>")
		     end

		     print[[</a>
		   </li>
   ]]
		  end
	       end
	    end

	    print[[
		  </ul>
		</div>
   ]]

	 end
      end
   end


   print([[
     </ul>
   </div>
]])

end

-- ##############################################

function page_utils.is_system_view()
   return ((ntop.getPref("ntopng.prefs.system_mode_enabled") == "1") and isAdministrator())
end

-- ##############################################

function page_utils.set_system_view(toggle)
   local t = (toggle and "1" or "0")
   ntop.setPref("ntopng.prefs.system_mode_enabled", t)
end

-- ##############################################

return page_utils

