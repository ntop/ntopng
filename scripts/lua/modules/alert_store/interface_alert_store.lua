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
   local subtype = alert.subtype or ''

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, tstamp, tstamp_end, severity, score, ifid, subtype, name, alias, granularity, json) "..
      "VALUES (%u, %u, %u, %u, %u, %d, '%s', '%s', '%s', %u, '%s'); ",
      self._table_name,
      alert.alert_id,
      alert.tstamp,
      alert.tstamp_end,
      ntop.mapScoreToSeverity(alert.score),
      alert.score,
      alert.ifid,
      self:_escape(subtype),
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
   local subtype = _GET["subtype"]
   
   self:add_filter_condition_list('subtype', subtype)
end

-- ##############################################

--@brief Get info about additional available filters
function interface_alert_store:_get_additional_available_filters()
   local filters = {
      subtype = {
	 value_type = 'text',
	 i18n_label = i18n('tags.subtype'),
      }
   }

   return filters
end 

-- ##############################################

local RNAME = {
   ALERT_NAME = { name = "alert_name", export = true},
   SUBTYPE = { name = "subtype", export = true},
   MSG = { name = "msg", export = true, elements = {"name", "value", "description"}}
}

function interface_alert_store:get_rnames()
   return RNAME
end

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function interface_alert_store:format_record(value, no_html)
   local record = self:format_json_record_common(value, alert_entities.interface.entity_id, no_html)

   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html, alert_entities.interface.entity_id)
   local alert_fullname = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), true, alert_entities.interface.entity_id)
   local subtype = value.subtype
   local alert_info = alert_utils.getAlertInfo(value)
   local msg = alert_utils.formatAlertMessage(interface.getId(), value, alert_info)

   record[RNAME.ALERT_NAME.name] = alert_name
   record[RNAME.SUBTYPE.name] = subtype

   if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
      msg = ""
   end

   if no_html then
      msg = noHtml(msg)
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

return interface_alert_store
