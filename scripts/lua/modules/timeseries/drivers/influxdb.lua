--
-- (C) 2018 - ntop.org
--

local driver = {}

local ts_common = require("ts_common")

local json = require("dkjson")
local os_utils = require("os_utils")
require("ntop_utils")

--
-- Sample query:
--    select * from "iface:ndpi" where ifid='0' and protocol='SSL'
--
-- See also callback_utils.uploadTSdata
--

local INFLUX_QUERY_TIMEMOUT_SEC = 5
local MIN_INFLUXDB_SUPPORTED_VERSION = "1.5.1"
local RP_1H_DURATION = "30d" -- NOTE keep in sync with RP_1H_DURATION_SECS below
local RP_1H_DURATION_SECS = 2592000
local RP_1D_DURATION = "365d"  -- NOTE keep in sync with RP_1D_DURATION_SECS below
local RP_1D_DURATION_SECS = 31536000
local FIRST_AGGREGATION_TIME_KEY = "ntopng.prefs.influxdb.first_aggregation_time"

-- ##############################################

function driver:new(options)
  local obj = {
    url = options.url,
    db = options.db,
    username = options.username or "",
    password = options.password or "",
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

-- ##############################################

function driver:append(schema, timestamp, tags, metrics)
  return interface.appendInfluxDB(schema.name, timestamp, tags, metrics)
end

-- ##############################################

local function getResponseError(res)
  if res.CONTENT and res.CONTENT_TYPE == "application/json" then
    local jres = json.decode(res.CONTENT)

    if jres then
      if jres.error then
        if res.RESPONSE_CODE then
          return "[".. res.RESPONSE_CODE .. "] " ..jres.error
        else
          return jres.error
        end
      elseif jres.results then
        for _, single_res in pairs(jres.results) do
          if single_res.error then
            return single_res.error
          end
        end
      end
    end
  end

  return res.RESPONSE_CODE or "unknown error"
end

-- ##############################################

-- Determines the most appropriate retention policy
local function getSchemaRetentionPolicy(schema, tstart, tend, options)
  options = options or {}
  local first_aggr_time = tonumber(ntop.getPref(FIRST_AGGREGATION_TIME_KEY))

  if not first_aggr_time then
    return "raw"
  end

  -- RP selection logic
  local oldest_1d_data = os.time() - RP_1D_DURATION_SECS
  local oldest_1h_data = os.time() - RP_1H_DURATION_SECS
  local oldest_raw_data = tonumber(ntop.getPref("ntopng.prefs.influx_retention")) or 365 -- TODO make in common with prefs.lua
  local max_raw_interval = 12 * 3600 -- after 12 hours begin to use the aggregated data

  if options.target_aggregation then
    if((options.target_aggregation == "1h") and (tstart < oldest_1h_data)) or
      ((options.target_aggregation == "raw") and (tstart < oldest_raw_data)) then
      -- cannot satisfy the target_aggregation
    else
      -- user override
      return options.target_aggregation
    end
  end

  -- Fix the limits to ensure that the first_aggr_time is not crossed
  -- Crossing it is still acceptable for the options.target_aggregation check above
  oldest_1d_data = math.max(oldest_1d_data, first_aggr_time)
  oldest_1h_data = math.max(oldest_1h_data, first_aggr_time)

  if tstart < oldest_1d_data then
    return "raw"
  elseif tstart < oldest_1h_data then
    return "1d"
  elseif tstart < oldest_raw_data then
    return "1h"
  end

  local interval = tend - tstart

  if interval >= max_raw_interval then
    return "1h"
  end

  return "raw"
end

-- ##############################################

-- returns schema_name, step
local function retentionPolicyToSchema(schema, rp)
  if rp == "raw" then
    rp = nil
  end

  if not isEmptyString(rp) then
    return string.format('"%s"."%s"', rp, schema.name), ternary(rp == "1d", 86400, 3600)
  end

  -- raw
  return string.format('"%s"', schema.name), schema.options.step
end

-- ##############################################

local function getQuerySchema(schema, tstart, tend, options)
  return retentionPolicyToSchema(schema, getSchemaRetentionPolicy(schema, tstart, tend, options))
end

-- ##############################################

local function influx_query(base_url, query, username, password, options)
  options = options or {}
  local full_url = base_url .."&q=" .. urlencode(query)
  local tstart = os.time()
  local res = ntop.httpGet(full_url, username, password, ternary(options.no_timeout, 99999999999, INFLUX_QUERY_TIMEMOUT_SEC), true)
  local tend = os.time()
  local debug_influxdb_queries = (ntop.getPref("ntopng.prefs.debug_influxdb_queries") == "1")

  if debug_influxdb_queries then
    local tdiff = tend - tstart
    if tdiff > 0 then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "Query took ".. (tend - tstart) .." sec to complete: ".. query)
    end
  end

  if not res then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid response for query: " .. full_url)
    return nil
  end

  if((res.RESPONSE_CODE ~= 200) and (not res.IS_PARTIAL)) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad response code[" .. res.RESPONSE_CODE .. "]: " .. (res.CONTENT or ""))
    return nil
  end

  if((res.CONTENT == nil) or (res.IS_PARTIAL)) then
    ts_common.setLastError(ts_common.ERR_OPERATION_TOO_SLOW, i18n("graphs.query_too_slow"))
    return nil
  end

  local jres = json.decode(res.CONTENT)

  if (not jres) or (not jres.results) or (not #jres.results) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid JSON reply[" .. res.CONTENT_LEN .. " bytes]: " .. string.sub(res.CONTENT, 1, 50))
    return nil
  end

  if jres.results[1]["error"] then
    traceError(TRACE_ERROR, TRACE_CONSOLE, jres.results[1]["error"])
  end

  if not jres.results[1].series then
    -- no results found
    return {}
  end

  return jres.results[1]
end

-- ##############################################

local function influx2Series(schema, tstart, tend, tags, options, data, time_step)
  local series = {}
  local max_vals = {}

  -- Create the columns
  for i=2, #data.columns do
    series[i-1] = {label=data.columns[i], data={}}
    max_vals[i-1] = ts_common.getMaxPointValue(schema, series[i-1].label, tags)
  end

  -- The first time available in the returned data
  local first_t = data.values[1][1]
  -- next_t holds the expected timestamp of the next point to process
  local next_t = tstart + ((first_t - tstart) % time_step)
  -- the next index to use for insertion in the result table
  local series_idx = 1
  --tprint(time_step .. ") " .. tstart .. " vs " .. first_t .. " - " .. next_t)

  -- Convert the data
  for idx, values in ipairs(data.values) do
    local cur_t = data.values[idx][1]

    if #values < 2 or cur_t < tstart then
      -- skip empty points (which are out of query bounds)
      goto continue
    end

    -- Fill the missing points
    while((cur_t - next_t) >= time_step) do
      for _, serie in pairs(series) do
        serie.data[series_idx] = options.fill_value
      end

      --tprint("FILL [" .. series_idx .."] " .. cur_t .. " vs " .. next_t)
      series_idx = series_idx + 1
      next_t = next_t + time_step
    end

    for i=2, #values do
      local val = ts_common.normalizeVal(values[i], max_vals[i-1], options)
      series[i-1].data[series_idx] = val
    end

    series_idx = series_idx + 1
    next_t = next_t + time_step

    ::continue::
  end

   -- Fill the missing points at the end
  while((tend - next_t) >= 0) do
    for _, serie in pairs(series) do
      serie.data[series_idx] = options.fill_value
    end

    --tprint("FILL [" .. series_idx .."] " .. tend .. " vs " .. next_t)
    series_idx = series_idx + 1
    next_t = next_t + time_step
  end

  local count = series_idx - 1

  return series, count
end

-- Test only
driver._influx2Series = influx2Series

 --##############################################

local function getTotalSerieQuery(schema, query_schema, raw_step, tstart, tend, tags, time_step, data_type, label)
  label = label or "total_serie"

  --[[
  SELECT NON_NEGATIVE_DERIVATIVE(total_serie) AS total_serie FROM               // derivate the serie, if necessary
    (SELECT MEAN("total_serie") AS "total_serie" FROM                           // sample the total serie points, if necessary
      (SELECT SUM("value") AS "total_serie" FROM                                // sum all the series together
        (SELECT (bytes_sent + bytes_rcvd) AS "value" FROM "host:ndpi"           // possibly sum multiple metrics within same serie
          WHERE host='192.168.43.18' AND ifid='2'
          AND time >= 1531916170000000000 AND time <= 1532002570000000000)
        GROUP BY time(300s))
      GROUP BY time(600s))
  ]]
  local is_single_serie = schema:allTagsDefined(tags)
  local simplified_query = 'SELECT (' .. table.concat(schema._metrics, " + ") ..') AS "'.. label ..'" FROM '.. query_schema ..' WHERE ' ..
    table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= ' .. tstart .. '000000000 AND time <= ' .. tend .. '000000000'

  local query

  if is_single_serie then
    -- optimized version
    query = simplified_query
  else
    query = 'SELECT SUM("'.. label ..'") AS "'.. label ..'" FROM ('.. simplified_query ..')'..
      ' GROUP BY time('.. raw_step ..'s)'
  end

  if time_step and (raw_step ~= time_step) then
    -- sample the points
    query = 'SELECT MEAN("'.. label ..'") AS "'.. label ..'" FROM ('.. query ..') GROUP BY time('.. time_step ..'s)'
  end

  if data_type == ts_common.metrics.counter then
    local optimized = false

    if (query == simplified_query) and (#schema._metrics == 1) then
      -- Remove nested query if possible
      local parts = split(query, " FROM ")

      if #parts == 2 then
        query = "SELECT NON_NEGATIVE_DERIVATIVE(".. schema._metrics[1] ..") AS ".. label .." FROM " .. parts[2]
      end
    end

    if not optimized then
      query = "SELECT NON_NEGATIVE_DERIVATIVE(".. label ..") AS ".. label .." FROM (" .. query .. ")"
    end
  end

  return query
end

-- ##############################################

function driver:_makeTotalSerie(schema, query_schema, raw_step, tstart, tend, tags, options, url, time_step, label, unaligned_offset)
  local data_type = schema.options.metrics_type
  local query = getTotalSerieQuery(schema, query_schema, raw_step, tstart, tend + unaligned_offset, tags, time_step, data_type, label)
  local data = influx_query(url .. "/query?db=".. self.db .."&epoch=s", query, self.username, self.password, options)

  if table.empty(data) then
    local rv = {}
    local i = 1

    for t=tstart + time_step, tend, time_step do
      rv[i] = 0
      i = i + 1
    end

    return rv
  end

  data = data.series[1]

  local series, count = influx2Series(schema, tstart + time_step, tend, tags, options, data, time_step)
  return series[1].data
end

-- ##############################################

-- NOTE: mean / percentile values are calculated manually because of an issue with
-- empty points in the queries https://github.com/influxdata/influxdb/issues/6967
function driver:_performStatsQuery(stats_query, tstart, tend)
  local data = influx_query(self.url .. "/query?db=".. self.db .."&epoch=s", stats_query, self.username, self.password)

  if (data and data.series and data.series[1] and data.series[1].values[1]) then
    local data_stats = data.series[1].values[1]
    local total = data_stats[2]

    return {total=total, average = (total / (tend - tstart))}
  end

  return nil
end

-- ##############################################

local function makeSeriesQuery(query_schema, metrics, tags, tstart, tend, time_step)
  return 'SELECT '.. table.concat(metrics, ",") ..' FROM ' .. query_schema .. ' WHERE ' ..
      table.tconcat(tags, "=", " AND ", nil, "'") .. " AND time >= " .. tstart .. "000000000 AND time <= " .. tend .. "000000000" ..
      " GROUP BY TIME(".. time_step .."s)"
end

function driver:query(schema, tstart, tend, tags, options)
  local metrics = {}
  local data_type = schema.options.metrics_type
  local retention_policy = getSchemaRetentionPolicy(schema, tstart, tend, options)
  local query_schema, raw_step = retentionPolicyToSchema(schema, retention_policy)
  local time_step = ts_common.calculateSampledTimeStep(raw_step, tstart, tend, options)

  -- NOTE: this offset is necessary to fix graph edge points when data insertion is not aligned with tstep
  local unaligned_offset = raw_step - 1

  for i, metric in ipairs(schema._metrics) do
    -- NOTE: why we need to device by time_step ? is MEAN+GROUP BY TIME bugged?
    if data_type == ts_common.metrics.counter then
      metrics[i] = "(DERIVATIVE(MEAN(\"" .. metric .. "\")) / ".. time_step ..") as " .. metric
    else
      metrics[i] = "MEAN(\"".. metric .."\") as " .. metric
    end
  end

  -- NOTE: GROUP BY TIME and FILL do not work well together! Additional zeroes produce non-existent derivative values
  -- Will perform fill manually below
  --[[
  SELECT (DERIVATIVE(MEAN("bytes")) / 60) as bytes
    FROM "iface:ndpi" WHERE protocol='SSL' AND ifid='2'
    AND time >= 1531991910000000000 AND time <= 1532002710000000000
    GROUP BY TIME(60s)
  ]]
  local query = makeSeriesQuery(query_schema, metrics, tags, tstart, tend + unaligned_offset, time_step)

  local url = self.url
  local data = influx_query(url .. "/query?db=".. self.db .."&epoch=s", query, self.username, self.password, options)
  local series, count

  if table.empty(data) then
    series, count = ts_common.fillSeries(schema, tstart + time_step, tend, time_step, options.fill_value)
  else
    -- Note: we are working with intervals because of derivatives. The first interval ends at tstart + time_step
    -- which is the first value returned by InfluxDB
    series, count = influx2Series(schema, tstart + time_step, tend, tags, options, data.series[1], time_step)
  end

  local total_serie = nil
  local stats = nil

  if options.calculate_stats then
    local is_single_serie = (#series == 1)

    if is_single_serie then
      -- optimization
      total_serie = table.clone(series[1].data)
    else
      -- try to inherit label from existing series
      local label = series and series[1] and series[1].label
      total_serie = self:_makeTotalSerie(schema, query_schema, raw_step, tstart + time_step, tend, tags, options, url, time_step, label, unaligned_offset)
    end

    if total_serie then
      stats = ts_common.calculateStatistics(total_serie, time_step, tend - tstart, schema.options.metrics_type)

      if stats.total ~= nil then
        -- override total and average
        local stats_query = "(SELECT ".. table.concat(schema._metrics, " + ") .. ' AS value FROM ' .. query_schema ..
          ' ' ..getWhereClause(tags, tstart, tend, unaligned_offset) .. ")"
        stats_query = "(SELECT NON_NEGATIVE_DIFFERENCE(value) as value FROM " .. stats_query .. ")"
        stats_query = "SELECT SUM(value) FROM " .. stats_query

        stats = table.merge(stats, self:_performStatsQuery(stats_query, tstart, tend))
      end
    end
  end

  if options.initial_point then
    local initial_metrics = {}

    for idx, metric in ipairs(schema._metrics) do
      initial_metrics[idx] = "FIRST(" .. metric .. ")"
    end

    local query = makeSeriesQuery(query_schema, metrics, tags, tstart-time_step, tstart+unaligned_offset, time_step)
    local data = influx_query(url .. "/query?db=".. self.db .."&epoch=s", query, self.username, self.password, options)

    if table.empty(data) then
      -- Data fill
      for _, serie in pairs(series) do
        table.insert(serie.data, 1, options.fill_value)
      end
    else
      local values = data.series[1].values[1]
      for i=2, #values do
        local max_val = ts_common.getMaxPointValue(schema, series[i-1].label, tags)
        local val = ts_common.normalizeVal(values[i], max_val, options)
        table.insert(series[i-1].data, 1, val)
      end
    end

    if total_serie then
      local label = series and series[1].label
      local additional_pt = self:_makeTotalSerie(schema, query_schema, raw_step, tstart-time_step, tstart, tags, options, url, time_step, label, unaligned_offset) or {options.fill_value}
      table.insert(total_serie, 1, additional_pt[1])
    end

    count = count + 1
  end

  if options.calculate_stats and total_serie then
    stats = table.merge(stats, ts_common.calculateMinMax(total_serie))
  end

  local rv = {
    start = tstart,
    step = time_step,
    raw_step = raw_step,
    count = count,
    series = series,
    statistics = stats,
    source_aggregation = retention_policy or "raw",
    additional_series = {
      total = total_serie,
    },
  }

  return rv
end

-- ##############################################

function driver:_exportErrorMsg(ret)
  local err_msg = i18n("delete_data.msg_err_unknown")
  local suffix = ""

  if ret ~= nil then
    if ret.error_msg ~= nil then
      err_msg = ret.error_msg .. "."
    elseif ret.CONTENT ~= nil then
      local content = json.decode(ret.CONTENT)

      if((content ~= nil) and (content.error ~= nil)) then
        err_msg = content.error

        if string.find(err_msg, "max-values-per-tag limit exceeded", nil, true) ~= nil then
          suffix = ". " .. i18n("alert_messages.influxdb_partial_write")
        end
      elseif ret.RESPONSE_CODE ~= nil then
        err_msg = err_msg .. " [" .. ret.RESPONSE_CODE .. "]"
      end
    elseif ret.RESPONSE_CODE ~= nil then
        err_msg = err_msg .. " [" .. ret.RESPONSE_CODE .. "]"
    end
  end

  return i18n("alert_messages.influxdb_write_error", {influxdb=self.url, err=err_msg}) .. suffix
end

function driver:_exportTsFile(fname)
  if not ntop.exists(fname) then
    return nil
  end

  -- Delete the file after POST
  local delete_file_after_post = true
  local ret = ntop.postHTTPTextFile(self.username, self.password, self.url .. "/write?db=" .. self.db, fname, delete_file_after_post, 5 --[[ timeout ]])

  if((ret == nil) or ((ret.RESPONSE_CODE ~= 200) and (ret.RESPONSE_CODE ~= 204))) then
    local msg = self:_exportErrorMsg(ret)
    interface.storeAlert(alertEntity("influx_db"), self.url, alertType("influxdb_export_failure"), alertSeverity("error"), msg)

     --delete the file manually
    os.remove(fname)
    return nil
  end

  return ret
end

function driver:export()
  while(true) do
    local name_id = ntop.lpopCache("ntopng.influx_file_queue")
    local ret

    if((name_id == nil) or (name_id == "")) then
      break
    end

    local parts = split(name_id, "|")
    local ifid = tonumber(parts[1])
    local time_ref = tonumber(parts[2])
    local export_id = tonumber(parts[3])

    if((ifid == nil) or (time_ref == nil) or (export_id == nil)) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid name "..name_id.."\n")
      break
    end

    local time_key = "ntopng.cache.influxdb_export_time_" .. self.db .. "_" .. ifid
    local prev_t = tonumber(ntop.getCache(time_key)) or 0
    local fname = os_utils.fixPath(dirs.workingdir .. "/" .. ifid .. "/ts_export/" .. export_id .. "_" .. time_ref)

    --local t = os.time()
    ret = self:_exportTsFile(fname)

    if ret == nil then
      break
    end

    -- Successfully exported
    --tprint("Exported ".. fname .." in " .. (os.time() - t) .. " sec")
    ntop.setCache(time_key, tostring(math.max(prev_t, time_ref)))
  end
end

-- ##############################################

function driver:getLatestTimestamp(ifid)
  local k = "ntopng.cache.influxdb_export_time_" .. self.db .. "_" .. ifid
  local v = tonumber(ntop.getCache(k))

  if v ~= nil then
    return v
  end

  return os.time()
end

-- ##############################################

function driver:listSeries(schema, tags_filter, wildcard_tags, start_time)
  -- At least 2 values are needed otherwise derivative will return empty
  local min_values = 2
  -- NOTE: do not use getQuerySchema here, otherwise we'll miss series

  -- NOTE: time based query not currently supported on show tags/series, using select
  -- https://github.com/influxdata/influxdb/issues/5668
  --[[
  SELECT * FROM "iface:ndpi_categories"
    WHERE ifid='2' AND time >= 1531981349000000000
    GROUP BY category
    LIMIT 2
  ]]
  local query = 'SELECT * FROM "' .. schema.name .. '" WHERE ' ..
      table.tconcat(tags_filter, "=", " AND ", nil, "'") ..
      ternary(table.empty(tags_filter), "", " AND ") .. " time >= " .. start_time .. "000000000" ..
      ternary(not table.empty(wildcard_tags), " GROUP BY " .. table.concat(wildcard_tags, ","), "") ..
      " LIMIT " .. min_values

  local url = self.url
  local data = influx_query(url .. "/query?db=".. self.db, query, self.username, self.password)

  if table.empty(data) then
    return data
  end

  if table.empty(data.series) then
    return {}
  end

  if table.empty(wildcard_tags) then
    -- Simple "exists" check
    if #data.series[1].values >= min_values then
      return tags_filter
    else
      return {}
    end
  end

  local res = {}

  for _, serie in pairs(data.series) do
    if #serie.values < min_values then
      goto continue
    end

    for _, value in pairs(serie.values) do
      local tags = {}

      for i=2, #value do
        local tag = serie.columns[i]

        -- exclude metrics
        if schema.tags[tag] ~= nil then
          tags[tag] = value[i]
        end
      end

      for key, val in pairs(serie.tags) do
        tags[key] = val
      end

      res[#res + 1] = tags
      break
    end

    ::continue::
  end

  return res
end

-- ##############################################

function getWhereClause(tags, tstart, tend, unaligned_offset)
  return 'WHERE '.. table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= '.. tstart ..'000000000 AND time <= '.. (tend + unaligned_offset) .. "000000000"
end

function driver:topk(schema, tags, tstart, tend, options, top_tags)
  if #top_tags ~= 1 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "InfluxDB driver expects exactly one top tag, " .. #top_tags .. " found")
    return nil
  end

  local top_tag = top_tags[1]
  local retention_policy = getSchemaRetentionPolicy(schema, tstart, tend, options)
  local query_schema, raw_step = retentionPolicyToSchema(schema, retention_policy)

  -- NOTE: this offset is necessary to fix graph edge points when data insertion is not aligned with tstep
  local unaligned_offset = raw_step - 1

  local derivate_metrics = {}
  local sum_metrics = {}
  local all_metrics = table.concat(schema._metrics, ", ")

  for idx, metric in ipairs(schema._metrics) do
    derivate_metrics[idx] = 'NON_NEGATIVE_DIFFERENCE('.. metric .. ') as ' .. metric
    sum_metrics[idx] = 'SUM('.. metric .. ') as ' .. metric
  end

  --[[
    SELECT TOP(value,protocol,10) FROM
      (SELECT SUM(value) AS value FROM
        (SELECT NON_NEGATIVE_DIFFERENCE(value) as value FROM
          (SELECT protocol, (bytes_sent + bytes_rcvd) AS "value" FROM "host:ndpi" WHERE host='192.168.1.1'
            AND ifid='1' AND time >= 1537540320000000000 AND time <= 1537540649000000000)
          GROUP BY protocol)
        GROUP BY protocol)
  ]]
  -- Aggregate into 1 metric and filter
  local base_query = '(SELECT '.. top_tag ..', (' .. table.concat(schema._metrics, " + ") ..') AS "value", '..
      all_metrics .. ' FROM '.. query_schema ..
      ' '.. getWhereClause(tags, tstart, tend, unaligned_offset) ..')'

   -- Calculate difference between counter values
  base_query = '(SELECT NON_NEGATIVE_DIFFERENCE(value) as value, '.. table.concat(derivate_metrics, ", ")  ..
      ' FROM ' .. base_query .. " GROUP BY ".. top_tag ..")"

  -- Sum the traffic
  base_query = '(SELECT SUM(value) AS value, '.. table.concat(sum_metrics, ", ")  ..
      ' FROM '.. base_query .. ' GROUP BY '.. top_tag ..')'

  -- Calculate TOPk
  local query = 'SELECT TOP(value,'.. top_tag ..','.. options.top ..'), '.. all_metrics ..' FROM ' .. base_query

  local url = self.url
  local data = influx_query(url .. "/query?db=".. self.db .."&epoch=s", query, self.username, self.password, options)

  if table.empty(data) then
    return data
  end

  if table.empty(data.series) then
    return {}
  end

  data = data.series[1]

  local res = {}

  for idx, value in pairs(data.values) do
    -- top value
    res[idx] = value[2]
  end

  local sorted = {}

  for idx in pairsByValues(res, rev) do
    local value = data.values[idx]

    if value[2] > 0 then
      local partials = {}

      for idx=4, #value do
        partials[data.columns[idx]] = value[idx]
      end

      sorted[#sorted + 1] = {
        tags = table.merge(tags, {[top_tag] = value[3]}),
        value = value[2],
        partials = partials,
      }
    end
  end

  local time_step = ts_common.calculateSampledTimeStep(raw_step, tstart, tend, options)
  local label = series and series[1].label
  local total_serie = self:_makeTotalSerie(schema, query_schema, raw_step, tstart, tend, tags, options, url, time_step, label, unaligned_offset)
  local stats = nil

  if options.calculate_stats and total_serie then
    stats = ts_common.calculateStatistics(total_serie, time_step, tend - tstart, schema.options.metrics_type)

    if stats.total ~= nil then
      -- override total and average
      -- NOTE: sum must be calculated on individual top_tag fields to avoid
      -- calculating DIFFERENCE on a decreasing serie (e.g. this can happend on a top hosts query
      -- when a previously seen host becomes idle, which causes its traffic contribution on the total to become zero on next points)
      local stats_query = "SELECT SUM(value) as value FROM " .. base_query
      stats = table.merge(stats, self:_performStatsQuery(stats_query, tstart, tend))
    end
  end

  if options.initial_point and total_serie then
    local additional_pt = self:_makeTotalSerie(schema, query_schema, raw_step, tstart-time_step, tstart, tags, options, url, time_step, label, unaligned_offset) or {options.fill_value}
    table.insert(total_serie, 1, additional_pt[1])
  end

  if options.calculate_stats and total_serie then
    stats = table.merge(stats, ts_common.calculateMinMax(total_serie))
  end

  return {
    topk = sorted,
    statistics = stats,
    source_aggregation = retention_policy or "raw",
    additional_series = {
      total = total_serie,
    },
  }
end

-- ##############################################

function driver:queryTotal(schema, tstart, tend, tags, options)
  local data_type = schema.options.metrics_type
  local query_schema = getQuerySchema(schema, tstart, tend, options)
  local query

  if data_type == ts_common.metrics.counter then
    local metrics = {}
    local sum_metrics = {}

    for i, metric in ipairs(schema._metrics) do
      metrics[i] = "NON_NEGATIVE_DIFFERENCE(" .. metric .. ") as " .. metric
      sum_metrics[i] = "SUM(" .. metric .. ") as " .. metric
    end

    -- SELECT SUM("bytes_sent") as "bytes_sent", SUM("bytes_rcvd") as "bytes_rcvd" FROM
    --  (SELECT DIFFERENCE("bytes_sent") AS "bytes_sent", DIFFERENCE("bytes_rcvd") AS "bytes_rcvd"
    --    FROM "host:traffic" WHERE ifid='1' AND host='192.168.1.1' AND time >= 1536321770000000000 AND time <= 1536322070000000000)
    query = 'SELECT ' .. table.concat(sum_metrics, ", ") .. ' FROM ' ..
    '(SELECT ' .. table.concat(metrics, ", ") .. ' FROM '.. query_schema ..' WHERE ' ..
      table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= ' .. tstart .. '000000000 AND time <= ' .. tend .. '000000000)'
  else
    local metrics = {}

    for i, metric in ipairs(schema._metrics) do
      metrics[i] = "SUM(" .. metric .. ") as " .. metric
    end

    query = 'SELECT ' .. table.concat(metrics, ", ") .. ' FROM ' .. query_schema ..' WHERE ' ..
      table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= ' .. tstart .. '000000000 AND time <= ' .. tend .. '000000000'
  end

  local url = self.url
  local data = influx_query(url .. "/query?db=".. self.db .."&epoch=s", query, self.username, self.password, options)

  if table.empty(data) then
    return data
  end

  data = data.series[1]
  local res = {}

  for i=2, #data.columns do
    local metric = data.columns[i]
    local total = data.values[1][i]

    res[metric] = total
  end

  return res
end

-- ##############################################

function driver:queryMean(schema, tags, tstart, tend)
  local metrics = {}
  local query_schema = getQuerySchema(schema, tstart, tend)

  for i, metric in ipairs(schema._metrics) do
    metrics[i] = "MEAN(" .. metric .. ") as " .. metric
  end

  local query = 'SELECT ' .. table.concat(metrics, ", ") .. ' FROM '.. query_schema ..' WHERE ' ..
      table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= ' .. tstart .. '000000000 AND time <= ' .. tend .. '000000000'

  local url = self.url
  local data = influx_query(url .. "/query?db=".. self.db .."&epoch=s", query, self.username, self.password)

  if table.empty(data) then
    return data
  end

  data = data.series[1]
  local res = {}

  for i=2, #data.columns do
    local metric = data.columns[i]
    local average = data.values[1][i]

    res[metric] = average
  end

  return res
end

-- ##############################################

local function getInfluxdbVersion(url, username, password)
  local res = ntop.httpGet(url .. "/ping", username, password, INFLUX_QUERY_TIMEMOUT_SEC, true)
  if not res or ((res.RESPONSE_CODE ~= 200) and (res.RESPONSE_CODE ~= 204)) then
    local err = i18n("prefs.could_not_contact_influxdb", {msg=getResponseError(res)})

    traceError(TRACE_ERROR, TRACE_CONSOLE, err)
    return nil, err
  end

  local content = res.CONTENT or ""
  return string.match(content, "\nX%-Influxdb%-Version: ([%d|%.]+)")
end

function driver:getInfluxdbVersion()
  return getInfluxdbVersion(self.url, self.username, self.password)
end

-- ##############################################

function driver:getDiskUsage()
  local query = 'select SUM(last) FROM (select LAST(diskBytes) FROM "monitor"."shard" where "database" = \''.. self.db ..'\' group by id)'
  local data = influx_query(self.url .. "/query?db=_internal", query, self.username, self.password)

  if data and data.series[1] and data.series[1].values[1] then
    return data.series[1].values[1][2]
  end

  return nil
end

-- ##############################################

local function toVersion(version_str)
  local parts = string.split(version_str, "%.")

  if (#parts ~= 3) then
    return nil
  end

  return {
    major = tonumber(parts[1]) or 0,
    minor = tonumber(parts[2]) or 0,
    patch = tonumber(parts[3]) or 0,
  }
end

local function isCompatibleVersion(version)
  local current = toVersion(version)
  local required = toVersion(MIN_INFLUXDB_SUPPORTED_VERSION)

  if (version == nil) or (required == nil) then
    return false
  end

  return (current.major == required.major) and
    ((current.minor > required.minor) or
      ((current.minor == required.minor) and (current.patch >= required.patch)))
end

function driver.init(dbname, url, days_retention, username, password, verbose)
  local timeout = INFLUX_QUERY_TIMEMOUT_SEC

  -- Check version
  if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "Contacting influxdb at " .. url .. " ...") end

  local version = getInfluxdbVersion(url, username, password)

  if not version or not isCompatibleVersion(version) then
    local err = i18n("prefs.incompatible_influxdb_version",
      {required=MIN_INFLUXDB_SUPPORTED_VERSION, found=version})

    traceError(TRACE_ERROR, TRACE_CONSOLE, err)
    return false, err
  end

  -- Check existing database (this is used to prevent db creationg error for unprivileged users)
  if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "Checking database " .. dbname .. " ...") end
  local query = "SHOW DATABASES"
  local res = ntop.httpPost(url .. "/query", "q=" .. query, username, password, timeout, true)
  local db_found = false

  if res and (res.RESPONSE_CODE == 200) and res.CONTENT then
    local reply = json.decode(res.CONTENT)

    if reply and reply.results and reply.results[1] and reply.results[1].series then
      local dbs = reply.results[1].series[1] or {values={}}

      for _, row in pairs(dbs.values) do
        local user_db = row[1]

        if user_db == dbname then
          db_found = true
          break
        end
      end
    end
  end

  if not db_found then
    -- Create database
    if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "Creating database " .. dbname .. " ...") end
    local query = "CREATE DATABASE \"" .. dbname .. "\""

    local res = ntop.httpPost(url .. "/query", "q=" .. query, username, password, timeout, true)
    if not res or (res.RESPONSE_CODE ~= 200) then
      local err = i18n("prefs.influxdb_create_error", {db=dbname, msg=getResponseError(res)})

      traceError(TRACE_ERROR, TRACE_CONSOLE, err)
      return false, err
    end
  end

  -- Set retention
  if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "Setting retention for " .. dbname .. " ...") end
  local query = "ALTER RETENTION POLICY autogen ON \"".. dbname .."\" DURATION ".. days_retention .."d"

  local res = ntop.httpPost(url .. "/query", "q=" .. query, username, password, timeout, true)
  if not res or (res.RESPONSE_CODE ~= 200) then
    local warning = i18n("prefs.influxdb_retention_error", {db=dbname, msg=getResponseError(res)})

    traceError(TRACE_WARNING, TRACE_CONSOLE, warning)
    -- This is just a warning, we can proceed
    --return false, err
  end

  return true, i18n("prefs.successfully_connected_influxdb", {db=dbname, version=version})
end

-- ##############################################

function driver:delete(schema_prefix, tags)
  local url = self.url
  local measurement_pattern = ternary(schema_prefix == "", '//', '/^'.. schema_prefix ..':/')
  local query = 'DELETE FROM '.. measurement_pattern
  if not table.empty(tags) then
    query = query .. ' WHERE ' .. table.tconcat(tags, "=", " AND ", nil, "'")
  end
  local full_url = url .. "/query?db=".. self.db .."&q=" .. urlencode(query)

  local res = ntop.httpGet(full_url, self.username, self.password, INFLUX_QUERY_TIMEMOUT_SEC, true)

  if not res or (res.RESPONSE_CODE ~= 200) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, getResponseError(res))
    return false
  end

  return true
end

-- ##############################################

function driver:deleteOldData(ifid)
  -- NOTE: retention is perfomed automatically based on the database retention policy,
  -- no need for manual intervention
  return true
end

-- ##############################################

function driver:_multiQuery(queries)
  local query_str = table.concat(queries, ";")
  local res = ntop.httpPost(self.url .. "/query", "q=" .. urlencode(query_str), self.username, self.password, INFLUX_QUERY_TIMEMOUT_SEC, true)

  if not res then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid response for query: " .. query_str)
    return false
  end

  if res.RESPONSE_CODE ~= 200 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad response code[" .. res.RESPONSE_CODE .. "]: " .. getResponseError(res))
    --tprint(query_str)
    return false
  end

  local err = getResponseError(res)
  if err ~= 200 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Unexpected query error: " .. err)
    return false
  end

  return true
end

-- ##############################################

local function getCqQuery(dbname, metrics, tags, schema, source, dest, resemple)
  local cq_name = string.format("%s__%s", schema.name, dest)
  local resemple_s = ""

  if resemple then
    resemple_s = "RESAMPLE FOR " .. resemple
  end

  return string.format([[
    CREATE CONTINUOUS QUERY "%s" ON %s
    %s
    BEGIN
      SELECT
        %s
        INTO "%s"."%s"
        FROM (
          SELECT
            %s
            FROM "%s"."%s"
            GROUP BY time(%us),%s
            FILL(0)
        ) GROUP BY time(%s),%s
    END]], cq_name, dbname, resemple_s,
    metrics, dest, schema.name,
    metrics, source, schema.name,
    schema.options.step, tags, dest, tags)
end

function driver:setup(ts_utils)
  local queries = {}
  local max_batch_size = 25 -- note: each query is about 400 characters

  queries[#queries + 1] = string.format('CREATE RETENTION POLICY "1h" ON %s DURATION %s REPLICATION 1', self.db, RP_1H_DURATION)
  queries[#queries + 1] = string.format('CREATE RETENTION POLICY "1d" ON %s DURATION %s REPLICATION 1', self.db, RP_1D_DURATION)

  ts_utils.loadSchemas()
  local schemas = ts_utils.getLoadedSchemas()

  for _, schema in pairs(schemas) do
    local tags = table.concat(schema._tags, ",")
    local metrics = {}
    for _, metric in ipairs(schema._metrics) do
      metrics[#metrics + 1] = string.format('MEAN(%s) as %s', metric, metric)
    end

    if #metrics == 0 then
      goto continue
    end
    metrics = table.concat(metrics, ",")

    local cq_1h = getCqQuery(self.db, metrics, tags, schema, "autogen", "1h", "2h")
    local cq_1d = getCqQuery(self.db, metrics, tags, schema, "1h", "1d")

    -- TODO temporary fix to alter existing queries, remove after beta end
    queries[#queries + 1] = string.format('DROP CONTINUOUS QUERY "%s__1d" ON %s', schema.name, self.db)

    queries[#queries + 1] = cq_1h:gsub("\n", ""):gsub("%s%s+", " ")
    queries[#queries + 1] = cq_1d:gsub("\n", ""):gsub("%s%s+", " ")

    if #queries >= max_batch_size then
      if not self:_multiQuery(queries) then
        traceError(TRACE_ERROR, TRACE_CONSOLE, "InfluxDB setup failed")
        return false
      end
      queries = {}
    end

    ::continue::
  end

  if #queries >= 0 then
    if not self:_multiQuery(queries) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "InfluxDB setup() failed")
      return false
    end
  end

  if tonumber(ntop.getPref(FIRST_AGGREGATION_TIME_KEY)) == nil then
    local res = influx_query(self.url .. "/query?db=".. self.db .."&epoch=s",
      'SELECT FIRST(bytes) FROM "1h"."iface:traffic"', self.username, self.password)
    local first_t = os.time()

    if res and res.series and res.series[1].values then
      local v = res.series[1].values[1][1]

      if v ~= nil then
        first_t = v
      end
    end

    ntop.setPref(FIRST_AGGREGATION_TIME_KEY, tostring(first_t))
  end

  return true
end

-- ##############################################

return driver
