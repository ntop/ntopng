--
-- (C) 2018 - ntop.org
--

local influxdb = require("influxdb")
local influx2Series = influxdb._influx2Series

local function makeTimeStamp(series, tstart, tstep)
  local v = {}

  for idx, serie in ipairs(series) do
    local data = {}
    t = tstart

    for i, pt in ipairs(serie.data) do
      data[i] = {t, pt}
      t = t + tstep
    end

    v[idx] = data
  end

  return v
end

-- Reproduces 12c8fc315654c1a0e7bf82f089ee47d45a98fc07 - Fix occasional series ponts differences in InfluxDB
local function test_sampling1(test)
  local schema = {
    options = {
      step = 300,
      metrics_type = "counter",
    }
  }

  local options = {
    fill_value = 0,
    min_value = 0,
    max_value = math.huge,
  }
  local tstart = 1532009616
  local tend = 1532091600
  local tags = {}
  local time_step = 600 -- sampling taking place

  local data1 = {
    statement_id = 0,
    series = {
      {
        name = "host:ndpi",
        columns = {
          "time", "bytes_sent", "bytes_rcvd"
        },
        values = {
          {1532010000, 7.1333333333333, 199.05166666667},
          {1532010600, 11, 205.45166666667},
          {1532011200, 9.4366666666667, 198.38833333333},
          {1532011800, 0, 0},
          {1532012400, 0, 0},
          {1532013000, 9.5633333333333, 198.87833333333},
          {1532013600, 0, 0},
          {1532081400, -0.54522123893805, -12.366224188791},
          {1532082000, 0, 0},
          {1532082600, 0, 0},
          {1532083200, 7.5833333333333, 200.805},
          {1532083800, 0, 0},
          {1532086800, 1.8586666666667, 39.729},
          {1532087400, 0, 0},
          {1532088000, 0, 0},
          {1532088600, 0, 0},
          {1532089200, 0, 0},
          {1532089800, 4.6116666666667, 99.195},
          {1532090400, 4.6116666666667, 99.195},
          {1532091000, 0, 0},
          {1532091600, 0, 0},
        },
      }
    },
  }

  local data2 = {
    statement_id = 0,
    series = {
      {
        name = "host:ndpi",
        columns = {
          "time", "bytes_sent", "bytes_rcvd"
        },
        values = {
          {1532086800, -0.18549180327869, -5.7308606557377},
          {1532087400, 4.9166666666667, 5.66},
          {1532088000, 7.14, 8.0383333333333},
          {1532088600, 6.0525, 6.9458333333333},
          {1532089200, 8.1358333333333, 9.5725},
          {1532089800, 7.8566666666667, 9.0508333333333},
          {1532090400, 9.4025, 23.83},
          {1532091000, 7.1975, 8.2333333333333},
          {1532091600, 4.475, 5.5808333333333},
        },
      }
    },
  }

  local data1_series, data1_count = influx2Series(schema, tstart, tend, tags, options, data1.series[1], time_step)
  local data2_series, data2_count = influx2Series(schema, tstart, tend, tags, options, data2.series[1], time_step)

  -- Number of points must be the same
  if(not(data1_count == data2_count)) then
    return test:assertion_failed("data1_count == data2_count\n")
  end

  -- No initial gaps
  if(not(data1_series[1].data[1] == 7.1333333333333)) then
    return test:assertion_failed("data1_series[1].data[1] == 7.1333333333333\n")
  end

  return test:success()
end

-- Reproduces e8955df951556421659c964a202cc006a4bf40d1 - Fix influx2Series points bug
local function test_datafill1(test)
  local tags = {}
  local options = {
    fill_value = 0,
    min_value = 0,
    max_value = math.huge,
  }

  local data1 = {
    statement_id = 0,
    series = {
      {
        name = "iface:traffic",
        columns = {
          "time", "bytes"
        },
        values = {
          {1533808916, 0},
        },
      }
    }
  }

  local data2 = {
    statement_id = 0,
    series = {
      {
        name = "iface:traffic",
        columns = {
          "time", "bytes"
        },
        values = {
          {1533808616, 156},
          {1533808617, 384},
          {1533808618, 1443},
          {1533808619, 763},
          {1533808620, 12763},
          {1533808621, 4372},
          {1533808622, 0},
          {1533808623, 0},
          {1533808624, 1215},
          {1533808625, 3397},
          {1533808626, 245613},
          {1533808627, 76308},
          {1533808628, 202},
          {1533808629, 0},
          {1533808630, 0},
        },
      }
    }
  }

  local schema = {
    options = {
      step = 1,
      metrics_type = "counter",
    }
  }

  local time_step = 1 -- no sampling
  local tstart = 1533808915; tend = 1533808930
  local data1_series, data1_count = influx2Series(schema, tstart, tend, tags, options, data1.series[1], time_step)
  local tstart = 1533808615; tend = 1533808630
  local data2_series, data2_count = influx2Series(schema, tstart, tend, tags, options, data2.series[1], time_step)

  -- No initial gaps
  if(not(data1_count == data2_count)) then
    return test:assertion_failed("data1_count == data2_count\n")
  end

  return test:success()
end

-- Reproduces 65b30e24c8eb851cdd8614917e328b54873d4a2c - Fix influx2Series points bug with sampling
local function test_datafill2(test)
  local tags = {}
  local options = {
    fill_value = 0,
    min_value = 0,
    max_value = math.huge,
  }

  local data1 = {
    statement_id = 0,
    series = {
      {
        name = "iface:traffic",
        columns = {
          "time", "bytes"
        },
        values = {
          {1533808816, 130.79671280276},
          {1533808850, 231.55622837371},
          {1533808884, 149.47404844291},
          {1533808918, 208.94723183391},
          {1533808952, 101.22664359862},
          {1533808986, 53.307093425599},
          {1533809020, 87.579584775095},
          {1533809054, 56.829584775082},
          {1533809088, 134.9682939672},
        },
      }
    }
  }

  local data2 = {
    statement_id = 0,
    series = {
      {
        name = "iface:traffic",
        columns = {
          "time", "bytes"
        },
        values = {
          {1533808544, 479.54411764706},
          {1533808578, 111.54584775086},
          {1533808612, 6143.3468858131},
          {1533808646, 4240.8070934256},
          {1533808680, 164.98183391004},
          {1533808714, 120.65224913495},
          {1533808748, 658.87543252595},
          {1533808782, 363.52923278845},
        },
      }
    }
  }

  local schema = {
    options = {
      step = 1,
      metrics_type = "counter",
    }
  }

  local time_step = 34 -- 34x sampling
  local tstart = 1533808810; tend = 1533809110
  local data1_series, data1_count = influx2Series(schema, tstart, tend, tags, options, data1.series[1], time_step)
  local tstart = 1533808510; tend = 1533808810
  local data2_series, data2_count = influx2Series(schema, tstart, tend, tags, options, data2.series[1], time_step)

  -- No initial gaps
  if(not(data1_count == data2_count)) then
    return test:assertion_failed("data1_count == data2_count\n")
  end

  return test:success()
end

function test_datafill3(test)
  local tags = {}
  local options = {
    fill_value = 0,
    min_value = 0,
    max_value = math.huge,
  }    

  local data1 = {
    statement_id = 0,
    series = {
      {
        name = "iface:traffic",
        columns = {
          "time", "bytes"
        },
        values = {
          {1534254780, 43468.299166667},
          {1534254840, 43840.816666667},
          {1534254900, 43736.703055556},
          {1534254960, 45451.860277778},
          {1534255020, 51042.556111111},
          {1534255080, 41195.961111111},
          {1534255140, 49409.312222222},
          {1534255200, 46668.393333333},
          {1534255260, 49719.968611111},
          {1534255320, 46598.248611111},
          {1534255380, -1986466.8319444},
          {1534255560, -2555.5150205761},
          {1534255620, 32720.676450617},
          {1534255680, 90807.558333333},
          {1534255740, 43846.880833333},
          {1534255800, 40665.011111111},
          {1534255860, 46311.474444444},
          {1534255920, 35688.736944444},
          {1534255980, 35530.134166667},
          {1534256040, 35844.119722222},
          {1534256100, 40027.853055556},
          {1534256160, 47747.443055556},
          {1534256220, 33840.845},
          {1534256280, 13316.156944444},
          {1534256340, 12864.246944444},
          {1534256400, 33067.384444444},
          {1534256460, 35054.200555556},
          {1534256520, 38080.145},
          {1534256580, 31810.306527778},
        },
      }
    }
  }

  local schema = {
    options = {
      step = 1,
      metrics_type = "counter",
    }
  }

  local time_step = 60 -- 60x sampling
  local tstart = 1534254780; tend = 1534256640
  local data1_series, data1_count = influx2Series(schema, tstart, tend, tags, options, data1.series[1], time_step)
  local with_tstamp = makeTimeStamp(data1_series, tstart, time_step)[1]
  local last_val = with_tstamp[#with_tstamp - 1]
  local last_expected_val = data1.series[1].values[#data1.series[1].values]

  -- Timestamp must correspond
  if not(last_val[1] == last_expected_val[1]) then
    return test:assertion_failed("last_val[0] == last_expected_val[0]\n")
  end

  -- Value must correspond
  if not(last_val[2] == last_expected_val[2]) then
    return test:assertion_failed("last_val[1] == last_expected_val[1]\n")
  end

  return test:success()
end

function test_no_derivative1(test)
  local tags = {}
  local options = {
    fill_value = 0,
    min_value = 0,
    max_value = math.huge,
  }    

  local data1 = {
    statement_id = 0,
    series = {
      {
        name = "iface:flows",
        columns = {
          "time", "total_serie"
        },
        values = {
          {1534492860, 40},
          {1534492920, 35},
          {1534492980, 19},
          {1534493040, 26},
          {1534493100, 33},
          {1534493160, 18},
        },
      }
    }
  }

  local schema = {
    options = {
      step = 1,
      metrics_type = "gauge",
    }
  }

  local time_step = 60 -- no sampling
  local tstart = 1534492620; tend = 1534493220
  local data1_series, data1_count = influx2Series(schema, tstart+time_step, tend, tags, options, data1.series[1], time_step)
  local with_tstamp = makeTimeStamp(data1_series, tstart+time_step, time_step)[1]
  local first_expected_val = data1.series[1].values[1]

  for _, pt in pairs(with_tstamp) do
    if pt[1] == first_expected_val[1] then
      if not(pt[2] == first_expected_val[2]) then
        return test:assertion_failed("pt[2] == first_expected_val[2]\n")
      end

      break
    end
  end

  return test:success()
end

--http://127.0.0.1:3000/lua/get_ts.lua?ts_query=ifid:1&epoch_end=1534493220&ts_schema=iface:flows&epoch_begin=1534492620&initial_point=true&ts_compare=30m&limit=42

function test_skip_initial1(test)
  local tags = {}
  local options = {
    fill_value = 0,
    min_value = 0,
    max_value = math.huge,
  }    

  local data1 = {
    statement_id = 0,
    series = {
      {
        name = "iface:flows",
        columns = {
          "time", "num_flows"
        },
        values = {
          {1534502280, 12},
          {1534502340, 23},
          {1534502400, 28},
          {1534502460, 13},
          {1534502520, 12},
          {1534502580, 13},
          {1534502640, 20},
          {1534502700, nil},
        },
      }
    }
  }

  local schema = {
    options = {
      step = 1,
      metrics_type = "gauge",
    }
  }

  local time_step = 60 -- no sampling
  local tstart = 1534502340; tend = 1534493220
  local data1_series, data1_count = influx2Series(schema, tstart, tend, tags, options, data1.series[1], time_step)
  local with_tstamp = makeTimeStamp(data1_series, tstart, tstart)[1]
  local first_expected_val = data1.series[1].values[2]

  for _, pt in ipairs(with_tstamp) do
    if pt[2] ~= 0 then
      if not(pt[2] == first_expected_val[2]) then
        return test:assertion_failed("pt[2] == first_expected_val\n")
      end

      break
    end
  end

  return test:success()
end

function run(tester)
  local rv = tester.run_test("influx2Series:test_sampling1", test_sampling1)
  rv = tester.run_test("influx2Series:test_datafill1", test_datafill1) and rv
  rv = tester.run_test("influx2Series:test_datafill2", test_datafill2) and rv
  rv = tester.run_test("influx2Series:test_datafill3", test_datafill3) and rv
  rv = tester.run_test("influx2Series:test_no_derivative1", test_no_derivative1) and rv
  rv = tester.run_test("influx2Series:test_skip_initial1", test_skip_initial1) and rv

  return rv
end

return {
  run = run
}
