--
-- (C) 2014-26 - ntop.org
--
-- Contains prefs menu schema and visibility flags
--
-- Redis key convention: prefix = "ntopng.prefs."
--   ntopng.prefs.<name>                    <- global preference
--   ntopng.user.__SESSION_USER__.<name>    <- per-user preference (user_pref=true)
--
local M = {}

-- Runtime flags
-- Called once per request by the REST endpoints to build the flags table that
-- controls section/entry visibility and pro write-guards.
function M.get_flags()
    local page_utils = require "page_utils"
    local recording_utils = require "recording_utils"

    local prefs = ntop.getPrefs()
    local info = ntop.getInfo(false)

    local have_nedge = ntop.isnEdge and ntop.isnEdge() or false
    local is_windows = ntop.isWindows and ntop.isWindows() or false
    local hasRadius = ntop.hasRadiusSupport and ntop.hasRadiusSupport() or false
    local hasLdap = ntop.hasLdapSupport and ntop.hasLdapSupport() or false
    local is_zmq_interface = interface.isZMQInterface and interface.isZMQInterface() or false
    local recording_available = recording_utils.isAvailable and recording_utils.isAvailable() or false

    -- License tier
    local is_pro = ntop.isPro and ntop.isPro() or false
    local is_enterprise = ntop.isEnterprise and ntop.isEnterprise() or false
    local is_enterprise_m = ntop.isEnterpriseM and ntop.isEnterpriseM() or false
    local is_enterprise_l = ntop.isEnterpriseL and ntop.isEnterpriseL() or false
    local is_enterprise_xl = ntop.isEnterpriseXL and ntop.isEnterpriseXL() or false
    local is_nedge_enterprise = ntop.isnEdgeEnterprise and ntop.isnEdgeEnterprise() or false
    local has_ch_support = (hasClickHouseSupport and hasClickHouseSupport()) and true or false
    local has_nanalyst = ntop.hasnAnalyst and ntop.hasnAnalyst() or false

    return {
        prefs = prefs,
        info = info,
        have_nedge = have_nedge,
        is_windows = is_windows,
        hasRadius = hasRadius,
        hasLdap = hasLdap,
        is_zmq_interface = is_zmq_interface,
        recording_available = recording_available,
        is_pro = is_pro,
        is_enterprise = is_enterprise,
        is_enterprise_m = is_enterprise_m,
        is_enterprise_l = is_enterprise_l,
        is_enterprise_xl = is_enterprise_xl,
        is_nedge_enterprise = is_nedge_enterprise,
        has_ch_support = has_ch_support,
        has_nanalyst = has_nanalyst
    }
end

-- Preference sections
function M.get_sections(flags)
    local prefs = flags.prefs
    local info = flags.info
    local have_nedge = flags.have_nedge
    local hasRadius = flags.hasRadius
    local hasLdap = flags.hasLdap
    local is_windows = flags.is_windows
    local is_dump_flows_enabled = prefs.is_dump_flows_enabled
    local has_cmdl_disable_alerts = prefs.has_cmdl_disable_alerts
    local has_cmdl_trace_lvl = prefs.has_cmdl_trace_lvl
    local is_users_login_enabled = prefs.is_users_login_enabled
    local active_ts_driver = ntop.getPref("ntopng.prefs.timeseries_driver") or "rrd"

    local sections =
        { -- Active Monitoring
        {
            id = "active_monitoring",
            label = i18n("active_monitoring_stats.active_monitoring"),
            advanced = false,
            pro_only = false,
            hidden = false,
            entries = {{
                key = "toggle_active_monitoring",
                title = i18n("prefs.toggle_active_monitoring_title"),
                description = i18n("prefs.toggle_active_monitoring_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.active_monitoring",
                default = "0"
            }}
        },

        -- Alerts
        {
            id = "alerts",
            label = i18n("show_alerts.alerts"),
            advanced = false,
            pro_only = false,
            hidden = (has_cmdl_disable_alerts == true),
            entries = {{
                key = "disable_alerts_generation",
                title = i18n("prefs.disable_alerts_generation_title"),
                description = i18n("prefs.disable_alerts_generation_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.disable_alerts_generation",
                default = "0",
                on_value = "0",
                off_value = "1",
                to_switch = {"toggle_emit_flow_alerts", "toggle_emit_host_alerts", "max_entity_alerts",
                             "max_num_secs_before_delete_alert", "alert_page_refresh_rate_enabled"}
            }, {
                key = "toggle_emit_flow_alerts",
                title = i18n("prefs.toggle_emit_flow_alerts_title"),
                description = i18n("prefs.toggle_emit_flow_alerts_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.emit_flow_alerts",
                default = "1",
                on_value = "1",
                off_value = "0"
            }, {
                key = "toggle_emit_host_alerts",
                title = i18n("prefs.toggle_emit_host_alerts_title"),
                description = i18n("prefs.toggle_emit_host_alerts_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.emit_host_alerts",
                default = "1",
                on_value = "1",
                off_value = "0"
            }, {
                key = "max_entity_alerts",
                title = i18n("prefs.max_entity_alerts_title"),
                description = i18n("prefs.max_entity_alerts_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.max_entity_alerts",
                default = tostring(prefs.max_entity_alerts or 1024),
                attrs = {
                    min = "1"
                }
            }, {
                key = "max_num_secs_before_delete_alert",
                title = i18n("prefs.max_num_secs_before_delete_alert_title"),
                description = i18n("prefs.max_num_secs_before_delete_alert_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.max_num_secs_before_delete_alert",
                default = tostring(math.floor((prefs.max_num_secs_before_delete_alert or 31536000) / 86400)),
                display_multiplier = 86400,
                unit = i18n("metrics.days"),
                attrs = {
                    min = "1"
                }
            }, {
                key = "alert_page_refresh_rate_enabled",
                title = i18n("prefs.enable_alerts_refresh_title"),
                description = i18n("prefs.enable_alerts_refresh_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.alert_page_refresh_rate_enabled",
                default = "0",
                to_switch = {"alert_page_refresh_rate"}
            }, {
                key = "alert_page_refresh_rate",
                title = i18n("prefs.alert_page_refresh_rate_title"),
                description = i18n("prefs.alerts_page_refresh_rate_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.alert_page_refresh_rate",
                default = tostring(prefs.alert_page_refresh_rate or 60),
                tformat = "m",
                attrs = {
                    min = "3"
                }
            }}
        },

        -- Logging
        {
            id = "logging",
            label = i18n("prefs.logging"),
            advanced = false,
            pro_only = false,
            hidden = (has_cmdl_trace_lvl == true),
            entries = {{
                key = "toggle_logging_level",
                title = i18n("prefs.toggle_logging_level_title"),
                description = i18n("prefs.toggle_logging_level_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.logging_level",
                default = "normal",
                options = {{
                    value = "trace",
                    label = "Trace"
                }, {
                    value = "debug",
                    label = "Debug"
                }, {
                    value = "info",
                    label = "Info"
                }, {
                    value = "normal",
                    label = "Normal"
                }, {
                    value = "warning",
                    label = "Warning"
                }, {
                    value = "error",
                    label = "Error"
                }}
            }, {
                key = "toggle_log_to_file",
                title = i18n("prefs.toggle_log_to_file_title"),
                description = i18n("prefs.toggle_log_to_file_description", {
                    product = info.product
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.log_to_file",
                default = "0"
            }, {
                key = "toggle_access_log",
                title = i18n("prefs.toggle_access_log_title"),
                description = i18n("prefs.toggle_access_log_description", {
                    product = info.product
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.enable_access_log",
                default = "0"
            }, {
                key = "toggle_assets_log",
                title = i18n("prefs.toggle_assets_log_title"),
                description = i18n("prefs.toggle_assets_log_description", {
                    product = info.product
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.enable_assets_log",
                default = "0",
                hidden = (not is_enterprise_m)
            }, {
                key = "toggle_host_pools_log",
                title = i18n("prefs.toggle_host_pools_log_title"),
                description = i18n("prefs.toggle_host_pools_log_description", {
                    product = info.product
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.enable_host_pools_log",
                default = "0"
            }, {
                key = "toggle_active_monitoring_log",
                title = i18n("prefs.toggle_active_monitoring_log_title"),
                description = i18n("prefs.toggle_active_monitoring_log_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.trace.active_monitoring",
                default = "0"
            }}
        },

        -- GUI
        {
            id = "gui",
            label = i18n("prefs.gui"),
            advanced = false,
            pro_only = false,
            hidden = false,
            entries = {{
                key = "toggle_autologout",
                title = i18n("prefs.toggle_autologout_title"),
                description = i18n("prefs.toggle_autologout_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.is_autologon_enabled",
                default = "1",
                section = i18n("prefs.web_user_interface"),
                hidden = not (prefs.is_autologout_enabled == true)
            }, {
                key = "toggle_theme",
                title = i18n("prefs.toggle_theme_title"),
                description = i18n("prefs.toggle_theme_description"),
                type = "button_group",
                redis_key = "ntopng.user.__SESSION_USER__.theme",
                default = "default",
                section = i18n("prefs.web_user_interface"),
                options = {{
                    value = "default",
                    label = i18n("default")
                }, {
                    value = "white",
                    label = i18n("white")
                }, {
                    value = "dark",
                    label = i18n("dark")
                }},
                user_pref = true
            }, {
                key = "toggle_date_type",
                title = i18n("prefs.toggle_date_type_title"),
                description = i18n("prefs.toggle_date_type_description"),
                type = "button_group",
                redis_key = "ntopng.user.__SESSION_USER__.date_format",
                default = "middle_endian",
                section = i18n("prefs.web_user_interface"),
                options = {{
                    value = "little_endian",
                    label = i18n("little_endian")
                }, {
                    value = "middle_endian",
                    label = i18n("middle_endian")
                }, {
                    value = "big_endian",
                    label = i18n("big_endian")
                }},
                user_pref = true
            }, {
                key = "max_ui_strlen",
                title = i18n("prefs.max_ui_strlen_title"),
                description = i18n("prefs.max_ui_strlen_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.max_ui_strlen",
                default = tostring(prefs.max_ui_strlen or 24),
                section = i18n("prefs.web_user_interface"),
                attrs = {
                    min = "3",
                    max = "128"
                }
            }, {
                key = "mgmt_acl",
                title = i18n("prefs.mgmt_acl_title"),
                description = i18n("prefs.mgmt_acl_description", {
                    product = info.product
                }),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.http_acl_management_port",
                default = "",
                section = i18n("prefs.web_user_interface"),
                attrs = {
                    maxlength = "512",
                    spellcheck = "false",
                    pattern = "((([0-9]{1,3}.){3}[0-9]{1,3}(/([0-9]|[1-2][0-9]|3[0-2]))?)(,|$))+"
                }
            }, {
                key = "toggle_interface_name_only",
                title = i18n("prefs.toggle_interface_name_only_title"),
                description = i18n("prefs.toggle_interface_name_only_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.is_interface_name_only",
                default = "0",
                section = i18n("prefs.web_user_interface")
            }, {
                key = "http_index_page",
                title = i18n("prefs.http_index_page"),
                description = i18n("prefs.http_index_page_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.http_index_page",
                default = tostring(prefs.http_index_page or ""),
                section = i18n("prefs.web_user_interface"),
                attrs = {
                    maxlength = "518",
                    spellcheck = "false",
                    pattern = "(/[A-Za-z0-9_.~!$&'()*+,;=:@%-]*)+"
                }
            }, {
                key = "toggle_menu_entry_help",
                title = i18n("prefs.toggle_menu_entry_help_title"),
                description = i18n("prefs.toggle_menu_entry_help_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.menu_entries.help",
                default = "1",
                section = i18n("prefs.menu_entries"),
                hidden = (not is_enterprise_m)
            }, {
                key = "toggle_menu_entry_developer",
                title = i18n("prefs.toggle_menu_entry_developer_title"),
                description = i18n("prefs.toggle_menu_entry_developer_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.menu_entries.developer",
                default = "1",
                section = i18n("prefs.menu_entries"),
                hidden = (not is_enterprise_m)
            }, {
                key = "toggle_search_in_all_interfaces",
                title = i18n("prefs.toggle_search_in_all_interfaces_title"),
                description = i18n("prefs.toggle_search_in_all_interfaces_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.search_in_all_interfaces",
                default = "0",
                section = i18n("prefs.search_preferences")
            }}
        },

        -- Telemetry
        {
            id = "telemetry",
            label = i18n("prefs.telemetry"),
            advanced = false,
            pro_only = false,
            hidden = false,
            entries = {{
                key = "toggle_fingerprint_stats",
                title = i18n("prefs.toggle_fingerprint_stats_title"),
                description = i18n("prefs.toggle_fingerprint_stats_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.fingerprint_stats",
                default = "0"
            }, {
                key = "toggle_sites_collection",
                title = i18n("prefs.toggle_sites_collection_title"),
                description = i18n("prefs.toggle_sites_collection_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.sites_collection",
                default = "0"
            }}
        },

        -- Notifications
        {
            id = "notifications",
            label = i18n("prefs.notifications"),
            advanced = false,
            pro_only = false,
            hidden = false,
            entries = {{
                key = "toggle_starttls",
                title = i18n("prefs.toggle_toggle_starttls_title"),
                description = i18n("prefs.toggle_toggle_starttls_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.starttls",
                default = "1"
            }}
        },

        -- Network Discovery
        {
            id = "discovery",
            label = i18n("prefs.network_discovery"),
            advanced = false,
            pro_only = false,
            hidden = false,
            entries = {{
                key = "toggle_network_discovery",
                title = i18n("active_monitoring_stats.network_discovery"),
                description = i18n("active_monitoring_stats.network_discovery_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.network_discovery",
                default = "0",
                to_switch = {"toggle_periodic_network_discovery", "toggle_network_discovery_debug"}
            }, {
                key = "toggle_periodic_network_discovery",
                title = i18n("prefs.toggle_network_discovery_title"),
                description = i18n("prefs.toggle_network_discovery_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.is_periodic_network_discovery_enabled",
                default = "0",
                to_switch = {"network_discovery_interval"}
            }, {
                key = "network_discovery_interval",
                title = i18n("prefs.network_discovery_interval_title"),
                description = i18n("prefs.network_discovery_interval_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.network_discovery_interval",
                default = tostring(15 * 60),
                tformat = "mhd",
                attrs = {
                    min = tostring(15 * 60)
                }
            }, {
                key = "toggle_network_discovery_debug",
                title = i18n("prefs.toggle_network_discovery_debug_title"),
                description = i18n("prefs.toggle_network_discovery_debug_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.network_discovery_debug",
                default = "0"
            }}
        },

        -- Names
        {
            id = "names",
            label = i18n("prefs.names"),
            advanced = false,
            pro_only = false,
            hidden = false,
            entries = (function()
                local host_info = ntop.getHostInformation() or {}
                return {{
                    key = "ntopng_host_address",
                    title = i18n("prefs.ntopng_host_address_title"),
                    description = i18n("prefs.ntopng_host_address_description"),
                    type = "input",
                    input_type = "text",
                    redis_key = "ntopng.prefs.ntopng_host_address",
                    default = host_info.ip or "",
                    attrs = {
                        spellcheck = "false"
                    }
                }, {
                    key = "ntopng_instance_name",
                    title = i18n("prefs.ntopng_instance_name_title"),
                    description = i18n("prefs.ntopng_instance_name_description"),
                    type = "input",
                    input_type = "text",
                    redis_key = "ntopng.prefs.ntopng_instance_name",
                    default = host_info.instance_name or "",
                    attrs = {
                        spellcheck = "false"
                    }
                }}
            end)()
        },

        -- Misc
        {
            id = "misc",
            label = i18n("prefs.misc"),
            advanced = false,
            pro_only = false,
            hidden = false,
            entries = {{
                key = "connectivity_check_url",
                title = i18n("prefs.connectivity_check_url_title"),
                description = i18n("prefs.connectivity_check_url_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.connectivity_check_url",
                default = "",
                section = i18n("prefs.connectivity_check"),
                attrs = {
                    spellcheck = "false"
                }
            }, {
                key = "domain_classification_token",
                title = i18n("prefs.domain_classification_token_title"),
                description = i18n("prefs.domain_classification_token_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.classification_user_token",
                default = "",
                section = i18n("prefs.connectivity_check"),
                attrs = {
                    spellcheck = "false"
                }
            }, {
                key = "toggle_thpt_content",
                title = i18n("prefs.toggle_thpt_content_title"),
                description = i18n("prefs.toggle_thpt_content_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.thpt_content",
                default = "bps",
                section = i18n("prefs.report"),
                options = {{
                    value = "bps",
                    label = i18n("bytes")
                }, {
                    value = "pps",
                    label = i18n("packets")
                }}
            }, {
                key = "topk_heuristic_precision",
                title = i18n("prefs.topk_heuristic_precision_title"),
                description = i18n("prefs.topk_heuristic_precision_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.topk_heuristic_precision",
                default = "more_accurate",
                section = i18n("prefs.report"),
                hidden = (not is_pro),
                options = {{
                    value = "disabled",
                    label = i18n("topk_heuristic.precision.disabled")
                }, {
                    value = "more_accurate",
                    label = i18n("topk_heuristic.precision.more_accurate")
                }, {
                    value = "accurate",
                    label = i18n("topk_heuristic.precision.less_accurate")
                }, {
                    value = "aggressive",
                    label = i18n("topk_heuristic.precision.aggressive")
                }}
            }, {
                key = "toggle_host_mask",
                title = i18n("prefs.toggle_host_mask_title"),
                description = i18n("prefs.toggle_host_mask_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.host_mask",
                default = "0",
                section = i18n("hosts"),
                hidden = (not is_admin),
                options = {{
                    value = "0",
                    label = i18n("prefs.no_host_mask")
                }, {
                    value = "1",
                    label = i18n("prefs.local_host_mask")
                }, {
                    value = "2",
                    label = i18n("prefs.remote_host_mask")
                }}
            }, {
                key = "toggle_use_mac_in_flow_key",
                title = i18n("prefs.toggle_use_mac_in_flow_key_title"),
                description = i18n("prefs.toggle_use_mac_in_flow_key_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.use_mac_in_flow_key",
                default = "0",
                section = i18n("hosts"),
                hidden = (not is_admin) or have_nedge
            }, {
                key = "toggle_use_host_pools_for_local",
                title = i18n("prefs.toggle_use_host_pools_for_local_title"),
                description = i18n("prefs.toggle_use_host_pools_for_local_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.use_host_pools_for_local",
                default = "0",
                section = i18n("hosts"),
                hidden = (not is_admin)
            }, {
                key = "toggle_enable_full_stats",
                title = i18n("prefs.toggle_enable_full_stats"),
                description = i18n("prefs.toggle_enable_full_stats_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.enable_full_stats",
                default = "1",
                section = i18n("prefs.flow_table")
            }, {
                key = "toggle_flow_begin",
                title = i18n("prefs.flow_table_begin_epoch_title"),
                description = i18n("prefs.flow_table_begin_epoch_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.first_seen_set",
                default = "0",
                section = i18n("prefs.flow_table")
            }, {
                key = "flow_table_time",
                title = i18n("prefs.flow_table_time_title"),
                description = i18n("prefs.flow_table_time_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.flow_table_time",
                default = "0",
                section = i18n("prefs.flow_table"),
                options = {{
                    value = "0",
                    label = i18n("prefs.duration")
                }, {
                    value = "1",
                    label = i18n("prefs.last_seen")
                }}
            }, {
                key = "flow_table_probe_order",
                title = i18n("prefs.flow_table_probe_order_title"),
                description = i18n("prefs.flow_table_probe_order_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.flow_table_probe_order",
                default = "0",
                section = i18n("prefs.flow_table"),
                options = {{
                    value = "0",
                    label = i18n("prefs.ip_order")
                }, {
                    value = "1",
                    label = i18n("prefs.name_order")
                }}
            }}
        },

        -- Updates
        {
            id = "updates",
            label = i18n("prefs.updates"),
            advanced = false,
            pro_only = false,
            hidden = (is_windows or (not ntop.isPackage())),
            entries = {{
                key = "toggle_autoupdates",
                title = i18n("prefs.toggle_autoupdates_title"),
                description = i18n("prefs.toggle_autoupdates_description", {
                    product = info.product
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.is_autoupdates_enabled",
                default = "0"
            }}
        },

        -- Authentication
        {
            id = "auth",
            label = i18n("prefs.user_authentication"),
            advanced = false,
            pro_only = false,
            hidden = (not is_users_login_enabled and not have_nedge),
            entries = {
                -- Authentication Duration
                {
                key = "authentication_duration",
                title = i18n("prefs.authentication_duration_title"),
                description = i18n("prefs.authentication_duration_descr"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.auth_session_duration",
                default = tostring(prefs.auth_session_duration or 3600),
                tformat = "mhd",
                attrs = {
                    min = "60",
                    max = tostring(86400 * 7)
                }
            }, {
                key = "toggle_auth_session_midnight_expiration",
                title = i18n("prefs.authentication_midnight_expiration_title"),
                description = i18n("prefs.authentication_midnight_expiration_descr"),
                type = "toggle",
                redis_key = "ntopng.prefs.auth_session_midnight_expiration",
                default = "0"
            }, -- OIDC (OpenID Connect SSO)
            {
                key = "toggle_oidc_auth",
                title = i18n("prefs.toggle_oidc_auth"),
                description = i18n("prefs.toggle_oidc_auth_descr"),
                type = "toggle",
                redis_key = "ntopng.prefs.oidc.enabled",
                default = "0",
                section = i18n("prefs.oidc_auth"),
                to_switch = {"oidc_issuer_url", "oidc_client_id", "oidc_client_secret", "oidc_base_redirect_uri",
                             "oidc_scopes", "oidc_group_claim", "oidc_admin_group", "toggle_oidc_auto_create_users",
                             "oidc_claim_ifname", "oidc_claim_nets", "oidc_claim_host_pools", "oidc_claim_allow_pcap",
                             "oidc_claim_allow_historical", "oidc_claim_allow_alerts"}
            }, {
                key = "oidc_issuer_url",
                title = i18n("prefs.oidc_issuer_url_title"),
                description = i18n("prefs.oidc_issuer_url_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.oidc_issuer_url",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "512"
                }
            }, {
                key = "oidc_client_id",
                title = i18n("prefs.oidc_client_id_title"),
                description = i18n("prefs.oidc_client_id_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.oidc_client_id",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "oidc_client_secret",
                title = i18n("prefs.oidc_client_secret_title"),
                description = i18n("prefs.oidc_client_secret_description"),
                type = "input",
                input_type = "password",
                redis_key = "ntopng.prefs.oidc.oidc_client_secret",
                default = "",
                password = true,
                attrs = {
                    spellcheck = "false",
                    maxlength = "512"
                }
            }, {
                key = "oidc_base_redirect_uri",
                title = i18n("prefs.oidc_base_redirect_uri_title"),
                description = i18n("prefs.oidc_base_redirect_uri_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.oidc_base_redirect_uri",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "512"
                }
            }, {
                key = "oidc_scopes",
                title = i18n("prefs.oidc_scopes_title"),
                description = i18n("prefs.oidc_scopes_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.oidc_scopes",
                default = "openid profile email roles",
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "oidc_group_claim",
                title = i18n("prefs.oidc_group_claim_title"),
                description = i18n("prefs.oidc_group_claim_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.oidc_group_claim",
                default = "groups",
                attrs = {
                    spellcheck = "false",
                    maxlength = "128"
                }
            }, {
                key = "oidc_admin_group",
                title = i18n("prefs.oidc_admin_group_title"),
                description = i18n("prefs.oidc_admin_group_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.oidc_admin_group",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "toggle_oidc_auto_create_users",
                title = i18n("prefs.toggle_oidc_auto_create_users_title"),
                description = i18n("prefs.toggle_oidc_auto_create_users_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.oidc.oidc_auto_create_users",
                default = "0"
            }, {
                key = "oidc_claim_ifname",
                title = i18n("prefs.oidc_claim_ifname_title"),
                description = i18n("prefs.oidc_claim_ifname_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.claim_ifname",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "128"
                }
            }, {
                key = "oidc_claim_nets",
                title = i18n("prefs.oidc_claim_nets_title"),
                description = i18n("prefs.oidc_claim_nets_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.claim_nets",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "128"
                }
            }, {
                key = "oidc_claim_host_pools",
                title = i18n("prefs.oidc_claim_host_pools_title"),
                description = i18n("prefs.oidc_claim_host_pools_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.claim_host_pools",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "128"
                }
            }, {
                key = "oidc_claim_allow_pcap",
                title = i18n("prefs.oidc_claim_allow_pcap_title"),
                description = i18n("prefs.oidc_claim_allow_pcap_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.claim_allow_pcap",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "128"
                }
            }, {
                key = "oidc_claim_allow_historical",
                title = i18n("prefs.oidc_claim_allow_historical_title"),
                description = i18n("prefs.oidc_claim_allow_historical_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.claim_allow_historical",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "128"
                }
            }, {
                key = "oidc_claim_allow_alerts",
                title = i18n("prefs.oidc_claim_allow_alerts_title"),
                description = i18n("prefs.oidc_claim_allow_alerts_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.oidc.claim_allow_alerts",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "128"
                }
            }, -- x509 (HTTPS Client Authentication)
            {
                key = "toggle_client_x509_auth",
                title = i18n("prefs.client_x509_auth_title", {
                    product = info.product
                }),
                description = i18n("prefs.client_x509_auth_descr", {
                    product = info.product
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.is_client_x509_auth_enabled",
                default = "0",
                section = i18n("prefs.x509_auth")
            }, -- LDAP auth
            {
                key = "toggle_ldap_auth",
                title = i18n("prefs.toggle_ldap_auth"),
                description = i18n("prefs.toggle_ldap_auth_descr"),
                type = "toggle",
                redis_key = "ntopng.prefs.ldap.auth_enabled",
                default = "0",
                hidden = (not hasLdap),
                section = i18n("prefs.ldap_authentication"),
                to_switch = {"multiple_ldap_account_type", "ldap_server_address", "toggle_ldap_anonymous_bind",
                             "bind_dn", "bind_pwd", "search_path", "admin_group", "user_group",
                             "toggle_ldap_ext_user_cap", "toggle_ldap_referrals", "toggle_ldap_debug"}
            }, {
                key = "multiple_ldap_account_type",
                title = i18n("prefs.multiple_ldap_account_type_title"),
                description = i18n("prefs.multiple_ldap_account_type_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.ldap.account_type",
                default = "posix",
                hidden = (not hasLdap),
                options = {{
                    value = "posix",
                    label = i18n("prefs.posix")
                }, {
                    value = "samaccount",
                    label = i18n("prefs.samaccount")
                }}
            }, {
                key = "ldap_server_address",
                title = i18n("prefs.ldap_server_address_title"),
                description = i18n("prefs.ldap_server_address_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.ldap.ldap_server_address",
                default = "ldap://localhost:389",
                hidden = (not hasLdap),
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "toggle_ldap_anonymous_bind",
                title = i18n("prefs.toggle_ldap_anonymous_bind_title"),
                description = i18n("prefs.toggle_ldap_anonymous_bind_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.ldap.anonymous_bind",
                default = "1",
                hidden = (not hasLdap),
                reverse_switch = true,
                to_switch = {"bind_dn", "bind_pwd"}
            }, {
                key = "bind_dn",
                title = i18n("prefs.bind_dn_title"),
                description = i18n("prefs.bind_dn_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.ldap.bind_dn",
                default = "",
                hidden = (not hasLdap),
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "bind_pwd",
                title = i18n("prefs.bind_pwd_title"),
                description = i18n("prefs.bind_pwd_description"),
                type = "input",
                input_type = "password",
                redis_key = "ntopng.prefs.ldap.bind_pwd",
                default = "",
                hidden = (not hasLdap),
                password = true,
                attrs = {
                    maxlength = "255"
                }
            }, {
                key = "search_path",
                title = i18n("prefs.search_path_title"),
                description = i18n("prefs.search_path_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.ldap.search_path",
                default = "",
                hidden = (not hasLdap),
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "admin_group",
                title = i18n("prefs.admin_group_title"),
                description = i18n("prefs.admin_group_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.ldap.admin_group",
                default = "",
                hidden = (not hasLdap),
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "user_group",
                title = i18n("prefs.user_group_title"),
                description = i18n("prefs.user_group_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.ldap.user_group",
                default = "",
                hidden = (not hasLdap),
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "toggle_ldap_ext_user_cap",
                title = i18n("prefs.toggle_ldap_ext_user_cap_title"),
                description = i18n("prefs.toggle_ldap_ext_user_cap_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.ldap.ext_user_cap",
                default = "0",
                hidden = (not hasLdap)
            }, {
                key = "toggle_ldap_referrals",
                title = i18n("prefs.toggle_ldap_referrals_title"),
                description = i18n("prefs.toggle_ldap_referrals_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.ldap.follow_referrals",
                default = "1",
                hidden = (not hasLdap)
            }, {
                key = "toggle_ldap_debug",
                title = i18n("prefs.toggle_ldap_debug_title"),
                description = i18n("prefs.toggle_ldap_debug_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.ldap_debug",
                default = "0",
                hidden = (not hasLdap)
            }, -- RADIUS auth
            {
                key = "toggle_radius_auth",
                title = i18n("prefs.toggle_radius_auth"),
                description = i18n("prefs.toggle_radius_auth_descr", {
                    product = info.product
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.radius.auth_enabled",
                default = "0",
                hidden = (not hasRadius),
                section = i18n("prefs.radius_auth"),
                to_switch = {"radius_server", "radius_secret", "radius_auth_proto", "radius_admin_group",
                             "radius_unpriv_capabilties_group", "toggle_radius_external_auth_for_local_users",
                             "toggle_radius_accounting", "radius_accounting_server"}
            }, {
                key = "radius_server",
                title = i18n("prefs.radius_server_title"),
                description = i18n("prefs.radius_server_description", {
                    example = "127.0.0.1:1812"
                }),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.radius.radius_server_address",
                default = "127.0.0.1:1812",
                hidden = (not hasRadius),
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "radius_secret",
                title = i18n("prefs.radius_secret_title"),
                description = i18n("prefs.radius_secret_descroption"),
                type = "input",
                input_type = "password",
                redis_key = "ntopng.prefs.radius.radius_secret",
                default = "",
                hidden = (not hasRadius),
                password = true,
                attrs = {
                    spellcheck = "false",
                    maxlength = "48"
                }
            }, {
                key = "radius_auth_proto",
                title = i18n("prefs.radius_auth_proto_title"),
                description = i18n("prefs.radius_auth_proto_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.radius.radius_auth_proto",
                default = "pap",
                hidden = (not hasRadius),
                options = {{
                    value = "pap",
                    label = i18n("prefs.pap")
                }, {
                    value = "chap",
                    label = i18n("prefs.chap")
                }}
            }, {
                key = "toggle_radius_external_auth_for_local_users",
                title = i18n("prefs.toggle_radius_external_auth_for_local_users"),
                description = i18n("prefs.toggle_radius_external_auth_for_local_users_descr", {
                    product = info.product
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.radius.external_auth_for_local_users_enabled",
                default = "0",
                hidden = (not hasRadius or not have_nedge),
                reverse_switch = true,
                to_switch = {"radius_admin_group", "radius_unpriv_capabilties_group"}
            }, {
                key = "radius_admin_group",
                title = i18n("prefs.radius_admin_group_title"),
                description = i18n("prefs.radius_admin_group_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.radius.radius_admin_group",
                default = "",
                hidden = (not hasRadius),
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "radius_unpriv_capabilties_group",
                title = i18n("prefs.radius_unpriv_capabilties_group_title"),
                description = i18n("prefs.radius_unpriv_capabilties_group_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.radius.radius_unpriv_capabilties_group",
                default = "",
                hidden = (not hasRadius),
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "toggle_radius_accounting",
                title = i18n("prefs.toggle_radius_accounting"),
                description = i18n("prefs.toggle_radius_accounting_descr", {
                    product = info.product
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.radius.accounting_enabled",
                default = "0",
                hidden = (not hasRadius or not have_nedge),
                to_switch = {"radius_accounting_server"}
            }, {
                key = "radius_accounting_server",
                title = i18n("prefs.radius_accounting_server_title"),
                description = i18n("prefs.radius_accounting_server_description", {
                    example = "127.0.0.1:1813"
                }),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.radius.radius_acct_server_address",
                default = "127.0.0.1:1813",
                hidden = (not hasRadius or not have_nedge),
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, -- HTTP auth
            {
                key = "toggle_http_auth",
                title = i18n("prefs.toggle_http_auth"),
                description = i18n("prefs.toggle_http_auth_descr"),
                type = "toggle",
                redis_key = "ntopng.prefs.http_authenticator.auth_enabled",
                default = "0",
                hidden = have_nedge,
                section = i18n("prefs.http_auth"),
                to_switch = {"http_auth_server"}
            }, {
                key = "http_auth_server",
                title = i18n("prefs.http_auth_server_title"),
                description = i18n("prefs.http_auth_server_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.http_authenticator.http_auth_url",
                default = "",
                hidden = have_nedge,
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, -- Local auth
            {
                key = "toggle_local_auth",
                title = i18n("prefs.toggle_local_auth"),
                description = i18n("prefs.toggle_local_auth_descr", {
                    product = info.product
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.local.auth_enabled",
                default = "1",
                section = i18n("prefs.local_auth")
            }}
        },

        -- Timeseries
        {
            id = "on_disk_ts",
            label = i18n("prefs.timeseries"),
            advanced = false,
            pro_only = false,
            hidden = false,
            entries = {
                -- Timeseries Database
                {
                key = "multiple_timeseries_database",
                title = i18n("prefs.multiple_timeseries_database_title"),
                description = i18n("prefs.multiple_timeseries_database_description"),
                type = "select",
                redis_key = "ntopng.prefs.timeseries_driver",
                default = "rrd",
                section = i18n("prefs.timeseries_database"),
                options = {{
                    value = "rrd",
                    label = "RRD"
                }, {
                    value = "influxdb",
                    label = "InfluxDB 1.x/2.x"
                }, {
                    value = "clickhouse",
                    label = "ClickHouse"
                }},
                to_switch = {"influxdb_url", "influxdb_dbname", "toggle_influx_auth", "influxdb_username",
                             "influxdb_password", "influxdb_query_timeout"},
                when_value_download = {
                    value    = "clickhouse",
                    url      = ntop.getHttpPrefix() .. "/misc/grafana/ntopng-clickhouse-dashboard.json",
                    filename = "ntopng-clickhouse-dashboard.json",
                    label    = i18n("prefs.clickhouse_ts_grafana_dashboard_btn")
                }
            }, {
                key = "influxdb_url",
                title = i18n("prefs.influxdb_url_title"),
                description = i18n("prefs.influxdb_url_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.ts_post_data_url",
                default = "http://localhost:8086",
                test_endpoint = "/lua/rest/v2/get/ntopng/test_url_connectivity.lua",
                attrs = {
                    spellcheck = "false",
                    maxlength = "255"
                }
            }, {
                key = "influxdb_dbname",
                title = i18n("prefs.influxdb_dbname_title"),
                description = i18n("prefs.influxdb_dbname_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.influx_dbname",
                default = "ntopng",
                attrs = {
                    spellcheck = "false",
                    maxlength = "64"
                }
            }, {
                key = "toggle_influx_auth",
                title = i18n("prefs.influxdb_auth_title"),
                description = i18n("prefs.influxdb_auth_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.influx_auth_enabled",
                default = "0",
                to_switch = {"influxdb_username", "influxdb_password"}
            }, {
                key = "influxdb_username",
                title = i18n("login.username"),
                description = i18n("prefs.influxdb_username_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.influx_username",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "64"
                }
            }, {
                key = "influxdb_password",
                title = i18n("login.password"),
                description = i18n("prefs.influxdb_password_description"),
                type = "input",
                input_type = "password",
                redis_key = "ntopng.prefs.influx_password",
                default = "",
                password = true,
                attrs = {
                    maxlength = "64"
                }
            }, {
                key = "timeseries_resolution_resolution",
                title = i18n("prefs.timeseries_resolution_resolution_title"),
                description = i18n("prefs.timeseries_resolution_resolution_description_2"),
                type = "button_group",
                redis_key = "ntopng.prefs.ts_resolution",
                default = "300",
                options = {{
                    value = "60",
                    label = "1m"
                }, {
                    value = "300",
                    label = "5m"
                }}
            }, {
                key = "influxdb_query_timeout",
                title = i18n("prefs.influxdb_query_timeout_title"),
                description = i18n("prefs.influxdb_query_timeout_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.influx_query_timeout",
                default = "10",
                attrs = {
                    min = "1"
                }
            }, {
                key = "ts_data_retention",
                title = i18n("prefs.ts_and_stats_data_retention"),
                description = i18n("prefs.ts_and_stats_data_retention_descr"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.ts_and_stats_data_retention_days",
                default = "30",
                attrs = {
                    min = "1",
                    max = tostring(365 * 10)
                }
            }, -- Interfaces Timeseries
                {
                key = "toggle_interface_traffic_rrd_creation",
                title = i18n("prefs.toggle_traffic_rrd_creation_title"),
                description = i18n("prefs.toggle_traffic_rrd_creation_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.interface_rrd_creation",
                default = "1",
                section = i18n("prefs.interfaces_timeseries"),
                to_switch = {"toggle_interface_ndpi_timeseries_creation"}
            }, {
                key = "toggle_interface_ndpi_timeseries_creation",
                title = i18n("prefs.toggle_ndpi_timeseries_creation_title"),
                description = i18n("prefs.toggle_ndpi_timeseries_creation_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.interface_ndpi_timeseries_creation",
                default = "per_protocol",
                options = {{
                    value = "none",
                    label = i18n("prefs.none")
                }, {
                    value = "per_protocol",
                    label = i18n("prefs.per_protocol")
                }, {
                    value = "per_category",
                    label = i18n("prefs.per_category")
                }, {
                    value = "both",
                    label = i18n("prefs.per_protocol") .. " + " .. i18n("prefs.per_category")
                }}
            }, {
                key = "toggle_split_ts_direction",
                title = i18n("prefs.toggle_split_ts_direction_title"),
                description = i18n("prefs.toggle_split_ts_direction_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.split_ts_direction",
                default = "total",
                options = {{
                    value = "total",
                    label = i18n("total")
                }, {
                    value = "rx_tx",
                    label = i18n("prefs.rx_tx")
                }}
            },
                -- Local Hosts Timeseries
                {
                key = "toggle_local_hosts_ts_creation",
                title = i18n("prefs.toggle_local_hosts_ts_creation_title"),
                description = i18n("prefs.toggle_local_hosts_ts_creation_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.hosts_ts_creation",
                default = "light",
                section = i18n("prefs.local_hosts_timeseries"),
                options = {{
                    value = "off",
                    label = i18n("off")
                }, {
                    value = "light",
                    label = i18n("prefs.light")
                }, {
                    value = "full",
                    label = i18n("prefs.full")
                }}
            }, {
                key = "toggle_local_hosts_one_way_ts",
                title = i18n("prefs.toggle_local_hosts_one_way_ts_title"),
                description = i18n("prefs.toggle_local_hosts_one_way_ts_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.hosts_one_way_traffic_rrd_creation",
                default = "0"
            }, {
                key = "hosts_ndpi_timeseries_creation",
                title = i18n("prefs.toggle_ndpi_timeseries_creation_title"),
                description = i18n("prefs.toggle_ndpi_timeseries_creation_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.host_ndpi_timeseries_creation",
                default = "none",
                options = {{
                    value = "none",
                    label = i18n("prefs.none")
                }, {
                    value = "per_protocol",
                    label = i18n("prefs.per_protocol")
                }, {
                    value = "per_category",
                    label = i18n("prefs.per_category")
                }, {
                    value = "both",
                    label = i18n("prefs.per_protocol") .. " + " .. i18n("prefs.per_category")
                }}
            },
                -- MAC Addresses Timeseries
                {
                key = "toggle_l2_devices_traffic_rrd_creation",
                title = i18n("prefs.toggle_l2_devices_traffic_rrd_creation_title"),
                description = i18n("prefs.toggle_l2_devices_traffic_rrd_creation_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.l2_device_rrd_creation",
                default = "0",
                section = i18n("prefs.mac_addresses_timeseries"),
                to_switch = {"l2_device_ndpi_timeseries_creation"}
            }, {
                key = "l2_device_ndpi_timeseries_creation",
                title = i18n("prefs.toggle_ndpi_timeseries_creation_title"),
                description = i18n("prefs.toggle_ndpi_timeseries_creation_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.l2_device_ndpi_timeseries_creation",
                default = "none",
                options = {{
                    value = "none",
                    label = i18n("prefs.none")
                }, {
                    value = "per_category",
                    label = i18n("prefs.per_category")
                }}
            },
                -- Flow Exporter Timeseries
                {
                key = "toggle_flow_rrds",
                title = i18n("prefs.toggle_flow_rrds_title"),
                description = i18n("prefs.toggle_flow_rrds_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.flow_device_port_rrd_creation",
                default = "0",
                section = i18n("prefs.flow_exporter_timeseries")
            }, {
                key = "toggle_exporters_ndpi_ts_creation",
                title = i18n("prefs.toggle_exporters_ndpi_ts_creation_title"),
                description = i18n("prefs.toggle_exporters_ndpi_ts_creation_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.exporters_ndpi_ts_creation",
                default = "none",
                options = {{
                    value = "none",
                    label = i18n("prefs.none")
                }, {
                    value = "per_protocol",
                    label = i18n("prefs.per_protocol")
                }}
            }, {
                key = "toggle_flow_rrds_resolution",
                title = i18n("prefs.toggle_flow_rrds_resolution_title"),
                description = i18n("prefs.toggle_flow_rrds_resolution_description"),
                type = "button_group",
                redis_key = "ntopng.prefs.exporters_ts_resolution",
                default = "300",
                options = {{
                    value = "60",
                    label = "1m"
                }, {
                    value = "300",
                    label = "5m"
                }}
            }, {
                key = "toggle_interface_usage_probes_timeseries",
                title = i18n("prefs.toggle_exporter_interface_usage_timeseries_title"),
                description = i18n("prefs.toggle_exporter_interface_usage_timeseries_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.interface_usage_probes_timeseries",
                default = "1"
            },
                -- System Timeseries
                {
                key = "toggle_system_probes_timeseries",
                title = i18n("prefs.toggle_system_probes_timeseries_title"),
                description = i18n("prefs.toggle_system_probes_timeseries_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.system_probes_timeseries",
                default = "1",
                section = i18n("prefs.system_timeseries")
            },
                -- Other Timeseries
                {
                key = "toggle_intranet_traffic_rrd_creation",
                title = i18n("prefs.toggle_intranet_traffic_rrds_title"),
                description = i18n("prefs.toggle_intranet_traffic_rrds_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.intranet_traffic_rrd_creation",
                default = "0",
                section = i18n("prefs.other_timeseries"),
                hidden = (not is_pro)
            }, {
                key = "toggle_observation_points_rrd_creation",
                title = i18n("prefs.toggle_observation_points_rrds_title"),
                description = i18n("prefs.toggle_observation_points_rrds_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.observation_points_rrd_creation",
                default = "0",
                hidden = (not is_pro)
            }, {
                key = "toggle_pools_rrds",
                title = i18n(have_nedge and "prefs.toggle_users_rrds_title" or "prefs.toggle_pools_rrds_title"),
                description = i18n(have_nedge and "prefs.toggle_users_rrds_description" or
                                       "prefs.toggle_pools_rrds_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.host_pools_rrd_creation",
                default = "0",
                hidden = (not is_pro)
            }, {
                key = "toggle_vlan_rrds",
                title = i18n("prefs.toggle_vlan_rrds_title"),
                description = i18n("prefs.toggle_vlan_rrds_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.vlan_rrd_creation",
                default = "0"
            }, {
                key = "toggle_asn_rrds",
                title = i18n("prefs.toggle_asn_rrds_title"),
                description = i18n("prefs.toggle_asn_rrds_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.asn_rrd_creation",
                default = "0"
            }, {
                key = "toggle_country_rrds",
                title = i18n("prefs.toggle_country_rrds_title"),
                description = i18n("prefs.toggle_country_rrds_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.country_rrd_creation",
                default = "0"
            }, {
                key = "toggle_ndpi_flows_rrds",
                title = i18n("prefs.toggle_ndpi_flows_rrds_title"),
                description = i18n("prefs.toggle_ndpi_flows_rrds_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.ndpi_flows_rrd_creation",
                default = "0",
                hidden = (not is_pro)
            }, {
                key = "toggle_internals_rrds",
                title = i18n("prefs.toggle_internals_rrds_title"),
                description = i18n("prefs.toggle_internals_rrds_description", {
                    url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=internals"
                }),
                type = "toggle",
                redis_key = "ntopng.prefs.internals_rrd_creation",
                default = "0"
            }, {
                key = "toggle_os_rrds",
                title = i18n("prefs.toggle_os_rrds_title"),
                description = i18n("prefs.toggle_os_rrds_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.os_rrd_creation",
                default = "0"
            }}
        },

        -- In Memory Cache
        {
            id = "in_memory",
            label = i18n("prefs.cache_settings"),
            advanced = true,
            pro_only = false,
            hidden = false,
            entries = {
                -- Stats Reset
                {
                key = "toggle_midnight_stats_reset",
                title = i18n("prefs.toggle_midnight_stats_reset_title"),
                description = i18n("prefs.toggle_midnight_stats_reset_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.midnight_stats_reset_enabled",
                default = "0",
                section = i18n("prefs.stats_reset")
            },
                -- Local Hosts Cache Settings
                {
                key = "toggle_local_host_cache_enabled",
                title = i18n("prefs.toggle_local_host_cache_enabled_title"),
                description = i18n("prefs.toggle_local_host_cache_enabled_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.is_local_host_cache_enabled",
                default = "1",
                section = i18n("prefs.local_hosts_cache_settings"),
                to_switch = {"local_host_cache_duration", "toggle_active_local_host_cache_enabled",
                             "active_local_host_cache_interval"}
            }, {
                key = "local_host_cache_duration",
                title = i18n("prefs.local_host_cache_duration_title"),
                description = i18n("prefs.local_host_cache_duration_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.local_host_cache_duration",
                default = "3600",
                tformat = "mhd",
                attrs = {
                    min = "60"
                }
            }, {
                key = "toggle_active_local_host_cache_enabled",
                title = i18n("prefs.toggle_active_local_host_cache_enabled_title"),
                description = i18n("prefs.toggle_active_local_host_cache_enabled_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.is_active_local_host_cache_enabled",
                default = "0",
                to_switch = {"active_local_host_cache_interval"}
            }, {
                key = "active_local_host_cache_interval",
                title = i18n("prefs.active_local_host_cache_interval_title"),
                description = i18n("prefs.active_local_host_cache_interval_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.active_local_host_cache_interval",
                default = "3600",
                tformat = "mhd",
                attrs = {
                    min = "60"
                }
            },
                -- Flow Cache Settings
                {
                key = "toggle_flow_swap_heuristic",
                title = i18n("prefs.toggle_flow_swap_heuristic"),
                description = i18n("prefs.toggle_flow_swap_heuristic_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.enable_flow_swap_heuristic",
                default = "1",
                section = i18n("prefs.flow_cache_settings")
            }, {
                key = "toggle_skip_dpi_for_collected_flows",
                title = i18n("prefs.toggle_skip_dpi_for_collected_flows"),
                description = i18n("prefs.toggle_skip_dpi_for_collected_flows_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.skip_dpi_for_collected_flows",
                default = "0"
            },
                -- Idle Timeout Settings
                {
                key = "flow_max_idle",
                title = i18n("prefs.flow_max_idle_title"),
                description = i18n("prefs.flow_max_idle_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.flow_max_idle",
                default = "60",
                tformat = "smh",
                section = i18n("prefs.idle_timeout_settings"),
                attrs = {
                    min = "1",
                    max = "3600"
                }
            }, {
                key = "local_host_max_idle",
                title = i18n("prefs.local_host_max_idle_title"),
                description = i18n("prefs.local_host_max_idle_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.local_host_max_idle",
                default = "300",
                tformat = "smh",
                attrs = {
                    min = "1",
                    max = tostring(7 * 86400)
                }
            }, {
                key = "non_local_host_max_idle",
                title = i18n("prefs.non_local_host_max_idle_title"),
                description = i18n("prefs.non_local_host_max_idle_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.non_local_host_max_idle",
                default = "60",
                tformat = "smh",
                attrs = {
                    min = "1",
                    max = tostring(7 * 86400)
                }
            }, {
                key = "mac_address_cache_duration",
                title = i18n("prefs.mac_address_cache_duration_title"),
                description = i18n("prefs.mac_address_cache_duration_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.mac_address_cache_duration",
                default = "300",
                tformat = "mhd",
                attrs = {
                    min = "5"
                }
            }}
        },

        -- Dump Settings
        {
            id = "dump_settings",
            label = i18n("prefs.dump_settings"),
            advanced = true,
            pro_only = false,
            hidden = (is_dump_flows_enabled == false),
            entries = {{
                key = "toggle_enable_runtime_flows_dump",
                title = i18n("prefs.toggle_enable_runtime_flows_dump_title"),
                description = i18n("prefs.toggle_enable_runtime_flows_dump_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.enable_runtime_flows_dump",
                default = "1"
            }, {
                key = "dump_frequency",
                title = i18n("prefs.dump_frequency_title"),
                description = i18n("prefs.dump_frequency_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.dump_frequency",
                default = "60",
                attrs = {
                    min = "1"
                }
            }, {
                key = "toggle_tiny_flows_dump",
                title = i18n("prefs.toggle_tiny_flows_dump_title"),
                description = i18n("prefs.toggle_tiny_flows_dump_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.tiny_flows_export_enabled",
                default = "1",
                reverse_switch = true,
                to_switch = {"max_num_packets_per_tiny_flow", "max_num_bytes_per_tiny_flow"}
            }, {
                key = "max_num_packets_per_tiny_flow",
                title = i18n("prefs.max_num_packets_per_tiny_flow_title"),
                description = i18n("prefs.max_num_packets_per_tiny_flow_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.max_num_packets_per_tiny_flow",
                default = "10",
                attrs = {
                    min = "1"
                }
            }, {
                key = "max_num_bytes_per_tiny_flow",
                title = i18n("prefs.max_num_bytes_per_tiny_flow_title"),
                description = i18n("prefs.max_num_bytes_per_tiny_flow_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.max_num_bytes_per_tiny_flow",
                default = "1024",
                attrs = {
                    min = "1"
                }
            }}
        },

        -- Network Interfaces
        {
            id = "ifaces",
            label = i18n("prefs.network_interfaces"),
            advanced = true,
            pro_only = false,
            hidden = false,
            nedge_hidden = true,
            entries = {{
                key = "ignored_interfaces",
                title = i18n("prefs.ignored_interfaces_title"),
                description = i18n("prefs.ignored_interfaces_description", {
                    product = info.product
                }),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.ignored_interfaces",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "32",
                    pattern = "^([0-9]+,)*[0-9]+$"
                }
            }, {
                key = "toggle_dst_with_post_nat_dst",
                title = i18n("prefs.toggle_dst_with_post_nat_dst_title"),
                description = i18n("prefs.toggle_dst_with_post_nat_dst_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.override_dst_with_post_nat_dst",
                default = "0"
            }, {
                key = "toggle_src_with_post_nat_src",
                title = i18n("prefs.toggle_src_with_post_nat_src_title"),
                description = i18n("prefs.toggle_src_with_post_nat_src_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.override_src_with_post_nat_src",
                default = "0"
            }}
        },

        -- OT Protocols
        {
            id = "ot_protocols",
            label = i18n("prefs.ot_protocols"),
            advanced = true,
            pro_only = false,
            hidden = false,
            entries = {{
                key = "iec60870_learning_period",
                title = i18n("prefs.iec60870_learning_period_title"),
                description = i18n("prefs.iec60870_learning_period_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.iec60870_learning_period",
                default = "21600",
                tformat = "hd",
                attrs = {
                    min = "3600"
                }
            }, {
                key = "modbus_learning_period",
                title = i18n("prefs.modbus_learning_period_title"),
                description = i18n("prefs.modbus_learning_period_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.modbus_learning_period",
                default = "21600",
                tformat = "hd",
                attrs = {
                    min = "3600"
                },
                hidden = (not is_enterprise_l)
            }, {
                key = "s7comm_learning_period",
                title = i18n("prefs.s7comm_learning_period_title"),
                description = i18n("prefs.s7comm_learning_period_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.s7comm_learning_period",
                default = "21600",
                tformat = "hd",
                attrs = {
                    min = "3600"
                },
                hidden = (not is_enterprise_l)
            }}
        },

        -- Recording
        {
            id = "recording",
            label = i18n("prefs.recording"),
            advanced = false,
            pro_only = false,
            hidden = (not flags.recording_available and not have_nedge),
            entries = {{
                key = "n2disk_license",
                title = i18n("prefs.n2disk_license_title"),
                description = i18n("prefs.n2disk_license_description", {
                    purchase_url = "http://shop.ntop.org/",
                    universities_url = "http://www.ntop.org/support/faq/do-you-charge-universities-no-profit-and-research/"
                }),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.n2disk_license",
                default = "",
                hidden = have_nedge,
                attrs = {
                    maxlength = "64"
                }
            }, {
                key = "max_extracted_pcap_bytes",
                title = i18n("traffic_recording.max_extracted_pcap_bytes_title"),
                description = i18n("traffic_recording.max_extracted_pcap_bytes_description"),
                type = "input",
                input_type = "number",
                tformat = "mg",
                redis_key = "ntopng.prefs.max_extracted_pcap_bytes",
                default = tostring(prefs.max_extracted_pcap_bytes or 104857600),
                attrs = {
                    min = tostring(10 * 1024 * 1024)
                }
            }, {
                key = "max_extracted_pcap_files",
                title = i18n("traffic_recording.max_extracted_pcap_files_title"),
                description = i18n("traffic_recording.max_extracted_pcap_files_description"),
                type = "input",
                input_type = "number",
                redis_key = "ntopng.prefs.max_extracted_pcap_files",
                default = tostring(prefs.max_extracted_pcap_files or 10),
                attrs = {
                    min = "0"
                }
            }}
        },

        -- ASN Settings
        {
            id = "asn_settings",
            label = i18n("prefs.asn_mode"),
            advanced = true,
            pro_only = false,
            hidden = not flags.is_zmq_interface,
            entries = {{
                key = "asn_mode_enabled",
                title = i18n("prefs.toggle_asn_mode_title"),
                description = i18n("prefs.toggle_asn_mode_description"),
                type = "toggle",
                redis_key = "ntopng.prefs.toggle_asn_mode",
                default = "0"
            }, {
                key = "bgp_server_address",
                title = i18n("prefs.bgp_server_address_title"),
                description = i18n("prefs.bgp_server_address_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.bgp_server.ip_address",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "128"
                }
            }, {
                key = "bgp_server_port",
                title = i18n("prefs.bgp_server_port_title"),
                description = i18n("prefs.bgp_server_port_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.bgp_server.port",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "128"
                }
            }, {
                key = "bgp_prefix_changes_endpoint",
                title = i18n("prefs.bgp_prefix_changes_endpoint_title"),
                description = i18n("prefs.bgp_prefix_changes_endpoint_description"),
                type = "input",
                input_type = "text",
                redis_key = "ntopng.prefs.bgp_server.prefix_changes_endpoint",
                default = "",
                attrs = {
                    spellcheck = "false",
                    maxlength = "128"
                }
            }}
        }} 

    -- Pro / Enterprise sections
    -- Always appended so community users see them as locked (pro_only=true).
    -- The POST endpoint rejects writes when is_pro/is_enterprise is false.

    local is_pro = flags.is_pro or false
    local is_enterprise = flags.is_enterprise or false
    local is_enterprise_m = flags.is_enterprise_m or false
    local is_enterprise_l = flags.is_enterprise_l or false
    local is_enterprise_xl = flags.is_enterprise_xl or false
    local is_nedge_enterprise = flags.is_nedge_enterprise or false
    local has_ch_support = flags.has_ch_support or false
    local has_nanalyst = flags.has_nanalyst or false

    -- Protocols
    sections[#sections + 1] = {
        id = "protocols",
        label = i18n("prefs.protocols"),
        advanced = false,
        pro_only = true,
        hidden = false,
        entries = {{
            key = "toggle_top_sites",
            title = i18n("prefs.toggle_top_sites_title"),
            description = i18n("prefs.toggle_top_sites_description", {
                url = "https://resources.sei.cmu.edu/asset_files/Presentation/2010_017_001_49763.pdf"
            }),
            type = "toggle",
            redis_key = "ntopng.prefs.host_top_sites_creation",
            default = "0",
            hidden = (not is_pro)
        }, {
            key = "toggle_dns_cache",
            title = i18n("prefs.toggle_dns_cache_title"),
            description = i18n("prefs.toggle_dns_cache_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.dns_cache",
            default = "0",
            hidden = (not is_pro)
        }, {
            key = "toggle_tls_quic_hostnaming",
            title = i18n("prefs.toggle_tls_quic_hostnaming_title"),
            description = i18n("prefs.toggle_tls_quic_hostnaming_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.tls_quic_hostnaming",
            default = "0",
            hidden = (not is_pro)
        }}
    }

    -- Assets / Wazuh
    sections[#sections + 1] = {
        id = "assets",
        label = i18n("prefs.assets"),
        advanced = false,
        pro_only = true,
        hidden = false,
        entries = {{
            key = "wazuh_url",
            title = i18n("prefs.wazuh_url_title"),
            description = i18n("prefs.wazuh_url_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.wazuh.wazuh_url",
            default = "",
            test_endpoint = "/lua/rest/v2/get/ntopng/test_wazuh_connectivity.lua",
            test_params = { username = "wazuh_username", password = "wazuh_password" },
            section = i18n("prefs.wazuh"),
            attrs = {
                spellcheck = "false",
                maxlength = "255",
                pattern = "https?://.+"
            },
            hidden = (not is_enterprise_m)
        }, {
            key = "wazuh_username",
            title = i18n("prefs.wazuh_username_title"),
            description = i18n("prefs.wazuh_username_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.wazuh.wazuh_username",
            default = "",
            attrs = {
                spellcheck = "false",
                maxlength = "128"
            },
            hidden = (not is_enterprise_m)
        }, {
            key = "wazuh_password",
            title = i18n("prefs.wazuh_password_title"),
            description = i18n("prefs.wazuh_password_description"),
            type = "input",
            input_type = "password",
            redis_key = "ntopng.prefs.wazuh.wazuh_password",
            default = "",
            password = true,
            attrs = {
                spellcheck = "false",
                maxlength = "255"
            },
            hidden = (not is_enterprise_m)
        }, {
            key = "toggle_wazuh_automerge",
            title = i18n("prefs.toggle_wazuh_automerge_title"),
            description = i18n("prefs.toggle_wazuh_automerge_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.wazuh_automerge_enabled",
            default = "0",
            hidden = (not is_enterprise_m)
        }}
    }

    -- Traffic Behaviour
    sections[#sections + 1] = {
        id = "traffic_behaviour",
        label = i18n("prefs.behaviour"),
        advanced = true,
        pro_only = true,
        hidden = (not is_enterprise),
        entries = {
            -- Assets
            {
            key = "toggle_assets_inventory",
            title = i18n("prefs.toggle_assets_inventory_title"),
            description = i18n("prefs.toggle_assets_inventory_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.enable_asset_inventory",
            default = "1",
            section = i18n("assets")
        },
            -- Service Map
            -- tformat="hd": value stored in seconds; UI shows number + Hours/Days selector
            -- LEARNING_STATUS (ntop_typedefs.h ServiceAcceptance): ALLOWED=0, DENIED=1, UNDECIDED=2
            {
            key = "behaviour_analysis_learning_period",
            title = i18n("prefs.behaviour_analysis_learning_period_title"),
            description = i18n("prefs.behaviour_analysis_learning_period_description"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.behaviour_analysis_learning_period",
            default = tostring(prefs.behaviour_analysis_learning_period or 7200),
            tformat = "hd",
            section = i18n("prefs.service_map"),
            attrs = {
                min = "3600"
            },
            hidden = (not is_enterprise_l)
        }, {
            key = "behaviour_analysis_learning_status_during_learning",
            title = i18n("prefs.behaviour_analysis_status_during_learning_title"),
            description = i18n("prefs.behaviour_analysis_status_during_learning_description"),
            type = "button_group",
            redis_key = "ntopng.prefs.behaviour_analysis_learning_status_during_learning",
            default = "0",
            options = {{
                value = "2",
                label = i18n("traffic_behaviour.undecided")
            }, {
                value = "0",
                label = i18n("traffic_behaviour.allowed")
            }, {
                value = "1",
                label = i18n("traffic_behaviour.denied")
            }},
            section = i18n("prefs.service_map"),
            hidden = (not is_enterprise_l)
        }, {
            key = "behaviour_analysis_learning_status_post_learning",
            title = i18n("prefs.behaviour_analysis_status_post_learning_title"),
            description = i18n("prefs.behaviour_analysis_status_post_learning_description"),
            type = "button_group",
            redis_key = "ntopng.prefs.behaviour_analysis_learning_status_post_learning",
            default = "0",
            options = {{
                value = "2",
                label = i18n("traffic_behaviour.undecided")
            }, {
                value = "0",
                label = i18n("traffic_behaviour.allowed")
            }, {
                value = "1",
                label = i18n("traffic_behaviour.denied")
            }},
            section = i18n("prefs.service_map"),
            hidden = (not is_enterprise_l)
        },
            -- Devices Behaviour
            {
            key = "devices_learning_period",
            title = i18n("prefs.devices_learning_period_title"),
            description = i18n("prefs.devices_learning_period_description"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.devices_learning_period",
            default = tostring(prefs.devices_learning_period or 7200),
            tformat = "hd",
            section = i18n("prefs.devices_behaviour"),
            attrs = {
                min = "7200"
            },
            hidden = (not is_enterprise_m)
        }, {
            key = "devices_status_during_learning",
            title = i18n("prefs.devices_status_during_learning_title"),
            description = i18n("prefs.devices_status_during_learning_description"),
            type = "button_group",
            redis_key = "ntopng.prefs.devices_status_during_learning",
            default = "0",
            options = {{
                value = "0",
                label = i18n("traffic_behaviour.allowed")
            }, {
                value = "1",
                label = i18n("traffic_behaviour.denied")
            }},
            section = i18n("prefs.devices_behaviour"),
            hidden = (not is_enterprise_m)
        }, {
            key = "devices_status_post_learning",
            title = i18n("prefs.devices_status_post_learning_title"),
            description = i18n("prefs.devices_status_post_learning_description"),
            type = "button_group",
            redis_key = "ntopng.prefs.devices_status_post_learning",
            default = "0",
            options = {{
                value = "0",
                label = i18n("traffic_behaviour.allowed")
            }, {
                value = "1",
                label = i18n("traffic_behaviour.denied")
            }},
            section = i18n("prefs.devices_behaviour"),
            hidden = (not is_enterprise_m)
        },
            -- Host Analysis
            {
            key = "host_port_learning_period",
            title = i18n("prefs.host_port_learning_period_title"),
            description = i18n("prefs.host_port_learning_period_description"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.host_port_learning_period",
            default = tostring(prefs.host_port_learning_period or 7200),
            tformat = "hd",
            section = i18n("prefs.host_analysis"),
            attrs = {
                min = "7200"
            },
            hidden = (not is_enterprise_m)
        }}
    }

    -- ClickHouse
    local ch_enabled = (is_enterprise_m or is_nedge_enterprise) and ntop.isClickHouseEnabled and
                           ntop.isClickHouseEnabled()
    -- aggregate flow prefs require EnterpriseXL + ClickHouse
    local agg_flows_enabled = is_enterprise_xl and ch_enabled
    sections[#sections + 1] = {
        id = "clickhouse",
        label = i18n("prefs.clickhouse"),
        advanced = true,
        pro_only = true,
        hidden = false,
        entries = {{
            key = "flow_data_retention",
            title = i18n("prefs.flows_and_alerts_data_retention"),
            description = i18n("prefs.flows_and_alerts_data_retention_descr"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.flows_and_alerts_data_retention_days",
            default = "30",
            attrs = {
                min = "1"
            },
            hidden = (not ch_enabled)
        }, {
            key = "aggregated_asn_data_retention",
            title = i18n("prefs.aggregated_asn_data_retention_title"),
            description = i18n("prefs.aggregated_asn_data_retention_descr"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.aggregated_asn_data_retention_days",
            default = "100",
            attrs = {
                min = "1"
            },
            hidden = (not ch_enabled)
        }, {
            key = "aggregated_flows_data_retention",
            title = i18n("prefs.aggregated_flows_data_retention_title"),
            description = i18n("prefs.aggregated_flows_data_retention_descr"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.aggregated_flows_data_retention_days",
            default = "365",
            attrs = {
                min = "1"
            },
            hidden = (not ch_enabled)
        }, {
            key = "vs_reports_data_retention",
            title = i18n("prefs.vs_reports_data_retention_title"),
            description = i18n("prefs.vs_reports_data_retention_descr"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.vs_reports_retention_days",
            default = "30",
            attrs = {
                min = "1"
            },
            hidden = (not ch_enabled)
        }, {
            key = "toggle_flow_aggregated_limit",
            title = i18n("prefs.toggle_flow_aggregated_limit_title"),
            description = i18n("prefs.toggle_flow_aggregated_limit_description"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.max_aggregated_flows_upperbound",
            default = "10000",
            attrs = {
                min = "1000",
                max = "10000000"
            },
            hidden = (not agg_flows_enabled)
        }, {
            key = "toggle_flow_aggregated_traffic_limit",
            title = i18n("prefs.toggle_flow_aggregated_traffic_limit_title"),
            description = i18n("prefs.toggle_flow_aggregated_traffic_limit_description"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.max_aggregated_flows_traffic_upperbound",
            default = "5",
            attrs = {
                min = "0",
                max = "5000"
            },
            hidden = (not agg_flows_enabled)
        }, {
            key = "toggle_flow_aggregated_alerted_flows",
            title = i18n("prefs.toggle_flow_aggregated_alerted_flows_title"),
            description = i18n("prefs.toggle_flow_aggregated_alerted_flows_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.include_alerted_flows_in_aggregated_flows",
            default = "0",
            hidden = (not agg_flows_enabled)
        }, {
            key = "toggle_dump_pcap_to_clickhouse",
            title = i18n("prefs.toggle_dump_pcap_to_clickhouse_title"),
            description = i18n("prefs.toggle_dump_pcap_to_clickhouse_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.dump_pcap_to_clickhouse",
            default = "0",
            hidden = (not ch_enabled)
        }, {
            key = "toggle_query_performance_log",
            title = i18n("prefs.toggle_query_performance_log_title"),
            description = i18n("prefs.toggle_query_performance_log_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.enable_query_performance_log",
            default = "0",
            hidden = (not ch_enabled)
        }, {
            key = "toggle_data_archive_before_ttl_delete",
            title = i18n("prefs.toggle_export_flows_to_archive_title"),
            description = i18n("prefs.toggle_export_flows_to_archive_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.data_archive_before_ttl_delete",
            default = "0",
            to_switch = {"path_data_archive_before_ttl_delete"},
            hidden = (not agg_flows_enabled)
        }, {
            key = "path_data_archive_before_ttl_delete",
            title = i18n("prefs.path_export_flows_to_archive_title"),
            description = i18n("prefs.path_export_flows_to_archive_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.path_data_archive_before_ttl_delete",
            default = "",
            attrs = {
                spellcheck = "false",
                maxlength = "512"
            },
            hidden = (not agg_flows_enabled)
        }}
    }

    -- Message Broker
    sections[#sections + 1] = {
        id = "message_broker",
        label = i18n("prefs.message_broker"),
        advanced = false,
        pro_only = true,
        hidden = false,
        entries = {{
            key = "toggle_message_broker",
            title = i18n("prefs.toggle_message_broker_title"),
            description = i18n("prefs.toggle_message_broker_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.toggle_message_broker",
            default = "0",
            to_switch = {"message_brokers_list", "message_broker_url", "message_broker_username",
                         "message_broker_password"},
            hidden = (not is_enterprise_m)
        }, {
            key = "message_brokers_list",
            title = i18n("prefs.message_brokers_title"),
            description = i18n("prefs.message_brokers_description"),
            type = "button_group",
            redis_key = "ntopng.prefs.message_broker",
            default = "nats",
            options = {{
                value = "nats",
                label = "NATS"
            }},
            hidden = (not is_enterprise_m)
        }, {
            key = "message_broker_url",
            title = i18n("prefs.message_broker_url_title"),
            description = i18n("prefs.message_broker_url_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.message_broker_url",
            default = "",
            attrs = {
                spellcheck = "false",
                maxlength = "255"
            },
            hidden = (not is_enterprise_m)
        }, {
            key = "message_broker_username",
            title = i18n("login.username"),
            description = i18n("prefs.message_broker_username_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.message_broker_username",
            default = "",
            attrs = {
                spellcheck = "false",
                maxlength = "128"
            },
            hidden = (not is_enterprise_m)
        }, {
            key = "message_broker_password",
            title = i18n("login.password"),
            description = i18n("prefs.message_broker_password_description"),
            type = "input",
            input_type = "password",
            redis_key = "ntopng.prefs.message_broker_password",
            default = "",
            password = true,
            attrs = {
                maxlength = "255"
            },
            hidden = (not is_enterprise_m)
        }}
    }

    -- LLM Providers (Pro + nAnalyst)
    sections[#sections + 1] = {
        id = "llm_providers",
        label = i18n("prefs.llm_providers"),
        advanced = false,
        pro_only = true,
        hidden = false,
        entries = {{
            key = "local_llm_url",
            title = i18n("prefs.llm_url_title"),
            description = i18n("prefs.llm_local_url_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.llm.local_llm_url",
            default = "http://localhost:11434/v1/chat/completions",
            test_endpoint = "/lua/rest/v2/get/ntopng/test_llm_connectivity.lua",
            test_params = { llm_token = "local_llm_token", model = "local_llm_model" },
            attrs = {
                spellcheck = "false",
                maxlength = "255"
            },
            section = i18n("prefs.llm_local"),
            hidden = (not has_nanalyst)
        }, {
            key = "local_llm_token",
            title = i18n("prefs.llm_token_title"),
            description = i18n("prefs.llm_local_token_description"),
            type = "input",
            input_type = "password",
            redis_key = "ntopng.prefs.llm.local_llm_token",
            default = "",
            password = true,
            attrs = {
                spellcheck = "false",
                maxlength = "255"
            },
            section = i18n("prefs.llm_local"),
            hidden = (not has_nanalyst)
        }, {
            key = "local_llm_model",
            title = i18n("prefs.llm_model_title"),
            description = i18n("prefs.llm_local_model_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.llm.local_llm_model",
            default = "Qwen3.5-9B",
            attrs = {
                spellcheck = "false",
                maxlength = "128"
            },
            section = i18n("prefs.llm_local"),
            hidden = (not has_nanalyst)
        }, {
            key = "qwen_url",
            title = i18n("prefs.llm_url_title"),
            description = i18n("prefs.llm_qwen_url_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.llm.qwen_url",
            default = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions",
            test_endpoint = "/lua/rest/v2/get/ntopng/test_llm_connectivity.lua",
            test_params = { llm_token = "qwen_token", model = "qwen_model" },
            attrs = {
                spellcheck = "false",
                maxlength = "255"
            },
            section = i18n("prefs.llm_qwen"),
            hidden = (not has_nanalyst)
        }, {
            key = "qwen_token",
            title = i18n("prefs.llm_token_title"),
            description = i18n("prefs.llm_qwen_token_description"),
            type = "input",
            input_type = "password",
            redis_key = "ntopng.prefs.llm.qwen_token",
            default = "",
            password = true,
            attrs = {
                spellcheck = "false",
                maxlength = "255"
            },
            section = i18n("prefs.llm_qwen"),
            hidden = (not has_nanalyst)
        }, {
            key = "qwen_model",
            title = i18n("prefs.llm_model_title"),
            description = i18n("prefs.llm_qwen_model_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.llm.qwen_model",
            default = "qwen-plus",
            attrs = {
                spellcheck = "false",
                maxlength = "128"
            },
            section = i18n("prefs.llm_qwen"),
            hidden = (not has_nanalyst)
        }, {
            key = "anthropic_url",
            title = i18n("prefs.llm_url_title"),
            description = i18n("prefs.llm_anthropic_url_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.llm.anthropic_url",
            default = "https://api.anthropic.com/v1/messages",
            test_endpoint = "/lua/rest/v2/get/ntopng/test_llm_connectivity.lua",
            test_params = { llm_token = "anthropic_token", model = "anthropic_model" },
            attrs = {
                spellcheck = "false",
                maxlength = "255"
            },
            section = i18n("prefs.llm_anthropic"),
            hidden = (not has_nanalyst)
        }, {
            key = "anthropic_token",
            title = i18n("prefs.llm_token_title"),
            description = i18n("prefs.llm_anthropic_token_description"),
            type = "input",
            input_type = "password",
            redis_key = "ntopng.prefs.llm.anthropic_token",
            default = "",
            password = true,
            attrs = {
                spellcheck = "false",
                maxlength = "255"
            },
            section = i18n("prefs.llm_anthropic"),
            hidden = (not has_nanalyst)
        }, {
            key = "anthropic_model",
            title = i18n("prefs.llm_model_title"),
            description = i18n("prefs.llm_anthropic_model_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.llm.anthropic_model",
            default = "claude-opus-4-5",
            attrs = {
                spellcheck = "false",
                maxlength = "128"
            },
            section = i18n("prefs.llm_anthropic"),
            hidden = (not has_nanalyst)
        }, {
            key = "openai_url",
            title = i18n("prefs.llm_url_title"),
            description = i18n("prefs.llm_openai_url_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.llm.openai_url",
            default = "https://api.openai.com/v1/chat/completions",
            test_endpoint = "/lua/rest/v2/get/ntopng/test_llm_connectivity.lua",
            test_params = { llm_token = "openai_token", model = "openai_model" },
            attrs = {
                spellcheck = "false",
                maxlength = "255"
            },
            section = i18n("prefs.llm_openai"),
            hidden = (not has_nanalyst)
        }, {
            key = "openai_token",
            title = i18n("prefs.llm_token_title"),
            description = i18n("prefs.llm_openai_token_description"),
            type = "input",
            input_type = "password",
            redis_key = "ntopng.prefs.llm.openai_token",
            default = "",
            password = true,
            attrs = {
                spellcheck = "false",
                maxlength = "255"
            },
            section = i18n("prefs.llm_openai"),
            hidden = (not has_nanalyst)
        }, {
            key = "openai_model",
            title = i18n("prefs.llm_model_title"),
            description = i18n("prefs.llm_openai_model_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.llm.openai_model",
            default = "gpt-4o",
            attrs = {
                spellcheck = "false",
                maxlength = "128"
            },
            section = i18n("prefs.llm_openai"),
            hidden = (not has_nanalyst)
        }}
    }

    -- Reports
    sections[#sections + 1] = {
        id = "reports",
        label = i18n("prefs.reports"),
        advanced = false,
        pro_only = true,
        hidden = false,
        entries = {{
            key = "toggle_enable_automatic_reports",
            title = i18n("prefs.toggle_enable_automatic_reports_title"),
            description = i18n("prefs.toggle_enable_automatic_reports_descr"),
            type = "toggle",
            redis_key = "ntopng.prefs.automatic_reports_enabled",
            default = "0",
            hidden = (not is_enterprise_l)
        }, {
            key = "reports_data_retention_time",
            title = i18n("prefs.reports_data_retention_time_title"),
            description = i18n("prefs.reports_data_retention_time_descr"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.reports_data_retention_days",
            default = "30",
            attrs = {
                min = "1"
            },
            hidden = (not is_enterprise_l)
        }}
    }

    -- SNMP
    sections[#sections + 1] = {
        id = "snmp",
        label = i18n("prefs.snmp"),
        advanced = true,
        pro_only = true,
        hidden = (not (is_enterprise_m or have_nedge)),
        entries = {{
            key = "toggle_snmp_rrds",
            title = i18n("prefs.toggle_snmp_rrds_title"),
            description = i18n("prefs.toggle_snmp_rrds_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.snmp_devices_rrd_creation",
            default = "0",
            to_switch = {"snmp_devices_exporters_rrds_resolution"},
            hidden = (not (is_enterprise_m or have_nedge))
        }, {
            key = "snmp_devices_exporters_rrds_resolution",
            title = i18n("prefs.snmp_devices_exporters_rrds_resolution_title"),
            description = i18n("prefs.snmp_devices_exporters_rrds_resolution_description"),
            type = "button_group",
            redis_key = "ntopng.prefs.snmp_devices_exporters_rrd",
            default = "60",
            options = {{
                value = "0",
                label = i18n("disabled")
            }, {
                value = "60",
                label = "1m"
            }, {
                value = "300",
                label = "5m"
            }},
            hidden = (not (is_enterprise_m or have_nedge))
        }, {
            key = "toggle_snmp_polling",
            title = i18n("prefs.toggle_snmp_polling_title"),
            description = i18n("prefs.toggle_snmp_polling_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.snmp_polling",
            default = "0",
            hidden = (not (is_enterprise_m or have_nedge))
        }, {
            key = "default_snmp_proto_version",
            title = i18n("prefs.default_snmp_proto_version_title"),
            description = i18n("prefs.default_snmp_proto_version_description"),
            type = "button_group",
            redis_key = "ntopng.prefs.default_snmp_version",
            default = "1",
            options = {{
                value = "0",
                label = "v1"
            }, {
                value = "1",
                label = "v2c"
            }},
            hidden = (not (is_enterprise_m or have_nedge))
        }, {
            key = "default_snmp_community",
            title = i18n("prefs.default_snmp_community_title"),
            description = i18n("prefs.default_snmp_community_description"),
            type = "input",
            input_type = "text",
            redis_key = "ntopng.prefs.default_snmp_community",
            default = "public",
            attrs = {
                spellcheck = "false",
                maxlength = "64"
            },
            hidden = (not (is_enterprise_m or have_nedge))
        }, {
            key = "snmp_interface_format",
            title = i18n("prefs.snmp_interface_format_title"),
            description = i18n("prefs.snmp_interface_format_description"),
            type = "button_group",
            redis_key = "ntopng.prefs.snmp_interface_format",
            default = "0",
            options = {{
                value = "0",
                label = "ifAlias"
            }, {
                value = "1",
                label = "ifName"
            }},
            hidden = (not (is_enterprise_m or have_nedge))
        }, {
            key = "default_snmp_timeout",
            title = i18n("prefs.default_snmp_timeout_title"),
            description = i18n("prefs.default_snmp_timeout_description"),
            type = "input",
            input_type = "number",
            redis_key = "ntopng.prefs.snmp_timeout_sec",
            default = "3",
            attrs = {
                min = "1",
                max = "10"
            },
            hidden = (not (is_enterprise_m or have_nedge))
        }, {
            key = "toggle_snmp_excluded_from_usage",
            title = i18n("prefs.toggle_snmp_excluded_from_usage_title"),
            description = i18n("prefs.toggle_snmp_excluded_from_usage_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.toggle_snmp_excluded_from_usage",
            default = "0",
            hidden = (not is_enterprise_l)
        }, {
            key = "toggle_snmp_trap",
            title = i18n("prefs.toggle_snmp_trap_title"),
            description = i18n("prefs.toggle_snmp_trap_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.toggle_snmp_trap",
            default = "0",
            hidden = (not is_enterprise_xl)
        }, {
            key = "toggle_snmp_debug",
            title = i18n("prefs.toggle_snmp_debug_title"),
            description = i18n("prefs.toggle_snmp_debug_description"),
            type = "toggle",
            redis_key = "ntopng.prefs.snmp_debug",
            default = "0",
            hidden = (not (is_enterprise_m or have_nedge))
        }}
    }

    return sections
end

return M
