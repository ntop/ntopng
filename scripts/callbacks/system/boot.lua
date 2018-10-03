--
-- (C) 2013-18 - ntop.org
--

--
-- This script is executed once at boot
-- * BEFORE * network interfaces are setup
-- * BEFORE * switching to nobody
--
-- ** PLEASE PAY ATTENTION TO WHAT YOU EXECUTE ON THIS FILE **
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "alert_utils"

local prefs_dump_utils = require "prefs_dump_utils"
prefs_dump_utils.readPrefsFromDisk()

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
   require("boot")
end

if not ntop.isnEdge() then -- nEdge data deletion is handled in nf_config.lua
   local delete_data_utils = require "delete_data_utils"

   if delete_data_utils.delete_active_interface_data_requested() then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "Deleting data for marked active interfaces...")

      local res = delete_data_utils.delete_active_interfaces_data()

      -- TODO: make a single error logging function together with nf_config.lua
      for op, op_res in pairs(res or {}) do
	 local trace_level = TRACE_NORMAL
	 local status = op_res["status"]

	 if status ~= "OK" then
	    trace_level = TRACE_ERROR
	 end

	 traceError(trace_level, TRACE_CONSOLE, string.format("Deleting data [%s][%s]", op, status))
      end

      delete_data_utils.clear_request_delete_active_interface_data()

      traceError(TRACE_NORMAL, TRACE_CONSOLE, "Data deletion done.")
   end
end
