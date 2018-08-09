--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require("lua_utils")
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/tests/?.lua;" .. package.path

-- ##############################################

local utils_test = require("utils_test")
local influxdb_test = require("influxdb_test")

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

utils_test.run(tester)
influxdb_test.run(tester)
