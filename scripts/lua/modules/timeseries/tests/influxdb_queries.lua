--
-- (C) 2021 - ntop.org
--

local ts_utils = require("ts_utils")
local test_utils = require("test_utils")
local influxdb = ts_utils.getQueryDriver()

-- ##############################################

-- use relative times to avoid retention policy issues
local now = os.time()
local options = ts_utils.getQueryOptions()
local f = nil

local schema = ts_utils.newSchema("test:test", {step=1})
schema:addTag("t")
schema:addMetric("v")

-- ##############################################

local function api_string(schema, tags, metrics, tstamp)
  return string.format("%s,%s %s %s000000000\n", schema, table.tconcat(tags, "=", ","), table.tconcat(metrics, "=", ","), tostring(tstamp))
end

local function insert(metrics, tstamp)
  f:write(api_string("test:test", {t="test"}, metrics, tstamp))
end

-- ##############################################

local function add_points(test, points)
  local fname = "/tmp/test_influx_ts"
  f = io.open(fname, "w")

  -- Insert values
  for _, point in ipairs(points) do
    insert(point[1], point[2])
  end

  -- Write data
  f:close()

  if influxdb:_exportTsFile(fname) == nil then
    return test:fail("influxdb:_exportTsFile failed")
  end

  return true
end

local function init_test(test, points)
  if not influxdb:delete("test") then
    return test:fail("influxdb:delete failed")
  end

  return add_points(test, points)
end

-- ##############################################

-- When performing the derivative between two points, the delta must be calculated
-- and accounted for the second point time
function test_simple_derivative(test)
  local test_data = {
    {{v=1000}, now},
    {{v=2000}, now+1},
  }

  if not init_test(test, test_data) then
    return false
  end

  local res = influxdb:query(schema, now-20, now+20, {t="test"}, options)

  if table.empty(res) then
    return test:assertion_failed("not table.empty(res)")
  end

  local rv = test_utils.timestampAsKey(test_utils.makeTimeStamp(res.series, res.start, schema.options.step))[1]

  local t1 = test_data[2][2]

  if not(rv[t1] == 1000) then
    return test:assertion_failed("rv[t1=".. t1 .."] == 1000")
  end

  return test:success()
end

-- ##############################################

function run(tester)
  if influxdb.db == nil then
    print("Skipping influx_query tests. Enable InfluxDB export in order to test.<br/>")
    return(true)
  end

  local rv = tester.run_test("influx_query:test_simple_derivative", test_simple_derivative)

  return rv
end

return {
  run = run
}
