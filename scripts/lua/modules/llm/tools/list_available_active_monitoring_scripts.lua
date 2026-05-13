local json = require("dkjson")

return {
   name = "list_available_active_monitoring_scripts",
   description = "Retrieve all available active monitoring script definitions.\n\n" ..
      "Active monitoring scripts are periodic checks executed against a host to verify availability or performance. " ..
      "Each script definition includes: key, label, unit, operator, max_threshold, default_threshold, granularities, force_host.\n\n" ..
      "Use this tool BEFORE enabling a script to ensure valid parameters.\n\nInput: none.",
   handler = function(_)
      local pcall_ok, active_monitoring = pcall(function() return require("active_monitoring") end)

      if not pcall_ok then
         return json.encode({error = "Could not load active_monitoring module"})
      end

      local am_defs = active_monitoring.get_am_defs()

      if type(am_defs) ~= "table" then
         return json.encode({error = "Invalid response from active_monitoring module", details = tostring(am_defs)})
      end

      return json.encode(am_defs)
   end,
   opts = { read_only = true }
}
