--
-- (C) 2020 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require "alert_consts"
local checks = require("checks")

local script

-- #################################################################

local function check_network_discovery(params)
   -- Get total number of packets, flows and interface id
   local network_discovery_check = alert_consts.alert_types.alert_network_discovery_executed.new()

   network_discovery_check:set_score_notice()
   network_discovery_check:set_subtype(getInterfaceName(interface.getId()))
   network_discovery_check:set_granularity(params.granularity)
   
   local discovery_executed = ntop.getCache("ntopng.cache.network_discovery_executed.ifid_" .. interface.getId()) == "1"

   if discovery_executed == true then
      ntop.delCache("ntopng.cache.network_discovery_executed.ifid_" .. interface.getId())
      network_discovery_check:store(params.alert_entity)
   end
end

-- #################################################################

script = {
   -- Script category
   category = checks.check_categories.network,

   default_enabled = true,
   hooks = {
      -- Time past between one call and an other
      min = check_network_discovery,
   },

   gui = {
      i18n_title        = "network_discovery.network_discovery_title",
      i18n_description  = "network_discovery.network_discovery_description",
   }
}

-- #################################################################

return script
