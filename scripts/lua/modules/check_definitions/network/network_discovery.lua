--
-- (C) 2022 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require "alert_consts"
local checks = require("checks")

local script = {
  -- Script category
  category = checks.check_categories.network,
  severity = alert_consts.get_printable_severities().notice,

  default_enabled = true,
  hooks = {},

  gui = {
     i18n_title        = "checks.network_discovery_title",
     i18n_description  = "checks.network_discovery_description",
  }
}

-- #################################################################

local function check_network_discovery(params)
   -- Get total number of packets, flows and interface id
   local network_discovery_check = alert_consts.alert_types.alert_network_discovery_executed.new()

   network_discovery_check:set_subtype(params)
  
   local discovery_executed = ntop.getCache("ntopng.cache.network_discovery_executed.ifid_" .. interface.getId()) == "1"

   if discovery_executed == true then
      ntop.delCache("ntopng.cache.network_discovery_executed.ifid_" .. interface.getId())
      network_discovery_check:store(params.alert_entity)
   end
end

-- #################################################################

script.hooks.min = check_network_discovery

-- #################################################################

return script
