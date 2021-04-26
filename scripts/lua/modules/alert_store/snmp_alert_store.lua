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
local snmp_utils = require "snmp_utils"
local json = require "dkjson"

-- ##############################################

local snmp_alert_store = classes.class(alert_store)

-- ##############################################

function snmp_alert_store:init(args)
   self.super:init()

   self._table_name = "snmp_alerts"
   self._alert_entity = alert_entities.snmp_device
end

-- ##############################################

function snmp_alert_store:insert(alert)
   local device_ip
   local device_name
   local port
   local port_name

   if not isEmptyString(alert.json) then
      local snmp_json = json.decode(alert.json)
      if snmp_json then
         device_ip = snmp_json.device
         device_name = snmp_json.device_name
         port = snmp_json.interface
         port_name = snmp_json.interface_name
      end
   end

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, tstamp, tstamp_end, severity, ip, name, port, port_name, json) "..
      "VALUES (%u, %u, %u, %u, '%s', '%s', %u, '%s', '%s'); ",
      self._table_name, 
      alert.alert_id,
      alert.tstamp,
      alert.tstamp_end,
      alert.severity,
      self:_escape(device_ip or alert.entity_val),
      self:_escape(device_name),
      port or 0,
      self:_escape(port_name),
      self:_escape(alert.json))

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   return interface.alert_store_query(insert_stmt)
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function snmp_alert_store:_add_additional_request_filters()
   -- Add filters specific to the snmp family
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function snmp_alert_store:format_record(value)
   local record = self:format_record_common(value, alert_entities.snmp_device.entity_id)

   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), false, alert_entities.snmp_device.entity_id)
   local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)

   record["alert_name"] = {
      label = alert_name,
      value = value["alert_id"]
   }
   record["ip"] = value["ip"]
   record["name"] = snmp_utils.get_snmp_device_sysname(value["ip"]) or ""
   record["port"] = {
      value = value["port"],
      label = value["port_name"]
   }
   record["msg"] = msg

   return record
end

-- ##############################################

return snmp_alert_store
