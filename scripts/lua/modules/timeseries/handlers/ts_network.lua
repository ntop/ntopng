--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

require "label_utils"
require "check_redis_prefs"
local ts_utils = require "ts_utils"
local ts_gui_utils = require "ts_gui_utils"

local ts_network = {}

local timeseries_id = "subnet"

local timeseries_list = {{
    schema = "subnet:traffic",
    id = timeseries_id,
    label = i18n("graphs.traffic"),
    description = i18n("graphs.metric_descr.subnet_traffic"),
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.traffic'),
    timeseries = {
        bytes_egress = {
            label = i18n('graphs.metrics_suffixes.egress'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        bytes_ingress = {
            label = i18n('graphs.metrics_suffixes.ingress'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        bytes_inner = {
            label = i18n('graphs.metrics_suffixes.inner'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    },
    always_visibile = true,
    default_visible = true
}, {
    schema = "subnet:broadcast_traffic",
    id = timeseries_id,
    label = i18n("broadcast_traffic"),
    description = i18n("graphs.metric_descr.subnet_broadcast_traffic"),
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.traffic'),
    timeseries = {
        bytes_egress = {
            label = i18n('graphs.metrics_suffixes.egress'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        bytes_ingress = {
            label = i18n('graphs.metrics_suffixes.ingress'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        bytes_inner = {
            label = i18n('graphs.metrics_suffixes.inner'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    }
}, {
    schema = "subnet:engaged_alerts",
    id = timeseries_id,
    label = i18n("show_alerts.engaged_alerts"),
    description = i18n("graphs.metric_descr.subnet_engaged_alerts"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.alerts'),
    timeseries = {
        alerts = {
            label = i18n('graphs.engaged_alerts')
        }
    }
}, {
    schema = "subnet:score",
    id = timeseries_id,
    label = i18n("score"),
    description = i18n("graphs.metric_descr.subnet_score"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        score = {
            label = i18n('score')
        },
        scoreAsClient = {
            label = i18n('score_as_client')
        },
        scoreAsServer = {
            label = i18n('score_as_server')
        }
    }
}, {
    schema = "subnet:tcp_retransmissions",
    id = timeseries_id,
    label = i18n("graphs.tcp_packets_retr"),
    description = i18n("graphs.metric_descr.subnet_tcp_packets_retr"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_ingress = {
            label = i18n('if_stats_overview.ingress_packets')
        },
        packets_egress = {
            label = i18n('if_stats_overview.egress_packets')
        },
        packets_inner = {
            label = 'Inner Packets'
        }
    },
    exclude_asn_mode = true
}, {
    schema = "subnet:tcp_out_of_order",
    id = timeseries_id,
    label = i18n("graphs.tcp_packets_ooo"),
    description = i18n("graphs.metric_descr.subnet_tcp_packets_ooo"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_ingress = {
            label = i18n('if_stats_overview.ingress_packets')
        },
        packets_egress = {
            label = i18n('if_stats_overview.egress_packets')
        },
        packets_inner = {
            label = 'Inner Packets'
        }
    },
    exclude_asn_mode = true
}, {
    schema = "subnet:tcp_lost",
    id = timeseries_id,
    label = i18n("graphs.tcp_packets_lost"),
    description = i18n("graphs.metric_descr.subnet_tcp_packets_lost"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_ingress = {
            label = i18n('if_stats_overview.ingress_packets'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        packets_egress = {
            label = i18n('if_stats_overview.egress_packets'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        packets_inner = {
            label = 'Inner Packets',
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    },
    exclude_asn_mode = true
}, {
    schema = "subnet:tcp_keep_alive",
    id = timeseries_id,
    label = i18n("graphs.tcp_packets_keep_alive"),
    description = i18n("graphs.metric_descr.subnet_tcp_packets_keep_alive"),
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.packets'),
    timeseries = {
        packets_ingress = {
            label = i18n('if_stats_overview.ingress_packets'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        packets_egress = {
            label = i18n('if_stats_overview.egress_packets'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        },
        packets_inner = {
            label = 'Inner Packets',
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    },
    exclude_asn_mode = true
}, {
    schema = "subnet:rtt",
    id = timeseries_id,
    label = i18n("graphs.rtt"),
    description = i18n("graphs.metric_descr.subnet_rtt"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        millis_rtt = {
            label = i18n('graphs.metric_labels.rtt'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    },
    nedge_exclude = true,
    exclude_asn_mode = true
}}

local function addTopTimeseries(tags, tsOptions)
    local timeseries = {}
    local network_top_ts_enabled = ntop.getPref("ntopng.prefs.intranet_traffic_rrd_creation")

    -- Top l7 Categories
    if network_top_ts_enabled and tags.subnet then
        network.select(tonumber(ntop.getLocalNetworkID(tags.subnet)))
        local net_stats = network.getNetworkStats() or {}
        if table.len(net_stats) > 0 then
            for second_subnet, _ in pairs(net_stats["intranet_traffic"]) do
                local label_1 = getFullLocalNetworkName(tags.subnet)
                local label_2 = getFullLocalNetworkName(second_subnet)

                timeseries[#timeseries + 1] = {
                    schema = "subnet:intranet_traffic_min",
                    priority = 3,
                    query = "subnet_2:" .. second_subnet,
                    label = i18n("graphs.intranet_traffic", {
                        net_1 = label_1,
                        net_2 = label_2
                    }),
                    measure_unit = "bps",
                    scale = i18n('graphs.metric_labels.traffic'),
                    timeseries = {
                        bytes_sent = {
                            label = i18n('graphs.metric_labels.sent'),
                            color = ts_gui_utils.get_timeseries_color('bytes')
                        },
                        bytes_rcvd = {
                            invert_direction = true,
                            label = i18n('graphs.metric_labels.rcvd'),
                            color = ts_gui_utils.get_timeseries_color('bytes')
                        }
                    }
                }
            end
        end
    end

    return timeseries

end

function ts_network.getTimeseries(tags, tsOptions)
    local timeseries = {}
    local emptyEpoch = false
    if (not tags.epoch_begin) or (not tags.epoch_end) then
        emptyEpoch = true
    end
    timeseries = timeseries_list

    if ntop.isPro and ntop.isPro() then
        local ts_network_pro = require "ts_network_pro"
        local timeseries_pro = ts_network_pro.getTimeseries(tags, emptyEpoch, tsOptions)
        timeseries = table.merge(timeseries, timeseries_pro)
    end
    
    if (not emptyEpoch) then
        -- Remove empty timeseries
        timeseries_list = ts_gui_utils.removeEmptyTimeseries(timeseries_list, tags)
        local top_timeseries = addTopTimeseries(tags, emptyEpoch, tsOptions)
        timeseries = table.merge(timeseries, top_timeseries)
    end
    
    return timeseries
end

return ts_network
