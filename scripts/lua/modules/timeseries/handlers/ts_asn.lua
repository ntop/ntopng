--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

require "lua_utils_get"
require "check_redis_prefs"
local ts_utils = require "ts_utils"
local ts_gui_utils = require "ts_gui_utils"

local ts_asn = {}

local timeseries_id = "asn"

local timeseries_list = {{
    schema = "asn:traffic",
    id = timeseries_id,
    label = i18n("graphs.traffic_rxtx"),
    description = i18n("graphs.metric_descr.asn_traffic_rxtx"),
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
    schema = "asn:traffic_ip",
    id = timeseries_id,
    label = i18n("graphs.ip_traffic_breakdown"),
    description = i18n("graphs.metric_descr.asn_traffic_ip"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.traffic'),
    timeseries = {
        bytes_ipv4 = {
	   label = i18n('graphs.metric_labels.ipv4'),
	   color = ts_gui_utils.get_timeseries_color('bytes_sent')
        },
        bytes_ipv6 = {
            invert_direction = true,
            label = i18n('graphs.metric_labels.ipv6'),
            color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
        }
    },
    always_visibile = true,
    default_visible = true
}, {
    schema = "asn:rtt",
    id = timeseries_id,
    label = i18n("graphs.rtt"),
    description = i18n("graphs.metric_descr.asn_rtt"),
    priority = 0,
    measure_unit = "ms",
    scale = i18n('graphs.metric_labels.rtt'),
    timeseries = {
        millis_rtt = {
            label = i18n('graphs.metric_labels.rtt'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    },
    exclude_asn_mode = true,
    nedge_exclude = true
}, {
    schema = "asn:traffic_sent",
    id = timeseries_id,
    label = i18n("graphs.traffic_sent"),
    description = i18n("graphs.metric_descr.asn_traffic_sent"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.sent'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.sent'),
            color = ts_gui_utils.get_timeseries_color('bytes_sent')
        }
    },
    nedge_exclude = true
}, {
    schema = "asn:traffic_rcvd",
    id = timeseries_id,
    label = i18n("graphs.traffic_rcvd"),
    description = i18n("graphs.metric_descr.asn_traffic_rcvd"),
    priority = 0,
    measure_unit = "bps",
    scale = i18n('graphs.metric_labels.rcvd'),
    timeseries = {
        bytes = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = ts_gui_utils.get_timeseries_color('bytes_rcvd')
        }
    },
    nedge_exclude = true
}, {
    schema = "asn:score",
    id = timeseries_id,
    label = i18n("graphs.score"),
    description = i18n("graphs.metric_descr.asn_score"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.score'),
    timeseries = {
        score = {
            label = i18n('graphs.metric_labels.score'),
            color = ts_gui_utils.get_timeseries_color('score')
        },
        scoreAsClient = {
            label = i18n('graphs.metric_labels.cli_score'),
            color = ts_gui_utils.get_timeseries_color('cli_score')
        },
        scoreAsServer = {
            label = i18n('graphs.metric_labels.srv_score'),
            color = ts_gui_utils.get_timeseries_color('srv_score')
        }
    }
}, {
    schema = "asn:tcp_retransmissions",
    id = timeseries_id,
    label = i18n("graphs.tcp_packets_retr"),
    description = i18n("graphs.metric_descr.asn_tcp_packets_retr"),
    priority = 0,
    measure_unit = "number",
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
    },
    nedge_exclude = true
}, {
    schema = "asn:tcp_keep_alive",
    id = timeseries_id,
    label = i18n("graphs.tcp_packets_keep_alive"),
    description = i18n("graphs.metric_descr.asn_tcp_packets_keep_alive"),
    priority = 0,
    measure_unit = "number",
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
    },
    nedge_exclude = true
}, {
    schema = "asn:tcp_out_of_order",
    id = timeseries_id,
    label = i18n("graphs.tcp_packets_ooo"),
    description = i18n("graphs.metric_descr.asn_tcp_packets_ooo"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.tcp_packets_ooo'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}, {
    schema = "asn:tcp_lost",
    id = timeseries_id,
    label = i18n("graphs.tcp_packets_lost"),
    description = i18n("graphs.metric_descr.asn_tcp_packets_lost"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.tcp_packets_lost'),
    timeseries = {
        packets_sent = {
            label = i18n('graphs.metric_labels.sent'),
            color = ts_gui_utils.get_timeseries_color('packets')
        },
        packets_rcvd = {
            label = i18n('graphs.metric_labels.rcvd'),
            color = ts_gui_utils.get_timeseries_color('packets')
        }
    },
    nedge_exclude = true
}}

local function addTopTimeseries(tags, tsOptions)
    require "lua_utils_gui"
    local timeseries = {}
    local asn_ts_enabled = ntop.getCache("ntopng.prefs.asn_rrd_creation")

    -- Top Exporters - ASN
    -- Note: a single grouped query, series with no data are not returned
    local series = ts_utils.queryTotalByTag("asn:exporter_traffic", tags.epoch_begin, tags.epoch_end, tags,
        {"device", "if_index"}) or {}

    for _, serie in ipairs(series) do
        local device = serie.tags.device
        local if_index = serie.tags.if_index

        timeseries[#timeseries + 1] = {
            schema = "asn:exporter_traffic",
            group = i18n("exporter_interface"),
            priority = 2,
            query = "device:" .. device .. ",if_index:" .. if_index,
            label = i18n("exporter_port", {
                exporter = getExporterName(device),
                port = format_portidx_name(device, if_index, true)
            }),
            disable_default_ago_ts = true,
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
            }
        }
    end

    -- Top l7 Protocols
    -- Note: a single grouped query, series with no data are not returned
    if (asn_ts_enabled) and (not tsOptions.is_asn_mode_enabled) then
        local top_series = ts_utils.queryTotalByTag("asn:ndpi", tags.epoch_begin, tags.epoch_end, tags, "protocol") or
                               {}

        for _, serie in ipairs(top_series) do
            local protocol = serie.tags.protocol

            timeseries[#timeseries + 1] = {
                schema = "top:asn:ndpi",
                group = i18n("graphs.l7_proto"),
                priority = 2,
                query = "protocol:" .. protocol,
                label = protocol,
                measure_unit = "bps",
                scale = i18n('graphs.metric_labels.traffic'),
                disable_perc_95_ts = true,
                timeseries = {
                    bytes_sent = {
                        label = protocol .. " " .. i18n('graphs.metric_labels.sent'),
                        color = ts_gui_utils.get_timeseries_color('bytes')
                    },
                    bytes_rcvd = {
                        label = protocol .. " " .. i18n('graphs.metric_labels.rcvd'),
                        color = ts_gui_utils.get_timeseries_color('bytes')
                    }
                }
            }
        end
    end

    return timeseries
end

function ts_asn.getTimeseries(tags, tsOptions)
    local timeseries = {}
    local emptyEpoch = false
    if (not tags.epoch_begin) or (not tags.epoch_end) then
        emptyEpoch = true
    end

    timeseries = timeseries_list

    if ntop.isPro and ntop.isPro() then
        local ts_asn_pro = require "ts_asn_pro"
        local timeseries_pro = ts_asn_pro.getTimeseries(tags, emptyEpoch, tsOptions)
        timeseries = table.merge(timeseries, timeseries_pro)
    end
    
    if (not emptyEpoch) then
        -- Remove empty timeseries
        timeseries = ts_gui_utils.removeEmptyTimeseries(timeseries, tags)
        local top_timeseries = addTopTimeseries(tags, tsOptions)
        timeseries = table.merge(timeseries, top_timeseries)
    end

    return timeseries
end

return ts_asn
