--
-- (C) 2021-21 - ntop.org
--
-- Module to keep things in common across alert_store of various type

local dirs = ntop.getDirs()

-- Import the classes library.
local classes = require "classes"
require "lua_utils"
local json = require "dkjson"
local format_utils = require "format_utils"
local alert_consts = require "alert_consts"
local alert_utils = require "alert_utils"
local alert_severities = require "alert_severities"
local alert_roles = require "alert_roles"
local tag_utils = require "tag_utils"

-- ##############################################

local alert_store = classes.class()

-- ##############################################

-- Default number of time slots to be returned when aggregating by time
local NUM_TIME_SLOTS = 31
local TOP_LIMIT = 10

local CSV_SEPARATOR = "|"

-- ##############################################

function alert_store:init(args)
   self._where = { "1 = 1" }
   self._group_by = nil
   self._top_limit = TOP_LIMIT
end

-- ##############################################

function alert_store:_escape(str)
   if not str then
      return ""
   end

   return str:gsub("'", "''")
end

-- ##############################################

--@brief Check if the submitted fields are avalid (i.e., they are not injection attempts)
function alert_store:_valid_fields(fields)
   local f = fields:split(",") or { fields }

   for _, field in pairs(f) do
      -- only allow alphanumeric characters and underscores
      if not string.match(field, "^[%w_(*) ]+$") then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Invalid field found in query [%s]", field:gsub('%W','') --[[ prevent stored injections --]]))
	 return false
      end
   end

   return true
end

-- ##############################################

--@brief Return the alert family name
function alert_store:get_family()
   local family_name

   if self._alert_entity then
      family_name = self._alert_entity.alert_store_name
   end

   return family_name
end

-- ##############################################

--@brief Add filters on status (engaged or historical)
--@param engaged true to select engaged alerts
--@return True if set is successful, false otherwise
function alert_store:add_status_filter(engaged)
   self._engaged = engaged
   return true
end

-- ##############################################

--@brief Handle filter operator (eq, lt, gt, gte, lte)
function alert_store:strip_filter_operator(value)
   if isEmptyString(value) then return nil, nil end
   local filter = split(value, ",")
   local value = filter[1]
   local op = filter[2]
   if tag_utils.tag_operators[op] then
      op = tag_utils.tag_operators[op]
   else
      op = tag_utils.tag_operators['eq']
   end
   return value, op
end

-- ##############################################

--@brief Add filters on time
--@param epoch_begin The start timestamp
--@param epoch_end The end timestamp
--@return True if set is successful, false otherwise
function alert_store:add_time_filter(epoch_begin, epoch_end)
   if not self._epoch_begin and tonumber(epoch_begin) then
      self._epoch_begin = tonumber(epoch_begin)
      self._where[#self._where + 1] = string.format("tstamp >= %u", epoch_begin)
   end

   if not self._epoch_end and tonumber(epoch_end) then
      self._epoch_end = tonumber(epoch_end)
      self._where[#self._where + 1] = string.format("tstamp <= %u", epoch_end)
   end

   return true
end

-- ##############################################

--@brief Add filters on alert id
--@param alert_id The id of an alert to be filtered
--@return True if set is successful, false otherwise
function alert_store:add_alert_id_filter(alert_id)
   if alert_id then
      local alert_id, op = self:strip_filter_operator(alert_id)
      if not self._alert_id and tonumber(alert_id) then
         self._alert_id = tonumber(alert_id)
         self._where[#self._where + 1] = string.format("alert_id = %u", alert_id)

         return true
      end
   end

   return false
end

-- ##############################################

--@brief Add filters on alert severity
--@param alert_severity The severity of an alert to be filtered
--@return True if set is successful, false otherwise
function alert_store:add_alert_severity_filter(alert_severity)
   if alert_severity then
      local alert_severity, op = self:strip_filter_operator(alert_severity)
      if not self._alert_severity and tonumber(alert_severity) then
         self._alert_severity = tonumber(alert_severity)
         self._where[#self._where + 1] = string.format("severity %s %u", op, alert_severity)
         return true
      end
   end

   return false
end

-- ##############################################

--@brief Add filters on alert rowid
--@param rowid The rowid of an alert to be filtered
--@return True if set is successful, false otherwise
function alert_store:add_alert_rowid_filter(rowid)
   if tonumber(rowid) then
      self._where[#self._where + 1] = string.format("rowid = %u", rowid)

      return true
   end

   return false
end

-- ##############################################

--@brief Pagination options to fetch partial results
--@param limit The number of results to be returned
--@param offset The number of records to skip before returning results
--@return True if set is successful, false otherwise
function alert_store:add_limit(limit, offset)
   if not self._limit and tonumber(limit) then
      self._limit = limit

      if not self._offset and tonumber(offset) then
	 self._offset = offset
      end

      return true
   end

   return false
end

-- ##############################################

--@brief Specify the sort criteria of the query
--@param sort_column The column to be used for sorting
--@param sort_order Order, either `asc` or `desc`
--@return True if set is successful, false otherwise
function alert_store:add_order_by(sort_column, sort_order)
   if not self._order_by 
      and sort_column and self:_valid_fields(sort_column)
      and (sort_order == "asc" or sort_order == "desc") then
      self._order_by = {sort_column = sort_column, sort_order = sort_order}
      return true
   end

   return false
end

-- ##############################################

function alert_store:group_by(fields)
   if not self._group_by 
      and fields and self:_valid_fields(fields) then
      self._group_by = fields
      return true
   end

   return false
end

-- ##############################################

function alert_store:insert(alert)
   traceError(TRACE_NORMAL, TRACE_CONSOLE, "alert_store:insert")
   return false
end

-- ##############################################

--@brief Deletes data according to specified filters
function alert_store:delete()
   local where_clause = table.concat(self._where, " AND ")

   -- Prepare the final query
   local q = string.format("DELETE FROM `%s` WHERE %s ", self._table_name, where_clause)

   local res = interface.alert_store_query(q)
   return res and table.len(res) == 0
end

-- ##############################################

function alert_store:select_historical(filter, fields)
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

   -- [OPTIONAL] Add the group by
   if self._group_by then
      group_by_clause = string.format("GROUP BY %s", self._group_by)
   end

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
   -- NOTE: entity_id is necessary as alert_utils.formatAlertMessage assumes it to always be present inside the alert
   local q = string.format(" SELECT %u entity_id, %s FROM `%s` WHERE %s %s %s %s %s",
			   self._alert_entity.entity_id, fields, self._table_name, where_clause, group_by_clause, order_by_clause, limit_clause, offset_clause)

   res = interface.alert_store_query(q)

   return res
end

-- ##############################################

--@brief Selects engaged alerts from memory
--@return Selected engaged alerts, and the total number of engaged alerts
function alert_store:select_engaged(filter)
   local alert_id_filter = tonumber(self._alert_id)
   local severity_filter = tonumber(self._alert_severity)
   local entity_id_filter = tonumber(self._alert_entity and self._alert_entity.entity_id) -- Possibly set in subclasses constructor
   local entity_value_filter = filter or self._entity_value
   -- Role is currently supported and populated for hosts engaged alerts.
   local role_filter = tonumber(self._role) or alert_roles.alert_role_any.role_id

   -- tprint(string.format("id=%s sev=%s entity=%s val=%s", alert_id_filter, severity_filter, entity_id_filter, entity_value_filter))
   local alerts = interface.getEngagedAlerts(entity_id_filter, entity_value_filter, alert_id_filter, severity_filter, role_filter)

   local total_rows = 0
   local sort_2_col = {}

   -- Sort and filtering
   for idx, alert in pairs(alerts) do
      -- Exclude alerts falling outside requested time ranges
      local tstamp = tonumber(alert.tstamp)
      if self._epoch_begin and tstamp < self._epoch_begin then goto continue end
      if self._epoch_end and tstamp > self._epoch_end then goto continue end

      if self._order_by and self._order_by.sort_column and alert[self._order_by.sort_column] ~= nil then
	 sort_2_col[#sort_2_col + 1] = {idx = idx, val = tonumber(alert[self._order_by.sort_column]) or string.format("%s", alert[self._order_by.sort_column])}
      else
	 sort_2_col[#sort_2_col + 1] = {idx = idx, val = tstamp}
      end

      total_rows = total_rows + 1

      ::continue::
   end

   -- Pagination
   local offset = self._offset or 0        -- The offset, or zero (start from the beginning) if no offset is set
   local limit = self._limit or total_rows -- The limit, or the actual number of records, ie., no limit

   local res = {}
   local i = 0

   for _, val in pairsByField(sort_2_col, "val", ternary(self._order_by and self._order_by.sort_order and self._order_by.sort_order == "asc", asc, rev)) do
      if i >= offset + limit then
	 break
      end

      if i >= offset then
	 res[#res + 1] = alerts[val.idx]
      end

      i = i + 1
   end

   return res, total_rows
end

-- ##############################################

--@brief Performs a query and counts the number of records
function alert_store:count()
   local count_query = self:select_historical(nil, "count(*) as count")
   local num_results = 0
   
   if count_query then
      num_results = tonumber(count_query[1]["count"])
   end
      
   return num_results
end

-- ##############################################

--@brief Returns minimum and maximum timestamps and the time slot width to
-- be used for queries performing group-by-time operations
function alert_store:_count_by_time_get_bounds()
   local now = os.time()
   local min_slot = self._epoch_begin or (now - 3600)
   local max_slot = self._epoch_end or now
   local slot_width

   -- Compute the width to obtain a fixed number of points
   local slot_span = max_slot - min_slot

   if slot_span < 0 or slot_span < NUM_TIME_SLOTS then
      -- Slot width is 1 second, can't be smaller than this
      slot_width = 1
   else
      -- Result is the floor to return an integer number
      slot_width = math.floor(slot_span / NUM_TIME_SLOTS)
   end

   -- Align the range using the width of the time slot to always return aligned data
   min_slot = min_slot - (min_slot % slot_width)
   max_slot = min_slot + slot_width * NUM_TIME_SLOTS

   return min_slot, max_slot, slot_width
end

-- ##############################################

--@brief Pad missing points with zeroes and prepare the series
function alert_store:_prepare_count_by_severity_and_time_series(all_severities, min_slot, max_slot, time_slot_width)
   local res = {}

   if table.len(all_severities) == 0 then
      -- No series, add a dummy series for "no alerts"
      local noalert_res = {}
      for slot = min_slot, max_slot + 1, time_slot_width do
	 noalert_res[#noalert_res + 1] = {slot * 1000 --[[ In milliseconds --]], 0}
      end
      res[0] = noalert_res
      return res
   end

   -- Pad missing points with zeroes
   for _, severity in pairs(alert_severities) do
      local severity_id = tonumber(severity.severity_id)

      -- Empty series for this severity, skip
      if not all_severities[severity_id] then goto skip_severity_pad end

      for slot = min_slot, max_slot + 1, time_slot_width do
	 if not all_severities[severity_id].all_slots[slot] then
	    all_severities[severity_id].all_slots[slot] = 0
	 end
      end

      ::skip_severity_pad::
   end

   -- Prepare the result as a Lua array ordered by time slot
   for _, severity in pairs(alert_severities) do
      local severity_id = tonumber(severity.severity_id)

      -- Empty series for this severity, skip
      if not all_severities[severity_id] then goto skip_severity_prep end

      local severity_res = {}

      for slot, count in pairsByKeys(all_severities[severity_id].all_slots, asc) do
	 severity_res[#severity_res + 1] = {slot * 1000 --[[ In milliseconds --]], count}
      end

      res[severity_id] = severity_res

      ::skip_severity_prep::
   end

   return res
end

-- ##############################################

--@brief Counts the number of engaged alerts in multiple time slots
function alert_store:count_by_severity_and_time_engaged(filter, severity)
   local min_slot, max_slot, time_slot_width = self:_count_by_time_get_bounds()
   local alert_id_filter = tonumber(self._alert_id)
   local severity_filter = tonumber(severity) or tonumber(self._alert_severity)
   local entity_id_filter = tonumber(self._alert_entity and self._alert_entity.entity_id) -- Possibly set in subclasses constructor
   local entity_value_filter = filter or self._entity_value

   -- tprint(string.format("id=%s sev=%s entity=%s val=%s", alert_id_filter, severity_filter, entity_id_filter, entity_value_filter))
   local alerts = interface.getEngagedAlerts(entity_id_filter, entity_value_filter, alert_id_filter, severity_filter)

   local all_severities = {}
   local all_slots = {}

   -- Calculate minimum and maximum slots to make sure the response always returns consecutive time slots, possibly filled with zeroes
   for _, alert in ipairs(alerts) do
      local severity_id = alert.severity

      local tstamp = tonumber(alert.tstamp)
      local cur_slot = tstamp - (tstamp % time_slot_width)

      -- Exclude alerts falling outside requested time ranges
      if self._epoch_begin and tstamp < self._epoch_begin then goto continue end
      if self._epoch_end and tstamp > self._epoch_end then goto continue end

      if not all_severities[severity_id] then all_severities[severity_id] = {} end
      if not all_severities[severity_id].all_slots then all_severities[severity_id].all_slots = {} end

      all_severities[severity_id].all_slots[cur_slot] = (all_severities[severity_id].all_slots[cur_slot] or 0) + 1

      ::continue::
   end

   return self:_prepare_count_by_severity_and_time_series(all_severities, min_slot, max_slot, time_slot_width)
end

-- ##############################################

--@brief Performs a query and counts the number of records in multiple time slots
function alert_store:count_by_severity_and_time_historical()
   -- Preserve all the filters currently set
   local min_slot, max_slot, time_slot_width = self:_count_by_time_get_bounds()
   local where_clause = table.concat(self._where, " AND ")

   if severity then
      where_clause = string.format("severity = %u", severity) .. " AND " .. where_clause
   end

   -- Group by according to the timeslot, that is, the alert timestamp MODULO the slot width
   local q = string.format("SELECT severity, (tstamp - tstamp %% %u) as slot, count(*) count FROM %s WHERE %s GROUP BY severity, slot ORDER BY severity, slot ASC",
			   time_slot_width, self._table_name, where_clause)

   local q_res = interface.alert_store_query(q) or {}

   local all_severities = {}

   -- Read points from the query
   for _, p in ipairs(q_res) do
      local severity_id = tonumber(p.severity)

      if not all_severities[severity_id] then all_severities[severity_id] = {} end
      if not all_severities[severity_id].all_slots then all_severities[severity_id].all_slots = {} end

      -- Make sure slots are within the requested bounds
      local cur_slot = tonumber(p.slot)
      local cur_count = tonumber(p.count)
      if cur_slot >= min_slot and cur_slot <= max_slot then
	 all_severities[severity_id].all_slots[cur_slot] = cur_count
      end
   end

   return self:_prepare_count_by_severity_and_time_series(all_severities, min_slot, max_slot, time_slot_width)
end

-- ##############################################

--@brief Count from memory (engaged) or database (historical)
--@return Alert counters divided into severity and time slots
function alert_store:count_by_severity_and_time()
   -- Add filters
   self:add_request_filters()
   -- Add limits and sort criteria
   self:add_request_ranges()

   if self._engaged then -- Engaged
      return self:count_by_severity_and_time_engaged() or 0
   else -- Historical
      return self:count_by_severity_and_time_historical() or 0
   end
end

-- ##############################################

--@brief Performs a query for the top alerts by alert count
function alert_store:top_alert_id_historical()
   -- Preserve all the filters currently set
   local where_clause = table.concat(self._where, " AND ")
   local limit = 10
tprint(where_clause)
   local q = string.format("SELECT alert_id, count(*) count FROM %s WHERE %s GROUP BY alert_id ORDER BY count DESC LIMIT %u",
			   self._table_name, where_clause, limit)

   local q_res = interface.alert_store_query(q) or {}

   return q_res
end

-- ##############################################

--@brief Child stats
function alert_store:_get_additional_stats()
   return {}
end

-- ##############################################

--@brief Stats used by the dashboard
function alert_store:get_stats()
   -- Add filters
   self:add_request_filters()

   -- Get child stats
   local stats = self:_get_additional_stats()

   stats.top = stats.top or {}
   stats.top.alert_id = self:top_alert_id_historical()

   return stats
end

-- ##############################################
-- REST API Utility Functions
-- ##############################################

--@brief Handle count requests (GET) from memory (engaged) or database (historical)
--@return Alert counters divided into severity and time slots
function alert_store:count_by_severity_and_time_request()
   local res = {
      series = {},
      colors = {}
   }

   local count_data = self:count_by_severity_and_time()

   for _, severity in pairsByField(alert_severities, "severity_id", rev) do
      if(count_data[severity.severity_id] ~= nil) then
	 res.series[#res.series + 1] = {
	    name = i18n(severity.i18n_title),
	    data = count_data[severity.severity_id],
	 }
	 res.colors[#res.colors + 1] = severity.color
      end
   end

   if table.len(res.series) == 0 and count_data[0] ~= nil then
      res.series[#res.series + 1] = {
        name = i18n("alerts_dashboard.no_alerts"),
        data = count_data[0],
      }
      res.colors[#res.colors + 1] = "#ccc"
   end

   return res
end

-- ##############################################

--@brief Handle alerts select request (GET) from memory (engaged) or database (historical)
--@param filter A filter on the entity value (no filter by default)
--@param select_fields The fields to be returned (all by default or in any case for engaged)
--@return Selected alerts, and the total number of alerts
function alert_store:select_request(filter, select_fields)

   -- Add filters
   self:add_request_filters()

   if self._engaged then -- Engaged
      -- Add limits and sort criteria
      self:add_request_ranges()

      local alerts, total_rows =  self:select_engaged(filter)

      return alerts, total_rows
   else -- Historical
      
      -- Count
      local total_row = self:count()

      -- Add limits and sort criteria only after the count has been done
      self:add_request_ranges()

      local res = self:select_historical(filter, select_fields)
      return res, total_row
   end
end

-- ##############################################

--@brief Possibly overridden in subclasses to add additional filters from the request
function alert_store:_add_additional_request_filters()
end

-- ##############################################

--@brief Add filters according to what is specified inside the REST API
function alert_store:add_request_filters()
   local epoch_begin = tonumber(_GET["epoch_begin"])
   local epoch_end = tonumber(_GET["epoch_end"])
   local alert_id = _GET["alert_id"] or _GET["alert_type"] --[[ compatibility ]]--
   local alert_severity = _GET["alert_severity"] or _GET["severity"]
   local rowid = _GET["row_id"]
   local status = _GET["status"]

   self:add_time_filter(epoch_begin, epoch_end)
   self:add_alert_id_filter(alert_id)
   self:add_alert_severity_filter(alert_severity)
   self:add_status_filter(status and status == 'engaged')
   self:add_alert_rowid_filter(rowid)
   self:_add_additional_request_filters()
end

-- ##############################################

--@brief Possibly overridden in subclasses to get info about additional available filters
function alert_store:_get_additional_available_filters()
   return {}
end

-- ##############################################

--@brief Get info about available filters
function alert_store:get_available_filters()
   local additional_filters = self:_get_additional_available_filters()

   local filters = {
      -- Note alert_id could have been defined here for all families, 
      -- however this requires a migration of the 'other' alerts
      -- in order to list alerts by entity
      severity = {
         value_type = 'severity',
	 i18n_label = 'tags.severity'
      },
   }

   return table.merge(filters, additional_filters)
end

-- ##############################################

--@brief Add offset, limit, and group by filters according to what is specified inside the REST API
function alert_store:add_request_ranges()
   local start = tonumber(_GET["start"])   --[[ The OFFSET: default no offset --]]
   local length = tonumber(_GET["length"]) --[[ The LIMIT: default no limit   --]]
   local sort_column = _GET["sort"]
   local sort_order = _GET["order"]

   self:add_limit(length, start)
   self:add_order_by(sort_column, sort_order)
end

-- ##############################################

-- define the base record names of the document, both json and csv
-- add a new record name here if you want to add a new base element
-- name: the actual record name 
-- export: use only in csv export, true the record is included in the csv, false otherwise
local BASE_RNAME = {
   FAMILY = { name = "family", export = true},
   ROW_ID = { name = "row_id", export = false},
   TSTAMP = { name = "tstamp", export = true},
   ALERT_ID = { name = "alert_id", export = true},
   SCORE = { name = "score", export = true},
   SEVERITY = { name = "severity", export = true},
   DURATION = { name = "duration", export = true},
   COUNT = { name = "count", export = true},
   SCRIPT_KEY = { name = "script_key", export = true},
}

--@brief Convert an alert coming from the DB (value) to a record returned by the REST API
function alert_store:format_json_record_common(value, entity_id)
   local record = {}

   -- Note: this record is rendered by 
   -- httpdocs/templates/pages/alerts/families/{host,..}/table[.js].template 
   
   record[BASE_RNAME.FAMILY.name] = self:get_family()

   record[BASE_RNAME.ROW_ID.name] = value["rowid"]

   local score = tonumber(value["score"])
   local severity_id = ntop.mapScoreToSeverity(score)
   local severity = alert_consts.alertSeverityById(severity_id)

   local tstamp = tonumber(value["alert_tstamp"] or value["tstamp"])
   record[BASE_RNAME.TSTAMP.name] = {
      value = tstamp,
      label = format_utils.formatPastEpochShort(tstamp),
      highlight = severity.color,
   }

   record[BASE_RNAME.ALERT_ID.name] = {
      value = value["alert_id"],
      label = alert_consts.alertTypeLabel(tonumber(value["alert_id"]), false, entity_id),
   }

   record[BASE_RNAME.SCORE.name] = {
      value = score,
      label = format_utils.formatValue(score),
      color = severity.color,
   }

   local severity_label = ""
   if severity then
      severity_label = "<i class='"..severity.icon.."' style='color: "..severity.color.."!important' title='"..i18n(severity.i18n_title).."'></i> "
   end

   record[BASE_RNAME.SEVERITY.name] = {
      value = severity_id,
      label = severity_label,
      color = severity.color,
   }

   if tonumber(value["tstamp_end"]) > 0 and tonumber(value["tstamp"]) > 0 then
      record[BASE_RNAME.DURATION.name] = tonumber(value["tstamp_end"]) - tonumber(value["tstamp"]) 
   elseif tonumber(value["tstamp"]) > 0 then
      local now = os.time()
      record[BASE_RNAME.DURATION.name] = now - tonumber(value["tstamp"])
   end

   record[BASE_RNAME.COUNT.name] = tonumber(value["count"]) or 1

   local alert_json = json.decode(value["json"]) or {}
   record[BASE_RNAME.SCRIPT_KEY.name] = alert_json["alert_generation"] and alert_json["alert_generation"]["script_key"]

   return record
end

-- Convert from table to CSV string
function alert_store:to_csv(documents)
   local csv = ""

   local rnames = self:get_rnames_to_export()

   -- column heading output
   local row = self:build_csv_row_header(rnames)
   csv = csv .. row .. '\n'

   for _, document in ipairs(documents) do
      row = self:build_csv_row(rnames, document)
      csv = csv .. row .. '\n'
   end

   return csv
end

function alert_store:get_rnames_to_export()
   local rnames = {}

   for key, value in pairs(self:get_export_base_rnames()) do
      if value.export then
         rnames[key] = value
      end
   end
   
   for key, value in pairs(self:get_rnames()) do
      if value.export then
         rnames[key] = value
      end
   end

   return rnames
end

-- do not override in subclasses
function alert_store:get_export_base_rnames()
   return BASE_RNAME
end

-- to add new elements in subclasses define a RNAME table in subclass and returned it overring this function
function alert_store:get_rnames()
   return {}
end

-- do not override in subclasses
function alert_store:build_csv_row_header(rnames)
   local row = ""

   for _, value in pairsByKeys(rnames) do
      if value["elements"] == nil then
         row = row .. CSV_SEPARATOR .. self:escape_csv(value.name)
      else
         for _, element in ipairs(value.elements) do
            row = row .. CSV_SEPARATOR .. self:escape_csv(value.name .. "_" .. element)
         end
      end
   end

   row = string.sub(row, 2) -- remove first separator
   
   return row;
end

function alert_store:build_csv_row(rnames, document)
   local row = ""
   
   for _, rname in pairsByKeys(rnames) do
      local doc_value = document[rname.name]
      if type(doc_value) ~= "table" then
         row = row .. CSV_SEPARATOR .. self:escape_csv(tostring(doc_value))
      else
         if rname["elements"] ~= nil then
            for _, element in ipairs(rname.elements) do
               row = row .. CSV_SEPARATOR .. self:escape_csv(tostring(doc_value[element]))
            end
         else
            row = row .. CSV_SEPARATOR .. self:escape_csv(tostring(doc_value.value))
         end
      end
   end
   
   row = string.sub(row, 2) -- remove first separator
   
   return row
end

-- Used to escape "'s by to_csv
function alert_store:escape_csv(s)
   if string.find(s, '[,"|\n]') then
      s = '"' .. string.gsub(s, '"', '""') .. '"'
   end
   return s
end
-- ##############################################

--@brief Deletes old data according to the configuration or up to a safe limit
function alert_store:housekeeping()
   local prefs = ntop.getPrefs()

   -- By Number of records
   
   local max_entity_alerts = prefs.max_entity_alerts
   local limit = math.floor(max_entity_alerts * 0.8) -- deletes 20% more alerts than the maximum number

   local q = string.format("DELETE FROM `%s` WHERE rowid <= (SELECT rowid FROM `%s` ORDER BY rowid DESC LIMIT 1 OFFSET %u)",
      self._table_name, self._table_name, limit)

   local deleted = interface.alert_store_query(q)

   -- By Time
   
   local now = os.time()
   local max_time_sec = prefs.max_num_secs_before_delete_alert
   local expiration_epoch = now - max_time_sec

   q = string.format("DELETE FROM `%s` WHERE tstamp < %u", self._table_name, expiration_epoch)

   deleted = interface.alert_store_query(q)
end

-- ##############################################

return alert_store
