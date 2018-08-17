require "lua_utils"

local prefs = ntop.getPrefs()

local have_nedge = ntop.isnEdge()
local info = ntop.getInfo(false)

-- This table is used both to control access to the preferences and to filter preferences results
local menu_subpages = {
  {id="auth",          label=i18n("prefs.user_authentication"),  advanced=false, pro_only=true, nedge_hidden=true, hidden=false, entries={
    multiple_ldap_authentication = {
      title       = i18n("prefs.multiple_ldap_authentication_title"),
      description = i18n("prefs.multiple_ldap_authentication_description"),
    }, multiple_ldap_account_type = {
      title       = i18n("prefs.multiple_ldap_account_type_title"),
      description = i18n("prefs.multiple_ldap_account_type_description"),
    }, ldap_server_address = {
      title       = i18n("prefs.ldap_server_address_title"),
      description = i18n("prefs.ldap_server_address_description"),
    }, bind_dn = {
      title       = i18n("prefs.bind_dn_title"),
      description = i18n("prefs.bind_dn_description"),
    }, bind_pwd = {
      title       = i18n("prefs.bind_pwd_title"),
      description = i18n("prefs.bind_pwd_description"),
    }, search_path = {
      title       = i18n("prefs.search_path_title"),
      description = i18n("prefs.search_path_description"),
    }, user_group = {
      title       = i18n("prefs.user_group_title"),
      description = i18n("prefs.user_group_description"),
    }, admin_group = {
      title       = i18n("prefs.admin_group_title"),
      description = i18n("prefs.admin_group_description"),
    }, toggle_ldap_anonymous_bind = {
      title       = i18n("prefs.toggle_ldap_anonymous_bind_title"),
      description = i18n("prefs.toggle_ldap_anonymous_bind_description"),
    },
  }}, {id="ifaces",    label=i18n("prefs.network_interfaces"),   advanced=true,  pro_only=false,  hidden=false, nedge_hidden=true, entries={
    dynamic_interfaces_creation = {
      title       = i18n("prefs.dynamic_interfaces_creation_title"),
      description = i18n("prefs.dynamic_interfaces_creation_description"),
    }, ignored_interfaces = {
      title       = i18n("prefs.ignored_interfaces_title"),
      description = i18n("prefs.ignored_interfaces_description", {product=info.product}),
    }, toggle_src_with_post_nat_src = {
      title       = i18n("prefs.toggle_src_with_post_nat_src_title"),
      description = i18n("prefs.toggle_src_with_post_nat_src_description"),
    }, toggle_dst_with_post_nat_dst = {
      title       = i18n("prefs.toggle_dst_with_post_nat_dst_title"),
      description = i18n("prefs.toggle_dst_with_post_nat_dst_description"),
    },
  }}, {id="in_memory",     label=i18n("prefs.cache_settings"),             advanced=true,  pro_only=false,  hidden=false, entries={
    local_host_max_idle = {
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
    }, influxdb_storage = {
      title       = i18n("prefs.influxdb_storage_title"),
      description = i18n("prefs.influxdb_storage_description"),
    }, minute_top_talkers_retention = {
      title       = i18n("prefs.minute_top_talkers_retention_title"),
      description = i18n("prefs.minute_top_talkers_retention_description"),
    }, rrd_files_retention = {
      title       = i18n("prefs.rrd_files_retention_title"),
      description = i18n("prefs.rrd_files_retention_description"),
    }, mysql_retention = {
      title       = i18n("prefs.mysql_retention_title"),
      description = i18n("prefs.mysql_retention_description"),
      hidden      = (prefs.is_dump_flows_to_mysql_enabled == false),
    }
  }}, {id="alerts",        label=i18n("show_alerts.alerts"),               advanced=false, pro_only=false,  hidden=(prefs.has_cmdl_disable_alerts == true), entries={
    disable_alerts_generation = {
      title       = i18n("prefs.disable_alerts_generation_title"),
      description = i18n("prefs.disable_alerts_generation_description"),
    }, toggle_alert_syslog = {
      title       = i18n("prefs.toggle_alert_syslog_title"),
      description = i18n("prefs.toggle_alert_syslog_description"),
    }, toggle_flow_alerts_iface = {
      title       = i18n("prefs.toggle_flow_alerts_iface_title"),
      description = i18n("prefs.toggle_flow_alerts_iface_description"),
    }, toggle_alert_probing = {
      title       = i18n("prefs.toggle_alert_probing_title"),
      description = i18n("prefs.toggle_alert_probing_description"),
    }, toggle_ssl_alerts = {
      title       = i18n("prefs.toggle_ssl_alerts_title"),
      description = i18n("prefs.toggle_ssl_alerts_description"),
    }, toggle_dns_alerts = {
      title       = i18n("prefs.toggle_dns_alerts_title"),
      description = i18n("prefs.toggle_dns_alerts_description"),
    }, toggle_ip_reassignment_alerts = {
       title       = i18n("prefs.toggle_ip_reassignment_title"),
       description = i18n("prefs.toggle_ip_reassignment_description"),	     
    }, toggle_remote_to_remote_alerts = {
      title       = i18n("prefs.toggle_remote_to_remote_alerts_title"),
      description = i18n("prefs.toggle_remote_to_remote_alerts_description"),
    }, toggle_dropped_flows_alerts = {
      title       = i18n("prefs.toggle_dropped_flows_alerts_title"),
      description = i18n("prefs.toggle_dropped_flows_alerts_description"),
    }, toggle_mining_alerts = {
      title       = i18n("prefs.toggle_mining_alerts_title"),
      description = i18n("prefs.toggle_mining_alerts_description"),
    }, toggle_malware_probing = {
      title       = i18n("prefs.toggle_malware_probing_title"),
      description = i18n("prefs.toggle_malware_probing_description", {url="https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"}),
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
    
  }}, {id="ext_alerts",    label=i18n("prefs.alerts_notifications"), advanced=false, hidden=hasAlertsDisabled(), pro_only=false, entries={
    toggle_external_alerts = {
      title       = i18n("prefs.toggle_alerts_notifications_title"),
      description = i18n("prefs.toggle_alerts_notifications_description"),
    },
    toggle_email_notification = {
      title       = i18n("prefs.toggle_email_notification_title"),
      description = i18n("prefs.toggle_email_notification_description"),
    },
    email_notification_sender = {
      title       = i18n("prefs.email_notification_sender_title"),
      description = i18n("prefs.email_notification_sender_description"),
    },
    email_notification_recipient = {
      title       = i18n("prefs.email_notification_recipient_title"),
      description = i18n("prefs.email_notification_recipient_description"),
    },
    email_notification_server = {
      title       = i18n("prefs.email_notification_server_title"),
      description = i18n("prefs.email_notification_server_description"),
    },
    toggle_slack_notification = {
      title       = i18n("prefs.toggle_slack_notification_title", {url="http://www.slack.com"}),
      description = i18n("prefs.toggle_slack_notification_description", {url="https://github.com/ntop/ntopng/blob/dev/doc/README.slack"}),
    }, slack_notification_severity_preference = {
      title       = i18n("prefs.slack_notification_severity_preference_title", {url="http://www.slack.com"}),
      description = i18n("prefs.slack_notification_severity_preference_description"),
    }, sender_username = {
      title       = i18n("prefs.sender_username_title"),
      description = i18n("prefs.sender_username_description"),
    }, slack_webhook = {
      title       = i18n("prefs.slack_webhook_title"),
      description = i18n("prefs.slack_webhook_description"),
    },
  }}, {id="protocols",     label=i18n("prefs.protocols"),            advanced=false, pro_only=false,  hidden=false, entries={
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
    },
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
    },
  }}, {id="nbox",          label=i18n("prefs.nbox_integration"),     advanced=true,  pro_only=true,  nedge_hidden=true, hidden=false, entries={
    toggle_nbox_integration = {
      title       = i18n("prefs.toggle_nbox_integration_title"),
      description = i18n("prefs.toggle_nbox_integration_description"),
    }, nbox_user = {
      title       = i18n("prefs.nbox_user_title"),
      description = i18n("prefs.nbox_user_description"),
    }, nbox_password = {
      title       = i18n("prefs.nbox_password_title"),
      description = i18n("prefs.nbox_password_description"),
    },
  }}, {id="discovery",     label=i18n("prefs.network_discovery"),     advanced=false,  pro_only=false,   hidden=false, entries={
    toggle_network_discovery = {
      title       = i18n("prefs.toggle_network_discovery_title"),
      description = i18n("prefs.toggle_network_discovery_description"),
    }, network_discovery_interval = {
      title       = i18n("prefs.network_discovery_interval_title"),
      description = i18n("prefs.network_discovery_interval_description"),
    },
  }}, {id="misc",          label=i18n("prefs.misc"),                 advanced=false, pro_only=false,  hidden=false, entries={
    toggle_autologout = {
      title       = i18n("prefs.toggle_autologout_title"),
      description = i18n("prefs.toggle_autologout_description"),
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
    },
  }}, {id="bridging",      label=i18n("prefs.traffic_bridging"),     advanced=false,  pro_only=true,   enterprise_only=true, hidden=(not hasBridgeInterfaces()), nedge_hidden=true, entries={
    safe_search_dns = {
      title       = i18n("prefs.safe_search_dns_title"),
      description = i18n("prefs.safe_search_dns_description", {url="https://en.wikipedia.org/wiki/SafeSearch"}),
    }, global_dns = {
      title       = i18n("prefs.global_dns_title"),
      description = i18n("prefs.global_dns_description"),
    }, secondary_dns = {
      title       = i18n("prefs.secondary_dns_title"),
      description = i18n("prefs.secondary_dns_description"),
    }, featured_dns = {
      title       = i18n("prefs.featured_dns_title"),
      description = i18n("prefs.featured_dns_description"),
    }, toggle_shaping_directions = {
      title       = i18n("prefs.toggle_shaping_directions_title"),
      description = i18n("prefs.toggle_shaping_directions_description"),
    }, toggle_captive_portal = {
      title       = i18n("prefs.toggle_captive_portal_title"),
      description = i18n("prefs.toggle_captive_portal_description"),
    }, captive_portal_url = {
      title       = i18n("prefs.captive_portal_url_title"),
      description = i18n("prefs.captive_portal_url_description"),
    }, policy_target_type = {
      title       = i18n("prefs.policy_target_type"),
      description = i18n("prefs.policy_target_type_description"),
    }
  }},
}

-- Add nagios configuration (if available)
-- Presently, nagios is not available under windows
if hasNagiosSupport() then
   for _, i in pairs(menu_subpages) do
      if i["id"] == "ext_alerts" then
	 local nagios = {
	    toggle_alert_nagios = {
	       title       = i18n("prefs.toggle_alert_nagios_title"),
	       description = i18n("prefs.toggle_alert_nagios_description"),
	    }, nagios_nsca_host = {
	       title       = i18n("prefs.nagios_nsca_host_title"),
	       description = i18n("prefs.nagios_nsca_host_description"),
	    }, nagios_nsca_port = {
	       title       = i18n("prefs.nagios_nsca_port_title"),
	       description = i18n("prefs.nagios_nsca_port_description"),
	    }, nagios_send_nsca_executable = {
	       title       = i18n("prefs.nagios_send_nsca_executable_title"),
	       description = i18n("prefs.nagios_send_nsca_executable_description"),
	    }, nagios_send_nsca_config = {
	       title       = i18n("prefs.nagios_send_nsca_config_title"),
	       description = i18n("prefs.nagios_send_nsca_config_description"),
	    }, nagios_host_name = {
	       title       = i18n("prefs.nagios_host_name_title"),
	       description = i18n("prefs.nagios_host_name_description", {product=info["product"]}),
	    }, nagios_service_name = {
	       title       = i18n("prefs.nagios_service_name_title"),
	       description = i18n("prefs.nagios_service_name_description", {product=info["product"]}),
	    },
	 }
	 i["entries"] = table.merge(i["entries"], nagios)
      end
   end
end

return menu_subpages
