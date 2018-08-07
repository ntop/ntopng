--
-- (C) 2017 - ntop.org
--

local ts_common = {}

-- ##############################################

ts_common.metrics = {}
ts_common.metrics.counter = "counter"
ts_common.metrics.gauge = "gauge"

-- ##############################################

-- Find the percentile of a list of values
-- N - A list of values.  N must be sorted.
-- P - A float value from 0.0 to 1.0
local function percentile(N, P)
  local n = math.floor(math.floor(P * #N + 0.5))
  return(N[n-1])
end

function ts_common.ninetififthPercentile(serie)
  N = table.clone(serie)
  table.sort(N) -- <<== Sort first
  return(percentile(N, 0.95))
end

-- ##############################################

function ts_common.calculateStatistics(total_serie, step, tdiff, data_type)
  local total = 0
  local min_val, max_val
  local min_val_pt, max_val_pt

  for idx, val in pairs(total_serie) do
    -- integrate
    total = total + val * step

    if (min_val_pt == nil) or (val < min_val) then
      min_val = val
      min_val_pt = idx - 1
    end
    if (max_val_pt == nil) or (val > max_val) then
      max_val = val
      max_val_pt = idx - 1
    end
  end

  local avg = total / tdiff

  if data_type == ts_common.metrics.gauge then
    -- no total for gauge values!
    total = nil
  end

  return {
    total = total,
    average = avg,
    min_val = min_val,
    max_val = max_val,
    min_val_idx = min_val_pt,
    max_val_idx = max_val_pt,
    ["95th_percentile"] = ts_common.ninetififthPercentile(total_serie),
  }
end

-- ##############################################

-- NOTE: this corresponds to graph_utils interpolateSerie
-- This is approximate
function ts_common.upsampleSerie(serie, num_points)
  if num_points <= #serie then
    return serie
  end

  local res = {}
  local intervals = num_points / #serie;

  local lerp = function(v0, v1, t)
    return (1 - t) * v0 + t * v1
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

-- test for ts_common.interpolateSerie
local function test_interpolateSerie()
  local serie = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
  local target_points = 19
  local max_err_perc = 10
  local res = interpolateSerie(serie, target_points)

  if not(#res == target_points) then
    io.write("test_influx2Series ASSERTION FAILED: target_points == #res\n")
    return false
  end

  local sum = function(a)
    local s = 0
    for _, x in pairs(a) do
      s = s + x
    end
    return s
  end

  local avg1 = sum(serie) / #serie
  local avg2 = sum(res) / #res
  local err = math.abs(avg1 - avg2)
  local err_perc = err * 100 / avg1

  if not(err_perc <= max_err_perc) then
    io.write("test_influx2Series ASSERTION FAILED: err <= ".. max_err_perc .."%\n")
    return false
  end

  return true
end

-- ##############################################

return ts_common
