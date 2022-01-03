--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local host_alert_keys = require "host_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local host_alert_tcp_syn_flood = classes.class(alert)

-- ##############################################

host_alert_tcp_syn_flood.meta = {
  alert_key = host_alert_keys.host_alert_syn_flood,
  i18n_title = "alerts_dashboard.tcp_syn_flood",
  icon = "fas fa-fw fa-life-ring",
  has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function host_alert_tcp_syn_flood:init(metric, value, operator, threshold)
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
function host_alert_tcp_syn_flood.format(ifid, alert, alert_type_params)
  local alert_consts = require "alert_consts"
  local entity = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
  local i18n_key

  if alert_type_params.is_attacker then
    i18n_key = "alert_messages.syn_flood_attacker"
  else
    i18n_key = "alert_messages.syn_flood_victim"
  end

  return i18n(i18n_key, {
    entity = entity,
    value = string.format("%u", math.ceil(alert_type_params.value or 0)),
    threshold = alert_type_params.threshold or 0,
  })
end

-- #######################################################

-- @brief Prepare a table containing a set of filters useful to query historical flows that contributed to the generation of this alert
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_tcp_syn_flood.filter_to_past_flows(ifid, alert, alert_type_params)
   local res = {}
   local host_key = hostinfo2hostkey({ip = alert["ip"], vlan = alert["vlan_id"]})

   -- Filter by client or server, depending on whether this alert is as-client or as-server
   if alert["is_client"] == true or alert["is_client"] == "1" then
      res["cli_ip"] = host_key
   elseif alert["is_server"] == true or alert["is_server"] == "1" then
      res["srv_ip"] = host_key
   end

   res["src2dst_tcp_flags"] = 0x02 -- Has SYN
   -- res["dst2src_tcp_flags"] = 0x16 -- TODO: Doesn't have ACK

   res["l4proto"] = "TCP"

   return res
end

-- #######################################################

return host_alert_tcp_syn_flood
