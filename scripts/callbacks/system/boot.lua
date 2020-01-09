--
-- (C) 2013-20 - ntop.org
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

local prefs_dump_utils = require "prefs_dump_utils"
prefs_dump_utils.readPrefsFromDisk()

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
   require("boot")
end

if not ntop.isnEdge() then -- nEdge data deletion is handled in nf_config.lua
   local delete_data_utils = require "delete_data_utils"

   delete_data_utils.delete_pcap_dump_interfaces_data()

   if delete_data_utils.delete_active_interface_data_requested() then
      traceError(TRACE_NORMAL, TRACE_CONSOLE, "Deleting data for marked active interfaces...")

      local res = delete_data_utils.delete_active_interfaces_data()

      delete_data_utils.clear_request_delete_active_interface_data()

      traceError(TRACE_NORMAL, TRACE_CONSOLE, "Data deletion done.")
   end
end
