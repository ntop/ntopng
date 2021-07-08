--
-- (C) 2019-21 - ntop.org
--

local alert_consts = require "alert_consts"
local alerts_api = require "alerts_api"
local alert_utils = require "alert_utils"
local checks = require("checks")
local callback_utils = require "callback_utils"

-- #################################################################

local script

-- #################################################################

local function check_allowed_mac(params)
   -- Holds a per-interface timestamp
   local prev_first_seen_key = string.format("ntopng.cache.ifid_%d.unexpected_new_device.prev_first_seen", interface.getId())
   -- Saving the mac address list into a local variable and swapping keys with value due to performance issues
   local mac_list = {}

   -- This is the whitelist, that is, MACs configured here won't trigger any alert
   for key, mac in ipairs(params.check_config.items) do
      mac_list[mac:upper()] = 1
   end

   -- Keep the current time
   local cur_first_seen = os.time()

   -- Read the previous time, that is, the time of the previous script execution
   local prev_first_seen = tonumber(ntop.getCache(prev_first_seen_key))

   if prev_first_seen then
      -- If here, this is not the first run

      local macs_stats = interface.getMacsInfo(nil --[[ sortColumn --]], nil --[[ perPage --]], nil --[[ to_skip --]],
					       nil --[[ sOrder --]], nil --[[ source_macs_only --]], nil --[[ manufacturer --]],
					       nil, nil --[[ device_type --]], "", prev_first_seen)

      -- tprint("processing interface: ".. interface.getId().." prev_first_seen: "..formatEpoch(prev_first_seen).." cur_first_seen: "..formatEpoch(cur_first_seen))

      for _, mac in pairs(macs_stats["macs"] or {}) do
	 local addr = mac["mac"]:upper()
	 -- tprint("processing: ".. addr.. " first_seen: "..formatEpoch(mac["seen.first"]).. " prev_first_seen: "..formatEpoch(prev_first_seen).." cur_first_seen: "..formatEpoch(cur_first_seen))

	 if mac["seen.first"] >= cur_first_seen then
	    -- Will be processed during the next execution (this avoids processing items twice)
	    goto continue
	 end

	 if mac_list[addr] then
	    -- MAC belongs to the whitelist, no alert
	    goto continue
	 end

	 if mac["location"] == "lan" and not mac["special_mac"] then
	    -- This is a LAN MAC address, let's trigger an alert
	    local device = getDeviceName(addr)

	    -- Check if the new mac address is expected or not
	    local alert = alert_consts.alert_types.alert_unexpected_new_device.new(
	       device,
	       addr
	    )

	    alert:set_score_warning()
	    alert:set_subtype(device)
	    alert:set_device_type(mac["devtype"])
	    alert:set_device_name(device)

	    alert:store(alerts_api.macEntity(addr))
	 end

	 ::continue::
      end
   end

   -- Store the current time so that it will be read again during the next execution
   ntop.setCache(prev_first_seen_key, tostring(cur_first_seen))
end

-- #################################################################

script = {
   -- Script category
   category = checks.check_categories.network,

   default_enabled = false,


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

      input_action_i18n = "Reset Learned Devices",
      input_action_url = "lua/rest/v2/delete/host/new_devices.lua",
      input_action_confirm = true,
      input_action_i18n_confirm = "Are you sure to reset the learned devices?",
   },
}

-- #################################################################

return script
