--
-- (C) 2014-18 - ntop.org
--

local dirs = ntop.getDirs()

local tracker = require "tracker"

local os_utils = {}
local NTOPCTL_CMD = "/usr/bin/ntopctl"
local NTOPNG_CONFIG_TOOL = "/usr/bin/ntopng-utils-manage-config"
local is_windows = ntop.isWindows()

-- ########################################################

function os_utils.getPathDivider()
   if(is_windows) then
      return "\\"
   else
      return "/"
   end
end

-- ########################################################

-- Fix path format Unix <-> Windows
function os_utils.fixPath(path)
   path = string.gsub(path, "//+", '/') -- removes possibly empty parts of the path

   if(is_windows and (string.len(path) > 2)) then
      path = string.gsub(path, "/", os_utils.getPathDivider())
   end

  return(path)
end

-- ########################################################

--! @brief Execute a system command and return its output
--! @return the pair (output, ret_code). output will be nil on error.
--! @note error condition is determined from the command exit status
--! @note redirect the stderr of the command if the command is expected to fail
function os_utils.execWithOutput(c, ret_code_success)
   if is_windows then
      return nil
   end

   local f = assert(io.popen(c, 'r'))
   ret_code_success = ret_code_success or 0
  
   local s = assert(f:read('*a'))
   local rv = {f:close()}
   local retcode = rv[3]

   if retcode ~= ret_code_success then
      return nil, retcode
   end

   return s, retcode
end

-- ########################################################

local function ntopctl_cmd(service_name, use_sudo, ...)
   if not ntop.exists(NTOPCTL_CMD) then
      return nil
   end

   local cmd = {NTOPCTL_CMD, service_name, ...}

   if use_sudo then
      table.insert(cmd, 1, "sudo")
   end

   return table.concat(cmd, " ")
end

--! @brief Execute service control tool and get its output.
--! @return Command output. See os_utils.execWithOutput for details.
function os_utils.ntopctlCmd(service_name, ...)
   local cmd = ntopctl_cmd(service_name, true, ...)
   if not cmd then return nil end
   return os_utils.execWithOutput(cmd)
end

-- ########################################################

--! @brief Check if a service is available into the system.
--! @return true if service is available, false otherwise.
function os_utils.hasService(service_name, ...)
   local prefs = ntop.getPrefs()

   if not isEmptyString(prefs.user) and prefs.user ~= "ntopng" then
     return false
   end

   local has_ntopctl = os_utils.execWithOutput("which ntopctl >/dev/null 2>&1")
   if has_ntopctl == nil then
      -- ntopctl is not available
      return false
   end

   if not ntop.exists(NTOPNG_CONFIG_TOOL) then
      return false
   end

   local cmd = ntopctl_cmd(service_name, false, "has-service", ...)

   if not cmd then return false end
   local rv = os_utils.execWithOutput(cmd)
   return(rv == "yes\n")
end
 
-- ########################################################

--! @brief Enable a service
--! @return true if service was enabled successfully, false otherwise
function os_utils.enableService(service_name, ...)
   local cmd = ntopctl_cmd(service_name, true, "enable", ...)
   if not cmd then return false end

   os_utils.execWithOutput(cmd)

   return os_utils.isEnabled(service_name)
end

-- ########################################################

--! @brief Disable a service
--! @return true if service was disabled successfully, false otherwise
function os_utils.disableService(service_name, ...)
   local cmd = ntopctl_cmd(service_name, true, "disable", ...)
   if not cmd then return false end

   os_utils.execWithOutput(cmd)

   return not os_utils.isEnabled(service_name)
end

-- ########################################################

--! @brief Restart a service
--! @note See os_utils.execWithOutput for return value
function os_utils.restartService(service_name, ...)
   local cmd = ntopctl_cmd(service_name, true, "restart", ...)
   if not cmd then return false end

   os_utils.execWithOutput(cmd)

   return(os_utils.serviceStatus(service_name) == "active")
end

-- ########################################################

--! @brief Stop a service
--! @note See os_utils.execWithOutput for return value
function os_utils.stopService(service_name, ...)
   local cmd = ntopctl_cmd(service_name, true, "stop", ...)
   if not cmd then return false end

   os_utils.execWithOutput(cmd)

   return(os_utils.serviceStatus(service_name) == "inactive")
end

-- ########################################################

--! @brief Check the service status.
--! @return active|inactive|error
function os_utils.serviceStatus(service_name, ...)
   local cmd = ntopctl_cmd(service_name, false, "is-active", ...)
   if not cmd then return "error" end

   local rv = os_utils.execWithOutput(cmd)

   if rv == "active\n" then
      return "active"
   elseif rv == "inactive\n" then
      return "inactive"
   else
      return "error"
   end
end

-- ########################################################

--! @brief List a series of services along with their status
--! @return a table with one or more <service name>="[active|inactive]"
function os_utils.serviceListWithStatus(service_name)
   local cmd = ntopctl_cmd(service_name, false, "list")
   if not cmd then return "error" end

   local rv = os_utils.execWithOutput(cmd) or ""
   rv = rv:split("\n") or {}

   local res = {}

   for _, service in ipairs(rv) do
      service = service:split(" ") or {}

      if #service == 3 then
	 local service_name, service_status, service_conf = service[1], service[2], service[3]
	 res[#res + 1] = {name = service_name, status = service_status, conf = service_conf}
      end
   end
   
   return res
end
 
-- ########################################################

--! @brief Check if the service is active
--! @return true if service is active, false otehrwise
function os_utils.isActive(service_name, ...)
  return(os_utils.serviceStatus(service_name, ...) == "active")
end

-- ########################################################

function os_utils.isEnabled(service_name, ...)
   local cmd = ntopctl_cmd(service_name, false, "is-enabled", ...)
   if not cmd then return false end

   local rv = os_utils.execWithOutput(cmd)

   return(rv == "enabled")
end

-- ########################################################

-- TRACKER HOOK

tracker.track(os_utils, 'enableService')
tracker.track(os_utils, 'disableService')

-- ########################################################

return os_utils

