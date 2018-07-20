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

return ts_common
