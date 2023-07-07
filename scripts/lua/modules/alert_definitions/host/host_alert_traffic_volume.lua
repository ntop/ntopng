--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"
local format_utils = require("format_utils")

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_traffic_volume = classes.class(alert)

-- ##############################################

host_alert_traffic_volume.meta = {
  alert_key = host_alert_keys.host_alert_traffic_volume,
  i18n_title = "alerts_dashboard.alert_traffic_volume",
  icon = "fas fa-fw fa-life-ring",
  has_attacker = false,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function host_alert_traffic_volume:init(metric, value, operator, threshold)
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
function host_alert_traffic_volume.format(ifid, alert, alert_type_params)
  local alert_consts = require "alert_consts"

  if(alert_type_params.metric ~=  "host:score") then
     alert_type_params.value     = format_utils.bytesToSize(alert_type_params.value)
     alert_type_params.threshold = format_utils.bytesToSize(alert_type_params.threshold)
  end

  if(alert_type_params.frequency == 300) then
     alert_type_params.frequency = i18n("edit_check.hooks_name.5mins")
  elseif(alert_type_params.frequency == 3600) then
     alert_type_params.frequency = i18n("edit_check.hooks_name.hour")
  else
     alert_type_params.frequency = i18n("edit_check.hooks_name.day")
  end

  local sign = ">"

  if not toboolean(alert_type_params.sign) then
   sign = "<"
  end
  
  return i18n("alert_messages.traffic_volume_alert", { metric = alert_type_params.metric, value = alert_type_params.value, threshold = alert_type_params.threshold,
						       frequency = alert_type_params.frequency, message = alert_type_params["message"], sign = sign } )
end

-- #######################################################

-- @brief Prepare a table containing a set of filters useful to query historical flows that contributed to the generation of this alert
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_traffic_volume.filter_to_past_flows(ifid, alert, alert_type_params)
   local res = {}
   local host_key = hostinfo2hostkey({ip = alert["ip"], vlan = alert["vlan_id"]})

   -- Filter by client or server, depending on whether this alert is as-client or as-server
   if alert["is_client"] == true or alert["is_client"] == "1" then
      res["cli_ip"] = host_key
   elseif alert["is_server"] == true or alert["is_server"] == "1" then
      res["srv_ip"] = host_key
   end

   return res
end

-- #######################################################

return host_alert_traffic_volume
