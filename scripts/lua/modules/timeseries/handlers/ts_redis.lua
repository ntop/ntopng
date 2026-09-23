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

local ts_redis = {}

local timeseries_id = "redis"

local timeseries_list = {{
    schema = "redis:memory",
    id = timeseries_id,
    label = i18n("about.ram_memory"),
    description = i18n("graphs.metric_descr.redis_ram_memory"),
    priority = 0,
    measure_unit = "bytes",
    scale = i18n('graphs.metric_labels.bytes'),
    timeseries = {
        resident_bytes = {
            label = i18n('graphs.metric_labels.bytes'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    },
    always_visibile = true
}, {
    schema = "redis:keys",
    id = timeseries_id,
    label = i18n("system_stats.redis.redis_keys"),
    description = i18n("graphs.metric_descr.redis_keys"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.keys'),
    timeseries = {
        num_keys = {
            label = i18n('graphs.metric_labels.keys'),
            color = ts_gui_utils.get_timeseries_color('default')
        }
    }
}, {
    schema = "redis:reads_writes_v2",
    id = timeseries_id,
    label = i18n("system_stats.redis.redis_reads_writes"),
    description = i18n("graphs.metric_descr.redis_reads_writes"),
    priority = 0,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.reads_writes'),
    timeseries = {
        num_reads = {
            label = i18n('graphs.metric_labels.reads'),
            color = ts_gui_utils.get_timeseries_color('default')
        },
        num_writes = {
            label = i18n('graphs.metric_labels.writes'),
            color = ts_gui_utils.get_timeseries_color('bytes')
        }
    },
    always_visibile = false
}}

local function addTopTimeseries(tags, tsOptions)
    local timeseries = {}
    local redis_timeseries_enabled = areSystemTimeseriesEnabled()

    -- Note: a single grouped query, series with no data are not returned
    if redis_timeseries_enabled then
        local series = ts_utils.queryTotalByTag("redis:hits", tags.epoch_begin, tags.epoch_end, tags, "command") or {}

        for _, serie in ipairs(series) do
            local command = serie.tags.command
            local label = string.upper(string.sub(command, 5))

            timeseries[#timeseries + 1] = {
                schema = "redis:hits",
                group = i18n("graphs.commands"),
                priority = 2,
                query = "command:" .. command,
                label = label,
                measure_unit = "number",
                timeseries = {
                    num_calls = {
                        label = label .. " " .. i18n("graphs.commands")
                    }
                }
            }
        end
    end

    return timeseries
end

function ts_redis.getTimeseries(tags, tsOptions)
    local timeseries = {}
    local emptyEpoch = false
    if (not tags.epoch_begin) or (not tags.epoch_end) then
        emptyEpoch = true
    end
    if (not emptyEpoch) then
        timeseries = addTopTimeseries(tags, emptyEpoch, tsOptions)
    end

    timeseries = table.merge(timeseries, timeseries_list)
    return timeseries
end

return ts_redis
