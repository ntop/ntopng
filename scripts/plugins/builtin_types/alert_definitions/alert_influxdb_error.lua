--
-- (C) 2019-20 - ntop.org
--

local function formatInfluxdbErrorMessage(ifid, alert, status)
  return(status.error_msg)
end

return {
  i18n_title = "alerts_dashboard.influxdb_error",
  i18n_description = formatInfluxdbErrorMessage,
  icon = "fas fa-database",
}
