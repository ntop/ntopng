return {
  label = "Redis",
  script = "redis_stats.lua",
  sort_order = 1700,

  is_shown = function()
    local user_scripts = require("user_scripts")

    return(user_scripts.isSystemScriptEnabled("redis_monitor"))
  end
}
