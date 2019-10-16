--
-- (C) 2019 - ntop.org
--

local function slowPeriodicActivityFormatter(ifid, alert, info)
  local duration
  local max_duration

  if(info.max_duration_ms > 3000) then
    duration = string.format("%u s", math.floor(info.duration_ms/1000))
    max_duration = string.format("%u s", math.floor(info.max_duration_ms/1000))
  else
    duration = string.format("%u ms", math.floor(info.duration_ms))
    max_duration = string.format("%u ms", math.floor(info.max_duration_ms))
  end

  return(i18n("alert_messages.slow_periodic_activity", {
    script = alert.alert_entity_val,
    duration = duration,
    max_duration = max_duration,
  }))
end

-- #######################################################

return {
  alert_id = 40,
  i18n_title = "alerts_dashboard.slow_periodic_activity",
  i18n_description = slowPeriodicActivityFormatter,
  icon = "fa-undo",
}
