--
-- (C) 2019 - ntop.org
--

local ts_utils = require("ts_utils_core")

local script = {
  -- This module is enabled by default
  default_enabled = true,

  -- No default configuration is provided
  default_value = {},

  -- See below
  hooks = {},
}

-- ##############################################

function script.setup()
  -- Only enabled if InfluxDB is active
  return(ts_utils.getDriverName() == "influxdb")
end

-- ##############################################

-- Defines an hook which is executed every 5 minutes
script.hooks["5mins"] = function(params)
  if params.ts_enabled then
    local influxdb = ts_utils.getQueryDriver()

    script._exportStats(when, influxdb)
    script._measureRtt(when, influxdb)
    script._exportStorageSize(when, influxdb)
  end
end

-- ##############################################

function script.getExportStats()
   local points_exported
   local points_dropped
   local exports
   local ifnames = interface.getIfNames()

   local influxdb = ts_utils.getQueryDriver()

   points_exported = influxdb:get_exported_points()
   points_dropped = influxdb:get_dropped_points()
   exports = influxdb:get_exports()

   local res = {
      health = influxdb:get_health(),
      points_exported = points_exported,
      points_dropped = points_dropped,
      exports = exports,
   }

   return(res)
end

-- ##############################################

function script._measureRtt(when, influxdb)
   local start_ms = ntop.gettimemsec()
   local res = influxdb:getInfluxdbVersion()
   local ifid = getSystemInterfaceId()

   if res ~= nil then
      local end_ms = ntop.gettimemsec()

      ts_utils.append("influxdb:rtt", {ifid = ifid, millis_rtt = ((end_ms-start_ms)*1000)}, when)
   end
end

-- ##############################################

function script._exportStats(when, influxdb)
   local stats = script.getExportStats()
   local ifid = getSystemInterfaceId()

   ts_utils.append("influxdb:exported_points", {ifid = ifid, points = stats.points_exported}, when)
   ts_utils.append("influxdb:dropped_points", {ifid = ifid, points = stats.points_dropped}, when)
   ts_utils.append("influxdb:exports", {ifid = ifid, num_exports = stats.exports}, when)
end

-- ##############################################

function script._exportStorageSize(when, influxdb)
   local disk_bytes = influxdb:getDiskUsage()
   local ifid = getSystemInterfaceId()

   if(disk_bytes ~= nil) then
      ts_utils.append("influxdb:storage_size", {ifid = ifid, disk_bytes = disk_bytes}, when)
   end
end

-- ##############################################

return(script)
