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

-- ##############################################

local all_alert_store = classes.class(alert_store)

-- ##############################################

function all_alert_store:init(args)
   self.super:init()

   -- This is a VIEW, not a table, but still available in SQL
   self._table_name = "all_alerts"
   self._alert_entity = nil -- No entity
end

-- ##############################################

function all_alert_store:insert(alert)
   traceError(TRACE_ERROR, TRACE_CONSOLE, "Unsupported!")
end

-- ##############################################

function all_alert_store:delete()
   traceError(TRACE_ERROR, TRACE_CONSOLE, "Unsupported!")
end

-- ##############################################

function all_alert_store:select_historical(filter, fields)
   local res = {}
   local where_clause = ''
   local group_by_clause = ''
   local order_by_clause = ''
   local limit_clause = ''
   local offset_clause = ''

   -- TODO handle fields (e.g. add entity value to WHERE)

   -- Select everything by defaul
   fields = fields or '*'

   if not self:_valid_fields(fields) then
      return res
   end

   where_clause = table.concat(self._where, " AND ")

   -- [OPTIONAL] Add sort criteria
   if self._order_by then
      order_by_clause = string.format("ORDER BY %s %s", self._order_by.sort_column, self._order_by.sort_order)
   end

   -- [OPTIONAL] Add limit for pagination
   if self._limit then
      limit_clause = string.format("LIMIT %u", self._limit)
   end

   -- [OPTIONAL] Add offset for pagination
   if self._offset then
      offset_clause = string.format("OFFSET %u", self._offset)
   end

   -- Prepare the final query
   -- NOTE: there's a forceful GROUP BY using the entity id
   -- Groups are those used to group alerts in levels that are coarser than individual severities.
   -- and are defined in ntop_typedefs.h AlertLevelGroup.
   local q = string.format(" SELECT entity_id, SUM(score) score, "..
			      "SUM(group_notice_or_lower) count_group_notice_or_lower, "..
			      "SUM(group_warning) count_group_warning, "..
			      "SUM(group_error_or_higher) count_group_error_or_higher, "..
			      "COUNT(*) count, "..
			      "0 tstamp, 0 tstamp_end, '{}' json FROM "..
			      "    (SELECT entity_id, score, "..
			      "    CASE WHEN severity <= 3 THEN 1 ELSE 0 END AS group_notice_or_lower, "..
			      "    CASE WHEN severity  = 4 THEN 1 ELSE 0 END AS group_warning, "..
			      "    CASE WHEN severity >= 5 THEN 1 ELSE 0 END AS group_error_or_higher, "..
			      "    score FROM `%s` WHERE %s) "..
			      "GROUP BY entity_id %s %s %s ",
			   self._table_name, where_clause, order_by_clause, limit_clause, offset_clause)

   res = interface.alert_store_query(q)

   return res
end

-- ##############################################

--@brief Handle alerts select request (GET) from memory (engaged) or database (historical)
--       NOTE: OVERRIDES alert_store:select_request
--@param filter A filter on the entity value (no filter by default)
--@param select_fields The fields to be returned (all by default or in any case for engaged)
--@return Selected alerts, and the total number of alerts
function all_alert_store:select_request(filter, select_fields)
   -- Add filters
   self:add_request_filters()
   -- Add limits and sort criteria
   self:add_request_ranges()

   if self._engaged then -- Engaged
      local alerts, total_rows =  self:select_engaged(filter)

      return alerts, total_rows
   else -- Historical
      local res = self:select_historical(filter, select_fields)
      return res, #res
   end
end

-- ##############################################

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function all_alert_store:format_record(value, no_html)
   local href_icon = "<i class='fas fa-laptop'></i>"
   local record = self:format_record_common(value, alert_entities.host.entity_id, no_html)

   record["entity"] = string.format('<a href="%s/lua/alert_stats.lua?page=%s&epoch_begin=%u&epoch_end=%u">%s</a>',
				    ntop.getHttpPrefix(),
				    alert_consts.alertEntityRaw(value["entity_id"]),
				    _GET["epoch_begin"],
				    _GET["epoch_end"],
				    alert_consts.alertEntityById(value["entity_id"]).label)

   local score = tonumber(value["score"])
   record["score"] = {
      value = score,
      label = format_utils.formatValue(score),
   }

   record["count_group_notice_or_lower"] = value["count_group_notice_or_lower"]
   record["count_group_warning"] = value["count_group_warning"]
   record["count_group_error_or_higher"] = value["count_group_error_or_higher"]

   return record
end

-- ##############################################

--@brief Deletes old data according to the configuration or up to a safe limit
function all_alert_store:housekeeping()
   -- Nothing do do, nothing do delete or vacuum, this is just a view
end

-- ##############################################

return all_alert_store
