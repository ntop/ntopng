--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local alert_creators = require "alert_creators"
local json = require("dkjson")
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_dns_server_contacts = classes.class(alert)

-- ##############################################

host_alert_dns_server_contacts.meta = {
  alert_key = host_alert_keys.host_alert_dns_server_contacts,
  i18n_title = "alerts_dashboard.host_alert_dns_server_contacts",
  icon = "fas fa-fw fa-life-ring",
  has_victim = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function host_alert_dns_server_contacts:init(metric, value, operator, threshold)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = alert_creators.createThresholdCross(metric, value, operator, threshold)
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_dns_server_contacts.format(ifid, alert, alert_type_params)
  local alert_consts = require("alert_consts")
  local entity = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
  local value = alert_type_params.value

  if(value == nil) then value = 0 end
  
  return i18n("alert_messages.host_alert_dns_server_contacts", {
    entity = entity,
    value = string.format("%u", math.ceil(value or 0)),
    threshold = alert_type_params.threshold or 0,
  })
end

-- #######################################################

-- @brief Prepare a table containing a set of filters useful to query historical flows that contributed to the generation of this alert
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_dns_server_contacts.filter_to_past_flows(ifid, alert, alert_type_params)
   local res = {}
   local host_key = hostinfo2hostkey({ip = alert["ip"], vlan = alert["vlan_id"]})

   -- Look for the IP as client as the alert is about too many contacted SERVERs
   res["cli_ip"] = host_key
   res["l7proto"] = "DNS"

   return res
end

-- #######################################################

return host_alert_dns_server_contacts
