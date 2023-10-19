--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"
local json = require("dkjson")

-- ##############################################

local alert_quota_exceeded = classes.class(alert)

-- ##############################################

alert_quota_exceeded.meta = {
   alert_key = other_alert_keys.alert_quota_exceeded,
   i18n_title = "alerts_dashboard.quota_exceeded",
   icon = "fas fa-fw fa-thermometer-full",
   entities = {
      alert_entities.host_pool
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param pool The host pool structure
-- @param proto The Layer-7 application which exceeded the quota
-- @param value The latest measured value
-- @param quota The quota set
-- @return A table with the alert built
function alert_quota_exceeded:init(pool, proto, value, quota)

   -- Call the parent constructor
   self.super:init()

   local host_pools = require "host_pools"
   local host_pools_instance = host_pools:create()

   local pool_name = host_pools_instance:get_pool_name(pool);

   --[[
   if not pool_name and ntop.isnEdge() then
      local host_pools_nedge = require "host_pools_nedge"
      pool_name = host_pools_nedge.getPoolName(pool)
   end
   --]]

   if not pool_name then
      pool_name = '-'
   end

   self.alert_type_params = {
      pool = pool_name,
      proto = proto,
      value = value,
      quota = quota,
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_quota_exceeded.format(ifid, alert, alert_type_params)
   local quota_str
   local value_str
   local subject_str
   -- local alert_info = json.decode(alert.json)   

   if alert.subtype == "traffic_quota" then
      quota_str = bytesToSize(alert_type_params.quota)
      value_str = bytesToSize(alert_type_params.value)
      subject_str = i18n("alert_messages.proto_bytes_quotas", {proto=alert_type_params.proto})
   else
      quota_str = secondsToTime(alert_type_params.quota)
      value_str = secondsToTime(alert_type_params.value)
      subject_str = i18n("alert_messages.proto_time_quotas", {proto=alert_type_params.proto})
   end

   return(i18n("alert_messages.subject_quota_exceeded", {
      pool = alert_type_params.pool,
      url = getNedgeHostPoolUrl(alert_type_params.pool),
      subject = subject_str,
      quota = quota_str,
      value = value_str
   }))
end

-- #######################################################

return alert_quota_exceeded
