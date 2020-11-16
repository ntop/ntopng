--
-- (C) 2019-20 - ntop.org
--

local alert_consts = require "alert_consts"
local alerts_api = require "alerts_api"
local alert_utils = require "alert_utils"
local user_scripts = require("user_scripts")
local callback_utils = require "callback_utils"

-- #################################################################

local script

-- #################################################################

local function getSavedDeviceNameKey(mac)
   return "ntopng.cache.devnames." .. mac
end

-- #################################################################

local function setSavedDeviceName(mac, name)
   local key = getSavedDeviceNameKey(mac)
   ntop.setCache(key, name)
end

-- #################################################################

function getSavedDeviceName(mac)
   local key = getSavedDeviceNameKey(mac)
   return ntop.getCache(key)
end

-- #################################################################

local function check_device_connection_disconnection(params)
   local ifid = interface.getId()
   local active_devices_set = alert_utils.getActiveDevicesHashKey(ifid)
   local prev_active_devices = swapKeysValues(ntop.getMembersCache(active_devices_set) or {})
   local num_prev_active_devices = table.len(prev_active_devices)

   local seen_devices_hash = getFirstSeenDevicesHashKey(ifid)
   local seen_devices = ntop.getHashAllCache(seen_devices_hash) or {}
   local num_seen_devices = table.len(seen_devices)

   local max_active_devices_cardinality = 16384
   if(num_seen_devices >= max_active_devices_cardinality) then
      traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Too many active devices, discarding %u devices", num_seen_devices))
      ntop.delCache(active_devices_set)
      prev_active_devices = {}
   end

   local active_devices = {}
   callback_utils.foreachDevice(getInterfaceName(ifid), function(devicename, devicestats, devicebase)
				   -- note: location is always lan when capturing from a local interface
				   if (not devicestats.special_mac) and (devicestats.location == "lan") then
				      local mac = devicestats.mac

				      active_devices[mac] = 1

				      if not prev_active_devices[mac] then
					 -- Device connection
					 ntop.setMembersCache(active_devices_set, mac)

					 -- Do not nofify new connected devices if the prev_active_devices
					 -- set was empty (cleared or on startup)
					 if num_prev_active_devices > 0 then

					    local name = getDeviceName(mac)
					    setSavedDeviceName(mac, name)

					    alerts_api.store(
					       alerts_api.macEntity(mac),
					       alert_consts.alert_types.alert_device_connection.create(
						  alert_consts.alert_severities.notice,
						  name
					       )
					    )
					 end
				      end
				   end
   end)

   -- Safety check to avoid notifying disconnected devices
   -- during shutdown when they are no longer active in ntopng.
   if not ntop.isShutdown() then
      for mac in pairs(prev_active_devices) do
	 if not active_devices[mac] then
	    -- Device disconnection
	    local name = getSavedDeviceName(mac)
	    ntop.delMembersCache(active_devices_set, mac)

	    alerts_api.store(
	       alerts_api.macEntity(mac),
	       alert_consts.alert_types.alert_device_disconnection.create(
		  alert_consts.alert_severities.notice,
		  name
	       )
	    )
	 end
      end
   end
end

-- #################################################################

script = {
   -- Script category
   category = user_scripts.script_categories.network,

   default_enabled = false,

   -- This script is only for alerts generation
   is_alert = true,

   hooks = {
      min = check_device_connection_disconnection,
   },

   gui = {
      i18n_title = "device_connection_disconnection.title",
      i18n_description = "device_connection_disconnection.description",
   },
}

-- #################################################################

return script
