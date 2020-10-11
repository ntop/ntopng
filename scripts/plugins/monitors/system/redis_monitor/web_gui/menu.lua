return {
  label = "Redis",
  script = "redis_stats.lua",
  sort_order = 1700,
  menu_entry = {key = "redis_monitor", i18n_title = "Redis", section = "system_health"},

  is_shown = function()
    local user_scripts = require("user_scripts")

    return(user_scripts.isSystemScriptEnabled("redis_monitor"))
  end
}
