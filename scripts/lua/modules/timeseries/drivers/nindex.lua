--
-- (C) 2021 - ntop.org
--
-- http://127.0.0.1:3000/lua/modules/timeseries/drivers/nindex.lua

local driver = {}

-- ##############################################

function driver:new(options)
  local obj = {}
  setmetatable(obj, self)
  self.__index = self

  return obj
end

function driver:query(schema, tstart, tend, tags, options)
  -- TODO, see rrd.lua sampleSeries
  local time_step = math.floor((tend - tstart) / options.max_num_points)
  local count = options.max_num_points
  local series = {{label = "sent", data = {},}, {label = "rcvd", data = {},}}

  for i=1,count do
    series[1].data[i] = i
    series[2].data[i] = i
  end

  -- TODO calculate statistics?
  -- TODO calculate total serie?
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

function driver:listSeries(schema, tags_filter, wildcard_tags, start_time)
  -- TODO ?
end

function driver:topk(schema, tags, tstart, tend, options, top_tags)
  -- TODO ?
end

-- ##############################################

function driver:append(schema, timestamp, tags, metrics)
  return
end

function driver:export()
  return
end

function driver:getLatestTimestamp(ifid)
  return os.time()
end

-- ##############################################

function test()
  local dirs = ntop.getDirs()
  package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
  require("lua_utils")
  local json = require("dkjson")
  local ts_utils = require("ts_utils")

  local nindex = driver:new()
  local options = {
    max_num_points = 12,    -- maximum number of points per data serie
    fill_value = 0,         -- e.g. 0/0 for nan
    min_value = 0,          -- minimum value of a data point
    max_value = math.huge,  -- maximum value for a data point
    top = 8,                -- topk number of items
    calculate_stats = true, -- calculate stats if possible
    initial_point = false,  -- add an extra initial point, not accounted in statistics but useful for drawing graphs
  }
  local tags = {
    ifid = 1,
    host = "8.8.8.8",
  }

  local res = nindex:query(ts_utils.getSchema("host:traffic"), os.time() - 3600, os.time(), tags, options)

  sendHTTPContentTypeHeader('application/json')
  print(json.encode(res))
end

test()

return driver
