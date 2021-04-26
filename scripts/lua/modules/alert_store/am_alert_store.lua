--
-- (C) 2021-21 - ntop.org
--

local dirs = ntop.getDirs()
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
   local measure_threshold
   local measure_value

   if not isEmptyString(alert.json) then
      local am_json = json.decode(alert.json)
      if am_json then
         resolved_ip = am_json.ip
         if am_json.host then
            resolved_name = am_json.host.host
         end
         measure_threshold = am_json.threshold
         measure_value = am_json.value
      end
   end

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, tstamp, tstamp_end, severity, interface_id, resolved_ip, resolved_name, "..
      "measure_threshold, measure_value, json) "..
      "VALUES (%u, %u, %u, %u, %d, '%s', '%s', %u, %f, '%s'); ",
      self._table_name, 
      alert.alert_id,
      alert.tstamp,
      alert.tstamp_end,
      alert.severity,
      getSystemInterfaceId(),
      self:_escape(resolved_ip),
      self:_escape(resolved_name),
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

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function am_alert_store:format_record(value)
   local record = self:format_record_common(value, alert_entities.am_host.entity_id)

   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), false, alert_entities.am_host.entity_id)
   local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)

   record["alert_name"] = alert_name
   record["threshold"] = 0
   record["value"] = 0
   record["msg"] = msg

   return record
end

-- ##############################################

return am_alert_store
