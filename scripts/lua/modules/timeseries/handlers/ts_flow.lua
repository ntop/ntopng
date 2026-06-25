--
-- (C) 2024 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

require "check_redis_prefs"
local ts_utils = require "ts_utils"
local ts_gui_utils = require "ts_gui_utils"

local ts_flow = {}

local timeseries_id = "flow"

local timeseries_list = {}

-- ##############################################

function ts_flow.getTimeseries(tags, options)
    local timeseries = table.clone(timeseries_list)

    if ntop.isEnterpriseM and ntop.isEnterpriseM() and ntop.isClickHouseEnabled() then
        timeseries[#timeseries + 1] = {
            schema       = "flow:hr_traffic",
            id           = timeseries_id,
            label        = i18n("graphs.hr_traffic_rxtx"),
            description  = i18n("graphs.metric_descr.flow_hr_traffic_rxtx"),
            priority     = 0,
            measure_unit = "bps",
            scale        = i18n("graphs.metric_labels.traffic"),
            default_visible = true,
            timeseries   = {
                bytes_sent = {
                    label = i18n("graphs.metric_labels.sent"),
                    color = ts_gui_utils.get_timeseries_color("bytes_sent"),
                },
                bytes_rcvd = {
                    invert_direction = true,
                    label = i18n("graphs.metric_labels.rcvd"),
                    color = ts_gui_utils.get_timeseries_color("bytes_rcvd"),
                },
            },
        }
    end

    if not options.emptyEpoch then
        timeseries = ts_gui_utils.removeEmptyTimeseries(timeseries, tags)
    end

    return timeseries
end

-- ##############################################

return ts_flow
