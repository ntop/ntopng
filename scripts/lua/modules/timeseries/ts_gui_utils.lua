--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
local ts_gui_utils = {}

local ts_utils = require "ts_utils"

-- #################################

-- The chart colors live in the GUI (colorUtils.metricColors in color-utils.js):
-- the REST sends the metric name and the GUI picks the color of the current theme
function ts_gui_utils.get_timeseries_color(subject)
    return subject
end

-- #################################

function ts_gui_utils.removeEmptyTimeseries(timeseries, tags)
    for index, ts_info in ipairs(timeseries) do
        if not ts_info.always_visibile then
            local tot_serie = ts_utils.queryTotal(ts_info.schema, tags.epoch_begin, tags.epoch_end, tags)
            if not tot_serie then
                table.remove(timeseries, index)
            end
        end
    end
    return timeseries
end

-- #################################

return ts_gui_utils
