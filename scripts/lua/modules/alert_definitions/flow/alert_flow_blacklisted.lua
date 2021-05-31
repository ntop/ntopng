--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_flow_blacklisted = classes.class(alert)

-- ##############################################

alert_flow_blacklisted.meta = {
   alert_key = flow_alert_keys.flow_alert_blacklisted,
   i18n_title = "alerts_dashboard.blacklisted_flow",
   icon = "fas fa-fw fa-exclamation",

   has_victim = true,
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param info A flow info table fetched with `flow.getBlacklistedInfo()`
-- @return A table with the alert built
function alert_flow_blacklisted:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_flow_blacklisted.format(ifid, alert, alert_type_params)
   local who = {}

   if not alert_type_params then
      return i18n("flow_details.blacklisted_flow")
   end

   if alert_type_params["cli_blacklisted"] then
      who[#who + 1] = i18n("client")
   end

   if alert_type_params["srv_blacklisted"] then
      who[#who + 1] = i18n("server")
   end

   -- if either the client or the server is blacklisted
   -- then also the category is blacklisted so there's no need
   -- to check it.
   -- Domain is basically the union of DNS names, SSL CNs and HTTP hosts.
   if #who == 0 and alert_type_params["cat_blacklisted"] then
      who[#who + 1] = i18n("domain")
   end

   if #who == 0 then
      return i18n("flow_details.blacklisted_flow")
   end

   local res = i18n("flow_details.blacklisted_flow_detailed", {who = table.concat(who, ", ")})

   return res
end

-- #######################################################

return alert_flow_blacklisted
