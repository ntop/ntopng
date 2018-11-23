--
-- (C) 2014-18 - ntop.org
--

local dirs = ntop.getDirs()

local os_utils = {}
local NTOPCTL_CMD = "sudo ntopctl"
local NTOPNG_CONFIG_TOOL = "/usr/bin/ntopng-utils-manage-config"
local is_windows = ntop.isWindows()

-- ########################################################

function os_utils.getPathDivider()
   if(ntop.isWindows()) then
      return "\\"
   else
      return "/"
   end
end

-- ########################################################

-- Fix path format Unix <-> Windows
function os_utils.fixPath(path)
   path = string.gsub(path, "//+", '/') -- removes possibly empty parts of the path

   if(ntop.isWindows() and (string.len(path) > 2)) then
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

local function ntopctl_cmd(service_name, ...)
   local cmd = {NTOPCTL_CMD, service_name, ...}
   return table.concat(cmd, " ") .. " 2>/dev/null"
end

--! @brief Execute service control tool and get its output.
--! @return Command output. See os_utils.execWithOutput for details.
function os_utils.ntopctlCmd(service_name, ...)
   return os_utils.execWithOutput(ntopctl_cmd(service_name, ...))
end

-- ########################################################

--! @brief Check if a service is available into the system.
--! @return true if service is available, false otherwise.
function os_utils.hasService(service_name, ...)
   if not ntop.exists(NTOPNG_CONFIG_TOOL) then
      return false
   end

   local rv = os_utils.execWithOutput(ntopctl_cmd(service_name, "has-service", ...))
   return(rv == "yes\n")
end
 
-- ########################################################

--! @brief Enable a service
--! @return true if service was enabled successfully, false otherwise
function os_utils.enableService(service_name, ...)
   os_utils.execWithOutput(ntopctl_cmd(service_name, "enable", ...))
   return os_utils.isEnabled(service_name)
end

-- ########################################################

--! @brief Disable a service
--! @return true if service was disabled successfully, false otherwise
function os_utils.disableService(service_name, ...)
   os_utils.execWithOutput(ntopctl_cmd(service_name, "disable", ...))
   return not os_utils.isEnabled(service_name)
end

-- ########################################################

--! @brief Restart a service
--! @note See os_utils.execWithOutput for return value
function os_utils.restartService(service_name, ...)
   os_utils.execWithOutput(ntopctl_cmd(service_name, "restart", ...))
   return(os_utils.serviceStatus(service_name) == "active")
end

-- ########################################################

--! @brief Stop a service
--! @note See os_utils.execWithOutput for return value
function os_utils.stopService(service_name, ...)
   os_utils.execWithOutput(ntopctl_cmd(service_name, "stop", ...))
   return(os_utils.serviceStatus(service_name) == "inactive")
end

-- ########################################################

--! @brief Check the service status.
--! @return active|inactive|error
function os_utils.serviceStatus(service_name, ...)
   local rv = os_utils.execWithOutput(ntopctl_cmd(service_name, "is-active", ...))

   if rv == "active\n" then
      return "active"
   elseif rv == "inactive\n" then
      return "inactive"
   else
      return "error"
   end
end
 
-- ########################################################

--! @brief Check if the service is active
--! @return true if service is active, false otehrwise
function os_utils.isActive(service_name, ...)
  return(os_utils.serviceStatus(service_name, ...) == "active")
end

-- ########################################################

function os_utils.isEnabled(service_name, ...)
   local rv = os_utils.execWithOutput(ntopctl_cmd(service_name, "is-enabled", ...))
   return(rv == "enabled")
end

-- ########################################################

return os_utils

