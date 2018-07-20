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

return ts_common
