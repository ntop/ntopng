--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path
  pcall(require, '5min')

  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
  require "snmp_utils"
end

require "lua_utils"

-- ########################################################

-- This must be placed at the end of the script
if ntop.isPro() then
   local rrd_dump = require "rrd_5min_dump_utils"     
   local verbose = ntop.verboseTrace()
   local config = rrd_dump.getConfig()
   local when = os.time()
   local time_threshold = when - (when % 300) + 300 - 10 -- safe margin

   local snmp_rrds_enabled = tostring(config.snmp_devices_rrd_creation) == "1"
   local snmpdevs = get_snmp_devices()

   for _,device in pairs(snmpdevs) do
      local snmp_device = require "snmp_device"

      if isSNMPDeviceUnresponsive(device["ip"]) or is_snmp_polling_disabled(device["ip"]) then
	 goto next_device
      end

      snmp_device.init(device["ip"])
      local cache_status = snmp_device.get_cache_status()

      if true then -- TODO: refine a policy to update bridge information
	 local res = snmp_device.cache_bridge()
	 if res["status"] ~= "OK" then
	    snmp_handle_cache_errors(device["ip"], res)
	    goto next_device
	 end
      end

      if true then -- TODO: refine a policy to interfaces information
	 local res = snmp_device.cache_interfaces()
	 if res["status"] ~= "OK" then
	    snmp_handle_cache_errors(device["ip"], res)
	    goto next_device
	 end
      end


      if true then -- TODO: refine a policy to interfaces status information
	 local res = snmp_device.cache_interfaces_status()
	 if res["status"] ~= "OK" then
	    snmp_handle_cache_errors(device["ip"], res)
	    goto next_device
	 end

	 snmp_check_device_interfaces_status_change(snmp_device)
      end

      if true then -- TODO: refine a policy to update interface counters (once every 1 minute or 10 minutes should be fine)
	 local res = snmp_device.cache_counters()
	 if res["status"] ~= "OK" then
	    snmp_handle_cache_errors(device["ip"], res)
	    goto next_device
	 end
      end

      if snmp_rrds_enabled then
	 local counters = snmp_device.get_device()["counters"]
	 snmp_update_interface_counters(device, counters)
      end

      ::next_device::
   end
end
