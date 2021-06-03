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

local network_alert_store = classes.class(alert_store)

-- ##############################################

function network_alert_store:init(args)
   self.super:init()

   self._table_name = "network_alerts"
   self._alert_entity = alert_entities.network
end

-- ##############################################

function network_alert_store:insert(alert)
   local name = alert.entity_val
   local alias = getLocalNetworkAlias(name)

   local insert_stmt = string.format("INSERT INTO %s "..
      "(alert_id, tstamp, tstamp_end, severity, score, local_network_id, name, alias, granularity, json) "..
      "VALUES (%u, %u, %u, %u, %u, %u, '%s', '%s', %u, '%s'); ",
      self._table_name, 
      alert.alert_id,
      alert.tstamp,
      alert.tstamp_end,
      ntop.mapScoreToSeverity(alert.score),
      alert.score,
      ntop.getLocalNetworkID(name),
      self:_escape(name),
      self:_escape(alias),
      alert.granularity,
      self:_escape(alert.json))

   -- traceError(TRACE_NORMAL, TRACE_CONSOLE, insert_stmt)

   return interface.alert_store_query(insert_stmt)
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function network_alert_store:_add_additional_request_filters()
   -- Add filters specific to the system family
end

-- ##############################################

--@brief Performs a query for the top networks by alert count
function network_alert_store:top_local_network_id_historical()
   -- Preserve all the filters currently set
   local where_clause = table.concat(self._where, " AND ")

   local q = string.format("SELECT local_network_id, count(*) count, name FROM %s WHERE %s GROUP BY local_network_id ORDER BY count DESC LIMIT %u",
			   self._table_name, where_clause, self._top_limit)

   local q_res = interface.alert_store_query(q) or {}

   return q_res
end

-- ##############################################

--@brief Stats used by the dashboard
function network_alert_store:_get_additional_stats()
   local stats = {}
   stats.top = {}
   stats.top.local_network_id = self:top_local_network_id_historical()
   return stats
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function network_alert_store:format_record(value, no_html)
   local record = self:format_record_common(value, alert_entities.network.entity_id, no_html)

   local alert_id_label = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html)
   local alert_name = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), no_html, alert_entities.network.entity_id)
   local alert_info = alert_utils.getAlertInfo(value)
   local msg = alert_utils.formatAlertMessage(ifid, value, alert_info)

   record["alias"] = value.alias
   record["local_network_id"] = value.local_network_id
   record["network"] = value.name

   record["alert_name"] = alert_name

   if string.lower(noHtml(msg)) == string.lower(noHtml(alert_name)) then
      msg = ""
   end

   record["msg"] = {
     name = noHtml(alert_name),
     value = tonumber(value["alert_id"]),
     description = msg,
     configset_ref = alert_utils.getConfigsetAlertLink(alert_info)
   }

   return record
end

-- ##############################################

return network_alert_store
