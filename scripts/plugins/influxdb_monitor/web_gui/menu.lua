return {
  label = "InfluxDB",
  script = "influxdb_stats.lua",
  sort_order = 1600,
  is_shown = function()
    local ts_utils = require("ts_utils_core")
    local user_scripts = require("user_scripts")

    return((ts_utils.getDriverName() == "influxdb") and
      user_scripts.isSystemScriptEnabled("influxdb_monitor"))
  end
}
