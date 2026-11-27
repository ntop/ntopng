--
-- (C) 2024 - ntop.org
--
-- ClickHouse timeseries driver.
--
-- Data is stored in a single table 'timeseries' using Map columns for
-- tags and metrics, following ClickHouse best practices:
--   * LowCardinality(String) for the schema name (bounded cardinality)
--   * Map(LowCardinality(String), String)  for tag key/value pairs
--   * Map(LowCardinality(String), Float64) for metric key/value pairs
--   * MergeTree engine partitioned by month for efficient time pruning
--   * Batch inserts (buffered through CHTimeseriesExporter, implementing
--     an in-memory FIFO queue of C++ structs); batches are dumped via the 
--     native clickhouse-cpp lib (Block/Insert)
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local driver = {}

require "ntop_utils"
local ts_common = require("ts_common")

-- ##############################################

-- Redis keys (stats only — the write buffer is an in-memory C++ queue)
local CH_TS_KEY_PREFIX         = "ntopng.cache.clickhouse_ts."
local CH_LAST_ERROR_KEY        = CH_TS_KEY_PREFIX .. "last_error"
local CH_EXPORTED_POINTS_KEY   = CH_TS_KEY_PREFIX .. "exported_points"
local CH_FAILED_EXPORTS_KEY    = CH_TS_KEY_PREFIX .. "failed_exports"
-- "1" when the table sort key has the entity column (set by driver:setup)
local CH_ENTITY_SORT_KEY       = CH_TS_KEY_PREFIX .. "entity_sort_key"
-- "0" when the table has no entity column (it could not be added): the points are written without it
local CH_ENTITY_COLUMN_KEY     = CH_TS_KEY_PREFIX .. "entity_column"
-- "1": move a table created before the entity column to the new sort key at the next startup
local CH_MIGRATION_REQUEST_KEY = CH_TS_KEY_PREFIX .. "migration_request"
-- JSON { success, message, epoch, duration } of the last migration
local CH_MIGRATION_STATUS_KEY  = CH_TS_KEY_PREFIX .. "migration_status"

-- Table and batching settings
local CH_TS_TABLE_NAME = "timeseries"
-- Filled by the migration, then exchanged with the timeseries table
local CH_TS_MIGRATION_TABLE_NAME = "timeseries_new"
-- Free disk needed by the migration, times the size of the table: the copy and its merges
local MIGRATION_DISK_MARGIN = 1.2

local CH_BATCH_SIZE = tonumber(ntop.getPref("ntopng.prefs.clickhouse_ts_batch_size")) or 10000

-- The entity column chains the values of the tags after ifid, in schema order
-- (e.g. host, protocol): a control character, not expected in a tag value
local ENTITY_SEPARATOR = "\31"

-- ##############################################

--! @brief Driver constructor.
--! @param options table with at least { db = "dbname" }.
function driver:new(options)
   if not ntop.isClickHouseEnabled() then
      return nil
   end

   local obj = {
      db = options.db or "ntopng",
   }
   setmetatable(obj, self)
   self.__index = self
   return obj
end

-- ##############################################

--! @brief Driver name to display
function driver:get_name()
   return "CH"
end

-- ##############################################
-- Internal helpers
-- ##############################################

-- Execute a query via the C++ ClickHouse native client.
-- Returns a list of row-tables on success, nil on failure.
local function ch_query(sql)
   local res,err = interface.execTSQuery(sql, false --[[no row limit]], false --[[don't wait for db]])
   if type(res) ~= "table" then
      return nil
   end
   return res
end

-- Execute a insert via the C++ ClickHouse native client.
-- Returns true on success.
local function ch_write(sql)
   return interface.execSQLWrite(sql)
end

-- ##############################################

-- Escape a string value for use inside a ClickHouse string literal.
local function ch_escape(s)
   s = tostring(s or "")
   s = s:gsub("\\", "\\\\")
   s = s:gsub("'",  "\\'")
   return s
end

-- Schema name -> its tags after ifid, in schema order (computed once per schema)
local entity_tags_by_schema = {}
-- Reused by every append: no table per point
local entity_values = {}

local function entity_tags(schema)
   local entity_tags = entity_tags_by_schema[schema.name]

   if not entity_tags then
      entity_tags = {}

      for _, tag in ipairs(schema._tags) do
         if tag ~= "ifid" then
            entity_tags[#entity_tags + 1] = tag
         end
      end

      entity_tags_by_schema[schema.name] = entity_tags
   end

   return entity_tags
end

-- nil until read: the columns and the sort key of the table do not change while ntopng runs
local entity_column = nil
local entity_in_sort_key = nil

-- An insert with a column the table does not have fails: no entity when it could not be added
local function has_entity_column()
   if entity_column == nil then
      entity_column = (ntop.getCache(CH_ENTITY_COLUMN_KEY) ~= "0")
   end

   return entity_column
end

local function is_entity_in_sort_key()
   if entity_in_sort_key == nil then
      entity_in_sort_key = (ntop.getCache(CH_ENTITY_SORT_KEY) == "1")
   end

   return entity_in_sort_key
end

-- Condition on the entity column for the leading entity tags of the schema found in tags:
-- all of them select one entity, only the first ones a prefix (e.g. a host with all its protocols)
local function entity_where(schema, tags)
   local schema_entity_tags = entity_tags(schema)
   local values = {}

   for _, tag in ipairs(schema_entity_tags) do
      local value = tags[tag]

      if value == nil then
         break
      end

      values[#values + 1] = ch_escape(value)
   end

   if #values == 0 then
      return nil
   end

   local entity = table.concat(values, "\\x1F")

   if #values == #schema_entity_tags then
      return string.format("entity = '%s'", entity)
   end

   return string.format("startsWith(entity, '%s\\x1F')", entity)
end

-- Build WHERE conditions for the supplied tags table.
-- Note: ifid is materialised into its own column as optimization
-- schema (optional): adds the condition on the entity column, the table sort key
function driver:tags_where(tags, schema)
   local conds = {}
   for k, v in pairs(tags) do
      if k == "ifid" and tonumber(v) ~= nil then
         conds[#conds + 1] = string.format("ifid = %d", tonumber(v))
      else
         conds[#conds + 1] = string.format("tags['%s'] = '%s'", ch_escape(k), ch_escape(v))
      end
   end

   -- A table created before the entity column has it empty in the old rows and not in the sort key
   if schema and is_entity_in_sort_key() then
      local entity_cond = entity_where(schema, tags)

      if entity_cond then
         conds[#conds + 1] = entity_cond
      end
   end

   -- TODO: enable this once we're ready to filter timeseries queries by the current ntopng instance
   -- local instance_name = ntop.getPrefs()["instance_name"] or ""
   -- conds[#conds + 1] = string.format("(ntopng_instance_name = '%s' OR ntopng_instance_name = '')", ch_escape(instance_name))

   if #conds > 0 then
      return " AND " .. table.concat(conds, " AND ")
   end
   return ""
end

-- Map ts_common aggregation constants to ClickHouse aggregate function names.
local function agg_func(schema)
   local fn = schema:getAggregationFunction()
   if fn == ts_common.aggregation.max  then return "max"
   elseif fn == ts_common.aggregation.min  then return "min"
   elseif fn == ts_common.aggregation.last then return "argMax"
   else                                          return "avg"   -- mean / default
   end
end

-- SELECT list of the metrics of a gauge / derivative schema, aggregated within each bucket.
local function gauge_select(schema)
   local af  = agg_func(schema)
   local sel = {}
   for _, metric in ipairs(schema._metrics) do
      local esc = ch_escape(metric)
      if af == "argMax" then
         sel[#sel + 1] = string.format(
            "argMax(metrics['%s'], tstamp) AS `%s`", esc, esc)
      else
         sel[#sel + 1] = string.format(
            "%s(metrics['%s']) AS `%s`", af, esc, esc)
      end
   end
   return table.concat(sel, ", ")
end

-- ##############################################
-- Driver API
-- ##############################################

--! @brief Append a new data point.
--! Serialised to line protocol by CHTimeseriesExporter and buffered in the
--! in-memory C++ queue; flushed to ClickHouse by driver:export().
function driver:append(schema, timestamp, tags, metrics)
   local entity = nil

   if has_entity_column() then
      local schema_entity_tags = entity_tags(schema)

      for i, tag in ipairs(schema_entity_tags) do
         entity_values[i] = tags[tag] or ""
      end

      entity = table.concat(entity_values, ENTITY_SEPARATOR, 1, #schema_entity_tags)
   end

   local ret = interface.chTsEnqueue(schema.name, timestamp, tags, metrics, tonumber(tags.ifid), entity)

   if ret == false then
      ntop.ts_inc_num_drops()
   end
   
   return ret
end

-- ##############################################

-- Builds the driver:query result (series with the missing buckets filled, statistics)
-- from the rows of one entity, ordered by time.
local function build_query_result(schema, data, tstart, tend, time_step, tags, options)
   -- Prepare output series skeletons.
   local series    = {}
   local max_vals  = {}
   for i, metric in ipairs(schema._metrics) do
      series[i]   = { id = metric, data = {} }
      max_vals[i] = ts_common.getMaxPointValue(schema, metric, tags)
   end

   -- expected_t tracks the next bucket we expect from CH.
   -- Start at tstart so a single missing bucket is detected and filled with NaN.
   local expected_t = tstart
   local idx        = 1

   if data and #data > 0 then
      for _, row in ipairs(data) do
         local cur_t = tonumber(row["t"])
         if cur_t == nil then goto continue end

         -- Fill missing buckets with fill_value.
         while (cur_t - expected_t) >= time_step do
            for _, serie in ipairs(series) do
               serie.data[idx] = options.fill_value
            end
            idx        = idx + 1
            expected_t = expected_t + time_step
         end

         -- Store values for this bucket.
         for i, metric in ipairs(schema._metrics) do
            local v = tonumber(row[metric])
            if v == nil then v = options.fill_value end
            series[i].data[idx] = ts_common.normalizeVal(v, max_vals[i], options)
         end

         idx        = idx + 1
         expected_t = expected_t + time_step

         ::continue::
      end
   end

   -- Fill remaining buckets up to tend.
   while (tend - expected_t) >= 0 do
      if (not options.fill_series) and (expected_t > os.time()) then break end
      for _, serie in ipairs(series) do
         serie.data[idx] = options.fill_value
      end
      idx        = idx + 1
      expected_t = expected_t + time_step
   end

   local count = idx - 1

   -- Optionally compute statistics.
   local total_serie, stats

   if options.calculate_stats then
      if #series == 1 then
         total_serie = table.clone(series[1].data)
      else
         total_serie = {}
         for i = 1, count do
            local s = 0
            for _, serie in ipairs(series) do
               local v = serie.data[i]
               if v == v then s = s + (v or 0) end   -- skip NaN
            end
            total_serie[i] = s
         end
      end

      if total_serie then
         stats = ts_common.calculateStatistics(total_serie, time_step, tend - tstart,
                    schema.options.metrics_type)
         stats = table.merge(stats or {}, ts_common.calculateMinMax(total_serie))
         -- Store per-serie statistics directly on each serie (same convention as RRD driver)
         -- so the frontend can access ts_info.statistics["average"] etc.
         for _, serie in ipairs(series) do
            local s = ts_common.calculateStatistics(serie.data, time_step, tend - tstart,
                         schema.options.metrics_type)
            serie.statistics = table.merge(s or {}, ts_common.calculateMinMax(serie.data))
         end
      end
   end

   return {
      metadata = {
         epoch_begin = tstart,
         epoch_end   = tend,
         epoch_step  = time_step,
         num_point   = count,
         schema      = schema.name,
         query       = tags,
      },
      series             = series,
      statistics         = stats,
      source_aggregation = "raw",
      additional_series  = { total = total_serie },
   }
end

-- ##############################################

--! @brief High-level query entry-point called by ts_utils_core (timeseries_query).
--! Unpacks the unified options table and delegates to driver:query.
function driver:timeseries_query(options)
   -- Strip any extra tags not defined in the schema (e.g. mac, host_ip added by ts_data)
   -- to avoid spurious WHERE conditions that return no rows.
   local actual_tags = options.schema_info:verifyTags(options.tags) or options.tags
   return self:query(options.schema_info, options.epoch_begin, options.epoch_end,
                     actual_tags, options)
end

-- ##############################################

--! @brief Query timeseries data.
function driver:query(schema, tstart, tend, tags, options)
   local raw_step   = schema.options.step
   local time_step  = ts_common.calculateSampledTimeStep(raw_step, tstart, tend, options)
   local is_counter = (schema.options.metrics_type == ts_common.metrics.counter)
   local tw         = self:tags_where(tags, schema)
   local sql

   if is_counter then
      -- For counter (cumulative) schemas, compute per-bucket rates as the
      -- difference between consecutive bucket last-values (cross-bucket delta).
      -- A plain max-min within a single bucket returns 0 whenever only one
      -- raw point lands in that bucket (e.g. time_step == raw_step).
      --
      -- Three-level structure:
      --   innermost  - argMax per bucket, fetching one extra bucket before tstart
      --   middle     - lag() window function over ALL rows (including the extra one)
      --                so the first real bucket has a valid predecessor
      --   outermost  - filter t >= tstart, apply greatest(0,...) / time_step
      --
      -- Window functions are evaluated after WHERE, so the lag must be computed
      -- in the middle subquery before the outer WHERE removes the extra bucket.
      -- __rn flags the first row of the windowed result set (ORDER BY t). When the 
      -- look-back bucket (tstart - time_step) has no data of its own, that first 
      -- row IS the real first requested bucket, and lag() has no predecessor to 
      -- diff against: it silently defaults to 0, turning the raw cumulative counter 
      -- value into the delta for that point (a huge bogus spike). Null it out 
      -- instead so it renders as a gap, same as any other missing sample.
      --
      -- A counter sample written at T closes the interval ending at T (e.g. the
      -- per-minute ASN dump at 10:31:00 holds the traffic up to 10:31:00), so it
      -- is bucketed at T - half raw step: otherwise sparse series (one sample per
      -- bucket) are labelled one step later than dense ones (iface 1s samples).
      local sample_offset = math.ceil(raw_step / 2)
      local inner_sel = {}
      local mid_sel   = { "t", "row_number() OVER (ORDER BY t) AS `__rn`" }
      local outer_sel = { "t" }
      for _, metric in ipairs(schema._metrics) do
         local esc = ch_escape(metric)
         inner_sel[#inner_sel + 1] = string.format(
            "argMax(metrics['%s'], tstamp) AS `%s`", esc, esc)
         mid_sel[#mid_sel + 1] = string.format(
            "`%s` - lag(`%s`, 1, 0) OVER (ORDER BY t) AS `%s`", esc, esc, esc)
         outer_sel[#outer_sel + 1] = string.format(
            "if(`__rn` = 1, NULL, greatest(0, `%s`) / %d) AS `%s`", esc, time_step, esc)
      end

      sql = string.format(
         "SELECT %s FROM ("
         ..   "SELECT %s FROM ("
         ..     "SELECT intDiv(toUnixTimestamp(tstamp) - %d, %d) * %d AS t, %s "
         ..     "FROM `%s`.`%s` "
         ..     "WHERE schema_name = '%s'%s "
         ..     "AND tstamp BETWEEN toDateTime(%d) AND toDateTime(%d) "
         ..     "GROUP BY t ORDER BY t ASC"
         ..   ")"
         .. ") WHERE t >= %d ORDER BY t ASC",
         table.concat(outer_sel, ", "),
         table.concat(mid_sel, ", "),
         sample_offset, time_step, time_step,
         table.concat(inner_sel, ", "),
         ch_escape(self.db), CH_TS_TABLE_NAME,
         ch_escape(schema.name), tw,
         tstart - time_step, tend + sample_offset, -- + offset: closing sample of the last bucket
         tstart)
   else
      -- Gauge / derivative: aggregate within each bucket directly.
      sql = string.format(
         "SELECT intDiv(toUnixTimestamp(tstamp), %d) * %d AS t, %s "
         .. "FROM `%s`.`%s` "
         .. "WHERE schema_name = '%s'%s "
         .. "AND tstamp BETWEEN toDateTime(%d) AND toDateTime(%d) "
         .. "GROUP BY t ORDER BY t ASC",
         time_step, time_step,
         gauge_select(schema),
         ch_escape(self.db), CH_TS_TABLE_NAME,
         ch_escape(schema.name), tw,
         tstart, tend)
   end

   return build_query_result(schema, ch_query(sql), tstart, tend, time_step, tags, options)
end

-- ##############################################

--! @brief Query a gauge schema for many entities (e.g. all the SNMP interfaces) with one
--! query instead of one per entity. entries: list of { index = n, tags = {...} }, all with
--! the same tag keys. Returns the results (same format of driver:query) by entry index.
function driver:timeseries_query_multi(options, entries)
   local schema  = options.schema_info
   local tstart  = options.epoch_begin
   local tend    = options.epoch_end
   local results = {}

   if #entries == 0 then
      return results
   end

   -- Counters need the per-entity lag() window of driver:query
   if schema.options.metrics_type == ts_common.metrics.counter then
      for _, entry in ipairs(entries) do
         results[entry.index] = self:query(schema, tstart, tend, entry.tags, options)
      end
      return results
   end

   -- Tags with the same value in every entry go in the WHERE, the others identify the entity
   local common_tags  = {}
   local entity_keys  = {}
   for key, value in pairs(entries[1].tags) do
      local is_common = true
      for _, entry in ipairs(entries) do
         if entry.tags[key] ~= value then
            is_common = false
            break
         end
      end
      if is_common then
         common_tags[key] = value
      else
         entity_keys[#entity_keys + 1] = key
      end
   end

   local tag_columns = {}
   local tag_values  = {}
   for i, key in ipairs(entity_keys) do
      tag_columns[i] = string.format("tags['%s']", ch_escape(key))
      tag_values[i]  = string.format("`__tag%d`", i)
   end

   -- Entity key -> entries, and the tuple of each entity for the IN filter
   local entries_by_entity = {}
   local tuples = {}
   for _, entry in ipairs(entries) do
      local values  = {}
      local escaped = {}
      for i, key in ipairs(entity_keys) do
         values[i]  = tostring(entry.tags[key])
         escaped[i] = string.format("'%s'", ch_escape(values[i]))
      end
      local entity = table.concat(values, "\0")
      if not entries_by_entity[entity] then
         entries_by_entity[entity] = {}
         tuples[#tuples + 1] = string.format("tuple(%s)", table.concat(escaped, ", "))
      end
      table.insert(entries_by_entity[entity], entry)
   end

   local raw_step  = schema.options.step
   local time_step = ts_common.calculateSampledTimeStep(raw_step, tstart, tend, options)
   local entity_select = {}
   for i, column in ipairs(tag_columns) do
      entity_select[i] = string.format("%s AS %s", column, tag_values[i])
   end
   local entity_filter = ""
   if #entity_keys > 0 then
      entity_filter = string.format(" AND tuple(%s) IN (%s)",
         table.concat(tag_columns, ", "), table.concat(tuples, ", "))
      table.insert(entity_select, "")
   end

   local sql = string.format(
      "SELECT %sintDiv(toUnixTimestamp(tstamp), %d) * %d AS t, %s "
      .. "FROM `%s`.`%s` "
      .. "WHERE schema_name = '%s'%s%s "
      .. "AND tstamp BETWEEN toDateTime(%d) AND toDateTime(%d) "
      .. "GROUP BY %st ORDER BY %st ASC",
      table.concat(entity_select, ", "), time_step, time_step,
      gauge_select(schema),
      ch_escape(self.db), CH_TS_TABLE_NAME,
      ch_escape(schema.name), self:tags_where(common_tags, schema), entity_filter,
      tstart, tend,
      (#entity_keys > 0) and (table.concat(tag_values, ", ") .. ", ") or "",
      (#entity_keys > 0) and (table.concat(tag_values, ", ") .. ", ") or "")

   -- Split the rows by entity, keeping the time order
   local rows_by_entity = {}
   for _, row in ipairs(ch_query(sql) or {}) do
      local values = {}
      for i = 1, #entity_keys do
         values[i] = tostring(row[string.format("__tag%d", i)])
      end
      local entity = table.concat(values, "\0")
      local rows = rows_by_entity[entity]
      if not rows then
         rows = {}
         rows_by_entity[entity] = rows
      end
      rows[#rows + 1] = row
   end

   for entity, entity_entries in pairs(entries_by_entity) do
      for _, entry in ipairs(entity_entries) do
         results[entry.index] = build_query_result(schema, rows_by_entity[entity], tstart, tend,
                                                   time_step, entry.tags, options)
      end
   end

   return results
end

-- ##############################################

--! @brief Calculate per-metric totals over a time range.
function driver:queryTotal(schema, tstart, tend, tags, options)
   if (tags.epoch_begin) or (tags.epoch_end) then
		local tmp_tags = table.clone(tags)
      tmp_tags.epoch_begin = nil
      tmp_tags.epoch_end = nil
      tags = tmp_tags
   end

   local is_counter    = (schema.options.metrics_type == ts_common.metrics.counter)
   local is_derivative = (schema.options.metrics_type == ts_common.metrics.derivative)
   local tw            = self:tags_where(tags, schema)

   local sel = {}
   for _, metric in ipairs(schema._metrics) do
      local esc = ch_escape(metric)
      if is_counter then
         -- Total bytes/packets = last counter value minus first counter value.
         sel[#sel + 1] = string.format(
            "greatest(0, max(metrics['%s']) - min(metrics['%s'])) AS `%s`",
            esc, esc, esc)
      elseif is_derivative then
         -- Derivative values are already rates; multiply by step to get totals.
         sel[#sel + 1] = string.format(
            "sum(metrics['%s']) * %d AS `%s`", esc, schema.options.step, esc)
      else
         -- Gauge: plain sum over all sampled values * step for total volume.
         sel[#sel + 1] = string.format("sum(metrics['%s']) AS `%s`", esc, esc)
      end
   end

   local sql = string.format(
      "SELECT %s FROM `%s`.`%s` "
      .. "WHERE schema_name = '%s'%s "
      .. "AND tstamp BETWEEN toDateTime(%d) AND toDateTime(%d)",
      table.concat(sel, ", "),
      ch_escape(self.db), CH_TS_TABLE_NAME,
      ch_escape(schema.name), tw,
      tstart, tend)

   local data = ch_query(sql)

   if (not data) or (#data == 0) then return {} end

   local row = data[1]
   local res = {}
   for _, metric in ipairs(schema._metrics) do
      res[metric] = tonumber(row[metric])
   end
   return res
end

-- ##############################################

--! @brief List existing series matching the supplied tag filter.
function driver:listSeries(schema, tags_filter, wildcard_tags, start_time, end_time)

   local tw = self:tags_where(tags_filter, schema)

   local time_cond = string.format("tstamp >= toDateTime(%d)", start_time)
   if end_time ~= nil then
      time_cond = time_cond .. string.format(" AND tstamp <= toDateTime(%d)", end_time)
   end

   -- Build GROUP BY on wildcard tags.
   local group_exprs = {}
   local sel_extra   = {}
   for _, tag in ipairs(wildcard_tags) do
      local esc = ch_escape(tag)
      group_exprs[#group_exprs + 1] = string.format("tags['%s']", esc)
      sel_extra[#sel_extra + 1]     = string.format("tags['%s'] AS `%s`", esc, esc)
   end

   local group_clause = (#group_exprs > 0)
      and (" GROUP BY " .. table.concat(group_exprs, ", "))
      or  ""

   local sel_cols = (#sel_extra > 0)
      and table.concat(sel_extra, ", ")
      or  "1"

   local sql = string.format(
      "SELECT %s FROM `%s`.`%s` "
      .. "WHERE schema_name = '%s'%s AND %s"
      .. "%s LIMIT 200",
      sel_cols,
      ch_escape(self.db), CH_TS_TABLE_NAME,
      ch_escape(schema.name), tw, time_cond,
      group_clause)

   local data = ch_query(sql)

   if (not data) or (#data == 0) then return nil end

   if #wildcard_tags == 0 then
      -- Simple existence check.
      return { tags_filter }
   end

   local res = {}
   for _, row in ipairs(data) do
      local tag_set = table.clone(tags_filter)
      for _, tag in ipairs(wildcard_tags) do
         tag_set[tag] = row[tag]
      end
      res[#res + 1] = tag_set
   end
   return res
end

-- ##############################################

--! @brief Find the top items by total metric value, with a single grouped query.
--! @return the items {tags, value} sorted by value descending, nil on error.
local function query_top_items(self, schema, tags, tstart, tend, options, top_tags)

   if #top_tags < 1 then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         "ClickHouse driver expects at least one top tag, none found")
      return nil
   end

   local is_counter = (schema.options.metrics_type == ts_common.metrics.counter)
   local tw         = self:tags_where(tags, schema)

   -- Build a value expression that sums all metrics into one comparable number.
   local value_parts = {}
   for _, metric in ipairs(schema._metrics) do
      local esc = ch_escape(metric)
      if is_counter then
         value_parts[#value_parts + 1] = string.format(
            "greatest(0, max(metrics['%s']) - min(metrics['%s']))", esc, esc)
      else
         value_parts[#value_parts + 1] = string.format("sum(metrics['%s'])", esc)
      end
   end

   -- options.unlimited_top asks for every group with data, not just the top ones
   local limit_clause = ""

   if not options.unlimited_top then
      limit_clause = string.format(" LIMIT %d", options.top or 8)
   end

   -- One group per distinct combination of the top tags
   local sel_tags   = {}
   local group_cols = {}

   for _, tag in ipairs(top_tags) do
      local esc = ch_escape(tag)
      sel_tags[#sel_tags + 1]     = string.format("tags['%s'] AS `%s`", esc, esc)
      group_cols[#group_cols + 1] = string.format("`%s`", esc)
   end

   local sql = string.format(
      "SELECT %s, (%s) AS value "
      .. "FROM `%s`.`%s` "
      .. "WHERE schema_name = '%s'%s "
      .. "AND tstamp BETWEEN toDateTime(%d) AND toDateTime(%d) "
      .. "GROUP BY %s "
      .. "ORDER BY value DESC%s",
      table.concat(sel_tags, ", "),
      table.concat(value_parts, " + "),
      ch_escape(self.db), CH_TS_TABLE_NAME,
      ch_escape(schema.name), tw,
      tstart, tend,
      table.concat(group_cols, ", "),
      limit_clause)

   local data = ch_query(sql)

   if (not data) or (#data == 0) then
      return {}
   end

   local sorted = {}

   for _, row in ipairs(data) do
      local val = tonumber(row["value"])
      if val then
         local item_tags = table.clone(tags)

         for _, tag in ipairs(top_tags) do
            item_tags[tag] = row[tag]
         end

         sorted[#sorted + 1] = {
            tags  = item_tags,
            value = val,
         }
      end
   end

   return sorted
end

-- ##############################################

--! @brief Top query entry-point called by ts_utils_core (timeseries_query_top).
--! Delegates to query_top_items and converts the result to the standard
--! {metadata, series} format that the other drivers (RRD, InfluxDB) return.
function driver:timeseries_top(options, top_tags)
   local schema   = options.schema_info
   -- Keep only tags defined in the schema, but don't require all of them
   -- (the top tag is intentionally absent in a top query).
   local tags = {}
   for k, v in pairs(options.tags) do
      if schema.tags[k] ~= nil then tags[k] = v end
   end
   local tstart   = options.epoch_begin
   local tend     = options.epoch_end
   local time_step = ts_common.calculateSampledTimeStep(schema.options.step, tstart, tend, options)

   local top_items = query_top_items(self, schema, tags, tstart, tend, options, top_tags)
   if not top_items or table.empty(top_items) then
      return nil
   end

   local top_tag    = top_tags[1]
   local top_series = {}
   local count      = 0

   -- For each top item, fetch its full time-series and aggregate all metrics.
   for _, item in ipairs(top_items) do
      -- options.totals_only: only the total of each item, no per item data query
      local serie_data = (not options.totals_only) and self:query(schema, tstart, tend, item.tags, options)
      if options.totals_only then
         top_series[#top_series + 1] = {
            tags  = item.tags,
            name  = item.tags[top_tag] or "",
            value = item.value,
         }
      elseif serie_data and serie_data.series and #serie_data.series > 0 then
         local n = (serie_data.metadata and serie_data.metadata.num_point) or 0
         local agg = {}
         for i = 1, n do
            local s         = 0
            local has_valid = false
            for _, serie in ipairs(serie_data.series) do
               local v = serie.data[i]
               if v and v == v then s = s + v; has_valid = true end   -- skip NaN
            end
            agg[i] = has_valid and s or options.fill_value
         end
         count = math.max(count, n)

         local top_val   = item.tags[top_tag] or ""
         local ext_label = ts_common.getExtLabel(options, item.tags)

         top_series[#top_series + 1] = {
            data       = agg,
            id         = schema._metrics[1] or "value",
            statistics = serie_data.statistics,
            tags       = item.tags,
            name       = top_val,
            ext_label  = ext_label,
            value      = item.value,
         }
      end
   end

   if #top_series == 0 then return nil end

   return {
      metadata = {
         epoch_begin = tstart,
         epoch_end   = tend,
         epoch_step  = time_step,
         num_point   = count,
         schema      = options.schema,
         query       = tags,
      },
      series = top_series,
   }
end

-- ##############################################

--! @brief Return the last N non-NaN values for each metric in the time range.
--! Note: values are already normalised by driver:query()
function driver:queryLastValues(options)
   local last_values = {}
   local rsp = self:timeseries_query(options)

   for _, data in pairs(rsp.series or {}) do
      local values = {}
      for i = (#data.data), 1, -1 do
         if #values == options.num_points then break end
         -- nan check
         if data.data[i] == data.data[i] then
            values[#values + 1] = data.data[i]
         end
      end
      last_values[data.id] = values
   end

   return last_values
end

-- ##############################################

--! @brief Flush the in-memory buffer to ClickHouse.
--! Called periodically by the export script. 
--! Dequeuing and INSERT both happen in C++ via native API;
--! (see CHTimeseriesExporter::exportBatch())
function driver:export()
   if interface.chTsQueueLen() == 0 then return(0) end

   local exported, err = interface.chTsExportBatch(CH_BATCH_SIZE)
   exported = exported or 0

   if exported == 0 then
      if err then
         ntop.incrCache(CH_FAILED_EXPORTS_KEY, 1)
         ntop.setCache(CH_LAST_ERROR_KEY,
            string.format("[ClickHouse] INSERT failed: %s", err))
         traceError(TRACE_ERROR, TRACE_CONSOLE,
            string.format("[ClickHouse TS] INSERT failed: %s", err))
      end
      return 0
   end

   ntop.incrCache(CH_EXPORTED_POINTS_KEY, exported)
   ntop.delCache(CH_LAST_ERROR_KEY)
   ntop.ts_inc_num_writes(exported)

   return(exported)
end

-- ##############################################

--! @brief Return the latest timestamp available for queries.
function driver:getLatestTimestamp(ifid)
   -- A conservative implementation: report current time.
   -- A more precise value would require a query but adds latency.
   return os.time()
end

-- ##############################################

--! @brief Delete timeseries matching schema_prefix and tags.
function driver:delete(schema_prefix, tags)
   local schema_cond
   if isEmptyString(schema_prefix) then
      schema_cond = "1=1"
   else
      schema_cond = string.format("startsWith(schema_name, '%s:')",
                      ch_escape(schema_prefix))
   end

   local tw = self:tags_where(tags)

   -- Use ALTER TABLE ... DELETE (asynchronous mutation, universally supported).
   local sql = string.format(
      "ALTER TABLE `%s`.`%s` DELETE WHERE %s%s",
      ch_escape(self.db), CH_TS_TABLE_NAME,
      schema_cond, tw)

   local ok = ch_write(sql)
   return (ok == true or ok == 0)
end

-- ##############################################

--! @brief Delete old data by dropping daily partitions older than the configured
--! retention period, rather then using a TTL clause set at table creation which
--! complicates retention management in case the retention time is changed by the
--! user.
function driver:deleteOldData(ifid)
   local data_retention_utils = require "data_retention_utils"
   local clickhouse_partition_utils = require "clickhouse_partition_utils"

   local retention_days = data_retention_utils.getTSAndStatsDataRetentionDays() or 365

   -- Compute the cutoff epoch, aligned to the start of the day.
   local now      = os.time()
   local cutoff   = now - 86400 * retention_days
   cutoff         = cutoff - (cutoff % 86400)

   -- The table is partitioned by day (toYYYYMMDD), so the partition key is an
   -- 8-digit integer YYYYMMDD.  Drop every active partition whose value is
   -- <= the cutoff date (data on that day is entirely outside the window).
   local cutoff_yyyymmdd = tonumber(os.date("%Y%m%d", cutoff))

   for _, tbl in ipairs(clickhouse_partition_utils.getDailyPartitionedTables(self.db, CH_TS_TABLE_NAME)) do
      local dropped = clickhouse_partition_utils.dropOldPartitions(self.db, tbl, cutoff_yyyymmdd)

      for _, part in ipairs(dropped) do
         traceError(TRACE_INFO, TRACE_CONSOLE,
            string.format("[ClickHouse TS] Dropped partition %u (cutoff: %u)", part, cutoff_yyyymmdd))
      end
   end

   return true
end

-- ##############################################

--! @brief Return a brief health indicator.
function driver:get_health()
   local last_err = ntop.getCache(CH_LAST_ERROR_KEY)
   if isEmptyString(last_err) then
      return "green"
   end
   return "yellow"
end

-- ##############################################

-- CREATE TABLE of the timeseries table (also used for the table the migration fills).
-- Best-practice design choices:
--   * LowCardinality(String) for schema_name          – bounded number of distinct values
--   * Int16 for ifid                                  – ifid from the tags Map materialized
--   * LowCardinality(String) for ntopng_instance_name – ntopng instance name
--   * Map(LowCardinality(String), String) for tags    – LowCardinality keys avoid redundant
--                                                        storage of repeated tag/metric names
--   * Map(LowCardinality(String), Float64) metrics    – same benefit for metric keys
--   * MergeTree partitioned by day                    – enables efficient partition pruning
--   * ORDER BY (schema_name, ifid, entity, tstamp)    – the rows of one entity (e.g. host,
--                                                        host + protocol) are contiguous: a
--                                                        query reads only them, not the rows
--                                                        of every entity of the schema
--  Note: a table created before the entity column keeps ORDER BY (schema_name, ifid, tstamp):
--  ClickHouse cannot change the sort key of an existing table, migrateSchema() only adds
--  the column
--  Note: no TTL clause, retention is enforced by deleting daily partitions in deleteOldData(),
--  which always uses the current preference value. A TTL configured at CREATE TABLE time
--  would become complicated to handle if the user changes the retention setting: it could
--  delete data that should be kept (if retention is increased) or keep data too long (if
--  retention is decreased)
local function create_table_sql(db, table_name)
   return string.format([[
CREATE TABLE IF NOT EXISTS `%s`.`%s`
(
    `schema_name`  LowCardinality(String),
    `ifid`         Int16,
    `ntopng_instance_name` LowCardinality(String),
    `tstamp`       DateTime CODEC(Delta, ZSTD),
    `tags`         Map(LowCardinality(String), String),
    `metrics`      Map(LowCardinality(String), Float64),
    `entity`       String
)
ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(tstamp)
ORDER BY (schema_name, ifid, entity, tstamp)]],
      ch_escape(db), ch_escape(table_name))
end

--! @brief Move a table created before the entity column to ORDER BY (schema_name, ifid, entity, tstamp).
--! ClickHouse cannot change the sort key of a table: the rows are copied, one day at a time, into a
--! new table with the entity computed from the schema tags, then the two tables are exchanged.
--! Runs at startup only, before the timeseries are written and the traffic is captured.
--! The old table is untouched until the copy is complete and checked: on failure it stays as it is.
--! @param ts_utils  reference to the ts_utils module (for the schemas)
--! @return true on success
function driver:migrateToEntityTable(ts_utils)
   local clickhouse_partition_utils = require "clickhouse_partition_utils"
   local format_utils = require "format_utils"
   local json = require "dkjson"
   local begin_time = os.time()
   local db = ch_escape(self.db)
   local old_table = CH_TS_TABLE_NAME
   local new_table = CH_TS_MIGRATION_TABLE_NAME

   -- Once per request: a migration that stops ntopng is not run again at every startup
   ntop.delCache(CH_MIGRATION_REQUEST_KEY)

   local function done(success, message)
      ntop.setCache(CH_MIGRATION_STATUS_KEY, json.encode({
         success = success,
         message = message,
         epoch = os.time(),
         duration = os.time() - begin_time,
      }))

      traceError(success and TRACE_NORMAL or TRACE_ERROR, TRACE_CONSOLE,
         "[ClickHouse TS] Migration to the entity sort key: " .. message)

      return success
   end

   -- Before the exchange: the old table is still the timeseries table
   local function failed(message)
      ch_write(string.format("DROP TABLE IF EXISTS `%s`.`%s` SYNC", db, new_table))
      return done(false, message)
   end

   -- 1. Disk: the copy needs about the size of the table
   local sizes = clickhouse_partition_utils.getPartitionsSize(self.db)

   if not sizes then
      return done(false, "unable to read the size of the table")
   end

   -- No parts: an empty table
   local old_size = sizes[old_table] or { bytes = 0, partitions = {} }

   local res = ch_query(string.format(
      "SELECT min(free_space) AS free_space FROM system.disks WHERE name IN "
      .. "(SELECT disk_name FROM system.parts WHERE database = '%s' AND table = '%s' AND active)",
      db, old_table)) or {}
   local free_space = tonumber(res[1] and res[1]["free_space"])
   local needed_space = math.ceil(old_size.bytes * MIGRATION_DISK_MARGIN)

   if (not free_space) or (free_space < needed_space) then
      return done(false, string.format("not enough free disk: %s needed, %s free",
         format_utils.bytesToSize(needed_space), format_utils.bytesToSize(free_space or 0)))
   end

   -- 2. Entity of the old rows: the same value driver:append writes, from the tags of each schema
   ts_utils.loadSchemas()

   local schema_names = {}
   local schema_tags = {}

   for name, schema in pairs(ts_utils.getLoadedSchemas()) do
      schema_names[#schema_names + 1] = string.format("'%s'", ch_escape(name))
      schema_tags[#schema_tags + 1] = string.format("'%s'", ch_escape(table.concat(entity_tags(schema), ",")))
   end

   -- Schemas not defined anymore get an empty entity
   local entity_sql = string.format(
      "arrayStringConcat(arrayMap(tag -> tags[tag], splitByChar(',', transform(schema_name, [%s], [%s], ''))), '\\x1F')",
      table.concat(schema_names, ","), table.concat(schema_tags, ","))

   -- 3. Copy, one day at a time (newest first) into a new table: a leftover of a failed run is dropped
   ch_write(string.format("DROP TABLE IF EXISTS `%s`.`%s` SYNC", db, new_table))

   if not ch_write(create_table_sql(self.db, new_table)) then
      return failed("unable to create the new table")
   end

   local partitions = {}

   for partition in pairs(old_size.partitions) do
      partitions[#partitions + 1] = partition
   end

   table.sort(partitions, function(a, b) return a > b end)

   for i, partition in ipairs(partitions) do
      local partition_begin = os.time()

      if not ch_write(string.format(
            "INSERT INTO `%s`.`%s` (schema_name, ifid, ntopng_instance_name, tstamp, tags, metrics, entity) "
            .. "SELECT schema_name, ifid, ntopng_instance_name, tstamp, tags, metrics, %s "
            .. "FROM `%s`.`%s` WHERE toYYYYMMDD(tstamp) = %u",
            db, new_table, entity_sql, db, old_table, partition)) then
         return failed(string.format("copy of the day %u failed", partition))
      end

      traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format(
         "[ClickHouse TS] Migration: day %u copied (%u/%u) in %u sec",
         partition, i, #partitions, os.time() - partition_begin))
   end

   -- 4. Check: every row copied
   local function count_rows(table_name)
      local rows = ch_query(string.format("SELECT count() AS rows FROM `%s`.`%s`", db, table_name)) or {}
      return tonumber(rows[1] and rows[1]["rows"])
   end

   local old_rows = count_rows(old_table)
   local new_rows = count_rows(new_table)

   if (not old_rows) or (old_rows ~= new_rows) then
      return failed(string.format("rows copied %s, expected %s", tostring(new_rows), tostring(old_rows)))
   end

   -- 5. Atomic exchange (Atomic database engine): from now on the copy is the timeseries table
   if not ch_write(string.format("EXCHANGE TABLES `%s`.`%s` AND `%s`.`%s`", db, old_table, db, new_table)) then
      return failed("unable to exchange the tables")
   end

   -- 6. The old rows, now in the other table
   if not ch_write(string.format("DROP TABLE `%s`.`%s` SYNC", db, new_table)) then
      return done(true, string.format("%u rows migrated, drop the old table `%s`.`%s` to free %s",
         new_rows, self.db, new_table, format_utils.bytesToSize(old_size.bytes)))
   end

   return done(true, string.format("%u rows migrated", new_rows))
end

-- ##############################################

--! @brief State of the move to the entity sort key, for the GUI: Redis keys only, no query.
--! @return { old_table = true for a table created before the entity column (as seen at startup),
--!           requested = true when the move runs at the next startup,
--!           last = { success, message, epoch, duration } of the last move, or nil }
function driver.getEntityMigrationState()
   local json = require "dkjson"
   local last = ntop.getCache(CH_MIGRATION_STATUS_KEY)

   -- A flag of a run with the ClickHouse driver stays when the driver is not active anymore
   local is_active = ntop.isClickHouseEnabled() and (ntop.getPref("ntopng.prefs.timeseries_driver") == "clickhouse")

   return {
      old_table = is_active and (ntop.getCache(CH_ENTITY_SORT_KEY) == "0"),
      requested = (ntop.getCache(CH_MIGRATION_REQUEST_KEY) == "1"),
      last = (not isEmptyString(last)) and json.decode(last) or nil,
   }
end

-- ##############################################

--! @brief Request the move to the entity sort key at the next startup.
--! @return false when the table does not need it (already moved, or not seen yet by a startup)
function driver.requestEntityMigration()
   if not driver.getEntityMigrationState().old_table then
      return false
   end

   ntop.setCache(CH_MIGRATION_REQUEST_KEY, "1")

   return true
end

-- ##############################################

--! @brief Initialise the ClickHouse schema for timeseries.
--! Called when the driver is first enabled or when retention changes.
--! @param ts_utils  reference to the ts_utils module.
--! @param first_setup  true at startup (the requested migration runs only then)
function driver:setup(ts_utils, first_setup)
   local data_retention_utils = require "data_retention_utils"
   local retention_days = data_retention_utils.getTSAndStatsDataRetentionDays() or 365

   local create_sql = create_table_sql(self.db, CH_TS_TABLE_NAME)

   local ok = ch_write(create_sql)
   if not ok then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         "[ClickHouse TS] Failed to create timeseries table")
      return false
   end

   entity_column = self:migrateSchema()
   ntop.setCache(CH_ENTITY_COLUMN_KEY, entity_column and "1" or "0")

   -- Queries filter on the entity only where it is in the sort key (not in a table created before it)
   -- @return nil when the sort key cannot be read
   local function read_entity_in_sort_key()
      local res = ch_query(string.format(
         "SELECT sorting_key FROM system.tables WHERE database = '%s' AND name = '%s'",
         ch_escape(self.db), ch_escape(CH_TS_TABLE_NAME)))

      if not (res and res[1] and res[1]["sorting_key"]) then
         return nil
      end

      return (string.find(res[1]["sorting_key"], "entity", 1, true) ~= nil)
   end

   local in_sort_key = read_entity_in_sort_key()

   if first_setup and ts_utils and (in_sort_key == false)
      and (ntop.getCache(CH_MIGRATION_REQUEST_KEY) == "1") then
      self:migrateToEntityTable(ts_utils)
      in_sort_key = read_entity_in_sort_key()

      -- The migrated table is created with the entity column
      if in_sort_key then
         entity_column = true
         ntop.setCache(CH_ENTITY_COLUMN_KEY, "1")
      end
   end

   -- Unknown: no entity filter and no upgrade proposed (a wrong "0" would propose a useless copy)
   entity_in_sort_key = (in_sort_key == true)

   if in_sort_key == nil then
      ntop.delCache(CH_ENTITY_SORT_KEY)
   else
      ntop.setCache(CH_ENTITY_SORT_KEY, in_sort_key and "1" or "0")
   end

   traceError(TRACE_INFO, TRACE_CONSOLE,
      string.format("[ClickHouse TS] Table `%s`.`%s` ready (retention: %d days)",
         self.db, CH_TS_TABLE_NAME, retention_days))
   return true
end

-- ##############################################

--! @brief Check actual schema (e.g. if it includes the ifid and ntopng_instance_name
--! columns), add those which are missing, and migrate data (ifid from tags to column)
--! @return true when the table has the entity column
function driver:migrateSchema()
   local sql = string.format(
      "SELECT name FROM system.columns WHERE database = '%s' AND table = '%s' "
      .. "AND name IN ('ifid', 'ntopng_instance_name', 'entity')",
      ch_escape(self.db), ch_escape(CH_TS_TABLE_NAME))

   local res = ch_query(sql) or {}
   local found = {}
   for _, row in ipairs(res) do
      found[row["name"]] = true
   end

   local has_ifid     = found["ifid"] or false
   local has_instance = found["ntopng_instance_name"] or false
   local has_entity   = found["entity"] or false
   local added        = {}

   if not has_ifid then
      -- Add ifid column
      if ch_write(string.format(
            "ALTER TABLE `%s`.`%s` ADD COLUMN IF NOT EXISTS `ifid` Int16",
            ch_escape(self.db), ch_escape(CH_TS_TABLE_NAME))) then
         has_ifid = true
         added[#added + 1] = "ifid"

         -- Copy ifid data from tags
         if ch_write(string.format(
               "ALTER TABLE `%s`.`%s` UPDATE `ifid` = toInt16OrZero(tags['ifid']) WHERE 1",
               ch_escape(self.db), ch_escape(CH_TS_TABLE_NAME))) then
            traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format(
               "[ClickHouse TS] Migrating 'ifid' data from tags['ifid'] on %s.%s",
               self.db, CH_TS_TABLE_NAME))
         else
            traceError(TRACE_WARNING, TRACE_CONSOLE, string.format(
               "[ClickHouse TS] Failed to migrate 'ifid' data from tags on %s.%s",
               self.db, CH_TS_TABLE_NAME))
         end
      end
   end

   if not has_instance then
      if ch_write(string.format(
            "ALTER TABLE `%s`.`%s` ADD COLUMN IF NOT EXISTS `ntopng_instance_name` LowCardinality(String)",
            ch_escape(self.db), ch_escape(CH_TS_TABLE_NAME))) then
         has_instance = true
         added[#added + 1] = "ntopng_instance_name"
      end
   end

   -- Only the column, so that the inserts have it: the existing rows are not rewritten
   -- (their entity is '') and the sort key stays (schema_name, ifid, tstamp)
   if not has_entity then
      if ch_write(string.format(
            "ALTER TABLE `%s`.`%s` ADD COLUMN IF NOT EXISTS `entity` String",
            ch_escape(self.db), ch_escape(CH_TS_TABLE_NAME))) then
         has_entity = true
         added[#added + 1] = "entity"
      end
   end

   if #added > 0 then
      traceError(TRACE_INFO, TRACE_CONSOLE, string.format(
         "[ClickHouse TS] Added '%s' column(s) to %s.%s",
         table.concat(added, "', '"), self.db, CH_TS_TABLE_NAME))
   end

   if (not has_ifid) or (not has_instance) or (not has_entity) then
      local missing = {}
      if not has_ifid     then missing[#missing + 1] = "ifid" end
      if not has_instance then missing[#missing + 1] = "ntopng_instance_name" end
      if not has_entity   then missing[#missing + 1] = "entity" end

      traceError(TRACE_WARNING, TRACE_CONSOLE, string.format(
         "[ClickHouse TS] Failed to add the '%s' column(s) to %s.%s",
         table.concat(missing, "', '"), self.db, CH_TS_TABLE_NAME))
   end

   return has_entity
end

-- ##############################################

--! @brief Static initialiser called once when the driver is first configured.
--! @param dbname        ClickHouse database name.
--! @param verbose       print diagnostic messages when true.
function driver.init(dbname, verbose)

   local obj = driver:new({ db = dbname })

   if verbose then
      traceError(TRACE_NORMAL, TRACE_CONSOLE,
         string.format("[ClickHouse TS] Initialising driver (db=%s)", dbname))
   end

   -- Verify connectivity
   local res = ch_query("SELECT 1 AS ok")
   if not res then
      local err = "[ClickHouse TS] Cannot reach ClickHouse (execTSQuery returned nil)"
      traceError(TRACE_ERROR, TRACE_CONSOLE, err)
      return false, err
   end

   local ok, err2 = obj:setup(nil)
   if not ok then
      return false, err2 or "[ClickHouse TS] setup() failed"
   end

   return true, "[ClickHouse TS] Successfully initialised"
end

-- ##############################################

return driver
