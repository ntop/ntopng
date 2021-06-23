--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_fail2ban_executed = classes.class(alert)

-- ##############################################

alert_fail2ban_executed.meta = {
  alert_key = other_alert_keys.alert_fail2ban_executed,
  i18n_title = "alerts_dashboard.fail2ban",
  icon = "fas fa-fw fa-info-circle",
  entities = {},
}

-- ##############################################

function alert_fail2ban_executed:init(script_exec_comm, jail, ip, alert_type)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    script_exec_comm = script_exec_comm,
    jail = jail,
    ip = ip,
    alert_type = alert_type, 
   }
end

-- #######################################################

function alert_fail2ban_executed.format(ifid, alert, alert_type_params)
  return(i18n("alert_messages.fail2ban_executed", {
    script_exec_comm = alert_type_params.script_exec_comm,
    jail = alert_type_params.jail,
    ip = alert_type_params.ip,
    alert_type = alert_type_params.alert_type,
  }))
end

-- #######################################################

return alert_fail2ban_executed
