require "lua_utils"

local recording_utils = require "recording_utils"
local remote_assistance = require "remote_assistance"
local plugins_utils = require("plugins_utils")

local prefs = ntop.getPrefs()

local have_nedge = ntop.isnEdge()
local info = ntop.getInfo(false)
local hasRadius = ntop.hasRadiusSupport()
local hasNindex = hasNindexSupport()
local hasLdap = ntop.hasLdapSupport()
local max_nindex_retention = 0
local nindex_utils = nil

if ntop.isPro() then
  package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

  if hasNindexSupport() then
     nindex_utils = require("nindex_utils")
     _, max_nindex_retention = nindex_utils.getRetention()
  end
end

local function getAlertEndpointsEntries()
  local endpoints = plugins_utils.getLoadedAlertEndpoints()
  local rv = {
    notification_severity_preference = {
      title       = i18n("prefs.slack_notification_severity_preference_title", {url="http://www.slack.com"}),
      description = i18n("prefs.slack_notification_severity_preference_description"),
    }
  }

  for _, endpoint in ipairs(endpoints) do
    for entry_k, entry in pairs(endpoint.prefs_entries or {}) do
      rv[entry_k] = entry
    end
  end

  return(rv)
end

-- This table is used both to control access to the preferences and to filter preferences results
local menu_subpages = {
  {id="auth",          label=i18n("prefs.user_authentication"),  advanced=false, pro_only=false, nedge_hidden=false, hidden=(not(prefs.is_users_login_enabled) and not have_nedge), entries={
    authentication_duration = {
      title       = i18n("prefs.authentication_duration_title"),
      description = i18n("prefs.authentication_duration_descr"),
    }, toggle_auth_session_midnight_expiration = {
      title       = i18n("prefs.authentication_midnight_expiration_title"),
      description = i18n("prefs.authentication_midnight_expiration_descr"),
    }, toggle_ldap_auth = {
      title       = i18n("prefs.toggle_ldap_auth"),
      description = i18n("prefs.toggle_ldap_auth_descr"),
      hidden      = (not hasLdap),
    }, toggle_radius_auth = {
      title       = i18n("prefs.toggle_radius_auth"),
      description = i18n("prefs.toggle_radius_auth_descr", {product=info.product}),
      hidden      = (not hasRadius),
    }, toggle_http_auth = {
      title       = i18n("prefs.toggle_http_auth"),
      description = i18n("prefs.toggle_http_auth_descr"),
      hidden      = have_nedge,
    }, toggle_local_auth = {
      title       = i18n("prefs.toggle_local_auth"),
      description = i18n("prefs.toggle_local_auth_descr", {product=info.product}),
    }, multiple_ldap_account_type = {
      title       = i18n("prefs.multiple_ldap_account_type_title"),
      description = i18n("prefs.multiple_ldap_account_type_description"),
      hidden      = (not hasLdap),
    }, ldap_server_address = {
      title       = i18n("prefs.ldap_server_address_title"),
      description = i18n("prefs.ldap_server_address_description"),
      hidden      = (not hasLdap),
    }, bind_dn = {
      title       = i18n("prefs.bind_dn_title"),
      description = i18n("prefs.bind_dn_description"),
      hidden      = (not hasLdap),
    }, bind_pwd = {
      title       = i18n("prefs.bind_pwd_title"),
      description = i18n("prefs.bind_pwd_description"),
      hidden      = (not hasLdap),
    }, search_path = {
      title       = i18n("prefs.search_path_title"),
      description = i18n("prefs.search_path_description"),
      hidden      = (not hasLdap),
    }, user_group = {
      title       = i18n("prefs.user_group_title"),
      description = i18n("prefs.user_group_description"),
      hidden      = (not hasLdap),
    }, admin_group = {
      title       = i18n("prefs.admin_group_title"),
      description = i18n("prefs.admin_group_description"),
      hidden      = (not hasLdap),
    }, toggle_ldap_anonymous_bind = {
      title       = i18n("prefs.toggle_ldap_anonymous_bind_title"),
      description = i18n("prefs.toggle_ldap_anonymous_bind_description"),
      hidden      = (not hasLdap),
    }, toggle_ldap_referrals = {
      title       = i18n("prefs.toggle_ldap_referrals_title"),
      description = i18n("prefs.toggle_ldap_referrals_description"),
      hidden      = (not hasLdap),
    }, radius_server = {
      title       = i18n("prefs.radius_server_title"),
      description = i18n("prefs.radius_server_description", {example="127.0.0.1:1812"}),
      hidden      = (not hasRadius),
    }, radius_secret = {
      title       = i18n("prefs.radius_secret_title"),
      description = i18n("prefs.radius_secret_descroption"),
      hidden      = (not hasRadius),
    }, radius_admin_group = {
      title       = i18n("prefs.radius_admin_group_title"),
      description = i18n("prefs.radius_admin_group_description"),
      hidden      = (not hasRadius),
    }, http_auth_server = {
      title       = i18n("prefs.http_auth_server_title"),
      description = i18n("prefs.http_auth_server_description"),
      hidden      = have_nedge,
    }, toggle_client_x509_auth = {
      title       = i18n("prefs.client_x509_auth_title"),
      description = i18n("prefs.client_x509_auth_descr"),
    },
  }}, {id="ifaces",    label=i18n("prefs.network_interfaces"),   advanced=true,  pro_only=false,  hidden=false, nedge_hidden=true, entries={
    ignored_interfaces = {
      title       = i18n("prefs.ignored_interfaces_title"),
      description = i18n("prefs.ignored_interfaces_description", {product=info.product}),
    }, toggle_src_with_post_nat_src = {
      title       = i18n("prefs.toggle_src_with_post_nat_src_title"),
      description = i18n("prefs.toggle_src_with_post_nat_src_description"),
    }, toggle_dst_with_post_nat_dst = {
      title       = i18n("prefs.toggle_dst_with_post_nat_dst_title"),
      description = i18n("prefs.toggle_dst_with_post_nat_dst_description"),
    }, toggle_src_and_dst_using_ports = {
      title       = i18n("prefs.toggle_src_and_dst_using_ports_title"),
      description = i18n("prefs.toggle_src_and_dst_using_ports_description"),
    },
  }}, {id="in_memory",     label=i18n("prefs.cache_settings"),             advanced=true,  pro_only=false,  hidden=false, entries={
    toggle_midnight_stats_reset = {
      title       = i18n("prefs.toggle_midnight_stats_reset_title"),
      description = i18n("prefs.toggle_midnight_stats_reset_description"),
    }, local_host_max_idle = {
      title       = i18n("prefs.local_host_max_idle_title"),
      description = i18n("prefs.local_host_max_idle_description"),
    }, non_local_host_max_idle = {
      title       = i18n("prefs.non_local_host_max_idle_title"),
      description = i18n("prefs.non_local_host_max_idle_description"),
    }, flow_max_idle = {
      title       = i18n("prefs.flow_max_idle_title"),
      description = i18n("prefs.flow_max_idle_description"),
    }, housekeeping_frequency = {
      title       = i18n("prefs.housekeeping_frequency_title"),
      description = i18n("prefs.housekeeping_frequency_description", {product=info["product"]}),
    }, toggle_local_host_cache_enabled = {
      title       = i18n("prefs.toggle_local_host_cache_enabled_title"),
      description = i18n("prefs.toggle_local_host_cache_enabled_description"),
    }, toggle_active_local_host_cache_enabled = {
      title       = i18n("prefs.toggle_active_local_host_cache_enabled_title"),
      description = i18n("prefs.toggle_active_local_host_cache_enabled_description"),
    }, active_local_host_cache_interval = {
      title       = i18n("prefs.active_local_host_cache_interval_title"),
      description = i18n("prefs.active_local_host_cache_interval_description"),
    }, local_host_cache_duration = {
      title       = i18n("prefs.local_host_cache_duration_title"),
      description = i18n("prefs.local_host_cache_duration_description"),
    },
  }}, {id="on_disk_ts",    label=i18n("prefs.timeseries"),       advanced=false, pro_only=false,  hidden=false, entries={
    toggle_interface_traffic_rrd_creation = {
      title       = i18n("prefs.toggle_traffic_rrd_creation_title"),
      description = i18n("prefs.toggle_traffic_rrd_creation_description"),
    }, toggle_local_hosts_traffic_rrd_creation = {
      title       = i18n("prefs.toggle_traffic_rrd_creation_title"),
      description = i18n("prefs.toggle_traffic_rrd_creation_description"),
    }, toggle_l2_devices_traffic_rrd_creation = { -- layer 2 devices
      title       = i18n("prefs.toggle_traffic_rrd_creation_title"),
      description = i18n("prefs.toggle_traffic_rrd_creation_description"),
    }, toggle_ndpi_timeseries_creation = {
      title       = i18n("prefs.toggle_ndpi_timeseries_creation_title"),
      description = i18n("prefs.toggle_ndpi_timeseries_creation_description"),
    }, toggle_system_probes_timeseries = {
      title       = i18n("prefs.toggle_system_probes_timeseries_title"),
      description = i18n("prefs.toggle_system_probes_timeseries_description"),
    }, toggle_flow_rrds = {
      title       = i18n("prefs.toggle_flow_rrds_title"),
      description = i18n("prefs.toggle_flow_rrds_description"),
    }, toggle_pools_rrds = {
      title       = i18n(ternary(have_nedge, "prefs.toggle_users_rrds_title", "prefs.toggle_pools_rrds_title")),
      description = i18n(ternary(have_nedge, "prefs.toggle_users_rrds_description", "prefs.toggle_pools_rrds_description")),
    }, toggle_vlan_rrds = {
      title       = i18n("prefs.toggle_vlan_rrds_title"),
      description = i18n("prefs.toggle_vlan_rrds_description"),
    }, toggle_asn_rrds = {
      title       = i18n("prefs.toggle_asn_rrds_title"),
      description = i18n("prefs.toggle_asn_rrds_description"),
    }, toggle_country_rrds = {
      title       = i18n("prefs.toggle_country_rrds_title"),
      description = i18n("prefs.toggle_country_rrds_description"),
    }, toggle_ndpi_flows_rrds = {
      title       = i18n("prefs.toggle_ndpi_flows_rrds_title"),
      description = i18n("prefs.toggle_ndpi_flows_rrds_description"),
      pro_only    = true,
    }, toggle_tcp_flags_rrds = {
      title       = i18n("prefs.toggle_tcp_flags_rrds_title"),
      description = i18n("prefs.toggle_tcp_flags_rrds_description"),
    }, toggle_tcp_retr_ooo_lost_rrds = {
      title       = i18n("prefs.toggle_tcp_retr_ooo_lost_rrds_title"),
      description = i18n("prefs.toggle_tcp_retr_ooo_lost_rrds_description"),
    }, multiple_timeseries_database = {
      title       = i18n("prefs.multiple_timeseries_database_title"),
      description = i18n("prefs.multiple_timeseries_database_description"),
    }, influxdb_url = {
      title       = i18n("prefs.influxdb_url_title"),
      description = i18n("prefs.influxdb_url_description"),
    }, influxdb_dbname = {
      title       = i18n("prefs.influxdb_dbname_title"),
      description = i18n("prefs.influxdb_dbname_description"),
    }, toggle_influx_auth = {
      title       = i18n("prefs.influxdb_auth_title"),
      description = i18n("prefs.influxdb_auth_description"),
    }, influxdb_username = {
      title       = i18n("login.username"),
      description = i18n("prefs.influxdb_username_description"),
    }, influxdb_password = {
      title       = i18n("login.password"),
      description = i18n("prefs.influxdb_password_description"),
    }, timeseries_resolution_resolution = {
      title       = i18n("prefs.timeseries_resolution_resolution_title"),
      description = i18n("prefs.timeseries_resolution_resolution_description"),
    }, influxdb_query_timeout = {
      title       = i18n("prefs.influxdb_query_timeout_title"),
      description = i18n("prefs.influxdb_query_timeout_description"),
    }
  }}, {id="alerts",        label=i18n("show_alerts.alerts"),               advanced=false, pro_only=false,  hidden=(prefs.has_cmdl_disable_alerts == true), entries={
    disable_alerts_generation = {
      title       = i18n("prefs.disable_alerts_generation_title"),
      description = i18n("prefs.disable_alerts_generation_description"),
    }, toggle_remote_to_remote_alerts = {
      title       = i18n("prefs.toggle_remote_to_remote_alerts_title"),
      description = i18n("prefs.toggle_remote_to_remote_alerts_description"),
    }, toggle_ip_reassignment_alerts = {
       title       = i18n("prefs.toggle_ip_reassignment_title"),
       description = i18n("prefs.toggle_ip_reassignment_description"),
    }, max_num_alerts_per_entity = {
      title       = i18n("prefs.max_num_alerts_per_entity_title"),
      description = i18n("prefs.max_num_alerts_per_entity_description"),
    }, max_num_flow_alerts = {
      title       = i18n("prefs.max_num_flow_alerts_title"),
      description = i18n("prefs.max_num_flow_alerts_description"),
    }, toggle_mysql_check_open_files_limit = {
      title       = i18n("prefs.toggle_mysql_check_open_files_limit_title"),
      description = i18n("prefs.toggle_mysql_check_open_files_limit_description"),
      hidden      = (prefs.is_dump_flows_to_mysql_enabled == false),
    }, toggle_device_first_seen_alert = {
      title       =  i18n("prefs.toggle_device_first_seen_alert_title"),
      description = i18n("prefs.toggle_device_first_seen_alert_description"),
    }, toggle_device_activation_alert = {
      title       = i18n("prefs.toggle_device_activation_alert_title"),
      description = i18n("prefs.toggle_device_activation_alert_description"),
    }, toggle_pool_activation_alert = {
      title       = i18n("prefs.toggle_pool_activation_alert_title"),
      description = i18n("prefs.toggle_pool_activation_alert_description"),
    }, toggle_quota_exceeded_alert = {
      title       = i18n("prefs.toggle_quota_exceed_alert_title"),
      description = i18n("prefs.toggle_quota_exceed_alert_description"),
      hidden      = not ntop.isPro(),
    }
    
  }}, {id="ext_alerts",    label=i18n("prefs.alerts_notifications"), advanced=false, hidden=hasAlertsDisabled(), pro_only=false,
    entries = getAlertEndpointsEntries()
  }, {id="protocols",     label=i18n("prefs.protocols"),            advanced=false, pro_only=false,  hidden=false, entries={
    toggle_top_sites = {
      title       = i18n("prefs.toggle_top_sites_title"),
      description = i18n("prefs.toggle_top_sites_description", {url="https://resources.sei.cmu.edu/asset_files/Presentation/2010_017_001_49763.pdf"})},
    ewma_alpha_percent = {
      title       = i18n("prefs.ewma_alpha_percent_title"),
      description = i18n("prefs.ewma_alpha_percent_description"),
    },
  }}, {id="logging",       label=i18n("prefs.logging"),              advanced=false, pro_only=false,  hidden=(prefs.has_cmdl_trace_lvl == true), entries={
    toggle_logging_level = {
      title       = i18n("prefs.toggle_logging_level_title"),
      description = i18n("prefs.toggle_logging_level_description"),
    }, toggle_log_to_file = {
      title       = i18n("prefs.toggle_log_to_file_title"),
      description = i18n("prefs.toggle_log_to_file_description", {product=info["product"]}),
    }, toggle_access_log = {
      title       = i18n("prefs.toggle_access_log_title"),
      description = i18n("prefs.toggle_access_log_description", {product=info["product"]}),
    }, toggle_host_pools_log = {
      title       = i18n("prefs.toggle_host_pools_log_title"),
      description = i18n("prefs.toggle_host_pools_log_description", {product=info["product"]}),
    },
  }}, {id="flow_db_dump",  label=i18n("prefs.flow_database_dump"),   advanced=true,  pro_only=false,  hidden=(prefs.is_dump_flows_enabled == false), entries={
    toggle_flow_db_dump_export = {
      title       = i18n("prefs.toggle_flow_db_dump_export_title"),
      description = i18n("prefs.toggle_flow_db_dump_export_description"),
    }, max_num_packets_per_tiny_flow = {
      title       = i18n("prefs.max_num_packets_per_tiny_flow_title"),
      description = i18n("prefs.max_num_packets_per_tiny_flow_description"),
    }, max_num_bytes_per_tiny_flow = {
      title       = i18n("prefs.max_num_bytes_per_tiny_flow_title"),
      description = i18n("prefs.max_num_bytes_per_tiny_flow_description"),
    }, toggle_aggregated_flows_export_limit = {
      title       = i18n("prefs.toggle_aggregated_flows_export_limit_title"),
      description = i18n("prefs.toggle_aggregated_flows_export_limit_description"),
    }, max_num_aggregated_flows_per_export = {
      title       = i18n("prefs.max_num_aggregated_flows_per_export_title"),
      description = i18n("prefs.max_num_aggregated_flows_per_export_description"),
    }
  }}, {id="snmp",          label=i18n("prefs.snmp"),                 advanced=true,  pro_only=true,   hidden=false, nedge_hidden=true, entries={
    toggle_snmp_rrds = {
      title       = i18n("prefs.toggle_snmp_rrds_title"),
      description = i18n("prefs.toggle_snmp_rrds_description"),
    }, default_snmp_community = {
      title       = i18n("prefs.default_snmp_community_title"),
      description = i18n("prefs.default_snmp_community_description"),
    }, default_snmp_proto_version = {
       title       = i18n("prefs.default_snmp_proto_version_title"),
       description = i18n("prefs.default_snmp_proto_version_description"),
    }, toggle_snmp_debug = {
       title       = i18n("prefs.toggle_snmp_debug_title"),
       description = i18n("prefs.toggle_snmp_debug_description"),
    }
  }}, {id="discovery",     label=i18n("prefs.network_discovery"), advanced=false,  pro_only=false,   hidden=false, entries={
    toggle_network_discovery = {
      title       = i18n("prefs.toggle_network_discovery_title"),
      description = i18n("prefs.toggle_network_discovery_description"),
    }, network_discovery_interval = {
      title       = i18n("prefs.network_discovery_interval_title"),
      description = i18n("prefs.network_discovery_interval_description"),
    },
  }}, {id="telemetry",     label=i18n("prefs.telemetry"), advanced=false,  pro_only=false,   hidden=false, entries={
    toggle_send_telemetry_data = {
      title       = i18n("prefs.toggle_send_telemetry_data_title"),
      description = i18n("prefs.toggle_send_telemetry_data_description", {product = info.product, url = ntop.getHttpPrefix() .. "/lua/telemetry.lua", ntop_org="https://www.ntop.org"}),
    },
    telemetry_email = {
      title       = i18n("prefs.telemetry_email_title"),
      description = i18n("prefs.telemetry_email_description", {product = info.product, url = ntop.getHttpPrefix() .. "/lua/telemetry.lua", ntop_org="https://www.ntop.org"}),
    },
  }}, {id="recording",     label=i18n("prefs.recording"),             advanced=false, pro_only=false,  hidden=(not recording_utils.isAvailable()), entries={
    n2disk_license = {
      title       = i18n("prefs.n2disk_license_title"),
      description = i18n("prefs.n2disk_license_description", { purchase_url='http://shop.ntop.org/', universities_url='http://www.ntop.org/support/faq/do-you-charge-universities-no-profit-and-research/'}),
    },
    max_extracted_pcap_bytes = {
      title       = i18n("traffic_recording.max_extracted_pcap_bytes_title"),
      description = i18n("traffic_recording.max_extracted_pcap_bytes_description"),
    },
  }}, {id="remote_assistance", label=i18n("remote_assistance.remote_assistance"), advanced=true,  pro_only=false, hidden=(not remote_assistance.isAvailable()), entries={
    n2n_supernode = {
      title       = i18n("prefs.n2n_supernode_title"),
      description = i18n("prefs.n2n_supernode_description", {url="https://www.ntop.org/products/n2n"}),
    },
  }}, {id="retention", label=i18n("prefs.data_retention"), advanced=true, pro_only=false, hidden=false, entries={
    data_retention = {
      title       = i18n("prefs.data_retention"),
      description = i18n("prefs.data_retention_descr"),
    },
  }}, {id="misc",          label=i18n("prefs.misc"),                 advanced=false, pro_only=false,  hidden=false, entries={
    toggle_autologout = {
      title       = i18n("prefs.toggle_autologout_title"),
      description = i18n("prefs.toggle_autologout_description"),
    }, toggle_arp_matrix_generation = {
      title       = i18n("prefs.toggle_arp_matrix_generation_title"),
      description = i18n("prefs.toggle_arp_matrix_generation_description", { product = info.product}),
    }, toggle_send_telemetry_data = {
      title       = i18n("prefs.toggle_send_telemetry_data_title"),
      description = i18n("prefs.toggle_send_telemetry_data_description", { product = info.product}),
    }, google_apis_browser_key = {
      title       = i18n("prefs.google_apis_browser_key_title"),
      description = i18n("prefs.google_apis_browser_key_description", {url="https://maps-apis.googleblog.com/2016/06/building-for-scale-updates-to-google.html"}),
    }, toggle_thpt_content = {
      title       = i18n("prefs.toggle_thpt_content_title"),
      description = i18n("prefs.toggle_thpt_content_description"),
    }, max_ui_strlen = {
       title       = i18n("prefs.max_ui_strlen_title"),
       description = i18n("prefs.max_ui_strlen_description"),
    }, mgmt_acl = {
       title       = i18n("prefs.mgmt_acl_title"),
       description = i18n("prefs.mgmt_acl_description", {product=info.product}),
    }, toggle_host_mask = {
      title       = i18n("prefs.toggle_host_mask_title"),
      description = i18n("prefs.toggle_host_mask_description"),
    }, topk_heuristic_precision = {
      title       = i18n("prefs.topk_heuristic_precision_title"),
      description = i18n("prefs.topk_heuristic_precision_description"),
    }
  }}, {id="updates", label=i18n("prefs.updates"), advanced=false, pro_only=false, hidden=false, entries={
    toggle_autoupdates = {
      title       = i18n("prefs.toggle_autoupdates_title"),
      description = i18n("prefs.toggle_autoupdates_description"),
    }
  }},
}

return menu_subpages
