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

local interface_alert_store = classes.class(alert_store)

-- ##############################################

function interface_alert_store:init(args)
   self.super:init()

   self._table_name = "interface_alerts"
   self._alert_entity = alert_entities.interface
end

-- ##############################################

function interface_alert_store:insert(alert)
   local name = getInterfaceName(alert.ifid)
   local alias = getHumanReadableInterfaceName(name)

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, tstamp, tstamp_end, severity, ifid, name, alias, granularity, json) "..
      "VALUES (%u, %u, %u, %u, %u, '%s', '%s', %u, '%s'); ",
      self._table_name, 
      alert.alert_id,
      alert.tstamp,
      alert.tstamp_end,
      alert.severity,
      alert.ifid,
      self:_escape(name),
      self:_escape(alias),
      alert.granularity,
      self:_escape(alert.json))

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   return interface.alert_store_query(insert_stmt)
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function interface_alert_store:_add_additional_request_filters()
   -- Add filters specific to the system family
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function interface_alert_store:format_record(value)
   local record = self:format_record_common(value, alert_entities.interface.entity_id)

   local alert_id_label = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), false, alert_entities.interface.entity_id)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), false, alert_entities.interface.entity_id)
   local alert_info = alert_utils.getAlertInfo(value)
   local msg = alert_utils.formatAlertMessage(interface.getId(), value, alert_info)

   record["alert_name"] = alert_name
   record["alert_id"] = {
      label = alert_id_label,
      value = value["alert_id"]
   }
   record["msg"] = msg

   return record
end

-- ##############################################

return interface_alert_store
