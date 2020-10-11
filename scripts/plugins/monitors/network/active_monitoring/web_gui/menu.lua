return {
  label = "active_monitoring_stats.active_monitoring",
  script = "active_monitoring_stats.lua",
  sort_order = 1500,
  menu_entry = {key = "active_monitor", i18n_title = "active_monitoring_stats.active_monitoring", section = "pollers"},

  is_shown = function()
    -- The active monitoring page is always shown. If the plugin is disabled,
    -- the page itself will show a warning
    return(true)
  end
}
