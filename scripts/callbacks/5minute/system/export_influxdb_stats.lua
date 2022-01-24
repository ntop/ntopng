--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_dump = require "ts_5min_dump_utils"
local ts_utils = require "ts_utils_core"
local influxdb_export_api = require "influxdb_export_api"

-- ##############################################

if influxdb_export_api.isInfluxdbEnabled() then
   local influxdb = ts_utils.getQueryDriver()
   local when = os.time()

   influxdb_export_api.exportStats(when, influxdb)
   influxdb_export_api.measureRtt(when, influxdb)
   influxdb_export_api.exportStorageSize(when, influxdb)
end

-- ##############################################
