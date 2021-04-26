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
local discover = require "discover_utils"
local json = require "dkjson"

-- ##############################################

local mac_alert_store =  classes.class(alert_store)

-- ##############################################

function mac_alert_store:init(args)
   self.super:init()

   self._table_name = "mac_alerts"
   self._alert_entity = alert_entities.mac
end

-- ##############################################

function mac_alert_store:insert(alert)
   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, tstamp, tstamp_end, severity, address, device_type, name, "..
      "is_attacker, is_victim, json) "..
      "VALUES (%u, %u, %u, %u, '%s', %u, '%s', %u, %u, '%s'); ",
      self._table_name, 
      alert.alert_id,
      alert.tstamp,
      alert.tstamp_end,
      alert.severity,
      self:_escape(alert.entity_val),
      alert.device_type or 0,
      self:_escape(alert.device_name),
      ternary(alert.is_attacker, 1, 0),
      ternary(alert.is_victim, 1, 0),
      self:_escape(alert.json))

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   return interface.alert_store_query(insert_stmt)
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function mac_alert_store:_add_additional_request_filters()
   -- Add filters specific to the mac family
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function mac_alert_store:format_record(value)
   local record = self:format_record_common(value, alert_entities.mac.entity_id)

   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), false, alert_entities.mac.entity_id)
   local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)

   record["alert_name"] = alert_name
   record["address"] = value["address"]
   record["device_type"] = { 
     value = value["device_type"],
     label = discover.devtype2string(value["device_type"]),
   }
   record["msg"] = msg

   return record
end

-- ##############################################

return mac_alert_store
