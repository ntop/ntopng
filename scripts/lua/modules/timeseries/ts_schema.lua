--
-- (C) 2021 - ntop.org
--

local ts_schema = {}
local ts_common = require("ts_common")

-- NOTE: to get the actual rentention period, multiply retention_dp * aggregation_dp * step
ts_schema.supported_steps = {
  ["1"] = {
    retention = {
      -- aggregation_dp: number of raw points to aggregate
      -- retention_dp: number of aggregated dp to store
      {aggregation_dp = 1, retention_dp = 86400},   -- 1 second resolution: keep for 1 day
      {aggregation_dp = 60, retention_dp = 43200},  -- 1 minute resolution: keep for 1 month
      {aggregation_dp = 3600, retention_dp = 2400}, -- 1 hour resolution: keep for 100 days
    }, hwpredict = {
      row_count = 86400,  -- keep 1 day prediction
      period = 3600,      -- assume 1 hour periodicity
    }
  },
  ["5"] = {
    retention = {
      -- aggregation_dp: number of raw points to aggregate
      -- retention_dp: number of aggregated dp to store
      {aggregation_dp = 1, retention_dp = 86400},   -- 1 second resolution: keep for 1 day
      {aggregation_dp = 12, retention_dp = 43200},  -- 1 minute resolution: keep for 1 month
      {aggregation_dp = 720, retention_dp = 2400}, -- 1 hour resolution: keep for 100 days
    }, hwpredict = {
      row_count = 86400,  -- keep 1 day prediction
      period = 3600,      -- assume 1 hour periodicity
    }
  },
  ["60"] = {
    retention = {
      {aggregation_dp = 1, retention_dp = 1440},    -- 1 minute resolution: keep for 1 day
      {aggregation_dp = 60, retention_dp = 2400},   -- 1 hour resolution: keep for 100 days
      {aggregation_dp = 1440, retention_dp = 365},  -- 1 day resolution: keep for 1 year
    }, hwpredict = {
      row_count = 10080,  -- keep 1 week prediction
      period = 1440,      -- assume 1 day periodicity
    }
  },
  ["300"] = {
    retention = {
      {aggregation_dp = 1, retention_dp = 288},     -- 5 minute resolution: keep for 1 day
      {aggregation_dp = 12, retention_dp = 2400},   -- 1 hour resolution: keep for 100 days
      {aggregation_dp = 288, retention_dp = 365},   -- 1 day resolution: keep for 1 year
    }, hwpredict = {
      row_count = 2016,  -- keep 1 week prediction
      period = 288,      -- assume 1 day periodicity
    }
  },
  ["3600"] = {
    retention = {
      {aggregation_dp = 1, retention_dp = 720},     -- 1 hour resolution: keep for 1 month
      {aggregation_dp = 24, retention_dp = 365},    -- 1 day resolution: keep for 1 year
    }
  }
}

function ts_schema:new(name, options)
  options = options or {}
  options.metrics_type = options.metrics_type or ts_common.metrics.counter
  --options.is_critical_ts : if true, this timeseries should be written even if ntop.isDeadlineApproaching()

  -- required options
  if not options.step then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "missing step option in schema " .. name)
    return nil
  end

  local obj = {name=name, options=options, _tags={}, _metrics={}, tags={}, metrics={}}
  local step_info = ts_schema.supported_steps[tostring(options.step)]

  if step_info ~= nil then
    -- add retention policy and other informations
    for k, v in pairs(step_info) do
      obj[k] = v
    end
  end

  setmetatable(obj, self)
  self.__index = self

  return obj
end

local function validateTagMetric(name)
  if(name == "measurement") then
    --[[
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Invalid tag/measurement name: \"%s\"", name))
    tprint(debug.traceback())
    ]]
    return(false)
  end

  return(true)
end

function ts_schema:addTag(name)
  if not validateTagMetric(name) then
    return
  end

  if self.tags[name] == nil then
    self._tags[#self._tags + 1] = name
    self.tags[name] = 1
  end
end

function ts_schema:addMetric(name)
  if not validateTagMetric(name) then
    return
  end

  if self.metrics[name] == nil then
    self._metrics[#self._metrics + 1] = name
    self.metrics[name] = 1
  end
end

function ts_schema:allTagsDefined(tags)
  for tag in pairs(self.tags) do
    if tags[tag] == nil then
      return false, tag
    end
  end

  return true
end

function ts_schema:verifyTags(tags)
  local actual_tags = {}

  local all_defined, missing_tag = self:allTagsDefined(tags)

  if not all_defined then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "missing tag '" .. missing_tag .. "' in schema " .. self.name)
    return nil
  end

  for tag in pairs(tags) do
    if self.tags[tag] == nil then
      -- NOTE: just ignore the additional tags
      --traceError(TRACE_ERROR, TRACE_CONSOLE, "unknown tag '" .. tag .. "' in schema " .. self.name)
      --return false
    else
      actual_tags[tag] = tags[tag]
    end
  end

  return actual_tags
end

function ts_schema:verifyTagsAndMetrics(tags_and_metrics)
  local tags = {}
  local metrics = {}

  for tag in pairs(self.tags) do
    if tags_and_metrics[tag] == nil then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing mandatory tag '" .. tag .. "' while using schema " .. self.name)
      return nil
    end

    tags[tag] = tags_and_metrics[tag]
  end


  for metric in pairs(self.metrics) do
    if tags_and_metrics[metric] == nil then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing mandatory metric '" .. metric .. "' while using schema " .. self.name)
      return nil
    end

    metrics[metric] = tags_and_metrics[metric]
  end

  for item in pairs(tags_and_metrics) do
    if((self.tags[item] == nil) and (self.metrics[item] == nil))then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "unknown tag/metric '" .. item .. "' in schema " .. self.name)
      return nil
    end
  end

  -- NOTE: the ifid tag is required in order to identify all the ts of
  -- a given interface (also for the system interface). This is required in
  -- order to properly delete them from "Manage Data".
  if(tags.ifid == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "An 'ifid' tag is required in schema " .. self.name)
    return nil
  end

  return tags, metrics
end

function ts_schema:getAggregationFunction()
  local fn = self.options.aggregation_function

  if((fn ~= nil) and (ts_common.aggregation[fn] ~= nil)) then
    return(fn)
  end

  -- fallback
  return(ts_common.aggregation.mean)
end

return ts_schema
