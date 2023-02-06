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

local host_alert_score_threshold = classes.class(alert)

-- ##############################################

host_alert_score_threshold.meta = {
  alert_key = host_alert_keys.host_alert_score_threshold,
  i18n_title = "alerts_thresholds_config.score_threshold_title",
  icon = "fas fa-fw fa-life-ring",
  has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function host_alert_score_threshold:init(threshold)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      threshold = threshold,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_score_threshold.format(ifid, alert, alert_type_params)
   local alert_consts = require("alert_consts")
   local host = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
   local threshold = alert_type_params["threshold"] or 0
   local as_cli_or_srv = i18n("client")
   local as_cli = true
   local vlan_id = tonumber(alert["vlan_id"])

   if alert_type_params["is_client_alert"] == false then
      as_cli_or_srv = i18n("server")
      as_cli = false
   end
   
   local flows_info_href = '(check live:  <a href="' .. ntop.getHttpPrefix().."/lua/flows_stats.lua?host="..host..'" data-placement="bottom" title="Live Flow Explorer"><i class="fas fa-search-plus"></i></a>)'
   
   if ntop.isClickHouseEnabled() then

      local extra_params = {
         ifid = {
            value = ifid,
            operator = "eq"
         },
         epoch_begin = {
            value = alert.tstamp,
            operator = "eq"
         },
         epoch_end = {
            value = alert.tstamp_end,
            operator = "eq"
         }
      }
      if vlan_id and vlan_id > 0 then
         extra_params.vlan_id = {
            value = alert["vlan_id"],
            operator = "eq"
         }
      end      

      if as_cli then 
         extra_params.cli_ip = {
            value = alert["ip"],
            operator = "eq"
         }
      else 
         extra_params.srv_ip = {
            value = alert["ip"],
            operator = "eq"
         }
      end

      flows_info_href = flows_info_href..' (check historical: <a href="' .. add_historical_flow_explorer_button_ref(extra_params,true) ..'" data-placement="bottom" title="Historical Flow Explorer"><i class="fas fa-search-plus"></i></a>)' 
   end

   if (tonumber(alert_type_params["value"]) > tonumber(threshold)) and (threshold > 0) then
      -- threshold due to threshold crossed
      return i18n("alert_messages.score_threshold", {
         entity = host,
         cli_or_srv = as_cli_or_srv,
         value = alert_type_params["value"],
         threshold = threshold,
         flows_info = flows_info_href
      })
   end
end

-- #######################################################

return host_alert_score_threshold
