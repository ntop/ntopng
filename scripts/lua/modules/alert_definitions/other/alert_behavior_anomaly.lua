--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
local classes = require "classes"
local alert = require "alert"
local alert_entities = require("alert_entities")
local behavior_utils = require("behavior_utils")

-- ##############################################

local alert_behavior_anomaly = classes.class(alert)

local i18n_title = i18n("alerts_dashboard.alert_unexpected_behavior_title", {type = ""})

-- ##############################################

alert_behavior_anomaly.meta = {
   alert_key = other_alert_keys.alert_behavior_anomaly,
   i18n_title = i18n_title,
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param entity           The entity of this anomaly (ASN, Network, ..)
-- @param type_of_behavior The type of anomaly presented (Traffic RX, Traffic TX, Score, ...)
-- @param value            The value got from the measurement
-- @param lower_bound      The lower bound of the measurement
-- @param upper_bound      The upper bound of the measurement
-- @param entity_id        The entity id of the anomaly (Found into behavior_utils.lua)
-- @param extra_params     Table of extra parameters used to create the href to the graph (e.g. protocol), pass nil if no extra params is needed
-- @return A table with the alert built
function alert_behavior_anomaly:init(entity, type_of_behavior, value, upper_bound, lower_bound, entity_id, timeseries_id, extra_params)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      entity = entity,
      type_of_behavior = type_of_behavior,
      value = value,
      upper_bound = upper_bound,
      lower_bound = lower_bound,
      entity_id = entity_id,
      timeseries_id = timeseries_id,
      extra_params = extra_params or {},
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_behavior_anomaly.format(ifid, alert, alert_type_params)
   local href = ""
   local type_of_behavior = ""
   
   -- Name of the behavior type, e.g. Score
   if alert_type_params.type_of_behavior then
      type_of_behavior = i18n("alert_behaviors." .. alert_type_params.type_of_behavior)
   end

   -- Generating the href for the timeserie
   if ntop.isEnterpriseL() then
      -- Mantaining family_key for supporting past alerts
      if (alert_type_params["family_key"] or alert_type_params["entity_id"]) and alert_type_params["timeseries_id"] then
         -- 10 minutes before and 10 minutes after the alert
         local alert_time = tonumber(alert.tstamp)
         local key = nil

         for k, v in pairs(alert_entities) do
            if v["entity_id"] == alert_type_params["entity_id"] then
               key = k
               break
            end
         end

         local timeseries_table = behavior_utils.get_behavior_timeseries_utils(key or (alert_type_params["family_key"]))
         -- Formatting all the strings used to create the href to the graph
         local timeseries_id = {}

         if timeseries_table["timeseries_id"] then
            timeseries_id[timeseries_table["timeseries_id"]] = alert_type_params["timeseries_id"]
         end

         local tmp = {
            ifid = interface.getId(),
            page = timeseries_table["page"],
            ts_schema = timeseries_table["schema_id"] .. "%3A" .. (timeseries_table["type_of_behavior"] or alert_type_params.type_of_behavior),
            zoom = "30m",
            epoch_begin = tonumber(alert_time - 600),
            epoch_end = tonumber(alert_time + 600),
         }         

         tmp = table.merge(tmp, alert_type_params["extra_params"] or {})
         tmp = table.merge(tmp, timeseries_id)
         
         href = timeseries_table["page_path"] .. "?" .. table.tconcat(tmp, "=", "&")
      end
   end

   return(i18n("alerts_dashboard.unexpected_behavior_anomaly_description", {
      entity = alert_type_params.entity or "",
      type_of_behavior = type_of_behavior,
      value = alert_type_params.value or 0,
      lower_bound = alert_type_params.lower_bound or 0,
      upper_bound = alert_type_params.upper_bound or 0,
      href = href,
   }))
end

-- #######################################################

return alert_behavior_anomaly