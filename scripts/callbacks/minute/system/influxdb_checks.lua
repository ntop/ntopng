--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_utils = require "ts_utils_core"
local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"
local influxdb_export_api = require "influxdb_export_api"
    
-- ##############################################

if influxdb_export_api.isInfluxdbEnabled() then
    -- Defines an hook which is executed every minute
    local last_error = ntop.getCache("ntopng.cache.influxdb.last_error")

    -- Note: last_error is automatically cleared once the error is gone
    if(not isEmptyString(last_error)) then
        local influxdb = ts_utils.getQueryDriver()

        local alert_type = alert_consts.alert_types.alert_influxdb_error.new(
            last_error
        )

        alert_type:set_score_error()
        alert_type:set_granularity(alert_consts.alerts_granularities.min)

        alert_type:store(alerts_api.systemEntity())
    end
end

-- ##############################################
