--
-- (C) 2021 - ntop.org
--

local test_utils = {}

-- ##############################################

function test_utils.makeTimeStamp(series, tstart, tstep)
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

-- ##############################################

function test_utils.timestampAsKey(tstamped_series)
  local rv = {}

  for idx, serie in pairs(tstamped_series) do
    rv[idx] = {}
    
    for _, val in ipairs(serie) do
      rv[idx][val[1]] = val[2]
    end
  end

  return rv
end

return test_utils
