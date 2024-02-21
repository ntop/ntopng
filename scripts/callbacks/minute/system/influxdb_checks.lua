--
-- (C) 2019-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local influxdb_export_api = require "influxdb_export_api"
    
-- ##############################################

if influxdb_export_api.isInfluxdbEnabled() then
    -- Defines an hook which is executed every minute
    local last_error = ntop.getCache("ntopng.cache.influxdb.last_error")

    -- Note: last_error is automatically cleared once the error is gone
    if(not isEmptyString(last_error)) then
        -- Include here, previously is a waste of memory
        local alert_consts = require "alert_consts"
        local ts_utils = require "ts_utils_core"
        local influxdb = ts_utils.getQueryDriver()

        local alert_type = alert_consts.alert_types.alert_influxdb_error.new(
            last_error
        )

        alert_type:set_score_error()
        alert_type:set_granularity("min")

        alert_type:store({
            alert_entity = alert_consts.alert_entities.system,
            entity_val = "system"
        }) -- [[ System Entity, in order to not include alerts_api, this is done ]]
    end
end

-- ##############################################

