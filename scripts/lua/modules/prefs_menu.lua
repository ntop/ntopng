require "lua_utils"

local recording_utils = require "recording_utils"

local prefs = ntop.getPrefs()

local have_nedge = ntop.isnEdge()
local is_windows = ntop.isWindows()
local info = ntop.getInfo(false)
local hasRadius = ntop.hasRadiusSupport()
local hasLdap = ntop.hasLdapSupport()

-- This table is used both to control access to the preferences and to filter preferences results
local menu_subpages = {{
    id = "active_monitoring",
    label = i18n("active_monitoring_stats.active_monitoring"),
    advanced = false,
    pro_only = false,
    hidden = false,
    entries = {
        toggle_active_monitoring = {
            title = i18n("prefs.toggle_active_monitoring_title"),
            description = i18n("prefs.toggle_active_monitoring_description")
        },
    }
},{
    id = "alerts",
    label = i18n("show_alerts.alerts"),
    advanced = false,
    pro_only = false,
    hidden = (prefs.has_cmdl_disable_alerts == true),
    entries = {
        disable_alerts_generation = {
            title = i18n("prefs.disable_alerts_generation_title"),
            description = i18n("prefs.disable_alerts_generation_description")
        },
        max_entity_alerts = {
            title = i18n("prefs.max_entity_alerts_title"),
            description = i18n("prefs.max_entity_alerts_description")
        },
        max_num_secs_before_delete_alert = {
            title = i18n("prefs.max_num_secs_before_delete_alert_title"),
            description = i18n("prefs.max_num_secs_before_delete_alert_description")
        },
        toggle_mysql_check_open_files_limit = {
            title = i18n("prefs.toggle_mysql_check_open_files_limit_title"),
            description = i18n("prefs.toggle_mysql_check_open_files_limit_description"),
            hidden = (prefs.is_dump_flows_to_mysql_enabled == false)
        },
        toggle_emit_flow_alerts = {
            title = i18n("prefs.toggle_emit_flow_alerts_title"),
            description = i18n("prefs.toggle_emit_flow_alerts_description")
        },
        toggle_emit_host_alerts = {
            title = i18n("prefs.toggle_emit_host_alerts_title"),
            description = i18n("prefs.toggle_emit_host_alerts_description")
        },
        alert_page_refresh_rate_enabled = {
            title = i18n("prefs.enable_alerts_refresh_title"),
            description = i18n("prefs.enable_alerts_refresh_description")
        },
        alert_page_refresh_rate = {
            title = i18n("prefs.alerts_page_refresh_rate__title"),
            description = i18n("prefs.alerts_page_refresh_rate_description")
        }
    }
}, {
    id = "protocols",
    label = i18n("prefs.protocols"),
    advanced = false,
    pro_only = true,
    hidden = false,
    entries = {
        toggle_top_sites = {
            title = i18n("prefs.toggle_top_sites_title"),
            description = i18n("prefs.toggle_top_sites_description", {
                url = "https://resources.sei.cmu.edu/asset_files/Presentation/2010_017_001_49763.pdf"
            })
        },
        toggle_sites_collection = {
            title = i18n("prefs.toggle_sites_collection_title"),
            description = i18n("prefs.toggle_sites_collection_description")
        },
        toggle_dns_cache = {
            title = i18n("prefs.toggle_dns_cache_title"),
            description = i18n("prefs.toggle_dns_cache_description")
        },
        toggle_tls_quic_hostnaming = {
            title = i18n("prefs.toggle_tls_quic_hostnaming_title"),
            description = i18n("prefs.toggle_tls_quic_hostnaming_description")
        }
    }
}, {
    id = "assets_inventory",
    label = i18n("prefs.assets_inventory"),
    advanced = false,
    pro_only = false,
    --hidden = not ntop.isEnterpriseXL(),
    hidden = true,
    entries = {
        toggle_ntopng_assets_inventory = {
            title = i18n("prefs.toggle_ntopng_assets_inventory_title"),
            description = i18n("prefs.toggle_ntopng_assets_inventory_description")
        },
        toggle_netbox = {
            title = i18n("prefs.toggle_netbox_title"),
            description = i18n("prefs.toggle_netbox_description")
        },
        netbox_activation_url = {
            title = i18n("prefs.netbox_activation_url_title"),
            description = i18n("prefs.netbox_activation_url_description")
        },
        netbox_default_site = {
            title = i18n("prefs.netbox_default_site"),
            description = i18n("prefs.netbox_default_site_description")
        },
        netbox_personal_access_token = {
            title = i18n("prefs.netbox_personal_access_token_title"),
            description = i18n("prefs.netbox_personal_access_token_description")
        }
    }
},
{
    id = "traffic_behaviour",
    label = i18n("prefs.behaviour"),
    advanced = true,
    hidden = not ntop.isEnterprise(),
    entries = {
        toggle_behaviour_analysis = {
            title = i18n("prefs.toggle_behaviour_analysis_title"),
            description = i18n("prefs.toggle_behaviour_analysis_description")
        },
        behaviour_analysis_learning_period = {
            title = i18n("prefs.behaviour_analysis_learning_period_title"),
            description = i18n("prefs.behaviour_analysis_learning_period_description")
        },
        behaviour_analysis_learning_status_during_learning = {
            title = i18n("prefs.behaviour_analysis_status_during_learning_title"),
            description = i18n("prefs.behaviour_analysis_status_during_learning_description")
        },
        behaviour_analysis_learning_status_post_learning = {
            title = i18n("prefs.behaviour_analysis_status_post_learning_title"),
            description = i18n("prefs.behaviour_analysis_status_post_learning_description")
        },
        devices_learning_period = {
            title = i18n("prefs.devices_learning_period_title"),
            description = i18n("prefs.devices_learning_period_description")
        },
        devices_status_during_learning = {
            title = i18n("prefs.devices_status_during_learning_title"),
            description = i18n("prefs.devices_status_during_learning_description")
        },
        devices_status_post_learning = {
            title = i18n("prefs.devices_status_post_learning_title"),
            description = i18n("prefs.devices_status_post_learning_description")
        },
        host_port_learning_period = {
            title = i18n("prefs.host_port_learning_period_title"),
            description = i18n("prefs.host_port_learning_period_description")
        },
    }
}, {
    id = "in_memory",
    label = i18n("prefs.cache_settings"),
    advanced = true,
    pro_only = false,
    hidden = false,
    entries = {
        toggle_midnight_stats_reset = {
            title = i18n("prefs.toggle_midnight_stats_reset_title"),
            description = i18n("prefs.toggle_midnight_stats_reset_description")
        },
        local_host_max_idle = {
            title = i18n("prefs.local_host_max_idle_title"),
            description = i18n("prefs.local_host_max_idle_description")
        },
        non_local_host_max_idle = {
            title = i18n("prefs.non_local_host_max_idle_title"),
            description = i18n("prefs.non_local_host_max_idle_description")
        },
        flow_max_idle = {
            title = i18n("prefs.flow_max_idle_title"),
            description = i18n("prefs.flow_max_idle_description")
        },
        toggle_local_host_cache_enabled = {
            title = i18n("prefs.toggle_local_host_cache_enabled_title"),
            description = i18n("prefs.toggle_local_host_cache_enabled_description")
        },
        toggle_active_local_host_cache_enabled = {
            title = i18n("prefs.toggle_active_local_host_cache_enabled_title"),
            description = i18n("prefs.toggle_active_local_host_cache_enabled_description")
        },
        toggle_assets_collection = {
            title = i18n("prefs.toggle_assets_collection"),
            description = i18n("prefs.toggle_assets_collection_description")
        },
        active_local_host_cache_interval = {
            title = i18n("prefs.active_local_host_cache_interval_title"),
            description = i18n("prefs.active_local_host_cache_interval_description")
        },
        local_host_cache_duration = {
            title = i18n("prefs.local_host_cache_duration_title"),
            description = i18n("prefs.local_host_cache_duration_description")
        },
        mac_address_cache_duration = {
            title = i18n("prefs.mac_address_cache_duration_title"),
            description = i18n("prefs.mac_address_cache_duration_description")
        }
    }
}, {
    id = "clickhouse",
    label = i18n("prefs.clickhouse"),
    advanced = true,
    pro_only = true,
    hidden = not ((ntop.isEnterpriseM() or ntop.isnEdgeEnterprise()) and ntop.isClickHouseEnabled()),
    entries = {
        flow_data_retention = {
            title = i18n("prefs.flows_and_alerts_data_retention"),
            description = i18n("prefs.flows_and_alerts_data_retention_descr")
        },
        aggregated_flows_data_retention = {
            title = i18n("prefs.aggregated_flows_data_retention_title"),
            description = i18n("prefs.aggregated_flows_data_retention_descr")
        },
        toggle_flow_aggregated_alerted_flows = {
            title = i18n("prefs.toggle_flow_aggregated_alerted_flows_title"),
            description = i18n("prefs.toggle_flow_aggregated_alerted_flows_description")
        },
        toggle_flow_aggregated_limit = {
            title = i18n("prefs.toggle_flow_aggregated_limit_title"),
            description = i18n("prefs.toggle_flow_aggregated_limit_description")
        },
        toggle_flow_aggregated_traffic_limit = {
            title = i18n("prefs.toggle_flow_aggregated_traffic_limit_title"),
            description = i18n("prefs.toggle_flow_aggregated_traffic_limit_description")
        }
    }
}, {
    id = "dump_settings",
    label = i18n("prefs.dump_settings"),
    advanced = true,
    pro_only = false,
    hidden = (prefs.is_dump_flows_enabled == false),
    entries = {
        toggle_enable_runtime_flows_dump = {
            title = i18n("prefs.toggle_enable_runtime_flows_dump_title"),
            description = i18n("prefs.toggle_enable_runtime_flows_dump_description")
        },
        dump_frequency = {
            title = i18n("prefs.dump_frequency_title"),
            description = i18n("prefs.dump_frequency_description")
        },
        toggle_tiny_flows_dump = {
            title = i18n("prefs.toggle_tiny_flows_dump_title"),
            description = i18n("prefs.toggle_tiny_flows_dump_description")
        },
        max_num_packets_per_tiny_flow = {
            title = i18n("prefs.max_num_packets_per_tiny_flow_title"),
            description = i18n("prefs.max_num_packets_per_tiny_flow_description")
        },
        max_num_bytes_per_tiny_flow = {
            title = i18n("prefs.max_num_bytes_per_tiny_flow_title"),
            description = i18n("prefs.max_num_bytes_per_tiny_flow_description")
        },
        toggle_flow_aggregated_alerted_flows = {
            title = i18n("prefs.toggle_flow_aggregated_alerted_flows_title"),
            description = i18n("prefs.toggle_flow_aggregated_alerted_flows_description")
        },
        toggle_flow_aggregated_limit = {
            title = i18n("prefs.toggle_flow_aggregated_limit_title"),
            description = i18n("prefs.toggle_flow_aggregated_limit_description")
        },
        toggle_flow_aggregated_traffic_limit = {
            title = i18n("prefs.toggle_flow_aggregated_traffic_limit_title"),
            description = i18n("prefs.toggle_flow_aggregated_traffic_limit_description")
        }
    }
}, {
    id = "logging",
    label = i18n("prefs.logging"),
    advanced = false,
    pro_only = false,
    hidden = (prefs.has_cmdl_trace_lvl == true),
    entries = {
        toggle_logging_level = {
            title = i18n("prefs.toggle_logging_level_title"),
            description = i18n("prefs.toggle_logging_level_description")
        },
        toggle_log_to_file = {
            title = i18n("prefs.toggle_log_to_file_title"),
            description = i18n("prefs.toggle_log_to_file_description", {
                product = info["product"]
            })
        },
        toggle_access_log = {
            title = i18n("prefs.toggle_access_log_title"),
            description = i18n("prefs.toggle_access_log_description", {
                product = info["product"]
            })
        },
        toggle_host_pools_log = {
            title = i18n("prefs.toggle_host_pools_log_title"),
            description = i18n("prefs.toggle_host_pools_log_description", {
                product = info["product"]
            })
        },
        toggle_asset_inventory_log = {
            title = i18n("prefs.toggle_asset_inventory_log_title"),
            description = i18n("prefs.toggle_asset_inventory_log_description")
        }
    }
}, {
    id = "message_broker",
    label = i18n("prefs.message_broker"),
    advanced = false,
    pro_only = false,    
    hidden = not (ntop.isEnterpriseM()),
    entries = {
        toggle_message_broker = {
            title = i18n("prefs.toggle_message_broker_title"),
            description = i18n("prefs.toggle_message_broker_description")
        },
        message_brokers_list = {
            title = i18n("prefs.message_brokers_title"),
            description = i18n("prefs.message_brokers_description")
        },
        message_broker_url = {
            title = i18n("prefs.message_broker_url_title"),
            description = i18n("prefs.message_broker_url_description")
        },
        message_broker_username = {
            title = i18n("login.username"),
            description = i18n("prefs.message_broker_username_description")
        },
        message_broker_password = {
            title = i18n("login.password"),
            description = i18n("prefs.message_broker_password_description")
        },
    }
}, {
    id = "misc",
    label = i18n("prefs.misc"),
    advanced = false,
    pro_only = false,
    hidden = false,
    entries = {
        connectivity_check_url = {
            title = i18n("prefs.connectivity_check_url_title"),
            description = i18n("prefs.connectivity_check_url_description")
        },
        toggle_thpt_content = {
            title = i18n("prefs.toggle_thpt_content_title"),
            description = i18n("prefs.toggle_thpt_content_description")
        },
        toggle_host_mask = {
            title = i18n("prefs.toggle_host_mask_title"),
            description = i18n("prefs.toggle_host_mask_description")
        },
        toggle_fingerprint_stats = {
            title = i18n("prefs.toggle_fingerprint_stats_title"),
            description = i18n("prefs.toggle_fingerprint_stats_description")
        }, 
        toggle_use_mac_in_flow_key = {
            title = i18n("prefs.toggle_use_mac_in_flow_key_title"),
            description = i18n("prefs.toggle_use_mac_in_flow_key_description")
        },
        topk_heuristic_precision = {
            title = i18n("prefs.topk_heuristic_precision_title"),
            description = i18n("prefs.topk_heuristic_precision_description")
        },
        toggle_flow_begin = {
            title = i18n("prefs.flow_table_begin_epoch_title"),
            description = i18n("prefs.flow_table_begin_epoch_description")
        },
        flow_table_time = {
            title = i18n("prefs.flow_table_time_title"),
            description = i18n("prefs.flow_table_time_description")
        },
        flow_table_probe_order = {
            title = i18n("prefs.flow_table_probe_order_title"),
            description = i18n("prefs.flow_table_probe_order_description")
        }
    }
}, {
    id = "names",
    label = i18n("prefs.names"),
    advanced = false,
    hidden = false,
    entries = {
        ntopng_host_address = {
            title = i18n("prefs.ntopng_host_address_title"),
            description = i18n("prefs.ntopng_host_address_description")
        },
        ntopng_instance_name = {
            title = i18n("prefs.ntopng_instance_name_title"),
            description = i18n("prefs.ntopng_instance_name_description")
        }
    }
}, {
    id = "discovery",
    label = i18n("prefs.network_discovery"),
    advanced = false,
    pro_only = false,
    hidden = false,
    entries = {
        toggle_network_discovery = {
            title = i18n("active_monitoring_stats.network_discovery"),
            description = i18n("active_monitoring_stats.network_discovery_description")
        },
        toggle_periodic_network_discovery = {
            title = i18n("prefs.toggle_network_discovery_title"),
            description = i18n("prefs.toggle_network_discovery_description")
        },
        network_discovery_interval = {
            title = i18n("prefs.network_discovery_interval_title"),
            description = i18n("prefs.network_discovery_interval_description")
        },
        toggle_network_discovery_debug = {
            title = i18n("prefs.toggle_network_discovery_debug_title"),
            description = i18n("prefs.toggle_network_discovery_debug_description")
        }
    }
}, {
    id = "ifaces",
    label = i18n("prefs.network_interfaces"),
    advanced = true,
    pro_only = false,
    hidden = false,
    nedge_hidden = true,
    entries = {
        ignored_interfaces = {
            title = i18n("prefs.ignored_interfaces_title"),
            description = i18n("prefs.ignored_interfaces_description", {
                product = info.product
            })
        },
        toggle_src_with_post_nat_src = {
            title = i18n("prefs.toggle_src_with_post_nat_src_title"),
            description = i18n("prefs.toggle_src_with_post_nat_src_description")
        },
        toggle_dst_with_post_nat_dst = {
            title = i18n("prefs.toggle_dst_with_post_nat_dst_title"),
            description = i18n("prefs.toggle_dst_with_post_nat_dst_description")
        }
    }
}, {
    id = "ot_protocols",
    label = i18n("prefs.ot_protocols"),
    advanced = true,
    hidden = false,
    entries = {
        iec60870_learning_period = {
            title = i18n("prefs.iec60870_learning_period_title"),
            description = i18n("prefs.iec60870_learning_period_description")
        },
        modbus_learning_period = {
            title = i18n("prefs.modbus_learning_period_title"),
            description = i18n("prefs.modbus_learning_period_description")
        }
    }
}, {
    id = "reports",
    label = i18n("prefs.reports"),
    advanced = false,
    pro_only = true,
    hidden = not (ntop.isEnterpriseL()),
    entries = {
        toggle_enable_automatic_reports = {
            title = i18n("prefs.toggle_enable_automatic_reports_title"),
            description = i18n("prefs.toggle_enable_automatic_reports_descr")
        },
        reports_data_retention_time = {
            title = i18n("prefs.reports_data_retention_time_title"),
            description = i18n("prefs.reports_data_retention_time_descr")
        }
    }
}, {
    id = "snmp",
    label = i18n("prefs.snmp"),
    advanced = true,
    pro_only = true,
    hidden = false,
    nedge_hidden = false,
    entries = {
        toggle_snmp_rrds = {
            title = i18n("prefs.toggle_snmp_rrds_title"),
            description = i18n("prefs.toggle_snmp_rrds_description")
        },
        toggle_snmp_polling = {
            title = i18n("prefs.toggle_snmp_polling_title"),
            description = i18n("prefs.toggle_snmp_polling_description")
        },
        default_snmp_community = {
            title = i18n("prefs.default_snmp_community_title"),
            description = i18n("prefs.default_snmp_community_description")
        },
        default_snmp_proto_version = {
            title = i18n("prefs.default_snmp_proto_version_title"),
            description = i18n("prefs.default_snmp_proto_version_description")
        },
        default_snmp_timeout = {
            title = i18n("prefs.default_snmp_timeout_title"),
            description = i18n("prefs.default_snmp_timeout_description")
        },
        toggle_snmp_debug = {
            title = i18n("prefs.toggle_snmp_debug_title"),
            description = i18n("prefs.toggle_snmp_debug_description")
        },
        toggle_snmp_trap = {
            title = i18n("prefs.toggle_snmp_trap_title"),
            description = i18n("prefs.toggle_snmp_trap_description")
        },
        toggle_snmp_excluded_from_usage = {
            title = i18n("prefs.toggle_snmp_excluded_from_usage_title"),
            description = i18n("prefs.toggle_snmp_excluded_from_usage_description")
        }
    }
}, {
    id = "on_disk_ts",
    label = i18n("prefs.timeseries"),
    advanced = false,
    pro_only = false,
    hidden = false,
    entries = {
        toggle_interface_traffic_rrd_creation = {
            title = i18n("prefs.toggle_traffic_rrd_creation_title"),
            description = i18n("prefs.toggle_traffic_rrd_creation_description")
        },
        toggle_local_hosts_ts_creation = {
            title = i18n("prefs.toggle_local_hosts_ts_creation_title"),
            description = i18n("prefs.toggle_local_hosts_ts_creation_description")
        },
        toggle_local_hosts_one_way_ts = {
            title = i18n("prefs.toggle_local_hosts_one_way_ts_title"),
            description = i18n("prefs.toggle_local_hosts_one_way_ts_description")
        },
        toggle_l2_devices_traffic_rrd_creation = { -- layer 2 devices
            title = i18n("prefs.toggle_traffic_rrd_creation_title"),
            description = i18n("prefs.toggle_traffic_rrd_creation_description")
        },
        toggle_ndpi_timeseries_creation = {
            title = i18n("prefs.toggle_ndpi_timeseries_creation_title"),
            description = i18n("prefs.toggle_ndpi_timeseries_creation_description")
        },
        toggle_system_probes_timeseries = {
            title = i18n("prefs.toggle_system_probes_timeseries_title"),
            description = i18n("prefs.toggle_system_probes_timeseries_description")
        },
        toggle_interface_usage_probes_timeseries = {
            title = i18n("prefs.toggle_exporter_interface_usage_timeseries_title"),
            description = i18n("prefs.toggle_exporter_interface_usage_timeseries_description")
        },
        toggle_exporters_ndpi_ts_creation = {
            title = i18n("prefs.toggle_exporters_ndpi_ts_creation_title"),
            description = i18n("prefs.toggle_exporters_ndpi_ts_creation_description")
        },
        ts_data_retention = {
            title = i18n("prefs.ts_and_stats_data_retention"),
            description = i18n("prefs.ts_and_stats_data_retention_descr")
        },
        toggle_observation_points_rrd_creation = {
            title = i18n("prefs.toggle_observation_points_rrds_title"),
            description = i18n("prefs.toggle_observation_points_rrds_description")
        },
        toggle_intranet_traffic_rrd_creation = {
            title = i18n("prefs.toggle_intranet_traffic_rrds_title"),
            description = i18n("prefs.toggle_intranet_traffic_rrds_description")
        },
        toggle_flow_rrds = {
            title = i18n("prefs.toggle_flow_rrds_title"),
            description = i18n("prefs.toggle_flow_rrds_description")
        },
        toggle_flow_rrds_resolution = {
            title = i18n("prefs.toggle_flow_rrds_resolution_title"),
            description = i18n("prefs.toggle_flow_rrds_resolution_description")
        },
        toggle_pools_rrds = {
            title = i18n(ternary(have_nedge, "prefs.toggle_users_rrds_title", "prefs.toggle_pools_rrds_title")),
            description = i18n(ternary(have_nedge, "prefs.toggle_users_rrds_description",
                "prefs.toggle_pools_rrds_description"))
        },
        toggle_vlan_rrds = {
            title = i18n("prefs.toggle_vlan_rrds_title"),
            description = i18n("prefs.toggle_vlan_rrds_description")
        },
        toggle_asn_rrds = {
            title = i18n("prefs.toggle_asn_rrds_title"),
            description = i18n("prefs.toggle_asn_rrds_description")
        },
        toggle_country_rrds = {
            title = i18n("prefs.toggle_country_rrds_title"),
            description = i18n("prefs.toggle_country_rrds_description")
        },
        toggle_os_rrds = {
            title = i18n("prefs.toggle_os_rrds_title"),
            description = i18n("prefs.toggle_os_rrds_description")
        },
        toggle_ndpi_flows_rrds = {
            title = i18n("prefs.toggle_ndpi_flows_rrds_title"),
            description = i18n("prefs.toggle_ndpi_flows_rrds_description"),
            pro_only = true
        },
        toggle_internals_rrds = {
            title = i18n("prefs.toggle_internals_rrds_title") .. " <i class=\"fas fa-sm fa-wrench\"></i>",
            description = i18n("prefs.toggle_internals_rrds_description", {
                url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=internals"
            })
        },
        multiple_timeseries_database = {
            title = i18n("prefs.multiple_timeseries_database_title"),
            description = i18n("prefs.multiple_timeseries_database_description")
        },
        influxdb_url = {
            title = i18n("prefs.influxdb_url_title"),
            description = i18n("prefs.influxdb_url_description")
        },
        influxdb_dbname = {
            title = i18n("prefs.influxdb_dbname_title"),
            description = i18n("prefs.influxdb_dbname_description")
        },
        toggle_influx_auth = {
            title = i18n("prefs.influxdb_auth_title"),
            description = i18n("prefs.influxdb_auth_description")
        },
        influxdb_username = {
            title = i18n("login.username"),
            description = i18n("prefs.influxdb_username_description")
        },
        influxdb_password = {
            title = i18n("login.password"),
            description = i18n("prefs.influxdb_password_description")
        },
        timeseries_resolution_resolution = {
            title = i18n("prefs.timeseries_resolution_resolution_title"),
            description = i18n("prefs.timeseries_resolution_resolution_description_2")
        },
        influxdb_query_timeout = {
            title = i18n("prefs.influxdb_query_timeout_title"),
            description = i18n("prefs.influxdb_query_timeout_description")
        }
    }
}, {
    id = "recording",
    label = i18n("prefs.recording"),
    advanced = false,
    pro_only = false,
    hidden = (not recording_utils.isAvailable()),
    entries = {
        n2disk_license = {
            title = i18n("prefs.n2disk_license_title"),
            description = i18n("prefs.n2disk_license_description", {
                purchase_url = 'http://shop.ntop.org/',
                universities_url = 'http://www.ntop.org/support/faq/do-you-charge-universities-no-profit-and-research/'
            })
        },
        max_extracted_pcap_bytes = {
            title = i18n("traffic_recording.max_extracted_pcap_bytes_title"),
            description = i18n("traffic_recording.max_extracted_pcap_bytes_description")
        }
    }
}, {
    id = "updates",
    label = i18n("prefs.updates"),
    advanced = false,
    pro_only = false,
    hidden = (is_windows or (not ntop.isPackage())),
    entries = {
        toggle_autoupdates = {
            title = i18n("prefs.toggle_autoupdates_title"),
            description = i18n("prefs.toggle_autoupdates_description", {
                product = info.product
            })
        }
    }
}, {
    id = "auth",
    label = i18n("prefs.user_authentication"),
    advanced = false,
    pro_only = false,
    nedge_hidden = false,
    hidden = (not (prefs.is_users_login_enabled) and not have_nedge),
    entries = {
        authentication_duration = {
            title = i18n("prefs.authentication_duration_title"),
            description = i18n("prefs.authentication_duration_descr")
        },
        toggle_auth_session_midnight_expiration = {
            title = i18n("prefs.authentication_midnight_expiration_title"),
            description = i18n("prefs.authentication_midnight_expiration_descr")
        },
        toggle_ldap_auth = {
            title = i18n("prefs.toggle_ldap_auth"),
            description = i18n("prefs.toggle_ldap_auth_descr"),
            hidden = (not hasLdap)
        },
        toggle_radius_accounting = {
            title = i18n("prefs.toggle_radius_accounting"),
            description = i18n("prefs.toggle_radius_accounting_descr", {
                product = info.product
            }),
            hidden = (not hasRadius or not have_nedge)
        },
        toggle_radius_auth = {
            title = i18n("prefs.toggle_radius_auth"),
            description = i18n("prefs.toggle_radius_auth_descr", {
                product = info.product
            }),
            hidden = (not hasRadius)
        },
        toggle_radius_external_auth_for_local_users = {
            title = i18n("prefs.toggle_radius_external_auth_for_local_users"),
            description = i18n("prefs.toggle_radius_external_auth_for_local_users_descr", {
                product = info.product
            }),
            hidden = (not hasRadius or not have_nedge)
        },
        toggle_http_auth = {
            title = i18n("prefs.toggle_http_auth"),
            description = i18n("prefs.toggle_http_auth_descr"),
            hidden = have_nedge
        },
        toggle_local_auth = {
            title = i18n("prefs.toggle_local_auth"),
            description = i18n("prefs.toggle_local_auth_descr", {
                product = info.product
            })
        },
        multiple_ldap_account_type = {
            title = i18n("prefs.multiple_ldap_account_type_title"),
            description = i18n("prefs.multiple_ldap_account_type_description"),
            hidden = (not hasLdap)
        },
        ldap_server_address = {
            title = i18n("prefs.ldap_server_address_title"),
            description = i18n("prefs.ldap_server_address_description"),
            hidden = (not hasLdap)
        },
        bind_dn = {
            title = i18n("prefs.bind_dn_title"),
            description = i18n("prefs.bind_dn_description"),
            hidden = (not hasLdap)
        },
        bind_pwd = {
            title = i18n("prefs.bind_pwd_title"),
            description = i18n("prefs.bind_pwd_description"),
            hidden = (not hasLdap)
        },
        search_path = {
            title = i18n("prefs.search_path_title"),
            description = i18n("prefs.search_path_description"),
            hidden = (not hasLdap)
        },
        user_group = {
            title = i18n("prefs.user_group_title"),
            description = i18n("prefs.user_group_description"),
            hidden = (not hasLdap)
        },
        admin_group = {
            title = i18n("prefs.admin_group_title"),
            description = i18n("prefs.admin_group_description"),
            hidden = (not hasLdap)
        },
        toggle_ldap_anonymous_bind = {
            title = i18n("prefs.toggle_ldap_anonymous_bind_title"),
            description = i18n("prefs.toggle_ldap_anonymous_bind_description"),
            hidden = (not hasLdap)
        },
        toggle_ldap_referrals = {
            title = i18n("prefs.toggle_ldap_referrals_title"),
            description = i18n("prefs.toggle_ldap_referrals_description"),
            hidden = (not hasLdap)
        },
        toggle_ldap_debug = {
            title = i18n("prefs.toggle_ldap_debug_title"),
            description = i18n("prefs.toggle_ldap_debug_description")
        },
        radius_server = {
            title = i18n("prefs.radius_server_title"),
            description = i18n("prefs.radius_server_description", {
                example = "127.0.0.1:1812"
            }),
            hidden = (not hasRadius)
        },
        radius_accounting_server = {
            title = i18n("prefs.radius_accounting_server_title"),
            description = i18n("prefs.radius_accounting_server_description", {
                example = "127.0.0.1:1813"
            }),
            hidden = (not hasRadius)
        },
        radius_secret = {
            title = i18n("prefs.radius_secret_title"),
            description = i18n("prefs.radius_secret_descroption"),
            hidden = (not hasRadius)
        },
        radius_auth_proto = {
            title = i18n("prefs.radius_auth_proto_title"),
            description = i18n("prefs.radius_auth_proto_description"),
            hidden = (not hasRadius)
        },
        radius_admin_group = {
            title = i18n("prefs.radius_admin_group_title"),
            description = i18n("prefs.radius_admin_group_description"),
            hidden = (not hasRadius)
        },
        radius_unpriv_capabilties_group = {
            title = i18n("prefs.radius_unpriv_capabilties_group_title"),
            description = i18n("prefs.radius_unpriv_capabilties_group_description"),
            hidden = (not hasRadius)
        },
        http_auth_server = {
            title = i18n("prefs.http_auth_server_title"),
            description = i18n("prefs.http_auth_server_description"),
            hidden = have_nedge
        },
        toggle_client_x509_auth = {
            title = i18n("prefs.client_x509_auth_title", {
                product = info.product
            }),
            description = i18n("prefs.client_x509_auth_descr", {
                product = info.product
            })
        }
    }
}, {
    id = "gui",
    label = i18n("prefs.gui"),
    advanced = false,
    pro_only = false,
    hidden = false,
    entries = {
        toggle_date_type = {
            title = i18n("prefs.toggle_date_type_title"),
            description = i18n("prefs.toggle_date_type_description")
        },
        toggle_autologout = {
            title = i18n("prefs.toggle_autologout_title"),
            description = i18n("prefs.toggle_autologout_description")
        },
        toggle_interface_name_only = {
            title = i18n("prefs.toggle_interface_name_only_title"),
            description = i18n("prefs.toggle_interface_name_only_description")
        },
        toggle_theme = {
            title = i18n("prefs.toggle_theme_title"),
            description = i18n("prefs.toggle_theme_description")
        },
        max_ui_strlen = {
            title = i18n("prefs.max_ui_strlen_title"),
            description = i18n("prefs.max_ui_strlen_description")
        },
        mgmt_acl = {
            title = i18n("prefs.mgmt_acl_title"),
            description = i18n("prefs.mgmt_acl_description", {
                product = info.product
            })
        },
        http_index_page = {
            title = i18n("prefs.http_index_page"),
            description = i18n("prefs.http_index_page_description")
        },
        toggle_menu_entry_help = {
            title = i18n("prefs.toggle_menu_entry_help_title"),
            description = i18n("prefs.toggle_menu_entry_help_description")
        },
        toggle_menu_entry_developer = {
            title = i18n("prefs.toggle_menu_entry_developer_title"),
            description = i18n("prefs.toggle_menu_entry_developer_description")
        }
    }
}, {
    id = "vulnerability_scan",
    label = i18n("prefs.vulnerability_scan"),
    advanced = false,
    pro_only = true,
    hidden =  not ntop.isEnterprise(),
    entries = {
        vs_concurrently_scan_number = {
            title = i18n("prefs.vs_concurrently_scan_number_title"),
            description = i18n("prefs.vs_concurrently_scan_number_descr")
        },
        toggle_slow_mode = {
            title = i18n("prefs.vs_slow_mode_title"),
            description = i18n("prefs.vs_slow_mode_description")
        }
    }
}}

return menu_subpages
