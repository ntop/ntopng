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

local ts_vlan = {}

local timeseries_id = "vlan"

local timeseries_list = {{
    schema = "vlan:traffic",
    id = timeseries_id,
    label = i18n("graphs.traffic_rxtx"),
    description = i18n("graphs.metric_descr.vlan_traffic_rxtx"),
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
    schema = "vlan:score",
    id = timeseries_id,
    label = i18n("score"),
    description = i18n("graphs.metric_descr.vlan_score"),
    priority = 0,
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
}}

local function addTopTimeseries(tags, tsOptions)
    local timeseries = {}
    local vlan_ts_enabled = ntop.getCache("ntopng.prefs.vlan_rrd_creation")

    -- Top l7 Protocols
    -- Note: a single grouped query, series with no data are not returned
    if (vlan_ts_enabled) and (tsOptions.is_asn_mode_enabled) then
        local series = ts_utils.queryTotalByTag("vlan:ndpi", tags.epoch_begin, tags.epoch_end, tags, "protocol") or {}

        for _, serie in ipairs(series) do
            local protocol = serie.tags.protocol

            timeseries[#timeseries + 1] = {
                schema = "top:vlan:ndpi",
                group = i18n("graphs.l7_proto"),
                priority = 2,
                id = timeseries_id,
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

function ts_vlan.getTimeseries(tags, tsOptions)
    local timeseries = {}
    local emptyEpoch = false
    if (not tags.epoch_begin) or (not tags.epoch_end) then
        emptyEpoch = true
    end
    if (not emptyEpoch) then
        timeseries = addTopTimeseries(tags, tsOptions)
    end
    timeseries = table.merge(timeseries, timeseries_list)
    return timeseries
end

return ts_vlan
