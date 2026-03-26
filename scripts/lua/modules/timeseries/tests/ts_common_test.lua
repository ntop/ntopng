--
-- (C) 2024 - ntop.org
--
-- Additional unit tests for ts_common functions that are not covered by
-- the existing utils_test.lua.
--

local ts_common = require("ts_common")

-- ##############################################

-- upsampleSerie: requesting fewer or equal points returns the original serie
local function upsampleSerie_no_upsampling(test)
  local serie = {10, 20, 30}

  -- same length
  local res = ts_common.upsampleSerie(serie, 3)
  if not(#res == #serie) then
    return test:assertion_failed("same-length upsample should return original serie length")
  end

  -- requesting fewer points
  local res2 = ts_common.upsampleSerie(serie, 1)
  if not(#res2 == #serie) then
    return test:assertion_failed("requesting fewer points should return original serie")
  end

  return test:success()
end

-- ##############################################

-- upsampleSerie: empty serie returns empty result
local function upsampleSerie_empty(test)
  local serie = {}
  local res = ts_common.upsampleSerie(serie, 5)
  if not(#res == 0) then
    return test:assertion_failed("upsample of empty serie should return empty result")
  end
  return test:success()
end

-- ##############################################

-- calculateMinMax: basic ascending sequence
local function calculateMinMax_basic(test)
  local serie = {3, 1, 4, 1, 5, 9, 2, 6}
  local r = ts_common.calculateMinMax(serie)

  if r.min_val ~= 1 then
    return test:assertion_failed("min_val expected 1, got " .. tostring(r.min_val))
  end

  if r.max_val ~= 9 then
    return test:assertion_failed("max_val expected 9, got " .. tostring(r.max_val))
  end

  return test:success()
end

-- ##############################################

-- calculateMinMax: single-element serie
local function calculateMinMax_single(test)
  local serie = {42}
  local r = ts_common.calculateMinMax(serie)

  if r.min_val ~= 42 then
    return test:assertion_failed("min_val expected 42, got " .. tostring(r.min_val))
  end

  if r.max_val ~= 42 then
    return test:assertion_failed("max_val expected 42, got " .. tostring(r.max_val))
  end

  return test:success()
end

-- ##############################################

-- calculateMinMax: serie containing NaN values (nan ~= nan in Lua)
local function calculateMinMax_with_nan(test)
  local nan = 0/0
  local serie = {nan, 5, nan, 2, nan}
  local r = ts_common.calculateMinMax(serie)

  if r.min_val ~= 2 then
    return test:assertion_failed("min_val expected 2 when NaN present, got " .. tostring(r.min_val))
  end

  if r.max_val ~= 5 then
    return test:assertion_failed("max_val expected 5 when NaN present, got " .. tostring(r.max_val))
  end

  return test:success()
end

-- ##############################################

-- calculateStatistics: counter data_type multiplies total by step
local function calculateStatistics_counter(test)
  local serie = {1, 2, 3, 4, 5}
  local step = 10
  local r = ts_common.calculateStatistics(serie, step, false, ts_common.metrics.counter)

  -- sum(serie) = 15, total for counter = 15 * step = 150
  if r.total ~= 150 then
    return test:assertion_failed("total expected 150 for counter, got " .. tostring(r.total))
  end

  -- average = 15 / 5 = 3
  if r.average ~= 3 then
    return test:assertion_failed("average expected 3, got " .. tostring(r.average))
  end

  return test:success()
end

-- ##############################################

-- calculateStatistics: gauge with keep_total=true retains total
local function calculateStatistics_gauge_keep_total(test)
  local serie = {2, 4, 6}
  local step = 5
  local r = ts_common.calculateStatistics(serie, step, true, ts_common.metrics.gauge)

  -- For gauge + keep_total=true, total is the raw sum (not multiplied by step)
  if r.total ~= 12 then
    return test:assertion_failed("total expected 12 for gauge+keep_total, got " .. tostring(r.total))
  end

  if r.average ~= 4 then
    return test:assertion_failed("average expected 4, got " .. tostring(r.average))
  end

  return test:success()
end

-- ##############################################

-- calculateStatistics: gauge without keep_total returns nil total
local function calculateStatistics_gauge_no_total(test)
  local serie = {10, 20, 30}
  local step = 1
  local r = ts_common.calculateStatistics(serie, step, false, ts_common.metrics.gauge)

  if r.total ~= nil then
    return test:assertion_failed("total expected nil for gauge without keep_total, got " .. tostring(r.total))
  end

  return test:success()
end

-- ##############################################

-- calculateStatistics: serie with NaN values skips them in average/total
local function calculateStatistics_with_nan(test)
  local nan = 0/0
  local serie = {10, nan, 20, nan, 30}
  local step = 1
  local r = ts_common.calculateStatistics(serie, step, true, ts_common.metrics.gauge)

  -- Only 3 valid points: 10, 20, 30 -> avg = 20
  if r.average ~= 20 then
    return test:assertion_failed("average expected 20 (ignoring NaN), got " .. tostring(r.average))
  end

  -- total (gauge+keep_total) = raw sum of valid points = 60
  if r.total ~= 60 then
    return test:assertion_failed("total expected 60 (ignoring NaN), got " .. tostring(r.total))
  end

  return test:success()
end

-- ##############################################

-- ninetififthPercentile: single-element serie returns that element
local function ninetififthPercentile_single(test)
  local serie = {7}
  local p = ts_common.ninetififthPercentile(serie)

  if p ~= 7 then
    return test:assertion_failed("percentile of single element expected 7, got " .. tostring(p))
  end

  return test:success()
end

-- ##############################################

-- ninetififthPercentile: all-NaN serie returns NaN
local function ninetififthPercentile_all_nan(test)
  local nan = 0/0
  local serie = {nan, nan, nan}
  local p = ts_common.ninetififthPercentile(serie)

  -- NaN != NaN is the standard check for NaN in Lua
  if p == p then
    return test:assertion_failed("percentile of all-NaN serie should be NaN, got " .. tostring(p))
  end

  return test:success()
end

-- ##############################################

function run(tester)
  local ok = true

  ok = tester.run_test("upsampleSerie:no_upsampling",    upsampleSerie_no_upsampling)    and ok
  ok = tester.run_test("upsampleSerie:empty",            upsampleSerie_empty)            and ok
  ok = tester.run_test("calculateMinMax:basic",          calculateMinMax_basic)          and ok
  ok = tester.run_test("calculateMinMax:single",         calculateMinMax_single)         and ok
  ok = tester.run_test("calculateMinMax:with_nan",       calculateMinMax_with_nan)       and ok
  ok = tester.run_test("calculateStatistics:counter",    calculateStatistics_counter)    and ok
  ok = tester.run_test("calculateStatistics:gauge_keep", calculateStatistics_gauge_keep_total) and ok
  ok = tester.run_test("calculateStatistics:gauge_no_total", calculateStatistics_gauge_no_total) and ok
  ok = tester.run_test("calculateStatistics:with_nan",   calculateStatistics_with_nan)   and ok
  ok = tester.run_test("ninetififthPercentile:single",   ninetififthPercentile_single)   and ok
  ok = tester.run_test("ninetififthPercentile:all_nan",  ninetififthPercentile_all_nan)  and ok

  return ok
end

return {
  run = run
}
