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

    local series = ts_utils.listSeries("asn:exporter_traffic", table.clone(tags), tags.epoch_begin) or {}
    local tmp_tags = table.clone(tags)

    -- Top Exporters - ASN
    if not table.empty(series) then
        for _, serie in pairs(series or {}) do
            local tot = 0
            tmp_tags.device = serie.device
            tmp_tags.if_index = serie.if_index
            local tot_serie = ts_utils.queryTotal("asn:exporter_traffic", tags.epoch_begin, tags.epoch_end, tmp_tags)
            -- Remove serie with no data
            for _, value in pairs(tot_serie or {}) do
                tot = tot + tonumber(value)
            end

            if (tot > 0) then
                timeseries[#timeseries + 1] = {
                    schema = "asn:exporter_traffic",
                    group = i18n("exporter_interface"),
                    priority = 2,
                    query = "device:" .. serie.device .. ",if_index:" .. serie.if_index,
                    label = i18n("exporter_port", {
                        exporter = getProbeName(serie.device),
                        port = format_portidx_name(serie.device, serie.if_index, true)
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
        end
    end

    -- Top l7 Protocols
    if (asn_ts_enabled) and (not tsOptions.is_asn_mode_enabled) then
        local series = ts_utils.listSeries("asn:ndpi", table.clone(tags), tags.epoch_begin) or {}
        tmp_tags = table.clone(tags)

        if not table.empty(series) then
            for _, serie in pairs(series or {}) do
                local tot = 0
                tmp_tags.protocol = serie.protocol
                local tot_serie = ts_utils.queryTotal("asn:ndpi", tags.epoch_begin, tags.epoch_end, tmp_tags)
                -- Remove serie with no data
                for _, value in pairs(tot_serie or {}) do
                    tot = tot + tonumber(value)
                end

                if (tot > 0) then
                    timeseries[#timeseries + 1] = {
                        schema = "top:asn:ndpi",
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
