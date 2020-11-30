--
-- (C) 2019-20 - ntop.org
--

local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local alerts_api = require "alerts_api"
local alert_utils = require "alert_utils"
local user_scripts = require("user_scripts")
local callback_utils = require "callback_utils"

local UNEXPECTED_DEV_CONN_PLUGINS_ENABLED_CACHE_KEY = "ntopng.cache.user_scripts.unexpected_new_device_plugins_enabled"

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

local function check_allowed_mac(params)
   -- Saving the mac address list into a local variable and swapping keys with value due to performance issues 
   local mac_list = {}

   for key, mac in ipairs(params.user_script_config.items) do
      mac_list[mac] = 1
   end

   -- Retrieving the if id 
   local ifid = interface.getId()
   local seen_devices_hash = getFirstSeenDevicesHashKey(ifid)
   -- Retrieving the list of the addresses already seen
   local seen_devices = ntop.getHashAllCache(seen_devices_hash) or {}

   -- Loop throught all the devices and check if their mac address was already seen before
   -- if not checks the mac address permitted list and throw an alarm
   callback_utils.foreachDevice( getInterfaceName(ifid), 
                                 function(devicename, devicestats, devicebase)
      -- note: location is always lan when capturing from a local interface
      if (not devicestats.special_mac) and (devicestats.location == "lan") then
         local mac = devicestats.mac

         -- First time we see a device
         if not seen_devices[mac] then
            seen_devices[mac] = 1
            -- Add the mac address to the already seen addresses
            ntop.setHashCache(seen_devices_hash, mac, tostring(os.time()))

            local device = getDeviceName(mac)
            setSavedDeviceName(mac, device)

            -- Check if the new mac address is expected or not
            if not mac_list[mac] then
               alerts_api.store(
                  alerts_api.macEntity(mac),
                  alert_consts.alert_types.alert_unexpected_new_device.create(
                     alert_severities.warning,
                     device,
                     mac
                  )
               )
            end
         end
      end
   end)
end

-- #################################################################

script = {
   -- Script category
   category = user_scripts.script_categories.network,

   default_enabled = true,

   -- This script is only for alerts generation
   is_alert = true,

   -- Specify the default value whe clicking on the "Reset Default" button
   default_value = {
	  items = {},
   },

   hooks = {
      min = check_allowed_mac,
   },

   gui = {
	i18n_title        = "unexpected_new_device.unexpected_new_device_title",
	i18n_description  = "unexpected_new_device.unexpected_new_device_description",

	input_builder     = "items_list",
	item_list_type    = "mac_address",
	input_title       = i18n("unexpected_new_device.title"),
   input_description = i18n("unexpected_new_device.description"),
   
   -- input_action_i18n = "Action Button",
   -- input_action_url = "lua/rest/v1/delete/host/pool.lua",
   -- input_action_confirm = true,
   -- input_action_i18n_confirm = "Would you like to confirm the action",
   },
}

-- #################################################################

return script
