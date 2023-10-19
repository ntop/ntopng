--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require("lua_utils")
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/tests/?.lua;" .. package.path

-- ##############################################

local tests = {
  require("utils_test"),
  require("influxdb2series"),
  require("influxdb_queries"),
  require("rrd_paths_test"),
}

-- ##############################################

local test = {}

function test:new(name)
  local obj = {
    name = name,
  }

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function test:success()
  print(self.name .. " OK<br>")
  return true
end

function test:fail(message)
  print(self.name .. " FAILED: ".. message .."<br>")
  return false
end

function test:assertion_failed(assertion)
  print(self.name .. " ASSERTION FAILED: ".. assertion .."<br>")
  return false
end

local tester = {
  new_test = function(name)
    return test:new(name)
  end,

  run_test = function(name, fn)
    local test = test:new(name)
    return fn(test)
  end
}

-- ##############################################

sendHTTPContentTypeHeader('text/html')

for _, test in ipairs(tests) do
  test.run(tester)
end
