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

local alert_shell_script_executed = classes.class(alert)

-- ##############################################

alert_shell_script_executed.meta = {
  alert_key = other_alert_keys.alert_shell_script_executed,
  i18n_title = "alerts_dashboard.shell_script",
  icon = "fas fa-fw fa-info-circle",
  entities = {
     alert_entities.system
  },
}

-- ##############################################

function alert_shell_script_executed:init(script_exec_comm, alert_type)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    script_exec_comm = script_exec_comm,
    alert_type = alert_type, 
   }
end

-- #######################################################

function alert_shell_script_executed.format(ifid, alert, alert_type_params)
  return(i18n("alert_messages.shell_script_executed", {
    script_exec_comm = alert_type_params.script_exec_comm,
    alert_type = alert_type_params.alert_type,
  }))
end

-- #######################################################

return alert_shell_script_executed
