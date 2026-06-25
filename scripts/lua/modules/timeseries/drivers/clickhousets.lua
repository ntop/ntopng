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
--     an in-memory FIFO queue) to avoid small-part overhead; points 
--     are serialised as line-protocol strings (same as RRD and InfluxDB)
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

-- Table and batching settings
local CH_TS_TABLE_NAME     = "timeseries"
local CH_BATCH_SIZE     = 2000    -- maximum rows per INSERT statement

-- ##############################################

-- Parse string produced by CHTimeseriesExporter into its
-- component fields.  The format is:
--   schema_name[,tag=val ...] metric=val[,metric=val ...] timestamp\n
local function line_protocol_parse(line)

   local measurement_and_tags, field_set, timestamp =
      line:match("(.+)%s(.+)%s(.+)\n")
   if not measurement_and_tags then return nil end

   local tags    = {}
   local metrics = {}
   local items   = measurement_and_tags:split(",")
   local schema_name

   if not items then
      schema_name = measurement_and_tags
   else
      schema_name = items[1]
      for i = 2, #items do
         local k, v = items[i]:match("([^=]+)=(.*)")
         if k then tags[k] = v end
      end
   end

   for _, kv in ipairs(field_set:split(",") or {field_set}) do
      local k, v = kv:match("([^=]+)=(.*)")
      if k then metrics[k] = v end
   end

   local data = { schema_name = schema_name, tags = tags,
            metrics = metrics, timestamp = tonumber(timestamp) }

   return data
end

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
-- Internal helpers
-- ##############################################

-- Execute a query via the C++ ClickHouse native client.
-- Returns a list of row-tables on success, nil on failure.
local function ch_query(sql)
   local res,err = interface.execSQLQuery(sql, false --[[no row limit]], false --[[don't wait for db]])
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

-- Serialise a Lua table as a ClickHouse map literal {'k': 'v', ...}.
local function tags_to_ch_map(t)
   local parts = {}
   for k, v in pairs(t) do
      parts[#parts + 1] = string.format("'%s': '%s'", ch_escape(k), ch_escape(v))
   end
   return "{" .. table.concat(parts, ", ") .. "}"
end

-- Serialise a Lua table as a ClickHouse map literal {'k': v, ...} for Float64 values.
local function metrics_to_ch_map(t)
   local parts = {}
   for k, v in pairs(t) do
      local num = tonumber(v) or 0
      parts[#parts + 1] = string.format("'%s': %.6g", ch_escape(k), num)
   end
   return "{" .. table.concat(parts, ", ") .. "}"
end

-- Build a ClickHouse WHERE fragment for the supplied tags table.
-- Returns a string starting with " AND " (or "" if tags is empty).
local function tags_where(tags)
   local conds = {}
   for k, v in pairs(tags) do
      conds[#conds + 1] = string.format("tags['%s'] = '%s'", ch_escape(k), ch_escape(v))
   end
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

-- ##############################################
-- Driver API
-- ##############################################

--! @brief Append a new data point.
--! Serialised to line protocol by CHTimeseriesExporter and buffered in the
--! in-memory C++ queue; flushed to ClickHouse by driver:export().
function driver:append(schema, timestamp, tags, metrics)
   return interface.chTsEnqueue(schema.name, timestamp, tags, metrics)
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
   local tw         = tags_where(tags)
   local af         = agg_func(schema)
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
      local inner_sel = {}
      local mid_sel   = { "t" }
      local outer_sel = { "t" }
      for _, metric in ipairs(schema._metrics) do
         local esc = ch_escape(metric)
         inner_sel[#inner_sel + 1] = string.format(
            "argMax(metrics['%s'], tstamp) AS `%s`", esc, esc)
         mid_sel[#mid_sel + 1] = string.format(
            "`%s` - lag(`%s`, 1, 0) OVER (ORDER BY t) AS `%s`", esc, esc, esc)
         outer_sel[#outer_sel + 1] = string.format(
            "greatest(0, `%s`) / %d AS `%s`", esc, time_step, esc)
      end

      sql = string.format(
         "SELECT %s FROM ("
         ..   "SELECT %s FROM ("
         ..     "SELECT intDiv(toUnixTimestamp(tstamp), %d) * %d AS t, %s "
         ..     "FROM `%s`.`%s` "
         ..     "WHERE schema_name = '%s'%s "
         ..     "AND tstamp BETWEEN toDateTime(%d) AND toDateTime(%d) "
         ..     "GROUP BY t ORDER BY t ASC"
         ..   ")"
         .. ") WHERE t >= %d ORDER BY t ASC",
         table.concat(outer_sel, ", "),
         table.concat(mid_sel, ", "),
         time_step, time_step,
         table.concat(inner_sel, ", "),
         ch_escape(self.db), CH_TS_TABLE_NAME,
         ch_escape(schema.name), tw,
         tstart - time_step, tend,
         tstart)
   else
      -- Gauge / derivative: aggregate within each bucket directly.
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

      sql = string.format(
         "SELECT intDiv(toUnixTimestamp(tstamp), %d) * %d AS t, %s "
         .. "FROM `%s`.`%s` "
         .. "WHERE schema_name = '%s'%s "
         .. "AND tstamp BETWEEN toDateTime(%d) AND toDateTime(%d) "
         .. "GROUP BY t ORDER BY t ASC",
         time_step, time_step,
         table.concat(sel, ", "),
         ch_escape(self.db), CH_TS_TABLE_NAME,
         ch_escape(schema.name), tw,
         tstart, tend)
   end

   local data = ch_query(sql)

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
   local tw            = tags_where(tags)

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

   local tw = tags_where(tags_filter)

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

--! @brief Top-k query: find the top items by total metric value.
function driver:topk(schema, tags, tstart, tend, options, top_tags)

   if #top_tags ~= 1 then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         "ClickHouse driver expects exactly one top tag, " .. #top_tags .. " found")
      return nil
   end

   local top_tag    = top_tags[1]
   local is_counter = (schema.options.metrics_type == ts_common.metrics.counter)
   local tw         = tags_where(tags)

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

   local sql = string.format(
      "SELECT tags['%s'] AS top_tag_val, (%s) AS value "
      .. "FROM `%s`.`%s` "
      .. "WHERE schema_name = '%s'%s "
      .. "AND tstamp BETWEEN toDateTime(%d) AND toDateTime(%d) "
      .. "GROUP BY top_tag_val "
      .. "ORDER BY value DESC LIMIT %d",
      ch_escape(top_tag),
      table.concat(value_parts, " + "),
      ch_escape(self.db), CH_TS_TABLE_NAME,
      ch_escape(schema.name), tw,
      tstart, tend,
      options.top or 8)

   local data = ch_query(sql)

   if (not data) or (#data == 0) then
      return { topk = {}, statistics = nil,
               source_aggregation = "raw",
               additional_series  = { total = nil } }
   end

   local sorted     = {}
   local total_vals = {}

   for _, row in ipairs(data) do
      local val = tonumber(row["value"]) or 0
      if val > 0 then
         sorted[#sorted + 1] = {
            tags     = table.merge(tags, { [top_tag] = row["top_tag_val"] }),
            value    = val,
            partials = {},
         }
         total_vals[#total_vals + 1] = val
      end
   end

   local time_step = ts_common.calculateSampledTimeStep(schema.options.step, tstart, tend, options)
   local stats

   if options.calculate_stats and #total_vals > 0 then
      stats = ts_common.calculateStatistics(total_vals, time_step, tend - tstart,
                 schema.options.metrics_type)
      if stats then
         stats = table.merge(stats, ts_common.calculateMinMax(total_vals))
      end
   end

   return {
      topk               = sorted,
      statistics         = stats,
      source_aggregation = "raw",
      additional_series  = { total = nil },
   }
end

-- ##############################################

--! @brief Top query entry-point called by ts_utils_core (timeseries_query_top).
--! Delegates to driver:topk and converts the result to the standard
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

   local topk_result = self:topk(schema, tags, tstart, tend, options, top_tags)
   if not topk_result or table.empty(topk_result.topk) then
      return nil
   end

   local top_tag    = top_tags[1]
   local top_series = {}
   local count      = 0

   -- For each top item, fetch its full time-series and aggregate all metrics.
   for _, item in ipairs(topk_result.topk) do
      local serie_data = self:query(schema, tstart, tend, item.tags, options)
      if serie_data and serie_data.series and #serie_data.series > 0 then
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
         local ext_label = nil

         -- Device/interface schemas: resolve SNMP interface label.
         if ntop.isPro and ntop.isPro() and options.tags and options.tags.device then
            local snmp_utils      = require "snmp_utils"
            local snmp_cached_dev = require "snmp_cached_dev"
            local cached_device   = snmp_cached_dev:create(options.tags.device)
            local ifindex         = item.tags["if_index"] or item.tags["port"]
            if cached_device and ifindex then
               ext_label = snmp_utils.get_snmp_interface_label(cached_device["interfaces"][ifindex])
            end
            if isEmptyString(ext_label) then ext_label = ifindex end
         end

         -- Protocol schemas: the ext_label is the protocol name itself.
         if item.tags["protocol"] then
            ext_label = top_val
         end

         top_series[#top_series + 1] = {
            data       = agg,
            id         = schema._metrics[1] or "value",
            statistics = serie_data.statistics,
            tags       = item.tags,
            name       = top_val,
            ext_label  = ext_label,
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
function driver:export()
   if interface.chTsQueueLen() == 0 then return end

   -- Drain up to CH_BATCH_SIZE rows per invocation.
   local rows = {}

   for _ = 1, CH_BATCH_SIZE do
      local item = interface.chTsDequeue()
      if item == nil then break end

      local row = line_protocol_parse(item)
      if row and row.schema_name and row.timestamp and row.tags and row.metrics then
         rows[#rows + 1] = string.format(
            "('%s', toDateTime(%d), %s, %s)",
            ch_escape(row.schema_name),
            row.timestamp,
            tags_to_ch_map(row.tags),
            metrics_to_ch_map(row.metrics))
      end
   end

   if #rows == 0 then return end

   local sql = string.format(
      "INSERT INTO `%s`.`%s` (schema_name, tstamp, tags, metrics) VALUES %s",
      ch_escape(self.db), CH_TS_TABLE_NAME,
      table.concat(rows, ","))

   local ok = ch_write(sql)

   if ok then
      ntop.incrCache(CH_EXPORTED_POINTS_KEY, #rows)
      ntop.delCache(CH_LAST_ERROR_KEY)
   else
      ntop.incrCache(CH_FAILED_EXPORTS_KEY, 1)
      ntop.setCache(CH_LAST_ERROR_KEY,
         string.format("[ClickHouse] INSERT failed (%d rows dropped)", #rows))
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         string.format("[ClickHouse TS] INSERT of %d rows failed", #rows))
   end
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

   local tw = tags_where(tags)

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
   local retention_days = data_retention_utils.getTSAndStatsDataRetentionDays() or 365

   -- Compute the cutoff epoch, aligned to the start of the day.
   local now      = os.time()
   local cutoff   = now - 86400 * retention_days
   cutoff         = cutoff - (cutoff % 86400)

   -- The table is partitioned by day (toYYYYMMDD), so the partition key is an
   -- 8-digit integer YYYYMMDD.  Drop every active partition whose value is
   -- <= the cutoff date (data on that day is entirely outside the window).
   local cutoff_yyyymmdd = tonumber(os.date("%Y%m%d", cutoff))

   local find_sql = string.format(
      "SELECT DISTINCT database, table, toUInt32OrZero(partition) AS drop_part"
      .. " FROM system.parts"
      .. " WHERE active"
      .. "   AND database = '%s'"
      .. "   AND table    = '%s'"
      .. "   AND drop_part <= %u"
      .. "   AND drop_part > 999999",  -- guard against unexpected partition formats
      ch_escape(self.db), ch_escape(CH_TS_TABLE_NAME), cutoff_yyyymmdd)

   local partitions = ch_query(find_sql) or {}

   for _, row in ipairs(partitions) do
      local drop_sql = string.format(
         "ALTER TABLE `%s`.`%s` DROP PARTITION '%s'",
         ch_escape(row["database"]),
         ch_escape(row["table"]),
         ch_escape(tostring(row["drop_part"])))

      traceError(TRACE_INFO, TRACE_CONSOLE,
         string.format("[ClickHouse TS] Dropping partition %s (cutoff: %u)",
            tostring(row["drop_part"]), cutoff_yyyymmdd))

      ch_write(drop_sql)
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

--! @brief Initialise the ClickHouse schema for timeseries.
--! Called when the driver is first enabled or when retention changes.
--! @param ts_utils  reference to the ts_utils module.
function driver:setup(ts_utils)
   local data_retention_utils = require "data_retention_utils"
   local retention_days = data_retention_utils.getTSAndStatsDataRetentionDays() or 365

   -- Create the timeseries table if it does not already exist.
   -- Best-practice design choices:
   --   * LowCardinality(String) for schema_name        – bounded number of distinct values
   --   * Map(LowCardinality(String), String) for tags  – LowCardinality keys avoid redundant
   --                                                      storage of repeated tag/metric names
   --   * Map(LowCardinality(String), Float64) metrics  – same benefit for metric keys
   --   * MergeTree partitioned by day                 – enables efficient partition pruning
   --   * ORDER BY (schema_name, tstamp)               – optimises time-range scans per schema
   --  Note: no TTL clause, retention is enforced by deleting daily partitions in deleteOldData(),
   --  which always uses the current preference value. A TTL configured at CREATE TABLE time 
   --  would become complicated to handle if the user changes the retention setting: it could 
   --  delete data that should be kept (if retention is increased) or keep data too long (if
   --  retention is decreased)
   local create_sql = string.format([[
CREATE TABLE IF NOT EXISTS `%s`.`%s`
(
    `schema_name`  LowCardinality(String),
    `tstamp`       DateTime CODEC(Delta, ZSTD),
    `tags`         Map(LowCardinality(String), String),
    `metrics`      Map(LowCardinality(String), Float64)
)
ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(tstamp)
ORDER BY (schema_name, tstamp)
-- TTL tstamp + toIntervalDay(N)  -- removed: see comment above]],
      ch_escape(self.db), CH_TS_TABLE_NAME)

   local ok = ch_write(create_sql)
   if not ok then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         "[ClickHouse TS] Failed to create timeseries table")
      return false
   end

   traceError(TRACE_INFO, TRACE_CONSOLE,
      string.format("[ClickHouse TS] Table `%s`.`%s` ready (retention: %d days)",
         self.db, CH_TS_TABLE_NAME, retention_days))
   return true
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

   -- Verify connectivity: a lightweight query against system tables.
   local res = ch_query("SELECT 1 AS ok FROM system.parts LIMIT 1")
   if not res then
      local err = "[ClickHouse TS] Cannot reach ClickHouse (execSQLQuery returned nil)"
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
