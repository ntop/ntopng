--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"
local snmp_device_pools = require "snmp_device_pools"
local snmp_utils = require "snmp_utils"
local snmp_consts = require "snmp_consts"

local alerts_api = require("alerts_api")
local checks = require("checks")
local alert_consts = require("alert_consts")
local snmp_config = require "snmp_config"
local snmp_cached_dev = require "snmp_cached_dev"

local do_benchmark = false         -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls

local config_alerts = nil
local available_modules = nil
local ifid = nil
local configset = nil
local pools_instance = nil
local snmp_device_entity = alert_consts.alert_entities.snmp_device.entity_id

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if do_trace then print("alert.lua:setup("..str_granularity..") called\n") end

   interface.select(getSystemInterfaceId())
   ifid = interface.getId()
   local ifname = getInterfaceName(tostring(ifid))

   -- Load the threshold checking functions
   available_modules = checks.load(ifid, checks.script_types.snmp_device, "snmp_device", {
      do_benchmark = do_benchmark,
   })

   configset = checks.getConfigset()
   -- Instance of snmp device pools to get assigned members
   pools_instance = snmp_device_pools:create()
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("alert.lua:teardown("..str_granularity..") called\n") end

   checks.teardown(available_modules, do_benchmark, do_print_benchmark)
end

-- #################################################################

local cur_granularity

local function snmp_device_run_checks(cached_device)
   local granularity = cur_granularity
   local device_ip  = cached_device["host_ip"]
   local snmp_device_entity = alerts_api.snmpDeviceEntity(device_ip)
   local all_modules = available_modules.modules
   local now = os.time()
   now = now - now % 300

   local info = {
      granularity = granularity,
      alert_entity = snmp_device_entity,
      check = check,
      cached_device = cached_device,
      now = now,
   }

   -- Retrieve the configuration
   local device_conf = checks.getConfig(configset, "snmp_device")

   -- Run callback for each device
   for mod_key, hook_fn in pairs(available_modules.hooks["snmpDevice"] or {}) do
      local script = all_modules[mod_key]
      local conf = checks.getTargetHookConfig(device_conf, script)

      if(conf.enabled) then
        alerts_api.invokeScriptHook(script, configset, hook_fn, device_ip, info, conf)
      end
   end

   -- Run callback for each interface
   for mod_key, hook_fn in pairs(available_modules.hooks["snmpDeviceInterface"] or {}) do
      local script = all_modules[mod_key]
      local conf = checks.getTargetHookConfig(device_conf, script)

      -- For each interface of the current device...
      for snmp_interface_index, snmp_interface in pairs(cached_device.interfaces) do
	 local if_type = snmp_consts.snmp_iftype(snmp_interface.type)

	 if(script.skip_virtual_interfaces and
	       ((if_type == "propVirtual") or (if_type == "softwareLoopback"))) then
	    goto continue
	 end

	 if(conf.enabled) then
	    local iface_entity = alerts_api.snmpDeviceEntity(device_ip) -- Use the same entity as for the global device
	    -- Augment data with counters and status
	    snmp_interface["if_counters"] = cached_device.if_counters[snmp_interface_index]
	    snmp_interface["bridge"] = cached_device.bridge[snmp_interface_index]

	    alerts_api.invokeScriptHook(script, configset, hook_fn, device_ip, snmp_interface_index, table.merge(snmp_interface, {
	       granularity = granularity,
	       alert_entity = iface_entity,
	       check = script,
	       conf = conf.script_conf,
	       now = now,
	    }))
	 end

	 ::continue::
      end
   end

   return true
end

-- #################################################################

-- The function below is called once per local snmp_device
function runScripts(granularity)
   cur_granularity = granularity

   if(table.empty(available_modules.hooks)) then
      -- Nothing to do
      return
   end

   -- NOTE: don't use foreachSNMPDevice, we want to get all the SNMP
   -- devices, not only the active ones, without changing the device state
   local snmpdevs = snmp_config.get_all_configured_devices()

   for device_ip, device in pairs(snmpdevs) do
      local cached_device = snmp_cached_dev:create(device_ip)

      if cached_device then
	 snmp_device_run_checks(cached_device)
      end
   end
end
