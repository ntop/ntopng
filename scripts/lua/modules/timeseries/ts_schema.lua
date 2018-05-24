--
-- (C) 2018 - ntop.org
--

local ts_schema = {}

function ts_schema:new(name, options)
  options = options or {}

  -- required options
  if not options.step then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "missing step option in schema " .. name)
    return nil
  end

  local obj = {name=name, options=options, _tags={}, _metrics={}, tags={}, metrics={}}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

function ts_schema:addTag(name)
  self._tags[#self._tags + 1] = name
  self.tags[name] = 1
end

-- metric_type: a type in ts_utils.metrics
function ts_schema:addMetric(name, metric_type)
  self._metrics[#self._metrics + 1] = name
  self.metrics[name] = {["type"]=metric_type}
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
