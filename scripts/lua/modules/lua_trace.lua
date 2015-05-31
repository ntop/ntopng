--
-- (C) 2014-15 - ntop.org
--

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

function traceError(p_trace_level, p_trace_mode,p_message)
  currentline = debug.getinfo(2).currentline
  what =  debug.getinfo(2).what
  src =  debug.getinfo(2).short_src
  traceback = debug.traceback()

  for str in (string.gmatch(traceback, '([^\n]+)')) do
    traceback = str
  end
  for str in (string.gmatch(traceback, '([^/]+)')) do
    traceback = str
  end
  i = 0
  for str in (string.gmatch(traceback, '([^:][^ ]+)')) do
    if (i == 0) then traceback = str end
    i = i + 1
  end
  traceback = traceback:sub(1, string.len(traceback)-1)
  filename = src
  for str in (string.gmatch(src, '([^/]+)')) do
    filename = str
  end
  date = os.date("%d/%b/%Y %X")

  trace_prefix = ''

  if (p_trace_level == TRACE_ERROR) then trace_prefix = 'ERROR: ' end
  if (p_trace_level == TRACE_WARNING) then trace_prefix = 'WARNING: ' end
  if (p_trace_level == TRACE_INFO) then trace_prefix = 'INFO: ' end
  if (p_trace_level == TRACE_DEBUG) then trace_prefix = 'DEBUG: ' end

  if ((p_trace_level <= MAX_TRACE_LEVEL) and (p_trace_level <= TRACE_LEVEL) )then
    if (p_trace_mode == TRACE_WEB) then
      if (filename..':'..currentline ~= traceback) then
        print('<b>'..date..' ['..traceback..'] ['..filename..':'..currentline..'] ' ..trace_prefix..p_message..'</b></br>')
      else
        print('<b>'..date..' ['..filename..':'..currentline..'] ' ..trace_prefix..p_message..'</b></br>')
      end
    elseif (p_trace_mode == TRACE_CONSOLE) then
      if (filename..':'..currentline ~= traceback) then
        io.write(date..' ['..traceback..'] ['..filename..':'..currentline..'] ' ..trace_prefix..p_message..'\n')
      else
        io.write(date..' ['..filename..':'..currentline..'] ' ..trace_prefix..p_message..'\n')
      end
    end
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