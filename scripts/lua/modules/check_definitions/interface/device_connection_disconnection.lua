--
-- (C) 2019-22 - ntop.org
--

local alert_consts = require "alert_consts"
local checks = require("checks")
local callback_utils = require "callback_utils"

-- #################################################################

local script

-- ###########################################

local function check_allowed_mac(params)
  local ifid = interface.getId()
  local seen_devices_hash = getDevicesHashMapKey(ifid)
  
  -- Retrieving the list of the addresses already seen (both allowed and disallowed) and whitelisted
  local seen_devices = ntop.getHashAllCache(seen_devices_hash) or {}

  callback_utils.foreachDevice(getInterfaceName(ifid), function(devicename, devicestats, devicebase)
    local mac_addr = devicestats["mac"]:upper()

    local alert = alert_consts.alert_types.alert_device_connection_disconnection.new(
      mac_addr
    )

    alert:set_score_warning()
    alert:set_subtype(getInterfaceName(ifid))
    alert:set_device_type(devicestats["devtype"])
    alert:set_device_name(mac_addr)
    alert:set_granularity(params.granularity)

    if (devicestats["location"] == "lan") and not (devicestats["special_mac"]) then
      -- This is a LAN MAC address, let's trigger an alert   
      -- Add this mac to the seen devices on the network
      ntop.setHashCache(seen_devices_hash, mac_addr:upper(), 'denied')
      alert:trigger(params.alert_entity, nil, params.cur_alerts)
    elseif (seen_devices[mac_addr]) and (seen_devices[mac_addr] == 'allowed') then
      -- No alert needs to be triggered or a MAC has been moved from denied to allowed
      alert:release(params.alert_entity, nil, params.cur_alerts)
    end
  end)
end

-- #################################################################

script = {
  -- Script category
  category = checks.check_categories.network,
  default_enabled = false,

  hooks = {
      min = check_allowed_mac,
  },

  gui = {
    i18n_title        = "checks.device_connection_disconnection_title",
    i18n_description  = "checks.device_connection_disconnection_description",
  },
}

-- #################################################################

return script
