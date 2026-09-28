--
-- (C) 2026 - ntop.org
--
-- ClickHouse utilities to manage clickhouse retention for flows and timeseries
-- Note: only require grants on the ntopng database, not to other system tables such as system.parts
--

local clickhouse_partition_utils = {}

-- ##############################################

local function ch_escape(s)
   s = tostring(s or "")
   s = s:gsub("\\", "\\\\")
   s = s:gsub("'", "\\'")
   return s
end

-- ##############################################

--! @brief Return the tables of the database partitioned by day (toYYYYMMDD)
function clickhouse_partition_utils.getDailyPartitionedTables(database, table_name)
   local sql = string.format(
      "SELECT name, partition_key FROM system.tables"
      .. " WHERE database = '%s' AND partition_key LIKE 'toYYYYMMDD(%%'",
      ch_escape(database))

   if table_name then
      sql = sql .. string.format(" AND name = '%s'", ch_escape(table_name))
   end

   local res = interface.execSQLQuery(sql, false --[[ no row limit ]], false --[[ don't wait for db ]])

   if type(res) ~= "table" then
      return {}
   end

   return res
end

-- ##############################################

--! @brief Return the daily partitions (YYYYMMDD numbers) with data older or equal than cutoff_yyyymmdd.
--! This is computed on the table itself, grouping by the partition key. This is cheap as
--! ClickHouse reads metadata only, not the data.
function clickhouse_partition_utils.getOldPartitions(database, tbl, cutoff_yyyymmdd)
   local sql = string.format(
      "SELECT %s AS drop_part FROM `%s`.`%s` WHERE drop_part <= %u GROUP BY drop_part ORDER BY drop_part",
      tbl.partition_key, database, tbl.name, cutoff_yyyymmdd)

   local res = interface.execSQLQuery(sql, false --[[ no row limit ]], false --[[ don't wait for db ]])
   local partitions = {}

   for _, row in ipairs(res or {}) do
      partitions[#partitions + 1] = tonumber(row["drop_part"])
   end

   return partitions, sql
end

-- ##############################################

--! @brief Drop the daily partitions older or equal than cutoff_yyyymmdd.
--! @return the list of dropped partitions
function clickhouse_partition_utils.dropOldPartitions(database, tbl, cutoff_yyyymmdd, debug)
   local partitions, sql = clickhouse_partition_utils.getOldPartitions(database, tbl, cutoff_yyyymmdd)

   if debug then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "ClickHouse retention query: " .. sql)
   end

   for _, part in ipairs(partitions) do
      local drop_sql = string.format("ALTER TABLE `%s`.`%s` DROP PARTITION '%u'",
         database, tbl.name, part)

      if debug then
         traceError(TRACE_NORMAL, TRACE_CONSOLE, "ClickHouse retention: " .. drop_sql)
      end

      interface.execSQLWrite(drop_sql)
   end

   return partitions
end

-- ##############################################

return clickhouse_partition_utils
