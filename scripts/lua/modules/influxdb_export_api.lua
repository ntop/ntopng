--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_utils_core = require("ts_utils_core")

local influxdb_export_api = {}

-- ##############################################

function influxdb_export_api.isInfluxdbEnabled()
   return ts_utils_core.getDriverName() == "influxdb"
end

-- ##############################################

function influxdb_export_api.isInfluxdbChecksEnabled()
   return true -- TODO: Check if influxdb checks are enabled
end

-- ##############################################

function influxdb_export_api.getExportStats()
   local points_exported
   local points_dropped
   local exports
   local ifnames = interface.getIfNames()

   local influxdb = ts_utils_core.getQueryDriver()

   points_exported = influxdb:get_exported_points()
   exports = influxdb:get_exports()

   local res = {
      health = influxdb:get_health(),
      points_exported = points_exported,
      exports = exports,
   }

   return(res)
end

-- ##############################################

function influxdb_export_api.measureRtt(when, influxdb)
   local start_ms = ntop.gettimemsec()
   local res = influxdb:getInfluxdbVersion()
   local ifid = getSystemInterfaceId()

   if res ~= nil then
      local end_ms = ntop.gettimemsec()

      ts_utils_core.append("influxdb:rtt", { ifid = ifid, millis_rtt = ((end_ms-start_ms)*1000) }, when)
   end
end

-- ##############################################

function influxdb_export_api.exportStats(when, influxdb)
   local stats = influxdb_export_api.getExportStats()
   local ifid = getSystemInterfaceId()

   ts_utils_core.append("influxdb:exported_points", { ifid = ifid, points = stats.points_exported }, when)
   ts_utils_core.append("influxdb:exports", { ifid = ifid, num_exports = stats.exports }, when)
end

-- ##############################################

function influxdb_export_api.exportStorageSize(when, influxdb)
   local disk_bytes = influxdb:getDiskUsage()
   local ifid = getSystemInterfaceId()

   if(disk_bytes ~= nil) then
      ts_utils_core.append("influxdb:storage_size", { ifid = ifid, disk_bytes = disk_bytes }, when)
   end
end

return influxdb_export_api
