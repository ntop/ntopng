--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_trace"
local unittest = {}

function unittest:runner(test_no, test_name, f)
   return function(...)
      -- for each function run by this runner, failed assertions are counted
      -- so we start clean with a reset
      self.failed_assertions = 0

      local f_name = debug.getinfo(1, "n").name
      local start  = os.time()
      local result = {f(...)}
      local finish = os.time()

      local result = table.unpack(result)

      traceError(TRACE_NORMAL,TRACE_CONSOLE, string.format("[%s][test: %.2u][%s] executed in %i secs",
							   self.failed_assertions > 0 and "FAILED" or "OK",
							   test_no, test_name, finish - start))

      return self.failed_assertions == 0
   end
end

function unittest:new(options)
   local obj = {
      test_fns = {},
      failed_assertions = 0,
      -- add here other class members and possibly initialize them from the options
   }

   setmetatable(obj, self)
   self.__index = self

   return obj
end

function unittest:assertEqual(actual, expected, msg)
   if actual ~= expected then
      traceError(TRACE_ERROR, TRACE_CONSOLE,
		 string.format("Assertion failed [actual: %s][expected: %s][%s]", tostring(actual), tostring(expected), msg))
      self.failed_assertions = self.failed_assertions + 1
      return false
   end

   return true
end

function unittest:appendTest(test_name, test_fn)
   self.test_fns[#self.test_fns + 1] = {test_name = test_name, test_fn = test_fn}
end

function unittest:run()
   local unittest_file = debug.getinfo(2).short_src
   traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("Running unittest [%s]", unittest_file))

   for test_no, test_fn in ipairs(self.test_fns) do
      local test_name = test_fn["test_name"]
      local test_fn   = test_fn["test_fn"]

      self:runner(test_no, test_name, test_fn)()
   end

   traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("Unittest done [%s]", unittest_file))
end

return unittest
