--
-- (C) 2017 - ntop.org
--

local ts_common = {}

-- ##############################################

ts_common.metrics = {}
ts_common.metrics.counter = "counter"
ts_common.metrics.gauge = "gauge"
ts_common.metrics.derivative = "derivative"

ts_common.aggregation = {}
ts_common.aggregation.mean = "mean"
ts_common.aggregation.max = "max"
ts_common.aggregation.min = "min"
ts_common.aggregation.last = "last"

-- ##############################################

-- Find the percentile of a list of values
-- N - A list of values.  N must be sorted.
-- P - A float value from 0.0 to 1.0
local function percentile(N, P)
  local n = math.floor(math.floor(P * #N + 0.5))
  return(N[n-1])
end

function ts_common.ninetififthPercentile(serie)
  if #serie <= 1 then
    return serie[1]
  end

  N = table.clone(serie)
  table.sort(N) -- <<== Sort first
  return(percentile(N, 0.95))
end

-- ##############################################

function ts_common.calculateMinMax(total_serie)
  local min_val, max_val
  local min_val_pt, max_val_pt

  for idx, val in pairs(total_serie) do
    if (min_val_pt == nil) or (val < min_val) then
      min_val = val
      min_val_pt = idx - 1
    end
    if (max_val_pt == nil) or (val > max_val) then
      max_val = val
      max_val_pt = idx - 1
    end
  end

  return {
    min_val = min_val,
    max_val = max_val,
    min_val_idx = min_val_pt,
    max_val_idx = max_val_pt,
  }
end

-- ##############################################

function ts_common.calculateStatistics(total_serie, step, tdiff, data_type)
  local total = 0
  local pt_sum = 0

  for idx, val in pairs(total_serie) do
    -- integrate
    total = total + val * step
    pt_sum = pt_sum + val
  end

  local avg = pt_sum / #total_serie

  if data_type == ts_common.metrics.gauge then
    -- no total for gauge values!
    total = nil
  end

  return {
    total = total,
    average = avg,
    ["95th_percentile"] = ts_common.ninetififthPercentile(total_serie),
  }
end

-- ##############################################

-- NOTE: this corresponds to graph_utils interpolateSerie
-- This is approximate.
-- Aproximate means it doesn't adjust the step.
-- TODO: take as input and adjust the step as well.
function ts_common.upsampleSerie(serie, num_points)
  if num_points <= #serie then
    return serie
  end

  local res = {}
  local intervals = num_points / #serie;

  local lerp = function(v0, v1, t)
    return (1 - t) * v0 + t * v1
  end

  if #serie == 0 then
    return res
  end

  for i=1,num_points do
    local index = (i-1) / (intervals)
    local _, t = math.modf(index)
    local prev_i = math.floor(index)
    local next_i = math.min(math.ceil(index), #serie - 1)

    local v = lerp(serie[prev_i+1], serie[next_i+1], t)
    res[i] = v
  end

  return res
end

-- ##############################################

-- If a point value exceeds this value, it should be discarded as invalid
function ts_common.getMaxPointValue(schema, metric, tags)
  if tags.ifid ~= nil then
    if string.contains(metric, "bytes") then
      local ifspeed = getInterfaceSpeed(tonumber(tags.ifid))

      if ifspeed ~= nil then
        -- bit/s
        return ifspeed * 1000 * 1000
      end
    elseif string.contains(metric, "packets") then
      local ifspeed = getInterfaceSpeed(tonumber(tags.ifid))

      if ifspeed ~= nil then
        -- mbit/s
        local speed_mbps = ifspeed
        local max_pps_baseline = 14881 -- for 10 mbps

        return speed_mbps / 10 * max_pps_baseline
      end
    end
  end

  return math.huge
end

-- ##############################################

function ts_common.normalizeVal(v, max_val, options)
  -- it's undesirable to normalize and set a 0 when
  -- the number is greater than max value
  -- this was causing missing points in the charts
  -- with ZMQ interface which can actually exceed the nominal value

  if v ~= v then
    -- NaN value
    v = options.fill_value
  elseif v < options.min_value then
    v = options.min_value
  end

  return v
end

-- ##############################################

function ts_common.calculateSampledTimeStep(raw_step, tstart, tend, options)
  local estimed_num_points = math.ceil((tend - tstart) / raw_step)
  local time_step = raw_step

  if estimed_num_points > options.max_num_points then
    -- downsample
    local num_samples = math.ceil(estimed_num_points / options.max_num_points)
    time_step = num_samples * raw_step
  end

  return time_step
end

-- ##############################################

function ts_common.fillSeries(schema, tstart, tend, time_step, fill_value)
  local count = math.ceil((tend-tstart) / time_step)
  local res = {}

  for idx, metric in ipairs(schema._metrics) do
    local data = {}

    for i=1, count do
      data[i] = fill_value
      i = i + 1
    end

    res[idx] = {label=metric, data=data}
  end

  return res, count
end

-- ##############################################

function ts_common.serieWithTimestamp(serie, tstart, tstep)
  local data = {}
  local t = tstart

  for i, pt in ipairs(serie) do
    data[t] = pt
    t = t + tstep
  end

  return data
end

-- ##############################################

local last_error = nil
local last_error_msg = nil
ts_common.ERR_OPERATION_TOO_SLOW = "OPERATION_TOO_SLOW"

function ts_common.clearLastError()
  err = nil
end

function ts_common.setLastError(err, msg)
  last_error = err
  last_error_msg = msg
end

function ts_common.getLastError()
  return last_error
end

function ts_common.getLastErrorMessage()
  return last_error_msg
end

-- ##############################################

return ts_common
