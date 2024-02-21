--
-- (C) 2016-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- #################################

local profiling = {}

-- #################################

function profiling.get_current_memory(file)
  require "lua_trace"
  
  local lua_memory_usage = collectgarbage("count") 
  traceError(TRACE_NORMAL, TRACE_CONSOLE, "Currently executing file: " .. file .. "; Current LUA memory usage: " .. lua_memory_usage .. " KB")
end

-- #################################

return profiling