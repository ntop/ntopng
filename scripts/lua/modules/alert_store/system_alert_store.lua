--
-- (C) 2021-22 - ntop.org
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

local system_alert_store = classes.class(alert_store)

-- ##############################################

function system_alert_store:init(args)
   self.super:init()

   self._table_name = "system_alerts"
   self._alert_entity = alert_entities.other -- TODO check this
end

-- ##############################################

--@brief ifid
function system_alert_store:get_ifid()
   -- The System Interface has the id -1 and in u_int16_t is 65535 
   return 65535
end

-- ##############################################

function system_alert_store:insert(alert)
   local extra_columns = ""
   local extra_values = ""
   if(ntop.isClickHouseEnabled()) then
      extra_columns = "rowid, "
      extra_values = "generateUUIDv4(), "
   end
   local interface_id = self:get_ifid() -- interface.getId()
   interface_id = self:_convert_ifid(interface_id)

   local insert_stmt = string.format("INSERT INTO %s "..
      "(%salert_id, interface_id, tstamp, tstamp_end, severity, score, name, granularity, json) "..
      "VALUES (%s%u, %d, %u, %u, %u, %u, '%s', %u, '%s'); ",
      self._table_name, 
      extra_columns,
      extra_values,
      alert.alert_id,
      interface_id,
      alert.tstamp,
      alert.tstamp_end,
      map_score_to_severity(alert.score),
      alert.score,
      self:_escape(alert.entity_val),
      alert.granularity,
      self:_escape(alert.json))

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   local ret = ntop.alert_store_query(insert_stmt, -1 --[[ System ifid --]])

   return ret
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function system_alert_store:_add_additional_request_filters()
   -- Add filters specific to the system family
end

-- ##############################################

local RNAME = {
   ALERT_NAME = { name = "alert_name", export = true},
   DESCRIPTION = { name = "description", export = true},
   MSG = { name = "msg", export = true, elements = {"name", "value", "description"}}
}

function system_alert_store:get_rnames()
   return RNAME
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function system_alert_store:format_record(value, no_html)
   local record = self:format_json_record_common(value, no_html)

   local alert_info = alert_utils.getAlertInfo(value)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html, alert_entities.system.entity_id)
   local alert_fullname = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), true, alert_entities.system.entity_id)
   local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)

   record[RNAME.ALERT_NAME.name] = alert_name

   if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
      msg = ""
   end

   record[RNAME.DESCRIPTION.name] = msg

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

return system_alert_store
