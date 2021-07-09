--
-- (C) 2013-21 - ntop.org
--

--
-- This script is executed once at boot (normally as root)
-- * BEFORE * network interfaces are setup
-- * BEFORE * switching to nobody
--
-- ** PLEASE PAY ATTENTION TO WHAT YOU EXECUTE ON THIS FILE **
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local prefs_dump_utils = require "prefs_dump_utils"

-- Check connectivity
local connectivity_utils = require "connectivity_utils"
local online = connectivity_utils.checkConnectivity()
if not online then
   traceError(TRACE_WARNING, TRACE_CONSOLE, "No connectivity detected, ntopng will run in offline mode")
   ntop.setOffline()
end

-- Check and possibly restore preferences dumped to file
prefs_dump_utils.check_restore_prefs_from_disk()

-- Check and possibly perform a factory reset of preferences
prefs_dump_utils.check_prefs_factory_reset()

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
   require("boot")
end

if not ntop.isnEdge() then -- nEdge data deletion is handled in nf_config.lua
   local delete_data_utils = require "delete_data_utils"

   delete_data_utils.delete_pcap_dump_interfaces_data()

   if delete_data_utils.delete_active_interface_data_requested() then
      traceError(TRACE_INFO, TRACE_CONSOLE, "Deleting data for marked active interfaces...")

      local res = delete_data_utils.delete_active_interfaces_data()

      delete_data_utils.clear_request_delete_active_interface_data()

      traceError(TRACE_INFO, TRACE_CONSOLE, "Data deletion done.")
   end
end

if ntop.isAppliance() then
   package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path

   local appliance_config = require("appliance_config"):create()

   if not appliance_config.isFirstStart() then
      if appliance_config:getOperatingMode() == "bridging" then
         local br_name = appliance_config:getBridgeInterfaceName()
         if br_name ~= nil then
           ntop.overrideInterface(br_name);
         end
      end
   end
end

-- NOTE: cannot reload plugins here as we must first drop the privileges
-- They will be loaded in startup.lua . Here we only delete old directories.
local plugins_utils = require "plugins_utils"
plugins_utils.cleanup()

-- Check if there is a local file to run
local local_boot_file = "/usr/share/ntopng/local/scripts/callbacks/system/boot.lua"

if(ntop.exists(local_boot_file)) then
   traceError(TRACE_NORMAL, TRACE_CONSOLE, "Running "..local_boot_file)
   dofile(local_boot_file)
end

