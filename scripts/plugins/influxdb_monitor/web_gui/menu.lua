return {
  label = "InfluxDB",
  script = "influxdb_stats.lua",
  sort_order = 1600,
  is_shown = function()
    local ts_utils = require("ts_utils_core")

    return(ts_utils.getDriverName() == "influxdb")
  end
}
