--
-- (C) 2024 - ntop.org
--
-- ClickHouse High-Resolution timeseries driver.
--
-- HR timeseries are read directly from the 'flows' table by unpacking
-- the HR_SRC2DST_BYTES / HR_DST2SRC_BYTES Array(UInt64) columns that
-- nProbe populates when exporting with HR fields. Each element covers
-- a 15-second slot by default.
--
-- Note: there is NO write path, HR data is written by the C++ flow-dump,
-- calling append() is not required.
--
-- Schemas backed by this driver must define data_source = "flows"
-- in their options table. This driver is selected by ts_utils_core via
-- ts_utils.getQueryDriverForSchema().
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/flow_db/?.lua;" .. package.path

local driver = {}

require "ntop_utils"
local ts_common             = require("ts_common")
local clickhouse_utils      = require("clickhouse_utils")
local historical_flow_utils = require("historical_flow_utils")

-- ##############################################

local HR_SLOT_SECONDS = 15

-- Maximum number of series returned when group_by is active.
local GROUPBY_MAX_SERIES = 10

-- Maps group_by tag values to ClickHouse column/expression info.
-- expr  — ClickHouse expression producing the group key value (string or number).
-- resolve(v) — optional Lua function mapping the raw DB value to a display name.
local GROUPBY_TO_COL = {
   l7proto     = { expr = "L7_PROTO",        resolve = function(v) return interface.getnDPIProtoName(tonumber(v)) or v end },
   l7cat       = { expr = "L7_CATEGORY",     resolve = function(v) return interface.getnDPICategoryName(tonumber(v)) or v end },
   l4proto     = { expr = "multiIf(PROTOCOL=6,'TCP',PROTOCOL=17,'UDP',PROTOCOL=1,'ICMP',PROTOCOL=58,'ICMPv6',PROTOCOL=132,'SCTP',toString(PROTOCOL))" },
   cli_asn     = { expr = "toString(SRC_ASN)" },
   srv_asn     = { expr = "toString(DST_ASN)" },
}

-- Maps schema tag names to flows table column names
local TAG_TO_COLUMN = {
   ifid = "INTERFACE_ID",
}

-- For direction neutral schemas: metric name to HR array column
local METRIC_TO_ARRAY = {
   bytes_sent = "HR_SRC2DST_BYTES",
   bytes_rcvd = "HR_DST2SRC_BYTES",
}

-- For direction aware (e.g. host direction) schemas
local METRIC_DIRECTIONAL = {
   bytes_sent = { as_src = "HR_SRC2DST_BYTES", as_dst = "HR_DST2SRC_BYTES" },
   bytes_rcvd = { as_src = "HR_DST2SRC_BYTES", as_dst = "HR_SRC2DST_BYTES" },
}

-- ##############################################

local function ch_query(sql)
   local res, err = interface.execSQLQuery(sql, false --[[no row limit]], false --[[don't wait]])
   if type(res) ~= "table" then return nil end
   return res
end

local function ch_escape(s)
   s = tostring(s or "")
   s = s:gsub("\\", "\\\\")
   s = s:gsub("'",  "\\'")
   return s
end

-- ##############################################
-- Internal helpers — direction neutral
-- ##############################################

-- Build the WHERE fragment for simple (non-host) tags via TAG_TO_COLUMN.
local function tags_where(tags)
   local conds = {}
   for tag, val in pairs(tags) do
      local col = TAG_TO_COLUMN[tag]
      if col then
         conds[#conds + 1] = string.format("%s = '%s'", col, ch_escape(val))
      end
   end
   return (#conds > 0) and (" AND " .. table.concat(conds, " AND ")) or ""
end

-- Build the SELECT list for direction-neutral HR metrics.
local function metric_select(schema, divisor)
   local sel = {}
   for _, metric in ipairs(schema._metrics) do
      local arr = METRIC_TO_ARRAY[metric]
      if arr then
         if divisor and divisor > 0 then
            sel[#sel + 1] = string.format(
               "sum(arrayElement(%s, slot)) / %d AS `%s`",
               ch_escape(arr), divisor, ch_escape(metric))
         else
            sel[#sel + 1] = string.format(
               "sum(arrayElement(%s, slot)) AS `%s`",
               ch_escape(arr), ch_escape(metric))
         end
      end
   end
   return sel
end

-- Return the HR array column to use for ARRAY JOIN (first metric that maps).
local function pick_join_array(schema)
   for _, metric in ipairs(schema._metrics) do
      local arr = METRIC_TO_ARRAY[metric]
      if arr then return arr end
   end
   return "HR_SRC2DST_BYTES"   -- safe fallback
end

-- ClickHouse expression for the wall-clock time of a slot.
-- FIRST_SEEN is UInt32 (epoch seconds); slot is 1-based from arrayEnumerate.
-- toUInt64 prevents overflow for long-lived flows.
--
-- Slot 0 is NOT at FIRST_SEEN itself: both nProbe and Flow::mergeHRCounters()
-- anchor the array to the start of the MINUTE containing FIRST_SEEN, so every flow
-- shares the same global 15s grid.
local function slot_ts_expr()
   return string.format(
      "intDiv(toUInt64(FIRST_SEEN), 60) * 60 + (toUInt64(slot) - 1) * %d",
      HR_SLOT_SECONDS)
end

-- ##############################################
-- Internal helpers — direction aware
-- ##############################################

local function is_ipv6(ip)
   return ip:find(":") ~= nil
end

-- Return a context table with ClickHouse conditions for the given host IP.
--   src_cond  — "SRC column = <ip>" expression (used as CASE WHEN is_src)
--   dst_cond  — "DST column = <ip>" expression
--   match_any — "(src_cond OR dst_cond)" for the WHERE clause
local function host_ip_context(ip)
   local esc = ch_escape(ip)
   local src_cond, dst_cond
   if is_ipv6(ip) then
      src_cond = string.format("IPV6_SRC_ADDR = toIPv6('%s')", esc)
      dst_cond = string.format("IPV6_DST_ADDR = toIPv6('%s')", esc)
   else
      src_cond = string.format("IPV4_SRC_ADDR = toIPv4('%s')", esc)
      dst_cond = string.format("IPV4_DST_ADDR = toIPv4('%s')", esc)
   end
   return {
      src_cond  = src_cond,
      dst_cond  = dst_cond,
      match_any = string.format("(%s OR %s)", src_cond, dst_cond),
   }
end

-- Build direction-aware SELECT expressions using CASE WHEN.
-- When host is SRC: use the as_src array; when host is DST: use as_dst.
local function metric_select_directional(schema, is_src_cond, divisor)
   local sel = {}
   for _, metric in ipairs(schema._metrics) do
      local dir = METRIC_DIRECTIONAL[metric]
      if dir then
         local expr = string.format(
            "sum(CASE WHEN %s THEN arrayElement(%s, slot) "
            ..           "ELSE arrayElement(%s, slot) END)",
            is_src_cond,
            ch_escape(dir.as_src), ch_escape(dir.as_dst))
         if divisor and divisor > 0 then
            sel[#sel + 1] = string.format("%s / %d AS `%s`", expr, divisor, ch_escape(metric))
         else
            sel[#sel + 1] = string.format("%s AS `%s`", expr, ch_escape(metric))
         end
      end
   end
   return sel
end

-- ##############################################
-- Internal helpers — aggregation (optional filters)
-- ##############################################

-- Build WHERE conditions for flow:hr_traffic_aggr
-- This uses the same flowfilter logic as historical flows.
-- tags["ifid"] is a plain interface ID, all other filters arrive as "value;op"
local function build_agg_where(tags)
   -- Collect non-empty tags, skip internal/epoch fields handled elsewhere.
   local skip = { epoch_begin = true, epoch_end = true, group_by = true }
   local filters = {}
   for key, val in pairs(tags) do
      local s = tostring(val or "")
      if not skip[key] and s ~= "" and s ~= "nil" and s ~= "null" then
         filters[key] = s
      end
   end

   if next(filters) == nil then return "" end

   local where = clickhouse_utils.formatWhere(filters, false)
   if isEmptyString(where) then return "" end
   where = historical_flow_utils.fixWhereTypes(where)
   return " AND " .. where
end

-- ##############################################
-- Internal helpers — flow (5-tuple)
-- ##############################################

-- Build conditions for a flow identified by its 5-tuple.
local function build_flow_where(tags)
   local cli_ip   = tags["cli_ip"]
   local srv_ip   = tags["srv_ip"]
   local cli_port = tags["cli_port"]
   local srv_port = tags["srv_port"]
   local protocol = tags["protocol"]
   local first_seen = tags["first_seen"]

   if not cli_ip or not srv_ip or not cli_port or not srv_port or not protocol then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         "[ClickHouse HR] flow_context requires cli_ip, srv_ip, cli_port, srv_port, protocol tags")
      return nil
   end

   local conds = {}

   -- Interface
   local ifid_col = TAG_TO_COLUMN["ifid"]
   if ifid_col and tags["ifid"] then
      conds[#conds + 1] = string.format("%s = '%s'", ifid_col, ch_escape(tags["ifid"]))
   end

   -- IP address
   if is_ipv6(cli_ip) then
      conds[#conds + 1] = string.format("IPV6_SRC_ADDR = toIPv6('%s')", ch_escape(cli_ip))
      conds[#conds + 1] = string.format("IPV6_DST_ADDR = toIPv6('%s')", ch_escape(srv_ip))
   else
      conds[#conds + 1] = string.format("IPV4_SRC_ADDR = toIPv4('%s')", ch_escape(cli_ip))
      conds[#conds + 1] = string.format("IPV4_DST_ADDR = toIPv4('%s')", ch_escape(srv_ip))
   end

   -- Port and protocol
   conds[#conds + 1] = string.format("IP_SRC_PORT = %d", tonumber(cli_port) or 0)
   conds[#conds + 1] = string.format("IP_DST_PORT = %d", tonumber(srv_port) or 0)
   conds[#conds + 1] = string.format("PROTOCOL = %d",    tonumber(protocol) or 0)

   -- Optional: get a specific flow by first_seen
   if first_seen and tonumber(first_seen) then
      conds[#conds + 1] = string.format("FIRST_SEEN = %d", tonumber(first_seen))
   end

   return " AND " .. table.concat(conds, " AND ")
end

-- ##############################################

-- Returns tw (additional WHERE conditions), sel (SELECT list), join_arr (ARRAY JOIN column),
-- handling both simple and directional schemas.
-- `divisor`, when given, is the point's time width in seconds: pass the query's
-- time_step to get bytes/sec (chart points), omit it to get raw byte sums (totals).
local function build_query_parts(schema, tags, divisor)
   -- Exact 5-tuple match
   if schema.options and schema.options.flow_context then
      local tw  = build_flow_where(tags)
      if tw == nil then return nil end
      local sel = metric_select(schema, divisor)   -- bytes_sent→HR_SRC2DST_BYTES, bytes_rcvd→HR_DST2SRC_BYTES
      return tw, sel, pick_join_array(schema)
   end

   -- Aggregation: optional column filters
   if schema.options and schema.options.agg_context then
      local tw  = build_agg_where(tags)
      local sel = metric_select(schema, divisor)
      return tw, sel, pick_join_array(schema)
   end

   local host_dir_tag = schema.options and schema.options.host_direction

   if host_dir_tag then
      local host_val = tags[host_dir_tag]
      if not host_val then
         traceError(TRACE_ERROR, TRACE_CONSOLE,
            "[ClickHouse HR] host_direction tag '" .. host_dir_tag
            .. "' missing from tags in schema " .. schema.name)
         return nil
      end
      local ctx = host_ip_context(host_val)
      local tw  = tags_where(tags) .. " AND " .. ctx.match_any
      local sel = metric_select_directional(schema, ctx.src_cond, divisor)
      return tw, sel, "HR_SRC2DST_BYTES"
   end

   return tags_where(tags), metric_select(schema, divisor), pick_join_array(schema)
end

-- ##############################################
-- Driver API
-- ##############################################

--! @brief Driver constructor.
--! @param options table with at least { db = "dbname" }.
function driver:new(options)
   if not ntop.isClickHouseEnabled() then return nil end

   local obj = { db = options.db or "ntopng" }
   setmetatable(obj, self)
   self.__index = self
   return obj
end

-- ##############################################

--! @brief No-op: HR data is written by the C++ flow-dump pipeline.
function driver:append(schema, timestamp, tags, metrics)
   return true
end

-- ##############################################

--! @brief Query HR timeseries grouped by a single dimension (group_by tag).
-- Returns one series per unique group value (top GROUPBY_MAX_SERIES by total bytes).
-- Each series contains total (SRC2DST + DST2SRC) bytes per time slot.
function driver:query_grouped(schema, tstart, tend, tags, options)
   local gb_key = tags.group_by
   local gb_def = GROUPBY_TO_COL[gb_key]
   if not gb_def then
      traceError(TRACE_WARNING, TRACE_CONSOLE,
         "[ClickHouse HR] unsupported group_by value: " .. tostring(gb_key))
      return nil
   end

   local time_step = ts_common.calculateSampledTimeStep(HR_SLOT_SECONDS, tstart, tend, options)
   local sts       = slot_ts_expr()
   local tw        = build_agg_where(tags)   -- group_by is already skipped in build_agg_where
   local join_arr  = "HR_SRC2DST_BYTES"

   local sql = string.format(
      "SELECT toString(%s) AS group_key, intDiv(%s, %d) * %d AS t, "
      .. "sum(arrayElement(HR_SRC2DST_BYTES, slot) + arrayElement(HR_DST2SRC_BYTES, slot)) / %d AS bytes "
      .. "FROM `%s`.`flows` "
      .. "ARRAY JOIN arrayEnumerate(%s) AS slot "
      .. "WHERE length(%s) > 0%s "
      .. "AND FIRST_SEEN <= %d AND LAST_SEEN >= %d "
      .. "AND %s BETWEEN %d AND %d "
      .. "GROUP BY group_key, t ORDER BY group_key, t ASC",
      gb_def.expr,
      sts, time_step, time_step,
      time_step,
      ch_escape(self.db),
      ch_escape(join_arr), ch_escape(join_arr), tw,
      tend, tstart,
      sts, tstart, tend)

   local data = ch_query(sql)

   -- Compute per-group totals for ranking and collect row lists.
   local groups_rows  = {}   -- group_key -> list of { t, bytes }
   local groups_total = {}   -- group_key -> total bytes

   if data and #data > 0 then
      for _, row in ipairs(data) do
         local gk = tostring(row.group_key or "")
         if gk == "" or gk == "nil" then gk = "?" end
         if not groups_rows[gk] then
            groups_rows[gk]  = {}
            groups_total[gk] = 0
         end
         local b = tonumber(row.bytes) or 0
         groups_rows[gk][#groups_rows[gk]+1] = { t = tonumber(row.t), bytes = b }
         groups_total[gk] = groups_total[gk] + b
      end
   end

   -- Sort by total bytes descending, keep top GROUPBY_MAX_SERIES.
   local sorted_keys = {}
   for k in pairs(groups_total) do sorted_keys[#sorted_keys+1] = k end
   table.sort(sorted_keys, function(a, b) return groups_total[a] > groups_total[b] end)

   -- Build time-aligned series for each top group.
   local series = {}
   for rank, gk in ipairs(sorted_keys) do
      if rank > GROUPBY_MAX_SERIES then break end

      local display_name = gk
      if gb_def.resolve then
         display_name = gb_def.resolve(gk) or gk
      end

      -- Index t -> bytes for this group.
      local t_idx = {}
      for _, pt in ipairs(groups_rows[gk]) do
         if pt.t then t_idx[pt.t] = (t_idx[pt.t] or 0) + pt.bytes end
      end

      -- Align the start to the same intDiv(slot_ts, time_step)*time_step boundary the DB uses,
      -- so hash-map lookups hit rather than consistently missing due to tstart not being on a boundary.
      local t0 = math.floor(tstart / time_step) * time_step
      local arr       = {}
      local expected_t = t0
      local idx        = 1
      while (tend - expected_t) >= 0 do
         if (not options.fill_series) and (expected_t > os.time()) then break end
         arr[idx] = t_idx[expected_t] or options.fill_value
         idx        = idx + 1
         expected_t = expected_t + time_step
      end

      local serie_stats = {}
      if options.calculate_stats then
         local s  = ts_common.calculateStatistics(arr, time_step, tend - tstart,
                       schema.options.metrics_type)
         local mm = ts_common.calculateMinMax(arr)
         serie_stats = table.merge(s or {}, mm or {})
      end

      series[#series+1] = { id = display_name, data = arr, statistics = serie_stats }
   end

   local count = (series[1] and #series[1].data) or 0

   return {
      metadata = {
         epoch_begin = math.floor(tstart / time_step) * time_step,
         epoch_end   = tend,
         epoch_step  = time_step,
         num_point   = count,
         schema      = schema.name,
         query       = tags,
      },
      series             = series,
      source_aggregation = "raw",
      additional_series  = {},
   }
end

-- ##############################################

--! @brief Query HR timeseries data from the flows table.
function driver:query(schema, tstart, tend, tags, options)
   -- Grouped query: one series per dimension value.
   if schema.options and schema.options.agg_context
         and not isEmptyString(tostring(tags.group_by or "")) then
      return self:query_grouped(schema, tstart, tend, tags, options)
   end

   local time_step = ts_common.calculateSampledTimeStep(
      HR_SLOT_SECONDS, tstart, tend, options)
   local sts = slot_ts_expr()

   local tw, sel, join_arr = build_query_parts(schema, tags, time_step)

   if tw == nil or #sel == 0 then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
         "[ClickHouse HR] schema '" .. schema.name .. "' has no supported HR metrics")
      return nil
   end

   -- Three-level time filter:
   --   FIRST_SEEN <= tend / LAST_SEEN >= tstart  → pre-filters rows (uses index)
   --   slot timestamp BETWEEN tstart AND tend     → keeps only slots inside window
   local sql = string.format(
      "SELECT intDiv(%s, %d) * %d AS t, %s "
      .. "FROM `%s`.`flows` "
      .. "ARRAY JOIN arrayEnumerate(%s) AS slot "
      .. "WHERE length(%s) > 0%s "
      .. "AND FIRST_SEEN <= %d AND LAST_SEEN >= %d "
      .. "AND %s BETWEEN %d AND %d "
      .. "GROUP BY t ORDER BY t ASC",
      sts, time_step, time_step,
      table.concat(sel, ", "),
      ch_escape(self.db),
      ch_escape(join_arr),
      ch_escape(join_arr), tw,
      tend, tstart,
      sts, tstart, tend)

   local data = ch_query(sql)

   -- Build output series skeletons.
   local series   = {}
   local max_vals = {}
   for i, metric in ipairs(schema._metrics) do
      series[i]   = { id = metric, data = {} }
      max_vals[i] = ts_common.getMaxPointValue(schema, metric, tags)
   end

   local expected_t = tstart
   local idx        = 1

   if data and #data > 0 then
      for _, row in ipairs(data) do
         local cur_t = tonumber(row["t"])
         if cur_t == nil then goto continue end

         -- Fill gaps with fill_value.
         while (cur_t - expected_t) >= time_step do
            for _, serie in ipairs(series) do
               serie.data[idx] = options.fill_value
            end
            idx        = idx + 1
            expected_t = expected_t + time_step
         end

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
               if v and v == v then s = s + v end   -- skip NaN
            end
            total_serie[i] = s
         end
      end

      if total_serie then
         stats = ts_common.calculateStatistics(total_serie, time_step, tend - tstart,
                    schema.options.metrics_type)
         stats = table.merge(stats or {}, ts_common.calculateMinMax(total_serie))
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

--! @brief High-level query entry-point (mirrors clickhousets interface).
function driver:timeseries_query(options)
   local actual_tags = options.schema_info:verifyTags(options.tags) or options.tags
   return self:query(options.schema_info, options.epoch_begin, options.epoch_end,
                     actual_tags, options)
end

-- ##############################################

--! @brief Calculate per-metric totals over a time range.
function driver:queryTotal(schema, tstart, tend, tags, options)
   local sts = slot_ts_expr()

   local tw, sel, join_arr = build_query_parts(schema, tags)

   if tw == nil or #sel == 0 then return {} end

   local sql = string.format(
      "SELECT %s FROM `%s`.`flows` "
      .. "ARRAY JOIN arrayEnumerate(%s) AS slot "
      .. "WHERE length(%s) > 0%s "
      .. "AND FIRST_SEEN <= %d AND LAST_SEEN >= %d "
      .. "AND %s BETWEEN %d AND %d",
      table.concat(sel, ", "),
      ch_escape(self.db),
      ch_escape(join_arr),
      ch_escape(join_arr), tw,
      tend, tstart,
      sts, tstart, tend)

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

--! @brief Return the last N non-NaN values for each metric.
function driver:queryLastValues(options)
   local last_values = {}
   local rsp = self:timeseries_query(options)

   for _, data in pairs((rsp or {}).series or {}) do
      local values = {}
      for i = #data.data, 1, -1 do
         if #values == options.num_points then break end
         if data.data[i] == data.data[i] then   -- skip NaN
            values[#values + 1] = data.data[i]
         end
      end
      last_values[data.id] = values
   end

   return last_values
end

-- ##############################################

--! @brief Top queries are not supported for HR schemas; returns nil.
function driver:timeseries_top(options, top_tags)
   return nil
end

-- ##############################################

--! @brief Check whether HR data exists for the given tags / time range.
function driver:listSeries(schema, tags_filter, wildcard_tags, start_time, end_time)
   local join_arr  = pick_join_array(schema)
   local time_cond = string.format("FIRST_SEEN >= %d", start_time)
   if end_time then
      time_cond = time_cond .. string.format(" AND LAST_SEEN <= %d", end_time)
   end

   -- Build WHERE: flow context, aggregation, host direction, or simple tags.
   local tw
   if schema.options and schema.options.flow_context then
      tw = build_flow_where(tags_filter) or ""
   elseif schema.options and schema.options.agg_context then
      tw = build_agg_where(tags_filter)
   else
      tw = tags_where(tags_filter)
      local host_dir_tag = schema.options and schema.options.host_direction
      if host_dir_tag and tags_filter[host_dir_tag] then
         local ctx = host_ip_context(tags_filter[host_dir_tag])
         tw = tw .. " AND " .. ctx.match_any
      end
   end

   local sql = string.format(
      "SELECT 1 FROM `%s`.`flows` "
      .. "WHERE length(%s) > 0%s AND %s LIMIT 1",
      ch_escape(self.db),
      ch_escape(join_arr), tw, time_cond)

   local data = ch_query(sql)
   if (not data) or (#data == 0) then return nil end

   return { tags_filter }
end

-- ##############################################

--! @brief Delete is not meaningful for HR schemas (data lives in the flows table).
function driver:delete(schema_prefix, tags)
   return true
end

--! @brief HR data retention is managed by the flows table retention policy.
function driver:deleteOldData(ifid)
   return true
end

--! @brief No separate setup needed — the flows table is managed elsewhere.
function driver:setup(ts_utils)
   return true
end

--! @brief Return latest available timestamp.
function driver:getLatestTimestamp(ifid)
   return os.time()
end

--! @brief Health reflects ClickHouse reachability (same signal as the TS driver).
function driver:get_health()
   local res = interface.execSQLQuery(
      "SELECT 1 AS ok FROM system.parts LIMIT 1", false, false)
   return (type(res) == "table") and "green" or "yellow"
end

-- ##############################################

return driver
