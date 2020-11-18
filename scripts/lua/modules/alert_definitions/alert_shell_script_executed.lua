--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"

local function formatAlertShellExec(ifid, alert, info)
  return(i18n("alert_messages.shell_script_executed", {
    script_exec_comm = info.script_exec_comm,
    alert_type = info.alert_type,
  }))
end

-- #######################################################

local function createAlertShellExec(alert_severity, script_exec_comm, alert_type)
    local shell_script_type = {
        alert_severity = alert_severity,
        alert_type_params = {
            script_exec_comm = script_exec_comm,
            alert_type = alert_type, 
        }
     }
  
    return shell_script_type
end
  
  -- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_shell_script_executed,
  i18n_title = "alerts_dashboard.shell_script",
  i18n_description = formatAlertShellExec,
  icon = "fas fa-info-circle",
  creator = createAlertShellExec
}