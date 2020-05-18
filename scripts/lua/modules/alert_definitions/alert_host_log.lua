--
-- (C) 2020 - ntop.org
--

local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"

local function formatHostLogAlert(ifid, alert, info)
  local hostinfo = hostkey2hostinfo(alert.alert_entity_val)

  return(i18n("alert_messages.host_log", {
    host = info.host,
    url = getHostUrl(hostinfo["host"], hostinfo["vlan"]),
    facility = info.facility,
    line = info.message,
  }))
end

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param host The string with the name or ip address of the host
-- @return A table with the alert built
local function createHostLogAlert(subtype, severity, host, level, facility, message)
  local built = {
    alert_severity = severity,
    alert_subtype = subtype,
    alert_type_params = {
       host = host,
       facility = facility,
       message = message,
    },
  }

  return built
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_host_log,
  i18n_title = "alerts_dashboard.host_log",
  i18n_description = formatHostLogAlert,
  icon = "fa fa-file-text-o",
  creator = createHostLogAlert,
}
