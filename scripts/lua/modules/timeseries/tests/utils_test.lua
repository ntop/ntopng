--
-- (C) 2018 - ntop.org
--

local ts_common = require("ts_common")

local function interpolateSerie_test1(test)
  local serie = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
  local target_points = 19
  local max_err_perc = 10
  local res = ts_common.upsampleSerie(serie, target_points)

  if not(#res == target_points) then
    return test:assertion_failed("target_points == #res")
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
    return test:failure("err <= ".. max_err_perc .."%")
  end

  return test:success()
end

function run(tester)
  local rv = tester.run_test("interpolateSerie:test1", interpolateSerie_test1)

  return rv
end

return {
  run = run
}
