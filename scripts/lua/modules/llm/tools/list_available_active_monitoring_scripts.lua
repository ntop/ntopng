local active_monitoring = require("active_monitoring")
local json = require("dkjson")

return {
   name = "list_available_active_monitoring_scripts",
   description = "Retrieve all available active monitoring script definitions.\n\n" ..
      "Active monitoring scripts are periodic checks executed against a host to verify availability or performance. " ..
      "Each script definition includes: key, label, unit, operator, max_threshold, default_threshold, granularities, force_host.\n\n" ..
      "Use this tool BEFORE enabling a script to ensure valid parameters.\n\nInput: none.",
   handler = function(_)
      local am_defs = active_monitoring.get_am_defs()
      return json.encode(am_defs)
   end,
   opts = { read_only = true }
}
