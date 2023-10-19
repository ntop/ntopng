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

local host_alert_score_anomaly = classes.class(alert)

-- ##############################################

host_alert_score_anomaly.meta = {
  alert_key = host_alert_keys.host_alert_score_anomaly,
  i18n_title = "alerts_dashboard.score_anomaly",
  icon = "fas fa-fw fa-life-ring",
  has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function host_alert_score_anomaly:init()
   -- Call the parent constructor
   self.super:init()
end

-- ##############################################

-- @brief Local function used to get the most inpactant category for the score
-- @return The score category
local function get_problematic_category(alert_type_params, is_both, is_client_or_srv)
   local score_category_network  = 0
   local score_category_security = 0
   local tot                     = 0

   if is_both then
      score_category_network = alert_type_params["score_breakdown_client_0"] +
	 alert_type_params["score_breakdown_server_0"]
      score_category_security = alert_type_params["score_breakdown_client_1"] +
	 alert_type_params["score_breakdown_server_1"]
      
      tot = score_category_network + score_category_security
   else
      score_category_network = alert_type_params["score_breakdown_" .. is_client_or_srv .. "_0"]
      score_category_security = alert_type_params["score_breakdown_" .. is_client_or_srv .. "_1"]
      tot = score_category_network + score_category_security
   end

   if(tot > 0) then
      score_category_network  = (score_category_network*100)/tot
      score_category_security = 100 - score_category_network
   end

   return string.format('%.01f', score_category_network), string.format('%.01f', score_category_security)
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_score_anomaly.format(ifid, alert, alert_type_params)
   local alert_consts = require("alert_consts")
   local is_client_alert = alert_type_params["is_client_alert"]
   local is_both = alert_type_params["is_both"]
   local role
   local host = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
   local cli_or_srv
  
   if(is_both) then
      role = i18n("client_and_server")
   elseif(is_client_alert) then
      role = i18n("client")
      cli_or_srv = "client" 
   else
      role = i18n("server")
      cli_or_srv = "server"
   end

   local cat_net, cat_sec = get_problematic_category(alert_type_params, is_both, cli_or_srv)
   local alert_url = ntop.getHttpPrefix() .. '/lua/alert_stats.lua?'
   local url_params = {
      ip = alert["ip"] .. ';eq',
      page = 'flow',
      status = 'historical',
      epoch_begin = (alert["tstamp_end"] or os.time()) - (30 * 10),
      epoch_end = (alert["tstamp_end"] or os.time()) + (30 * 10)
   }

   local flow_params = alert_url .. table.tconcat(url_params, "=", "&")

   url_params['page'] = 'host'

   local host_params_historical = alert_url .. table.tconcat(url_params, "=", "&")

   url_params['status'] = 'engaged'

   local host_params_engaged = alert_url .. table.tconcat(url_params, "=", "&")

   -- Anomaly due to DES anomaly
   return i18n("alert_messages.score_number_anomaly", {
		role = role,
		host = host,
		score = alert_type_params["value"],
		lower_bound = alert_type_params["lower_bound"],
		upper_bound = alert_type_params["upper_bound"],
      cat_net = cat_net,
      cat_sec = cat_sec,
      flow_params = flow_params,
      host_params_historical = host_params_historical,
      host_params_engaged = host_params_engaged,
   })
end

-- #######################################################

-- @brief Prepare a table containing a set of filters useful to query historical flows that contributed to the generation of this alert
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_score_anomaly.filter_to_past_flows(ifid, alert, alert_type_params)
   local res = {}
   local host_key = hostinfo2hostkey({ip = alert["ip"], vlan = alert["vlan_id"]})

   -- Filter by client or server, depending on whether this alert is as-client or as-server
   if alert["is_client"] == true or alert["is_client"] == "1" then
      res["cli_ip"] = host_key
   elseif alert["is_server"] == true or alert["is_server"] == "1" then
      res["srv_ip"] = host_key
   end

   -- A non-normal flow status
   res["score"] = true

   return res
end

-- #######################################################

return host_alert_score_anomaly
