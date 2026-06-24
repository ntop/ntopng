--
-- (C) 2013-26 - ntop.org
--
-- Community menu definition.
-- Returns a function(f) where f is the flags table from ntopng_menu_visibility.
-- Conditions are plain Lua booleans: hidden = f.is_pcap_dump or f.no_admin
-- Pro/nEdge entries live in pro/scripts/lua/modules/menu_definition_pro.lu.
--
-- Sections with matching keys from the pro definition get their entries
-- appended to the community entries.  New pro-only sections declare
-- after = "section_key" to control where they are inserted.
--

-- NOTE: To add a new flag or check available visibility flags, update scripts/lua/modules/ntopng_menu_visibility.lua
return function(f)
    return {
    {
        key = "dashboard",
        i18n = "index_page.dashboard",
        icon = "fas fa-tachometer-alt",
        hidden = f.is_pcap_dump or f.is_system_interface or f.is_db_view_interface,
        entries = {{
            key = "traffic_dashboard",
            i18n = "dashboard.traffic_dashboard",
            icon = "fas fa-chart-area",
            url = "/lua/index.lua"
        } -- pro entries appended by menu_definition_pro: assets_dashboard, gateways_users, traffic_report, hr_chart
        }
    },
    {
        key = "monitoring",
        i18n = "monitoring",
        icon = "fas fa-eye",
        hidden = f.is_system_interface or f.no_admin,
        entries = {{
            key = "active_monitoring",
            i18n = "active_monitoring_stats.active_monitoring",
            icon = "fas fa-heartbeat",
            url = "/lua/active_monitoring.lua",
            hidden = f.is_windows
        }, {
            key = "network_discovery",
            i18n = "discover.network_discovery",
            icon = "fas fa-search",
            url = "/lua/discover.lua",
            hidden = f.no_discoverable_interface or f.is_windows or f.is_loopback_interface or f.limit_resource_usage or
                f.infrastructure_view
        }, {
            key = "vulnerability_scan",
            i18n = "scan_hosts",
            icon = "fas fa-shield-alt",
            url = "/lua/vulnerability_scan.lua",
            hidden = f.no_vs_utils or f.is_zmq_interface
        } -- pro entries appended by menu_definition_pro: infrastructure_dashboard, snmp_monitoring
        }
    },
    {
        key = "alerts",
        i18n = "details.alerts",
        icon = "fas fa-exclamation-triangle",
        hidden = f.alerts_disabled or f.no_alerts_cap or f.is_db_view_interface or f.infrastructure_view,
        entries = {{
            key = "alerts_list",
            i18n = "details.alerts_list",
            icon = "fas fa-list",
            url = "/lua/alert_stats.lua"
        }, -- pro entries appended by menu_definition_pro: alerts_graph, alerts_analysis
        {
            key = "divider",
            i18n = "menu_group.notifications",
            is_divider = true
        }, {
            key = "notifications",
            i18n = "endpoint_notifications.notifications",
            icon = "fas fa-bell",
            url = "/lua/admin/endpoint_notifications_list.lua",
            hidden = f.no_admin or f.is_pcap_dump
        }}
    },
    {
        key = "flows",
        i18n = "flows",
        icon = "fas fa-stream",
        hidden = f.is_asn_mode_enabled or f.is_system_interface or f.infrastructure_view or f.is_nedge,
        entries = {{
            key = "active_flows",
            i18n = "active_flows",
            icon = "fas fa-water",
            url = "/lua/flows_stats.lua"
        } -- pro entries appended by menu_definition_pro: db_explorer, server_ports, bgp_looking_glass
        }
    },
    {
        key = "hosts",
        i18n = "hosts",
        icon = "fas fa-laptop",
        hidden = f.is_system_interface or f.is_viewed or f.infrastructure_view or f.is_asn_mode_enabled or f.is_nedge,
        entries = {{
            key = "hosts",
            i18n = "hosts",
            icon = "fas fa-laptop",
            url = "/lua/hosts_stats.lua"
        }, {
            key = "devices",
            i18n = "layer_2",
            icon = "fas fa-hdd",
            url = "/lua/macs_stats.lua",
            hidden = f.no_macs
        } -- pro entries appended by menu_definition_pro: inventory divider + assets
        }
    },
    {
        key = "if_stats",
        i18n = "interface",
        icon = "fas fa-ethernet",
        hidden = f.is_system_interface or f.infrastructure_view,
        entries = {{
            key = "interface",
            i18n = "interface_details",
            icon = "fas fa-info-circle",
            url = "/lua/if_stats.lua"
        }, {
            key = "divider",
            i18n = "menu_group.segments",
            is_divider = true
        }, {
            key = "networks",
            i18n = "networks",
            icon = "fas fa-network-wired",
            url = "/lua/network_stats.lua",
            hidden = f.is_viewed_interface
        }, {
            key = "host_pools",
            i18n = "host_pools.host_pools",
            icon = "fas fa-layer-group",
            url = "/lua/pool_stats.lua",
            hidden = f.is_nedge
        }, {
            key = "autonomous_systems",
            i18n = "as_stats.autonomous_systems",
            icon = "fas fa-globe",
            url = "/lua/as_stats.lua",
            hidden = f.no_geoip or f.is_viewed_interface
        }, {
            key = "countries",
            i18n = "countries",
            icon = "fas fa-flag",
            url = "/lua/country_stats.lua",
            hidden = f.no_geoip or f.is_viewed_interface
        }, {
            key = "vlans",
            i18n = "vlan_stats.vlans",
            icon = "fas fa-tags",
            url = "/lua/vlan_stats.lua",
            hidden = f.no_vlans or f.is_viewed_interface
        }, {
            key = "divider",
            i18n = "menu_group.containers",
            is_divider = true
        }, {
            key = "pods",
            i18n = "pods",
            icon = "fab fa-docker",
            url = "/lua/pods_stats.lua",
            hidden = f.no_pods
        }, {
            key = "containers",
            i18n = "containers",
            icon = "fas fa-cube",
            url = "/lua/containers_stats.lua",
            hidden = f.no_containers
        }}
    },
    {
        key = "health",
        i18n = "health",
        icon = "fas fa-heartbeat",
        hidden = f.no_system_interface,
        entries = {{
            key = "system_status",
            i18n = "system_status",
            icon = "fas fa-server",
            url = "/lua/system_stats.lua"
        }, {
            key = "interfaces_status",
            i18n = "system_interfaces_status",
            icon = "fas fa-ethernet",
            url = "/lua/system_interfaces_stats.lua"
        }, {
            key = "divider",
            i18n = "menu_group.storage",
            is_divider = true
        }, {
            key = "influxdb_status",
            i18n = "InfluxDB",
            icon = "fas fa-database",
            url = "/lua/monitor/influxdb_monitor.lua",
            hidden = f.no_influxdb
        }, {
            key = "redis_status",
            i18n = "Redis",
            icon = "fas fa-memory",
            url = "/lua/monitor/redis_monitor.lua"
        } -- pro entry appended by menu_definition_pro: clickhouse_status
        }
    },
    {
        key = "admin",
        i18n = "settings",
        icon = "fas fa-cog",
        hidden = f.no_admin,
        entries = {{
            key = "divider",
            i18n = "menu_group.users",
            is_divider = true
        }, {
            key = "manage_users",
            i18n = "manage_users.manage_users",
            icon = "fas fa-user-cog",
            url = "/lua/admin/users.lua",
            hidden = f.no_local_auth_or_local_user
        }, {
            key = "divider",
            i18n = "menu_group.configuration",
            is_divider = true
        }, {
            key = "preferences",
            i18n = "prefs.preferences",
            icon = "fas fa-sliders-h",
            url = "/lua/admin/prefs.lua"
        }, {
            key = "tags",
            i18n = "tags_page.tags",
            icon = "fas fa-tag",
            url = "/lua/tags.lua"
        }, {
            key = "category_lists",
            i18n = "category_lists.category_lists",
            icon = "fas fa-list",
            url = "/lua/admin/blacklists.lua?enabled_status=enabled"
        }, {
            key = "manage_configurations",
            i18n = "manage_configurations.manage_configurations",
            icon = "fas fa-file-export",
            url = "/lua/admin/manage_configurations.lua",
            hidden = f.no_dump_cache
        }, {
            key = "divider",
            i18n = "menu_group.customization",
            is_divider = true
        }, {
            key = "categories",
            i18n = "custom_categories.apps_and_categories",
            icon = "fas fa-th-large",
            url = "/lua/admin/edit_categories.lua"
        } -- nEdge entries appended by menu_definition_pro: nedge_users, divider_nedge_admin, conf_backup, conf_restore
        }
    },
    {
        key = "dev",
        i18n = "developer",
        icon = "fas fa-code",
        hidden = f.is_oem or f.no_developer_cap or f.no_developer_menu,
        entries = {{
            key = "rest_api",
            i18n = "swagger_api",
            icon = "fas fa-plug",
            url = "/lua/swagger.lua"
        }, {
            key = "analyze_pcap",
            i18n = "upload_pcap",
            icon = "fas fa-file-upload",
            url = "/lua/upload_pcap.lua"
        }, {
            key = "manage_data",
            i18n = "manage_data.manage_data",
            icon = "fas fa-database",
            url = "/lua/manage_data.lua",
            hidden = f.no_admin
        }, {
            key = "divider",
            i18n = "menu_group.internals",
            is_divider = true
        }, {
            key = "checks_dev",
            i18n = "about.checks",
            icon = "fas fa-check-square",
            url = "/lua/checks_overview.lua"
        }, {
            key = "alert_definitions",
            i18n = "about.alert_defines",
            icon = "fas fa-exclamation-circle",
            url = "/lua/defs_overview.lua"
        }, {
            key = "ts_definitions",
            i18n = "about.ts_definitions",
            icon = "fas fa-chart-line",
            url = "/lua/ts_overview.lua"
        }, {
            key = "directories",
            i18n = "about.directories",
            icon = "fas fa-folder-open",
            url = "/lua/directories.lua"
        }, {
            key = "divider",
            i18n = "menu_group.documentation",
            is_divider = true
        }, {
            key = "api",
            i18n = "about.api_reference",
            icon = "fas fa-book-open",
            url = "https://www.ntop.org/guides/ntopng/api/",
            is_external = true
        }}
    },
    {
        key = "about",
        i18n = "help",
        icon = "fas fa-info-circle",
        hidden = f.is_oem or f.no_help_menu,
        entries = {{
            key = "about",
            i18n = "about.about",
            icon = "fas fa-info",
            url = "/lua/about.lua"
        }, {
            key = "license",
            i18n = "license_page.license",
            icon = "fas fa-id-card",
            url = "/lua/license.lua",
            hidden = f.pro_forced_community or f.no_admin
        }, {
            key = "limits",
            i18n = "limits_page.limits",
            icon = "fas fa-tachometer-alt",
            url = "/lua/limits.lua",
            hidden = f.no_admin
        }, {
            key = "divider",
            i18n = "menu_group.community",
            is_divider = true
        }, {
            key = "blog",
            i18n = "about.ntop_blog",
            icon = "fas fa-rss",
            url = "http://blog.ntop.org/",
            is_external = true
        }, {
            key = "telegram",
            i18n = "about.telegram",
            icon = "fab fa-telegram-plane",
            url = "https://t.me/ntop_community",
            is_external = true
        }, {
            key = "manual",
            i18n = "about.user_manual",
            icon = "fas fa-book",
            url = "https://www.ntop.org/guides/ntopng/",
            is_external = true
        }, {
            key = "divider",
            i18n = "menu_group.support",
            is_divider = true
        }, {
            key = "report_issue",
            i18n = "about.report_issue",
            icon = "fas fa-bug",
            url = "https://github.com/ntop/ntopng/issues",
            is_external = true
        }, {
            key = "suggest_feature",
            i18n = "about.suggest_feature",
            icon = "fas fa-lightbulb",
            url = "https://www.ntop.org/support/need-help-2/contact-us/",
            is_external = true
        }}
    }}
end
