return {
  label = "active_monitoring_stats.active_monitoring",
  script = "active_monitoring_stats.lua",
  sort_order = 1500,
  menu_entry = {key = "active_monitor", i18n_title = "active_monitoring_stats.active_monitoring", section = "system_stats"},

  is_shown = function()
    local user_scripts = require("user_scripts")

    return(user_scripts.isSystemScriptEnabled("active_monitoring"))
  end
}
