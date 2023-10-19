--
-- (C) 2014-22 - ntop.org
--

local clock_start = os.clock()

-- Trace Level
TRACE_LEVEL = 2


-- Login & session
debug_login = false
debug_session = false
debug_host = false
debug_flow_data = false

-------------------------------- Trace Event ----------------------------------
-- Trace level
TRACE_ERROR    = 0
TRACE_WARNING  = 1
TRACE_NORMAL   = 2
TRACE_INFO     = 3
TRACE_DEBUG    = 4

MAX_TRACE_LEVEL = 4
-- Trace mode
TRACE_CONSOLE = 0
TRACE_WEB = 1

function traceError(p_trace_level, p_trace_mode, p_message)
  local currentline = debug.getinfo(2).currentline
  local what =  debug.getinfo(2).what
  local src =  debug.getinfo(2).short_src
  local traceback = debug.traceback()

  for str in (string.gmatch(traceback, '([^\n]+)')) do
    traceback = str
  end
  for str in (string.gmatch(traceback, '([^/]+)')) do
    traceback = str
  end
  local i = 0
  for str in (string.gmatch(traceback, '([^:][^ ]+)')) do
    if (i == 0) then traceback = str end
    i = i + 1
  end
  traceback = traceback:sub(1, string.len(traceback)-1)
  local filename = src
  for str in (string.gmatch(src, '([^/]+)')) do
    filename = str
  end

  if ((p_trace_level <= MAX_TRACE_LEVEL) and (p_trace_level <= TRACE_LEVEL) )then
    if (p_trace_mode == TRACE_WEB) then
      local date = os.date("%d/%b/%Y %X")
      local trace_prefix = ''

      if (p_trace_level == TRACE_ERROR) then trace_prefix = 'ERROR: ' end
      if (p_trace_level == TRACE_WARNING) then trace_prefix = 'WARNING: ' end
      if (p_trace_level == TRACE_INFO) then trace_prefix = 'INFO: ' end
      if (p_trace_level == TRACE_DEBUG) then trace_prefix = 'DEBUG: ' end

      if (filename..':'..currentline ~= traceback) then
        print('<b>'..date..' ['..traceback..'] ['..filename..':'..currentline..'] ' ..trace_prefix..p_message..'</b></br>')
      else
        print('<b>'..date..' ['..filename..':'..currentline..'] ' ..trace_prefix..p_message..'</b></br>')
      end
    elseif (p_trace_mode == TRACE_CONSOLE) then
      if (filename..':'..currentline ~= traceback) then
        --~ io.write(date..' ['..traceback..'] ['..filename..':'..currentline..'] ' ..trace_prefix..p_message..'\n')
        ntop.traceEvent(p_trace_level, traceback..'] [' .. filename, currentline, p_message)
      else
        --~ io.write(date..' ['..filename..':'..currentline..'] ' ..trace_prefix..p_message..'\n')
        ntop.traceEvent(p_trace_level, filename, currentline, p_message)
      end
    end
  end
end

function startProfiling(mod)
  local profiling = {
    starting_time = os.clock(), 
    time = os.clock()
  }
  traceError(TRACE_NORMAL,TRACE_CONSOLE," --- Starting Profiling of ".. mod .. " --- \n")
  return profiling
end

function endProfiling(mod, profiling_data)
  traceError(TRACE_NORMAL,TRACE_CONSOLE," --- End Profiling of ".. mod .. 
    " after: " .. os.clock() - profiling_data.starting_time .. " --- \n")
end

function traceProfiling(func, profiling_data, new_function)
  local current_time = os.clock()
  if new_function then
    traceError(TRACE_NORMAL,TRACE_CONSOLE,"Start analyzing: " .. func .. "\n")
    profiling_data.time = current_time
  else
    traceError(TRACE_NORMAL,TRACE_CONSOLE,"Function : " .. func .. ", time spent:".. current_time - profiling_data.time .. "\n")
  end
end

function setTraceLevel(p_trace_level) 
  if (p_trace_level <= MAX_TRACE_LEVEL) then
    TRACE_LEVEL = p_trace_level
  end
end

function resetTraceLevel()
  TRACE_LEVEL = 1
end

--------------------------------

if(trace_script_duration ~= nil) then
  io.write(debug.getinfo(1,'S').source .." executed in ".. (os.clock()-clock_start)*1000 .. " ms\n")
end
