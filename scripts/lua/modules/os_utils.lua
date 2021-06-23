--
-- (C) 2014-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local tracker = require "tracker"

local os_utils = {}

local is_windows = ntop.isWindows()
local is_freebsd = ntop.isFreeBSD()

local dirs = ntop.getDirs()
local NTOPCTL_CMD = dirs.bindir.."/ntopctl"
local NTOPNG_CONFIG_TOOL = dirs.bindir.."/ntopng-utils-manage-config"

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

--! @brief Copy a `source` file to `dest`
function os_utils.copyFile(source, dest)
   if not ntop.exists(source) then
      return
   end

   local inp = assert(io.open(source, "rb"))
   local out = assert(io.open(dest, "wb"))

   local data = inp:read("*all")
   out:write(data)

   assert(out:close())
end

-- ########################################################

--! @brief Execute a system command and return its output
--! @return the pair (output, ret_code). output will be nil on error.
--! @note error condition is determined from the command exit status
--! @note redirect the stderr of the command if the command is expected to fail
function os_utils.execWithOutput(c, ret_code_success)
   local debug = false
   local f_name = nil 
   local f 

   ret_code_success = ret_code_success or 0

   if(is_windows) then
      return nil
   end

   if(debug) then tprint(c) end

   if is_freebsd then
      f_name = os.tmpname()
      os.execute(c.." > "..f_name)
      f = io.open(f_name, 'r')
   else
      f = io.popen(c, 'r')
   end  

   if f == nil then
      return nil, -1
   end
  
   local ret_string = f:read('*a')

   if ret_string ~= nil then
      if(debug) then tprint(s) end
   end
   
   local rv = { f:close() }

   local retcode = ret_code_success

   if f_name then
      os.remove(f_name)
   else
      retcode = rv[3]
   end

   if retcode ~= ret_code_success then
      return nil, retcode
   end

   return ret_string, retcode
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

   if not isEmptyString(prefs.user) 
      and prefs.user ~= "ntopng"
      and prefs.user ~= "root" then
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

local now = os.time()

function os_utils.os2record(ifId, os)
   local discover = require("discover_utils")

   -- Get from redis the throughput type bps or pps
   local throughput_type = getThroughputType()
   local record = {}
   record["key"] = tostring(os["os"])

   if os["os"] ~= nil then
      record["column_id"] = " <A HREF='"..ntop.getHttpPrefix().."/lua/hosts_stats.lua?os=".. os["os"] .."'>" 
      record["column_id"] = record["column_id"] .. discover.getOsAndIcon(os["os"]) .."</A>"
   end

   if((os["num_alerts"] ~= nil) and (os["num_alerts"] > 0)) then
      record["column_alerts"] = "<font color=#B94A48>"..formatValue(value["num_alerts"]).."</font>"
   else
      record["column_alerts"] = "0"
   end

   record["column_chart"] = ""

   if areOSTimeseriesEnabled(ifId) then
      record["column_chart"] = '<A HREF="'..ntop.getHttpPrefix()..'/lua/os_details.lua?os='..os["os"]..'&page=historical"><i class=\'fas fa-chart-area fa-lg\'></i></A>'
   end

   record["column_hosts"] = os["num_hosts"]..""
   record["column_since"] = secondsToTime(now - os["seen.first"] + 1)
   
   local sent2rcvd = round((os["bytes.sent"] * 100) / (os["bytes.sent"] + os["bytes.rcvd"]), 0)
   record["column_breakdown"] = "<div class='progress'><div class='progress-bar bg-warning' style='width: "
      .. sent2rcvd .."%;'>Sent</div><div class='progress-bar bg-success' style='width: " .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>"

   if(throughput_type == "pps") then
      record["column_thpt"] = pktsToSize(os["throughput_pps"])
   else
      record["column_thpt"] = bitsToSize(8*os["throughput_bps"])
   end

   record["column_traffic"] = bytesToSize(os["bytes.sent"] + os["bytes.rcvd"])

   return record
end

-- ########################################################

-- TRACKER HOOK

tracker.track(os_utils, 'enableService')
tracker.track(os_utils, 'disableService')

-- ########################################################

return os_utils

