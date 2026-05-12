local active_monitoring = require("active_monitoring")
local json = require("dkjson")

return {
   name = "add_active_monitoring_script",
   description = "Enable a new active monitoring script for a host.\n\n" ..
      "IMPORTANT: always call list_available_active_monitoring_scripts first to get valid values.\n\n" ..
      "Parameters (all required):\n" ..
      "1. host (string): target hostname or IP. For HTTP use http://HOST:80, for HTTPS https://HOST:443\n" ..
      "2. measurement (string): e.g. cicmp, http, icmp, speedtest, throughput\n" ..
      "3. ifid (int): interface id\n" ..
      "4. threshold (number): alert threshold value\n" ..
      "5. granularity (string): e.g. min, 5mins, hour\n\n" ..
      "Returns: {success: true/false, error: '...'}",
   handler = function(params)
      if type(params) ~= "table" then
         return json.encode({ success = false, error = "invalid parameters: expected JSON object" })
      end
      local host        = params.host
      local measurement = params.measurement
      local ifid        = params.ifid
      local threshold   = params.threshold
      local granularity = params.granularity
      local success, err = active_monitoring.add_am_script(host, measurement, ifid, threshold, granularity)
      return json.encode({ success = success, error = err })
   end,
   opts = {}
}
