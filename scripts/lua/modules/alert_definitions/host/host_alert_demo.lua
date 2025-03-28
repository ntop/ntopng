--
-- (C) 2019-25 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"
local classes = require "classes"
local alert = require "alert"
local mitre = require "mitre_utils"

-- ##############################################

local host_alert_demo = classes.class(alert)

-- ##############################################

host_alert_demo.meta = {
  alert_key = host_alert_keys.host_alert_demo,
  i18n_title = "alerts_dashboard.demo",
  icon = "fas fa-exclamation-triangle",

   -- Mitre Att&ck Matrix values
  mitre_values = {},
  has_attacker = false,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function host_alert_demo:init(ifid, client)
  self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_demo.format(ifid, alert, alert_type_params)
  return i18n("alert_messages.demo",{})
end

-- #######################################################

return host_alert_demo
