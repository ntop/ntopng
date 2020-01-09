--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "alert_utils"
require "snmp_utils"

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")

local do_benchmark = true          -- Compute benchmarks and store their results
local do_print_benchmark = false   -- Print benchmarks results to standard output
local do_trace = false             -- Trace lua calls

local config_alerts = nil
local available_modules = nil
local ifid = nil
local confisets = nil
local snmp_device_entity = alert_consts.alert_entities.snmp_device.entity_id

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if do_trace then print("alert.lua:setup("..str_granularity..") called\n") end

   interface.select(getSystemInterfaceId())
   ifid = interface.getId()
   local ifname = getInterfaceName(tostring(ifid))

   -- Load the threshold checking functions
   available_modules = user_scripts.load(ifid, user_scripts.script_types.snmp_device, "snmp_device", {
      do_benchmark = do_benchmark,
   })

   configsets = user_scripts.getConfigsets()
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("alert.lua:teardown("..str_granularity..") called\n") end

   user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
end

-- #################################################################

local cur_granularity

local function snmp_device_run_user_scripts(snmp_device)
   local granularity = cur_granularity
   local device_ip  = snmp_device.get_device_info()["host"]
   local device = snmp_device.get_device()
   local snmp_device_entity = alerts_api.snmpDeviceEntity(device_ip)
   local device_interfaces = snmp_device.merge_interfaces_data()
   local all_modules = available_modules.modules

   local info = {
      granularity = granularity,
      alert_entity = snmp_device_entity,
      interfaces = device_interfaces,
      user_script = check,
      system = device["system"],
   }

   local device_conf = user_scripts.getHostTargetConfigset(configsets, "snmp_device", device_ip)

   -- Run callback for each device
   for mod_key, hook_fn in pairs(available_modules.hooks["snmpDevice"] or {}) do
      local script = all_modules[mod_key]
      local conf = user_scripts.getTargetHookConfig(device_conf, script)

      hook_fn(device_ip, info, conf)
   end

   -- Run callback for each interface
   for mod_key, hook_fn in pairs(available_modules.hooks["snmpDeviceInterface"] or {}) do
      local script = all_modules[mod_key]
      local conf = user_scripts.getTargetHookConfig(device_conf, script)

      -- For each interface of the current device...
      for snmp_interface_index, snmp_interface in pairs(device_interfaces) do
	 local if_type = snmp_iftype(snmp_interface.type)
	 local do_call = true

	 if(script.skip_virtual_interfaces and
	       ((if_type == "propVirtual") or (if_type == "softwareLoopback"))) then
	    do_call = false
	 end

	 if(do_call) then
	    local iface_entity = alerts_api.snmpInterfaceEntity(device_ip, snmp_interface_index)

	    hook_fn(device_ip, snmp_interface_index, table.merge(snmp_interface, {
	       granularity = granularity,
	       alert_entity = iface_entity,
	       user_script = script,
	       conf = conf,
	    }))
	 end
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
   local snmpdevs = get_snmp_devices()

   for _, device in pairs(snmpdevs) do
      local snmp_device = require "snmp_device"
      snmp_device.init(device["ip"])

      snmp_device_run_user_scripts(snmp_device)
   end
end
