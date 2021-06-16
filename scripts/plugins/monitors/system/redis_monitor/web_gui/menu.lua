return {
  label = "Redis",
  script = "redis_stats.lua",
  sort_order = 1700,
  menu_entry = {key = "redis_monitor", i18n_title = "Redis", section = "health"},

  is_shown = function()
    local checks = require("checks")

    return(checks.isSystemScriptEnabled("redis_monitor"))
  end
}
