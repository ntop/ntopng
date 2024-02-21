--
-- (C) 2020-24 - ntop.org
--

-- ##############################################

-- Keep in sync with C
local alerts_granularities = {
  ["min"] = {
     granularity_id = 1,
     granularity_seconds = 60,
     i18n_title = "show_alerts.minute",
     i18n_description = "alerts_thresholds_config.every_minute",
  },
  ["5mins"] = {
     granularity_id = 2,
     granularity_seconds = 300,
     i18n_title = "show_alerts.5_min",
     i18n_description = "alerts_thresholds_config.every_5_minutes",
  },
  ["hour"] = {
     granularity_id = 3,
     granularity_seconds = 3600,
     i18n_title = "show_alerts.hourly",
     i18n_description = "alerts_thresholds_config.hourly",
  },
  ["day"] = {
     granularity_id = 4,
     granularity_seconds = 86400,
     i18n_title = "show_alerts.daily",
     i18n_description = "alerts_thresholds_config.daily",
  }
}

return alerts_granularities