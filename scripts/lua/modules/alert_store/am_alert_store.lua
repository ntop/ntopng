--
-- (C) 2021-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

-- Import the classes library.
local classes = require "classes"

require "lua_utils"
local alert_store = require "alert_store"
local format_utils = require "format_utils"
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_entities = require "alert_entities"
local json = require "dkjson"
local plugins_utils = require "plugins_utils"

-- ##############################################

local am_alert_store = classes.class(alert_store)

-- ##############################################

function am_alert_store:init(args)
   self.super:init()

   self._table_name = "active_monitoring_alerts"
   self._alert_entity = alert_entities.am_host
end

-- ##############################################

function am_alert_store:insert(alert)
   local resolved_ip
   local resolved_name
   local measurement
   local measure_threshold
   local measure_value

   if not isEmptyString(alert.json) then
      local am_json = json.decode(alert.json)
      if am_json then
         resolved_ip = am_json.ip
         if am_json.host then
            resolved_name = am_json.host.host
	    measurement = am_json.host.measurement
         end
         measure_threshold = am_json.threshold
         measure_value = am_json.value
      end
   end

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, tstamp, tstamp_end, severity, score, interface_id, resolved_ip, resolved_name, "..
      "measurement, measure_threshold, measure_value, json) "..
      "VALUES (%u, %u, %u, %u, %u, %d, '%s', '%s', '%s', %u, %f, '%s'); ",
      self._table_name, 
      alert.alert_id,
      alert.tstamp,
      alert.tstamp_end,
      ntop.mapScoreToSeverity(alert.score),
      alert.score,
      getSystemInterfaceId(),
      self:_escape(resolved_ip),
      self:_escape(resolved_name),
      self._escape(measurement),
      measure_threshold or 0,
      measure_value or 0,
      self:_escape(alert.json))

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   return interface.alert_store_query(insert_stmt)
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function am_alert_store:_add_additional_request_filters()
   -- Add filters specific to the active monitoring family
end

-- ##############################################

local RNAME = {
   ALERT_NAME = { name = "alert_name", export = true},
   MEASUREMENT = { name = "measurement", export = true},
   MEASURE_THRESHOLD = { name = "measure_threshold", export = true},
   MEASURE_VALUE = { name = "measure_value", export = true},
   MSG = { name = "msg", export = true, elements = {"name", "value", "description"}}
}

function am_alert_store:get_rnames()
   return RNAME
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function am_alert_store:format_record(value, no_html)
   local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")
   local record = self:format_json_record_common(value, alert_entities.am_host.entity_id, no_html)

   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html, alert_entities.am_host.entity_id)
   local alert_fullname = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), true, alert_entities.am_host.entity_id)
   local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)

   if alert_info.threshold > 0 then
      record[RNAME.MEASURE_THRESHOLD.name] = format_utils.formatValue(alert_info.threshold)
   end

   if alert_info.value > 0 then
      record[RNAME.MEASURE_VALUE.name] = alert_info.value
   end

   local measurement_info = am_utils.getMeasurementInfo(alert_info.host.measurement)
   record[RNAME.MEASUREMENT.name] = i18n(measurement_info.i18n_label)

   record[RNAME.ALERT_NAME.name] = alert_name

   if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
      msg = ""
   end

   record[RNAME.MSG.name] = {
     name = noHtml(alert_name),
     fullname = alert_fullname,
     value = tonumber(value["alert_id"]),
     description = msg,
     configset_ref = alert_utils.getConfigsetAlertLink(alert_info)
   }

   return record
end

-- ##############################################

return am_alert_store
