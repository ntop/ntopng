return {
  label = "host_config.rtt_monitor",
  script = "rtt_stats.lua",
  sort_order = 1500,

  is_shown = function()
    local user_scripts = require("user_scripts")

    return(user_scripts.isSystemScriptEnabled("rtt"))
  end
}
