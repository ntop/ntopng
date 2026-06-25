--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

require "check_redis_prefs"
local ts_utils = require "ts_utils"
local ts_gui_utils = require "ts_gui_utils"

local ts_host = {}

local timeseries_id = "host"

local timeseries_list = {{
    schema = "host:traffic",
    id = timeseries_id,
    label = i18n("graphs.traffic_rxtx"),
    description = i18n("graphs.metric_descr.host_traffic_rxtx"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.traffic'),
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
    schema = "host:packets",
    id = timeseries_id,
    label = i18n("graphs.packets_rxtx"),
    description = i18n("graphs.metric_descr.iface_packets_rxtx"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n("graphs.metric_labels.traffic"),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = ts_gui_utils.get_timeseries_color('bytes_sent')
        },
        packets_rcvd = {
            invert_direction = true,
            label = i18n('graphs.metric_labels.rcvd'),
            color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
        }
    },
    always_visibile = true
}, {
    schema = "host:score",
    id = timeseries_id,
    label = i18n("graphs.score"),
    description = i18n("graphs.metric_descr.host_score"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        score_as_cli = {
            label = i18n('graphs.cli_score'),
            color = ts_gui_utils.get_timeseries_color('cli_score')
        },
        score_as_srv = {
            label = i18n('graphs.srv_score'),
            color = ts_gui_utils.get_timeseries_color('srv_score')
        }
    }
}, {
    schema = "host:active_flows",
    id = timeseries_id,
    label = i18n("graphs.active_flows"),
    description = i18n("graphs.metric_descr.host_active_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = ts_gui_utils.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:total_flows",
    id = timeseries_id,
    label = i18n("graphs.total_flows"),
    description = i18n("graphs.metric_descr.host_total_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = ts_gui_utils.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:num_blacklisted_flows",
    id = timeseries_id,
    label = i18n("graphs.num_blacklisted_flows"),
    description = i18n("graphs.metric_descr.host_num_blacklisted_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = ts_gui_utils.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:alerted_flows",
    id = timeseries_id,
    label = i18n("graphs.total_alerted_flows"),
    description = i18n("graphs.metric_descr.host_total_alerted_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = ts_gui_utils.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:unreachable_flows",
    id = timeseries_id,
    label = i18n("graphs.total_unreachable_flows"),
    description = i18n("graphs.metric_descr.host_total_unreachable_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = ts_gui_utils.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:host_unreachable_flows",
    id = timeseries_id,
    label = i18n("graphs.host_unreachable_flows"),
    description = i18n("graphs.metric_descr.host_unreachable_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = ts_gui_utils.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:contacts",
    id = timeseries_id,
    label = i18n("graphs.active_host_contacts"),
    description = i18n("graphs.metric_descr.host_active_contacts"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.contacts'),
    timeseries = {
        num_as_clients = {
            label = i18n('graphs.metric_labels.as_cli'),
            color = ts_gui_utils.get_timeseries_color('flows')
        },
        num_as_server = {
            label = i18n('graphs.metric_labels.as_srv'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}, {
    schema = "host:contacts_behaviour",
    id = timeseries_id,
    label = i18n("graphs.host_contacts_behaviour"),
    description = i18n("graphs.metric_descr.host_contacts_behaviour"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.contacts'),
    timeseries = {
        value = {
            label = i18n('graphs.score'),
            color = ts_gui_utils.get_timeseries_color('score')
        },
        lower_bound = {
            label = i18n('graphs.lower_bound'),
            draw_type = "line",
            color = ts_gui_utils.get_timeseries_color('score')
        },
        upper_bound = {
            label = i18n('graphs.upper_bound'),
            draw_type = "line",
            color = ts_gui_utils.get_timeseries_color('score')
        }
    },
    nedge_exclude = true
}, {
    schema = "host:total_alerts",
    id = timeseries_id,
    label = i18n("graphs.alerts"),
    description = i18n("graphs.metric_descr.host_alerts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.alerts'),
    timeseries = {
        alerts = {
            label = i18n('graphs.tcp_rst_packets'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:engaged_alerts",
    id = timeseries_id,
    label = i18n("graphs.engaged_alerts"),
    description = i18n("graphs.metric_descr.host_engaged_alerts"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.alerts'),
    timeseries = {
        alerts = {
            label = i18n('graphs.tcp_rst_packets'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:dns_qry_sent_rsp_rcvd",
    id = timeseries_id,
    label = i18n("graphs.dns_qry_sent_rsp_rcvd"),
    description = i18n("graphs.metric_descr.host_dns_qry_sent_rsp_rcvd"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.queries'),
    timeseries = {
        queries_pkts = {
            label = i18n('graphs.metric_labels.queries_pkts'),
            color = ts_gui_utils.get_timeseries_color('default')
        },
        replies_ok_pkts = {
            label = i18n('graphs.metric_labels.ok_pkts'),
            color = ts_gui_utils.get_timeseries_color('default')
        },
        replies_error_pkts = {
            label = i18n('graphs.metric_labels.error_pkts'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    }
}, {
    schema = "host:dns_qry_rcvd_rsp_sent",
    id = timeseries_id,
    label = i18n("graphs.dns_qry_rcvd_rsp_sent"),
    description = i18n("graphs.metric_descr.host_dns_qry_rcvd_rsp_sent"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.queries'),
    timeseries = {
        queries_pkts = {
            label = i18n('graphs.metric_labels.queries_pkts'),
            color = ts_gui_utils.get_timeseries_color('default')
        },
        replies_ok_pkts = {
            label = i18n('graphs.metric_labels.ok_pkts'),
            color = ts_gui_utils.get_timeseries_color('default')
        },
        replies_error_pkts = {
            label = i18n('graphs.metric_labels.error_pkts'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    }
}, {
    schema = "host:tcp_rx_stats",
    id = timeseries_id,
    label = i18n("graphs.tcp_rx_stats"),
    description = i18n("graphs.metric_descr.host_tcp_rx_stats"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.rcvd'),
    timeseries = {
        retran_pkts = {
            label = i18n('graphs.metric_labels.retra_pkts'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        out_of_order_pkts = {
            label = i18n('graphs.metric_labels.ooo_pkts'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        lost_packets = {
            label = i18n('graphs.metric_labels.lost_pkts'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    },
    exclude_asn_mode = true
}, {
    schema = "host:tcp_tx_stats",
    id = timeseries_id,
    label = i18n("graphs.tcp_tx_stats"),
    description = i18n("graphs.metric_descr.host_tcp_tx_stats"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.sent'),
    timeseries = {
        retran_pkts = {
            label = i18n('graphs.metric_labels.retra_pkts'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        out_of_order_pkts = {
            label = i18n('graphs.metric_labels.ooo_pkts'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        lost_packets = {
            label = i18n('graphs.metric_labels.lost_pkts'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    },
    exclude_asn_mode = true
}, {
    schema = "host:echo_reply_packets",
    id = timeseries_id,
    label = i18n("graphs.echo_reply_packets"),
    description = i18n("graphs.metric_descr.host_echo_reply_packets"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:echo_packets",
    id = timeseries_id,
    label = i18n("graphs.echo_request_packets"),
    description = i18n("graphs.metric_descr.host_echo_request_packets"),
    priority = 0,
    measure_unit = "pps",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    }
}, {
    schema = "host:udp_sent_unicast",
    id = timeseries_id,
    label = i18n("graphs.udp_sent_unicast_vs_non_unicast"),
    description = i18n("graphs.metric_descr.host_udp_sent_unicast_vs_non_unicast"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        bytes_sent_unicast = {
            label = i18n('graphs.metric_labels.sent_uni'),
            color = ts_gui_utils.get_timeseries_color('bytes_sent')
        },
        bytes_sent_non_uni = {
            label = i18n('graphs.metric_labels.sent_non_uni'),
            color = ts_gui_utils.get_timeseries_color('bytes_sent')
        }
    }
}, {
    schema = "host:dscp",
    id = timeseries_id,
    label = i18n("graphs.dscp_classes"),
    description = i18n("graphs.metric_descr.host_dscp_classes"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        bytes_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = ts_gui_utils.get_timeseries_color('bytes_sent')
        },
        bytes_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
        }
    }
}, {
    schema = "host:host_tcp_unidirectional_flows",
    id = timeseries_id,
    label = i18n("graphs.unidirectional_tcp_flows"),
    description = i18n("graphs.metric_descr.host_tcp_unidirectional_flows"),
    priority = 0,
    measure_unit = "fps",
    scale = i18n('graphs.metric_labels.flows'),
    timeseries = {
        flows_as_client = {
            label = i18n('graphs.flows_as_client'),
            color = ts_gui_utils.get_timeseries_color('flows')
        },
        flows_as_server = {
            label = i18n('graphs.flows_as_server'),
            color = ts_gui_utils.get_timeseries_color('flows')
        }
    }
}}

local function addTopTimeseries(tags, tsOptions)
    local timeseries = {}
    local host_ts_creation = ntop.getPref("ntopng.prefs.hosts_ts_creation")
    local host_ts_enabled = ntop.getCache("ntopng.prefs.host_ndpi_timeseries_creation")
    local has_top_protocols = (host_ts_enabled == "both" or host_ts_enabled == "per_protocol") and
                                  (host_ts_creation == "full")
    local has_top_categories = (host_ts_enabled == "both" or host_ts_enabled == "per_category") and
                                   (host_ts_creation == "full")

    -- L4 Protocols
    if host_ts_creation == "full" then
        local series = ts_utils.listSeries("host:l4protos", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.l4proto = serie.l4proto
                local tot_serie = ts_utils.queryTotal("host:l4protos", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:host:l4protos",
                        group = i18n("graphs.l4_proto"),
                        priority = 2,
                        query = "l4proto:" .. serie.l4proto,
                        label = i18n(serie.l4proto) or serie.l4proto,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        disable_perc_95_ts = true,
                        timeseries = {
                            bytes_sent = {
                                label = serie.l4proto .. " " .. i18n('graphs.metric_labels.sent'),
                                color = ts_gui_utils.get_timeseries_color('bytes')
                            },
                            bytes_rcvd = {
                                label = serie.l4proto .. " " .. i18n('graphs.metric_labels.rcvd'),
                                color = ts_gui_utils.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    -- Top l7 Protocols
    if (has_top_protocols) and (not tsOptions.is_asn_mode_enabled) then
        local series = ts_utils.listSeries("host:ndpi", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.protocol = serie.protocol
                local tot_serie = ts_utils.queryTotal("host:ndpi", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:host:ndpi",
                        group = i18n("graphs.l7_proto"),
                        priority = 2,
                        query = "protocol:" .. serie.protocol,
                        label = serie.protocol,
                        measure_unit = "bps",
                        scale = i18n('graphs.metric_labels.traffic'),
                        disable_perc_95_ts = true,
                        timeseries = {
                            bytes_sent = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.sent'),
                                color = ts_gui_utils.get_timeseries_color('bytes')
                            },
                            bytes_rcvd = {
                                label = serie.protocol .. " " .. i18n('graphs.metric_labels.rcvd'),
                                color = ts_gui_utils.get_timeseries_color('bytes')
                            }
                        }
                    }
                end
            end
        end
    end

    -- Top Categories
    if has_top_categories then
        local series = ts_utils.listSeries("host:ndpi_categories", table.clone(tags), tags.epoch_begin) or {}
        local tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local category_name = getCategoryLabel(serie.category, interface.getnDPICategoryId(serie.category))
                local tot = 0
                tmp_tags.category = category_name
                local tot_serie =
                    ts_utils.queryTotal("host:ndpi_categories", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:host:ndpi_categories",
                        disable_perc_95_ts = true,
                        group = i18n("graphs.category"),
                        priority = 3,
                        query = "category:" .. category_name,
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

    return timeseries
end

function ts_host.getTimeseries(tags, tsOptions)
    local timeseries = {}
    local emptyEpoch = false
    if (not tags.epoch_begin) or (not tags.epoch_end) then
        emptyEpoch = true
    end

    timeseries = timeseries_list
    
    if ntop.isPro and ntop.isPro() then
        local ts_host_pro = require "ts_host_pro"
        local timeseries_pro = ts_host_pro.getTimeseries(tags, emptyEpoch, tsOptions)
        timeseries = table.merge(timeseries, timeseries_pro)
    end

    -- HR traffic chart: per-host traffic at 15-second resolution from the
    -- ClickHouse flows table (requires nProbe HR counters + Enterprise M license).
    if ntop.isEnterpriseM and ntop.isEnterpriseM() and ntop.isClickHouseEnabled() then
        timeseries[#timeseries + 1] = {
            schema      = "host:hr_traffic",
            id          = timeseries_id,
            label       = i18n("graphs.hr_traffic_rxtx"),
            description = i18n("graphs.metric_descr.host_hr_traffic_rxtx"),
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

    if (not emptyEpoch) then
        -- Remove empty timeseries
        timeseries = ts_gui_utils.removeEmptyTimeseries(timeseries, tags)
        local top_timeseries = addTopTimeseries(tags, tsOptions)
    end


    return timeseries
end

return ts_host
