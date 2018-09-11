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
  local tags_string = table.tconcat(tags, "=", ",")
  local metrics_string = table.tconcat(metrics, "=", ",")

  -- E.g. iface:ndpi_categories,category=Network,ifid=0 bytes=371707
  -- NB: time format is in nanoseconds UTC
  local api_line = schema.name .. "," .. tags_string .. " " .. metrics_string .. " " .. timestamp .. "000000000\n"

  return ntop.appendInfluxDB(api_line)
end

-- ##############################################

local function getResponseError(res)
  if res.CONTENT and res.CONTENT_TYPE == "application/json" then
    local jres = json.decode(res.CONTENT)

    if jres and jres.error then
      if res.RESPONSE_CODE then
        return "[".. res.RESPONSE_CODE .. "] " ..jres.error
      else
        return jres.error
      end
    end
  end

  return res.RESPONSE_CODE or "unknown error"
end

-- ##############################################

local function influx_query(full_url, username, password)
  local res = ntop.httpGet(full_url, username, password, INFLUX_QUERY_TIMEMOUT_SEC, true)

  if not res then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid response for query: " .. full_url)
    return nil
  end

  if res.RESPONSE_CODE ~= 200 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad response code[" .. res.RESPONSE_CODE .. "]: " .. (res.CONTENT or ""))
    return nil
  end

  if res.CONTENT == nil then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing content")
    return nil
  end

  local jres = json.decode(res.CONTENT)

  if (not jres) or (not jres.results) or (not #jres.results) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid JSON reply[" .. res.CONTENT_LEN .. " bytes]: " .. string.sub(res.CONTENT, 1, 50))
    return nil
  end

  if not jres.results[1].series then
    -- no results fount
    return nil
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

local function getTotalSerieQuery(schema, tstart, tend, tags, time_step, data_type, label)
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
  local query = 'SELECT SUM("value") AS "'.. label ..'" FROM ' ..
    '(SELECT (' .. table.concat(schema._metrics, " + ") ..') AS "value" FROM "'.. schema.name ..'" WHERE ' ..
    table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= ' .. tstart .. '000000000 AND time <= ' .. tend .. '000000000)'..
    ' GROUP BY time('.. schema.options.step ..'s)'

  if time_step and (schema.options.step ~= time_step) then
    -- sample the points
    query = 'SELECT MEAN("'.. label ..'") AS "'.. label ..'" FROM ('.. query ..') GROUP BY time('.. time_step ..'s)'
  end

  if data_type == ts_common.metrics.counter then
    query = "SELECT NON_NEGATIVE_DERIVATIVE(".. label ..") AS ".. label .." FROM (" .. query .. ")"
  end

  return query
end

-- ##############################################

function driver:_makeTotalSerie(schema, tstart, tend, tags, options, url, time_step, label)
  local data_type = schema.options.metrics_type
  local query = getTotalSerieQuery(schema, tstart, tend, tags, time_step, data_type, label)

  local full_url = url .. "/query?db=".. self.db .."&epoch=s&q=" .. urlencode(query)
  local data = influx_query(full_url, self.username, self.password)

  if not data then
    return nil
  end

  data = data.series[1]

  local series, count = influx2Series(schema, tstart + time_step, tend, tags, options, data, time_step)
  return series[1].data
end

-- ##############################################

-- NOTE: mean / percentile values are calculated manually because of an issue with
-- empty points in the queries https://github.com/influxdata/influxdb/issues/6967
function driver:_calcStats(schema, tstart, tend, tags, url, total_serie, time_step, label)
  local stats = ts_common.calculateStatistics(total_serie, time_step, tend - tstart, schema.options.metrics_type)

  if time_step ~= schema.options.step then
    -- NOTE: the total must be manually extracted from influx when sampling occurs
    local data_type = schema.options.metrics_type
    local query = getTotalSerieQuery(schema, tstart, tend, tags, nil --[[ important: no sampling ]], data_type, label)
    query = 'SELECT SUM("'.. (label or "total_serie") ..'") * ' .. schema.options.step ..' FROM (' .. query .. ')'

    local full_url = url .. "/query?db=".. self.db .."&epoch=s&q=" .. urlencode(query)
    local data = influx_query(full_url, self.username, self.password)

    if (data and data.series and data.series[1] and data.series[1].values[1]) then
      local data_stats = data.series[1].values[1]
      local total = data_stats[2]

      if stats.total then
        -- only overwrite it if previously set
        stats.total = total
      end

      stats.average = total / (tend - tstart)
    end
  end

  return stats
end

-- ##############################################

function calculateSampledTimeStep(schema, tstart, tend, options)
  local estimed_num_points = math.ceil((tend - tstart) / schema.options.step)
  local time_step = schema.options.step

  if estimed_num_points > options.max_num_points then
    -- downsample
    local num_samples = math.ceil(estimed_num_points / options.max_num_points)
    time_step = num_samples * schema.options.step
  end

  return time_step
end

-- ##############################################

local function makeSeriesQuery(schema, metrics, tags, tstart, tend, time_step)
  return 'SELECT '.. table.concat(metrics, ",") ..' FROM "' .. schema.name .. '" WHERE ' ..
      table.tconcat(tags, "=", " AND ", nil, "'") .. " AND time >= " .. tstart .. "000000000 AND time <= " .. tend .. "000000000" ..
      " GROUP BY TIME(".. time_step .."s)"
end

function driver:query(schema, tstart, tend, tags, options)
  local metrics = {}
  local time_step = calculateSampledTimeStep(schema, tstart, tend, options)
  local data_type = schema.options.metrics_type

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
  local query = makeSeriesQuery(schema, metrics, tags, tstart, tend, time_step)

  local url = self.url
  local full_url = url .. "/query?db=".. self.db .."&epoch=s&q=" .. urlencode(query)
  local data = influx_query(full_url, self.username, self.password)

  if not data then
    return nil
  end

  -- Note: we are working with intervals because of derivatives. The first interval ends at tstart + time_step
  -- which is the first value returned by InfluxDB
  local series, count = influx2Series(schema, tstart + time_step, tend, tags, options, data.series[1], time_step)
  local total_serie = nil
  local stats = nil

  if options.calculate_stats then
    -- try to inherit label from existing series
    local label = series and series[1].label
    total_serie = self:_makeTotalSerie(schema, tstart, tend, tags, options, url, time_step, label)

    if total_serie then
      stats = self:_calcStats(schema, tstart, tend, tags, url, total_serie, time_step, label)
    end
  end

  if options.initial_point then
    local initial_metrics = {}

    for idx, metric in ipairs(schema._metrics) do
      initial_metrics[idx] = "FIRST(" .. metric .. ")"
    end

    local query = makeSeriesQuery(schema, metrics, tags, tstart-time_step, tstart, time_step)
    local full_url = url .. "/query?db=".. self.db .."&epoch=s&q=" .. urlencode(query)

    local data = influx_query(full_url, self.username, self.password)

    if not data then
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
      local additional_pt = self:_makeTotalSerie(schema, tstart-time_step, tstart, tags, options, url, time_step, label) or {options.fill_value}
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
    count = count,
    series = series,
    statistics = stats,
    additional_series = {
      total = total_serie,
    },
  }

  return rv
end

-- ##############################################

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

    -- Delete the file after POST
    local delete_file_after_post = true

    local t = os.time()
    ret = ntop.postHTTPTextFile(self.username, self.password, self.url .. "/write?db=" .. self.db, fname, delete_file_after_post, 5 --[[ timeout ]])

    if(ret ~= true) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "POST of "..fname.." failed\n")

      -- delete the file manually
      os.remove(fname)
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
      " AND time >= " .. start_time .. "000000000" ..
      ternary(not table.empty(wildcard_tags), " GROUP BY " .. table.concat(wildcard_tags, ","), "") ..
      " LIMIT " .. min_values

  local url = self.url
  local full_url = url .. "/query?db=".. self.db .."&q=" .. urlencode(query)
  local data = influx_query(full_url, self.username, self.password)

  if not data then
    return nil
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

function driver:topk(schema, tags, tstart, tend, options, top_tags)
  if #top_tags ~= 1 then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "InfluxDB driver expects exactly one top tag, " .. #top_tags .. " found")
    return nil
  end

  local top_tag = top_tags[1]

  --[[
  SELECT TOP("value", "protocol", 10) FROM                                      // select top 10 protocols
    (SELECT protocol, (bytes_sent + bytes_rcvd) AS "value"                      // possibly sum multiple metrics within same serie
      FROM "host:ndpi" WHERE host='192.168.43.18' AND ifid='2'
      AND time >= 1531986825000000000 AND time <= 1531994776000000000)
  ]]
  local query = 'SELECT TOP("value", "'.. top_tag ..'", '.. options.top ..') FROM (SELECT '.. top_tag ..
      ', (' .. table.concat(schema._metrics, " + ") ..') AS "value" FROM "'.. schema.name ..'" WHERE '..
      table.tconcat(tags, "=", " AND ", nil, "'") .. ' AND time >= '.. tstart ..'000000000 AND time <= '.. tend ..'000000000)'
  local url = self.url
  local full_url = url .. "/query?db=".. self.db .."&epoch=s&q=" .. urlencode(query)

  local data = influx_query(full_url, self.username, self.password)

  if not data then
    return nil
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

    sorted[#sorted + 1] = {
      tags = table.merge(tags, {[top_tag] = value[3]}),
      value = value[2],
    }
  end

  local time_step = calculateSampledTimeStep(schema, tstart, tend, options)
  local label = series and series[1].label
  local total_serie = self:_makeTotalSerie(schema, tstart, tend, tags, options, url, time_step, label)
  local stats = nil

  if options.calculate_stats and total_serie then
    stats = self:_calcStats(schema, tstart, tend, tags, url, total_serie, time_step, label)
  end

  if options.initial_point and total_serie then
    local additional_pt = self:_makeTotalSerie(schema, tstart-time_step, tstart, tags, options, url, time_step, label) or {options.fill_value}
    table.insert(total_serie, 1, additional_pt[1])
  end

  if options.calculate_stats and total_serie then
    stats = table.merge(stats, ts_common.calculateMinMax(total_serie))
  end

  return {
    topk = sorted,
    statistics = stats,
     additional_series = {
      total = total_serie,
    },
  }
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

  local res = ntop.httpGet(url .. "/ping", username, password, INFLUX_QUERY_TIMEMOUT_SEC, true)
  if not res or ((res.RESPONSE_CODE ~= 200) and (res.RESPONSE_CODE ~= 204)) then
    local err = i18n("prefs.could_not_contact_influxdb", {msg=getResponseError(res)})

    traceError(TRACE_ERROR, TRACE_CONSOLE, err)
    return false, err
  end

  local content = res.CONTENT or ""
  local version = string.match(content, "\nX%-Influxdb%-Version: ([%d|%.]+)")

  if not version or not isCompatibleVersion(version) then
    local err = i18n("prefs.incompatible_influxdb_version",
      {required=MIN_INFLUXDB_SUPPORTED_VERSION, found=version})

    traceError(TRACE_ERROR, TRACE_CONSOLE, err)
    return false, err
  end

  -- Create database
  if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "Creating database " .. dbname .. " ...") end
  local query = "CREATE DATABASE \"" .. dbname .. "\""

  local res = ntop.httpPost(url .. "/query", "q=" .. query, username, password, timeout, true)
  if not res or (res.RESPONSE_CODE ~= 200) then
    local err = i18n("prefs.influxdb_create_error", {db=dbname, msg=getResponseError(res)})

    traceError(TRACE_ERROR, TRACE_CONSOLE, err)
    return false, err
  end

  -- Set retention
  if verbose then traceError(TRACE_NORMAL, TRACE_CONSOLE, "Setting retention for " .. dbname .. " ...") end
  local query = "ALTER RETENTION POLICY autogen ON \"".. dbname .."\" DURATION ".. days_retention .."d"

  local res = ntop.httpPost(url .. "/query", "q=" .. query, username, password, timeout, true)
  if not res or (res.RESPONSE_CODE ~= 200) then
    local err = i18n("prefs.influxdb_retention_error", {db=dbname, msg=getResponseError(res)})

    traceError(TRACE_ERROR, TRACE_CONSOLE, err)
    return false, err
  end

  return true, i18n("prefs.successfully_connected_influxdb", {db=dbname, version=version})
end

-- ##############################################

return driver
