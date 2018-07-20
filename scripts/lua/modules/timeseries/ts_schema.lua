--
-- (C) 2018 - ntop.org
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
}

function ts_schema:new(name, options)
  options = options or {}
  options.metrics_type = options.metrics_type or ts_common.metrics.counter

  -- required options
  if not options.step then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "missing step option in schema " .. name)
    return nil
  end

  local step_info = ts_schema.supported_steps[tostring(options.step)]

  if not step_info then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "missing step option in schema " .. name)
    return nil
  end

  local obj = {name=name, options=options, _tags={}, _metrics={}, tags={}, metrics={}}

  -- add retention policy and other informations
  for k, v in pairs(step_info) do
    obj[k] = v
  end

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function ts_schema:addTag(name)
  self._tags[#self._tags + 1] = name
  self.tags[name] = 1
end

function ts_schema:addMetric(name)
  self._metrics[#self._metrics + 1] = name
  self.metrics[name] = 1
end

function ts_schema:verifyTags(tags)
  for tag in pairs(self.tags) do
    if not tags[tag] then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "missing tag '" .. tag .. "' in schema " .. self.name)
      return false
    end
  end

  for tag in pairs(tags) do
    if not self.tags[tag] then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "unknown tag '" .. tag .. "' in schema " .. self.name)
      return false
    end
  end

  return true
end

function ts_schema:verifyTagsAndMetrics(tags_and_metrics)
  local tags = {}
  local metrics = {}

  for tag in pairs(self.tags) do
    if not tags_and_metrics[tag] then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "missing tag '" .. tag .. "' in schema " .. self.name)
      return nil
    end

    tags[tag] = tags_and_metrics[tag]
  end

  for metric in pairs(self.metrics) do
    if not tags_and_metrics[metric] then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "missing metric '" .. metric .. "' in schema " .. self.name)
      return nil
    end

    metrics[metric] = tags_and_metrics[metric]
  end

  for item in pairs(tags_and_metrics) do
    if not self.tags[item] and not self.metrics[item] then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "unknown tag/metric '" .. item .. "' in schema " .. self.name)
      return nil
    end
  end

  return tags, metrics
end

return ts_schema
