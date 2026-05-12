local active_monitoring = require("active_monitoring")
local json = require("dkjson")

return {
   name = "list_enabled_active_monitoring_scripts",
   description = "Retrieve all currently enabled active monitoring scripts.\n\n" ..
      "Each result contains: target host information, measurement type, threshold, granularity, last measurement value, alert status.\n\n" ..
      "Parameters:\n" ..
      "1. interface_id (number, required): ID of the interface used for monitoring\n" ..
      "2. measurement (string, optional): filter by measurement key (e.g. http, icmp)\n",
   handler = function(params)
      local ifid        = params.interface_id or params.ifid or interface.getId()
      local measurement = params.measurement
      local enabled     = active_monitoring.list_am_scripts(ifid, measurement)
      return json.encode(enabled)
   end,
   opts = { read_only = true }
}
