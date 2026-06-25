--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
if ntop.isPro and ntop.isPro() then
    package.path = dirs.installdir .. "/scripts/lua/pro/modules/timeseries/handlers/?.lua;" .. package.path
end

require "lua_utils_get"
require "check_redis_prefs"
local ts_utils = require "ts_utils"
local ts_gui_utils = require "ts_gui_utils"

local ts_interface = {}

local timeseries_id = "iface"

local timeseries_list = {{
    schema = "iface:traffic_rxtx",
    id = timeseries_id,
    label = i18n("graphs.traffic_rxtx"),
    description = i18n("graphs.metric_descr.iface_traffic_rxtx"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        bytes_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = ts_gui_utils.get_timeseries_color('bytes_sent')
        },
        bytes_rcvd = {
            invert_direction = true,
            label = i18n('graphs.metric_labels.rcvd'),
            color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
        }
    },
    always_visibile = true,
    default_visible = true
}, {
    schema = "iface:packets_rxtx",
    id = timeseries_id,
    label = i18n("graphs.packets_rxtx"),
    description = i18n("graphs.metric_descr.iface_packets_rxtx"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = ts_gui_utils.get_timeseries_color('packets_sent')
        },
        packets_rcvd = {
            invert_direction = true,
            label = i18n('graphs.metric_labels.rcvd'),
            color = ts_gui_utils.get_timeseries_color('packets_rcvd')
        }
    },
    always_visibile = true
}, {
    schema = "iface:traffic_ip",
    id = timeseries_id,
    label = i18n("graphs.traffic_ip"),
    description = i18n("graphs.metric_descr.iface_traffic_ip"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        bytes_ipv4 = {
            label = i18n('graphs.metric_labels.ipv4'),
            color = ts_gui_utils.get_timeseries_color('bytes_sent')
        },
        bytes_ipv6 = {
            label = i18n('graphs.metric_labels.ipv6'),
            color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
        }
    },
    always_visibile = true,
    draw_stacked = false
}, {
    schema = "iface:flows",
    id = timeseries_id,
    label = i18n("graphs.active_flows"),
    description = i18n("graphs.metric_descr.iface_active_flows"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        num_flows = {
            label = i18n('graphs.metric_labels.num_flows'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "iface:new_flows",
    id = timeseries_id,
    label = i18n("graphs.new_flows"),
    description = i18n("graphs.metric_descr.iface_new_flows"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        new_flows = {
            label = i18n('graphs.metric_labels.num_flows'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "iface:remote2local",
    id = timeseries_id,
    label = i18n("graphs.remote2local"),
    description = i18n("graphs.metric_descr.iface_remote2local"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.bytes'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "iface:local2remote",
    id = timeseries_id,
    label = i18n("graphs.local2remote"),
    description = i18n("graphs.metric_descr.iface_local2remote"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.bytes'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "iface:alerted_flows",
    id = timeseries_id,
    label = i18n("graphs.total_alerted_flows"),
    description = i18n("graphs.metric_descr.iface_total_alerted_flows"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        num_flows = {
            label = i18n('graphs.metric_labels.num_flows'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "iface:hosts",
    id = timeseries_id,
    label = i18n("graphs.active_hosts"),
    description = i18n("graphs.metric_descr.iface_active_hosts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.hosts'),
    timeseries = {
        num_hosts = {
            label = i18n('graphs.metric_labels.num_hosts'),
            color = ts_gui_utils.get_timeseries_color('hosts')
        }
    }
}, {
    schema = "iface:engaged_alerts",
    id = timeseries_id,
    label = i18n("graphs.engaged_alerts"),
    description = i18n("graphs.metric_descr.iface_engaged_alerts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.alerts'),
    timeseries = {
        engaged_alerts = {
            label = i18n('graphs.engaged_alerts'),
            color = ts_gui_utils.get_timeseries_color('alerts')
        }
    }
}, {
    schema = "iface:dropped_alerts",
    id = timeseries_id,
    label = i18n("graphs.dropped_alerts"),
    description = i18n("graphs.metric_descr.iface_dropped_alerts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.alerts'),
    timeseries = {
        dropped_alerts = {
            label = i18n('graphs.dropped_alerts'),
            color = ts_gui_utils.get_timeseries_color('alerts')
        }
    }
}, {
    schema = "iface:devices",
    id = timeseries_id,
    label = i18n("graphs.active_devices"),
    description = i18n("graphs.metric_descr.iface_active_devices"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.devices'),
    timeseries = {
        num_devices = {
            label = i18n('graphs.metric_labels.num_devices'),
            color = ts_gui_utils.get_timeseries_color('devices')
        }
    }
}, {
    schema = "iface:http_hosts",
    id = timeseries_id,
    label = i18n("graphs.active_http_servers"),
    description = i18n("graphs.metric_descr.iface_active_http_servers"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.servers'),
    timeseries = {
        num_hosts = {
            label = i18n('graphs.num_servers'),
            color = ts_gui_utils.get_timeseries_color('devices')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:traffic",
    id = timeseries_id,
    label = i18n("graphs.traffic"),
    description = i18n("graphs.metric_descr.iface_traffic"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.traffic'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:packets",
    id = timeseries_id,
    label = i18n("graphs.packets"),
    description = i18n("graphs.metric_descr.iface_packets"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n("graphs.metric_labels.packets"),
    timeseries = {
        packets = {
            label = i18n('graphs.metric_labels.packets'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:throughput_pps",
    id = timeseries_id,
    label = i18n("graphs.throughput_pps"),
    description = i18n("graphs.metric_descr.iface_throughput_pps"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        pps = {
            label = i18n('graphs.metric_labels.throughput'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "iface:throughput_bps",
    id = timeseries_id,
    label = i18n("graphs.throughput_bps"),
    description = i18n("graphs.metric_descr.iface_throughput_bps"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        bps = {
            label = i18n('graphs.metric_labels.throughput'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "iface:score",
    id = timeseries_id,
    label = i18n("graphs.score"),
    description = i18n("graphs.metric_descr.iface_score"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        cli_score = {
            label = i18n('graphs.cli_score'),
            color = ts_gui_utils.get_timeseries_color('cli_score')
        },
        srv_score = {
            label = i18n('graphs.srv_score'),
            color = ts_gui_utils.get_timeseries_color('srv_score')
        }
    }
}, {
    schema = "iface:packets_vs_drops",
    id = timeseries_id,
    label = i18n("graphs.packets_vs_drops"),
    description = i18n("graphs.metric_descr.iface_packets_vs_drops"),
    priority = 0,
    measure_unit = "number",
    scale = i18n("graphs.packets_vs_drops"),
    timeseries = {
        packets = {
            label = i18n('graphs.metric_labels.packets'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        drops = {
            label = i18n('graphs.metric_labels.drops'),
            draw_type = "line",
            color = ts_gui_utils.get_timeseries_color('default')
        }
    }
}, {
    schema = "iface:nfq_pct",
    id = timeseries_id,
    label = i18n("graphs.num_nfq_pct"),
    description = i18n("graphs.metric_descr.iface_num_nfq_pct"),
    priority = 0,
    measure_unit = "percentage",
    scale = i18n('graphs.metric_labels.load'),
    timeseries = {
        num_nfq_pct = {
            label = i18n('graphs.num_nfq_pct'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    },
    nedge_only = true
}, {
    schema = "iface:hosts_anomalies",
    id = timeseries_id,
    label = i18n("graphs.hosts_anomalies"),
    description = i18n("graphs.metric_descr.iface_hosts_anomalies"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.anomalies'),
    timeseries = {
        num_loc_hosts_anom = {
            label = i18n('graphs.loc_host_anomalies'),
            color = ts_gui_utils.get_timeseries_color('hosts')
        },
        num_rem_hosts_anom = {
            label = i18n('graphs.rem_host_anomalies'),
            draw_type = "line",
            color = ts_gui_utils.get_timeseries_color('hosts')
        }
    }
}, {
    schema = "iface:disc_prob_bytes",
    id = timeseries_id,
    label = i18n("graphs.discarded_probing_bytes"),
    description = i18n("graphs.metric_descr.iface_discarded_probing_bytes"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.drops'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:disc_prob_pkts",
    id = timeseries_id,
    label = i18n("graphs.discarded_probing_packets"),
    description = i18n("graphs.metric_descr.iface_discarded_probing_packets"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets = {
            label = i18n('graphs.metric_labels.drops'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:dumped_flows",
    id = timeseries_id,
    label = i18n("graphs.dumped_flows"),
    description = i18n("graphs.metric_descr.iface_dumped_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        dumped_flows = {
            label = i18n('graphs.dumped_flows'),
            color = ts_gui_utils.get_timeseries_color('flows')
        },
        dropped_flows = {
            label = i18n('graphs.dropped_flows'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "iface:zmq_recv_flows",
    id = timeseries_id,
    label = i18n("graphs.zmq_received_flows"),
    description = i18n("graphs.metric_descr.iface_zmq_received_flows"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows = {
            label = i18n('graphs.zmq_received_flows'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "iface:zmq_flow_coll_drops",
    id = timeseries_id,
    label = i18n("graphs.zmq_flow_coll_drops"),
    description = i18n("graphs.metric_descr.iface_zmq_flow_coll_drops"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        drops = {
            label = i18n('graphs.zmq_flow_coll_drops'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:zmq_flow_coll_udp_drops",
    id = timeseries_id,
    label = i18n("graphs.zmq_flow_coll_udp_drops"),
    description = i18n("graphs.metric_descr.iface_zmq_flow_coll_udp_drops"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        drops = {
            label = i18n('graphs.zmq_flow_coll_udp_drops'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    },
    nedge_exclude = true
}, {
    schema = "iface:tcp_stats",
    id = timeseries_id,
    label = i18n("graphs.tcp_stats"),
    description = i18n("graphs.tcp_stats"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    disable_default_ago_ts = true,
    timeseries = {
        keep_alive = {
            label = i18n('graphs.tcp_packets_keep_alive'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        retransmissions = {
            label = i18n('graphs.tcp_packets_retr'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        out_of_order = {
            label = i18n('graphs.tcp_packets_ooo'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        lost = {
            label = i18n('graphs.tcp_packets_lost'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    },
    exclude_asn_mode = true,
    nedge_exclude = true
}, {
    schema = "iface:tcp_flags",
    id = timeseries_id,
    label = i18n("graphs.tcp_flags"),
    description = i18n("graphs.metric_descr.iface_tcp_flags"),
    priority = 0,
    disable_default_ago_ts = true,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        fin_ack = {
            label = i18n('graphs.tcp_finack_packets'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        syn_ack = {
            label = i18n('graphs.tcp_synack_packets'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        syn = {
            label = i18n('graphs.tcp_syn_packets'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        rst = {
            label = i18n('graphs.tcp_rst_packets'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    label = i18n("graphs.zmq_msg_rcvd"),
    description = i18n("graphs.metric_descr.iface_zmq_msg_rcvd"),
    id = timeseries_id,
    schema = "iface:zmq_rcvd_msgs",
    priority = 0,
    measure_unit = "number",
    timeseries = {
        msgs = {
            label = i18n('graphs.metric_labels.rcvd_msgs'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    }
}, {
    label = i18n("graphs.zmq_msg_dropped"),
    description = i18n("graphs.metric_descr.iface_zmq_msg_dropped"),
    id = timeseries_id,
    schema = "iface:zmq_msg_drops",
    priority = 0,
    measure_unit = "number",
    timeseries = {
        msgs = {
            label = i18n('graphs.metric_labels.dropped_msgs'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    }
}, {
    schema = "iface:role_traffic_v3",
    id = timeseries_id,
    label = i18n("graphs.role_traffic"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n("graphs.metric_labels.traffic"),
    draw_stacked = true,
    timeseries = {
        peering = {
            label = i18n("prefs.snmp_interface_role_list.peering"),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        transit = {
            label = i18n("prefs.snmp_interface_role_list.transit"),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        ix = {
            label = i18n("prefs.snmp_interface_role_list.ix"),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        other = {
            label = i18n("prefs.snmp_interface_role_list.other"),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    },
    nedge_exclude = true

}}

local function addTopTimeseries(tags, emptyEpoch, tsOptions)
    local timeseries = {}
    local id = getIfacenDPITsName()

    -- Empty epoch, return the default timeseries list of applications
    if (emptyEpoch) then
        timeseries[#timeseries + 1] = {
            schema = "top:" .. id,
            disable_perc_95_ts = true,
            priority = 2,
            label = i18n('top_l7_proto'),
            measure_unit = "bps",
            scale = i18n('graphs.metric_labels.traffic'),
            disable_default_ago_ts = true,
            timeseries = {
                bytes = {
                    label = i18n('top_l7_proto'),
                    color = ts_gui_utils.get_timeseries_color('bytes')
                }
            }
        }
        timeseries[#timeseries + 1] = {
            schema = "top:asn:traffic",
            id = timeseries_id,
            draw_stacked = true,
            label = i18n("graphs.top_asn"),
            description = i18n("graphs.metric_descr.asn_traffic_rxtx"),
            priority = 0,
            measure_unit = "bps",
            scale = i18n('graphs.metric_labels.traffic'),
            timeseries = {
                bytes = {
                    label = i18n('graphs.metric_labels.bytes'),
                    color = ts_gui_utils.get_timeseries_color('bytes')
                }
            },
            disable_perc_95_ts = true,
            always_visibile = true
        }
        return timeseries
    end

    local interface_ts_enabled = ntop.getCache("ntopng.prefs.interface_ndpi_timeseries_creation")
    local has_top_protocols = interface_ts_enabled == "both" or interface_ts_enabled == "per_protocol" or
                                  interface_ts_enabled ~= "0"
    local has_top_categories = interface_ts_enabled == "both" or interface_ts_enabled == "per_category"

    if interface_ts_enabled then
        -- Adding L4 protocols timeseries
        local series = ts_utils.listSeries("iface:l4protos", table.clone(tags), tags.epoch_begin) or {}

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                timeseries[#timeseries + 1] = {
                    schema = "top:iface:l4protos",
                    disable_perc_95_ts = true,
                    group = i18n("graphs.l4_proto"),
                    priority = 2,
                    query = "l4proto:" .. serie.l4proto,
                    label = i18n(serie.l4proto) or serie.l4proto,
                    measure_unit = "bps",
                    scale = i18n('graphs.metric_labels.traffic'),
                    timeseries = {
                        bytes = {
                            label = serie.l4proto,
                            color = ts_gui_utils.get_timeseries_color('bytes')
                        }
                    }
                }
            end
        end

    end
    -- Top l7 Protocols
    if (has_top_protocols) and (not tsOptions.is_asn_mode_enabled) then
        local id = getIfacenDPITsName()
        local is_full_ts = ifaceFullnDPITs()
        local series = ts_utils.listSeries(id, table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.protocol = serie.protocol
                local tot_serie = ts_utils.queryTotal(id, tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    local ts = {
                        bytes = {
                            label = serie.protocol,
                            color = ts_gui_utils.get_timeseries_color('bytes')
                        }
                    }
                    if is_full_ts then
                        ts = {
                            bytes_sent = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'),
                                color = ts_gui_utils.get_timeseries_color('bytes_sent')
                            },
                            bytes_rcvd = {
                                invert_direction = true,
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'),
                                color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
                            }
                        }
                    end

                    timeseries[#timeseries + 1] = {
                        schema = "top:" .. id,
                        disable_perc_95_ts = true,
                        group = i18n("graphs.l7_proto"),
                        priority = 2,
                        query = "protocol:" .. serie.protocol,
                        label = serie.protocol,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = ts
                    }
                end
            end
            timeseries[#timeseries + 1] = {
                schema = "top:" .. id,
                disable_perc_95_ts = true,
                priority = 2,
                label = i18n('top_l7_proto'),
                measure_unit = "bps",
                scale = i18n('graphs.metric_labels.traffic'),
                disable_default_ago_ts = true,
                timeseries = {
                    bytes = {
                        label = i18n('top_l7_proto'),
                        color = ts_gui_utils.get_timeseries_color('bytes')
                    }
                }
            }
        end
    end

    -- Top Categories
    if has_top_categories then
        local series = ts_utils.listSeries("iface:ndpi_categories", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.category = serie.category
                local tot_serie = ts_utils.queryTotal("iface:ndpi_categories", tags.epoch_begin, tags.epoch_end,
                    tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    local category_name = getCategoryLabel(serie.category, interface.getnDPICategoryId(serie.category))
                    timeseries[#timeseries + 1] = {
                        schema = "top:iface:ndpi_categories",
                        group = i18n("graphs.category"),
                        priority = 3,
                        query = "category:" .. category_name,
                        disable_perc_95_ts = true,
                        label = category_name,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes = {
                                label = category_name,
                                color = ts_gui_utils.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    -- Top Traffic Profiles
    if ntop.isPro and ntop.isPro() then
        local series = ts_utils.listSeries("profile:traffic", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.profile = serie.profile
                local tot_serie = ts_utils.queryTotal("profile:traffic", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:profile:traffic",
                        group = i18n("graphs.top_profiles"),
                        priority = 2,
                        query = "profile:" .. serie.profile,
                        label = serie.profile,
                        measure_unit = "bps",
                        disable_perc_95_ts = true,
                        scale = i18n('graphs.metric_labels.traffic'),
                        timeseries = {
                            bytes = {
                                label = serie.profile,
                                color = ts_gui_utils.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    return timeseries
end

function ts_interface.getTimeseries(tags, tsOptions)
    local timeseries = {}
    local emptyEpoch = (not tags.epoch_begin) or (not tags.epoch_end) or (tsOptions and tsOptions.emptyEpoch == true)

    timeseries = timeseries_list

    if ntop.isPro and ntop.isPro() then
        local ts_interface_pro = require "ts_interface_pro"
        local timeseries_pro = ts_interface_pro.getTimeseries(tags, emptyEpoch, tsOptions)
        timeseries = table.merge(timeseries, timeseries_pro)
    end

    -- HR traffic chart: per-interface traffic at 15-second resolution from the
    -- ClickHouse flows table (requires nProbe HR counters + Enterprise M license).
    if ntop.isEnterpriseM and ntop.isEnterpriseM() and ntop.isClickHouseEnabled() then
        timeseries[#timeseries + 1] = {
            schema      = "iface:hr_traffic",
            id          = timeseries_id,
            label       = i18n("graphs.hr_traffic_rxtx"),
            description = i18n("graphs.metric_descr.iface_hr_traffic_rxtx"),
            priority    = 0,
            measure_unit = "bps",
            scale       = i18n("graphs.metric_labels.traffic"),
            timeseries  = {
                bytes_sent = {
                    label = i18n("graphs.metric_labels.sent"),
                    color = ts_gui_utils.get_timeseries_color("bytes_sent")
                },
                bytes_rcvd = {
                    invert_direction = true,
                    label = i18n("graphs.metric_labels.rcvd"),
                    color = ts_gui_utils.get_timeseries_color("bytes_rcvd")
                }
            }
        }
    end

    if not emptyEpoch then
        timeseries = ts_gui_utils.removeEmptyTimeseries(timeseries, tags)
    end
    local top_timeseries = addTopTimeseries(tags, emptyEpoch, tsOptions)
    timeseries = table.merge(timeseries, top_timeseries)

    return timeseries
end

return ts_interface
