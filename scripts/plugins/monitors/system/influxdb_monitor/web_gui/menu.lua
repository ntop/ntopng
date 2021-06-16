return {
  label = "InfluxDB",
  script = "influxdb_stats.lua",
  sort_order = 1600,
  menu_entry = {key = "influxdb", i18n_title = "InfluxDB", section = "health"},
  is_shown = function()
    local ts_utils = require("ts_utils_core")
    local checks = require("checks")

    return((ts_utils.getDriverName() == "influxdb") and
      checks.isSystemScriptEnabled("influxdb_monitor"))
  end
}
