--
-- (C) 2014-26 - ntop.org
--
local dirs = ntop.getDirs()
local ts_gui_utils = {}

local ts_utils = require "ts_utils"

-- #################################

local series_extra_info = {
    alerts = {
        color = '#f59e0b'
    },
    bytes = {
        color = '#3b82f6'
    },
    packets = {
        color = '#6366f1'
    },
    bytes_sent = {
        color = '#3b82f6'
    },
    bytes_rcvd = {
        color = '#10b981'
    },
    devices = {
        color = '#8b5cf6'
    },
    flows = {
        color = '#6366f1'
    },
    hosts = {
        color = '#f97316'
    },
    score = {
        color = '#ef4444'
    },
    cli_score = {
        color = '#dc2626'
    },
    srv_score = {
        color = '#fca5a5'
    },
    default = {
        color = '#3b82f6'
    },
    usage_sent = {
        color = '#818cf8'
    },
    usage_rcvd = {
        color = '#34d399'
    }
}

-- #################################

function ts_gui_utils.get_timeseries_color(subject)
    if series_extra_info[subject] then
        return series_extra_info[subject].color
    end

    -- Safety check, if an improper value is given,
    -- then return a default color
    return series_extra_info.default.color
end

-- #################################

function ts_gui_utils.removeEmptyTimeseries(timeseries, tags)
    for index, ts_info in ipairs(timeseries) do
        local tot_serie = ts_utils.queryTotal(ts_info.schema, tags.epoch_begin, tags.epoch_end, tags)
        if not tot_serie and (not ts_info.always_visibile) then
            table.remove(timeseries, index)
        end
    end
    return timeseries
end

-- #################################

return ts_gui_utils
