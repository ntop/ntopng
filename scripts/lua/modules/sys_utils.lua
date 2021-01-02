--
-- (C) 2013-21 - ntop.org
--

local sys_utils = {}

-- If false, some commands and config files are not executed/created really
-- This will be overwritten with the config value
local REAL_EXEC = ntop.getPref("ntopng.prefs.nedge_real_exec") == "1"

-- ################################################################

local FileMock = {}
FileMock.__index = FileMock

function FileMock.open(fname, mode)
  local obj = {}
  setmetatable(obj, FileMock)
  traceError(TRACE_NORMAL, TRACE_CONSOLE, "[File::" .. fname .. "]")
  return obj
end

function FileMock:write(data)
  local lines = split(data, "\n")

  for _, line in pairs(lines) do
    if not isEmptyString(line) then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "\t"..line)
    end
  end

  return true
end

function FileMock:close()
  traceError(TRACE_NORMAL, TRACE_CONSOLE, "[File::END]")
  return true
end

-- ################################################################

function sys_utils.setRealExec(new_v)
  REAL_EXEC = new_v
  local v = ternary(REAL_EXEC, "1", "0")

  if ntop.getPref("ntopng.prefs.nedge_real_exec") ~= v then
    ntop.setPref("ntopng.prefs.nedge_real_exec", v)
  end
end

-- ################################################################

function sys_utils.openFile(fname, mode)
  local cls

  if REAL_EXEC then
    cls = io
  else
    cls = FileMock
  end

  return cls.open(fname, mode)
end

-- ################################################################

-- Execute a system command
function sys_utils.execCmd(cmd)
   if(REAL_EXEC) then
    -- traceError(TRACE_NORMAL, TRACE_CONSOLE, "[execCmd] ".. cmd)
    return(os.execute(cmd))
   else
    traceError(TRACE_NORMAL, TRACE_CONSOLE, "[execCmd] ".. cmd)
    return 0
   end
end

-- ################################################################

-- execCmd with command output
-- NOTE: no check for REAL_EXEC, the command will always be executed!
function sys_utils.execShellCmd(c)
   local f = assert(io.popen(c, 'r'))
   local s = assert(f:read('*a'))
   f:close()
   return s
end

-- ################################################################

local function _isServiceStatus(service_name, status)
  local check_cmd = "systemctl is-"..status.." " .. service_name
  local is_active = sys_utils.execShellCmd(check_cmd)

  return ternary(string.match(is_active, "^"..status), true, false)
end

function sys_utils.isActiveService(service_name)
   return _isServiceStatus(service_name, "active")
end

function sys_utils.isFailedService(service_name)
   return _isServiceStatus(service_name, "failed")
end

function sys_utils.isActiveFailedService(service_name)
  local check_cmd = "systemctl is-active " .. service_name
  local is_active = sys_utils.execShellCmd(check_cmd)

  return ternary(string.match(is_active, "inactive"), false, true)
end

-- ################################################################

function sys_utils.enableService(service_name)
  return sys_utils.execCmd("systemctl enable " .. service_name)
end

function sys_utils.disableService(service_name)
  return sys_utils.execCmd("systemctl disable " .. service_name)
end

function sys_utils.restartService(service_name)
  return sys_utils.execCmd("systemctl restart " .. service_name)
end

function sys_utils.stopService(service_name)
  return sys_utils.execCmd("systemctl stop " .. service_name)
end

-- ################################################################

function sys_utils.rebootSystem()
  local do_reboot = ternary(REAL_EXEC, "reboot", nil)
  ntop.shutdown(do_reboot)
end

function sys_utils.shutdownSystem()
  local do_shutdown = ternary(REAL_EXEC, "poweroff", nil)
  ntop.shutdown(do_shutdown)
end

function sys_utils.restartSelf()
  local do_restart_self = ternary(REAL_EXEC, "restart_self", nil)
  ntop.shutdown(do_restart_self)
end

-- ################################################################

return sys_utils
