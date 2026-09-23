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

local ts_blacklist = {}

local timeseries_id = "blacklist"

local timeseries_list = {{
    schema = "top:blacklist_v2:hits",
    chart_type = "line",
    id = timeseries_id,
    label = i18n('graphs.metric_labels.top_blacklist_hits'),
    description = i18n("graphs.metric_descr.top_blacklist_hits"),
    type = "top",
    draw_stacked = true,
    priority = 2,
    measure_unit = "number",
    scale = i18n('graphs.metric_labels.blacklist_hits'),
    timeseries = {
        hits = {
            use_serie_name = true,
            label = i18n('graphs.metric_labels.blacklist_num_hits')
        }
    },
    default_visible = true,
    always_visibile = true
}}

local function addTopTimeseries(tags, tsOptions)
    local timeseries = {}
    local series = ts_utils.listSeries("blacklist_v2:hits", table.clone(tags), tags.epoch_begin, tags.epoch_end) or {}
    local tmp_tags = table.clone(tags)

    --    if table.empty(series) then
    --        return;
    --    end
    for _, serie in pairs(series or {}) do
        tmp_tags.blacklist_name = serie.blacklist_name
        timeseries[#timeseries + 1] = {
            schema = "blacklist_v2:hits",
            id = timeseries_id,
            chart_type = "line",
            group = i18n("graphs.metric_labels.blacklist_num_hits"),
            priority = 0,
            query = "blacklist_name:" .. serie.blacklist_name,
            label = serie.blacklist_name:gsub("_", " "),
            measure_unit = "number",
            scale = i18n('graphs.metric_labels.blacklist_hits'),
            timeseries = {
                hits = {
                    use_serie_name = true,
                    label = i18n('graphs.metric_labels.blacklist_num_hits')
                }
            }
        }
    end
    return timeseries
end

function ts_blacklist.getTimeseries(tags, tsOptions)
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

return ts_blacklist
