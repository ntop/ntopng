--
-- (C) 2019 - ntop.org
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
local snmp_device_entity = alert_consts.alert_entities.snmp_device.entity_id

-- The function below ia called once (#pragma once)
function setup(str_granularity)
   if do_trace then print("alert.lua:setup("..str_granularity..") called\n") end

   interface.select(getSystemInterfaceId())
   ifid = interface.getId()
   local ifname = getInterfaceName(tostring(ifid))

   -- Load the threshold checking functions
   available_modules = user_scripts.load(user_scripts.script_types.snmp_device, ifid, "snmp_device", nil --[[ load all hooks --]], nil, do_benchmark)

   -- config_alerts = getNetworksConfiguredAlertThresholds(ifname, str_granularity, available_modules.modules)
end

-- #################################################################

-- The function below ia called once (#pragma once)
function teardown(str_granularity)
   if(do_trace) then print("alert.lua:teardown("..str_granularity..") called\n") end

   user_scripts.teardown(available_modules, do_benchmark, do_print_benchmark)
end

-- #################################################################

local cur_granularity

local function snmp_device_interfaces_check_alerts(snmp_device, deadline)
   local do_call = true
   local granularity = cur_granularity

   local device_ip         = snmp_device.get_device_info()["host"]
   local device_interfaces = snmp_device.get_device()["interfaces"] or {}
   local device_if_status  = snmp_device.get_device()["interfaces_status"] or {}
   local device_counters   = snmp_device.get_device()["counters"] or {}
   local device_bridge     = snmp_device.get_device()["bridge"] or {}

   -- For each callback that needs to be called on the interfaces...
   for mod_key, hook_fn in pairs(available_modules.hooks["snmpDeviceInterface"]) do
      local check = available_modules.modules[mod_key]

      -- For each interface of the current device...
      for snmp_interface_index, snmp_interface in pairs(device_interfaces) do
	 local entity_info = alerts_api.snmpInterfaceEntity(device_ip, snmp_interface_index)
	 local info = {
	    snmp_device_ip = device_ip,
	    snmp_interface = snmp_interface,
	    if_status = device_if_status[snmp_interface_index],
	    if_counters = device_counters[snmp_interface_index],
	    if_bridge = device_bridge[snmp_interface_index]}

	 if(do_call) then
	    hook_fn({
	    	  granularity = granularity,
	    	  alert_entity = entity_info,
	    	  entity_info = info,
	    	  cur_alerts = cur_alerts,
	    	  alert_config = config,
	    	  user_script = check,
	    })
	 end
      end
   end

   return true
end

-- #################################################################

-- The function below is called once per local snmp_device
function checkAlerts(granularity)
   cur_granularity = granularity

   if not table.empty(available_modules.hooks["snmpDeviceInterface"]) then
      local in_time = foreachSNMPDevice(snmp_device_interfaces_check_alerts, nil --[[ snmp_rrds_enabled --]], nil --[[ deadline --]])
   end
end
