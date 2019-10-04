--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local check_module

-- #################################################################

local function check_ghost_networks(params)
  for domain, domain_info in pairs(params.entity_info.bcast_domains or {}) do
    if(domain_info.ghost_network) then
      local key = params.check_module.key .. "__" .. domain
      local delta_hits = alerts_api.interface_delta_val(key, params.granularity, domain_info.hits)
      local ghost_network_type = alerts_api.ghostNetworkType(domain, params.granularity)

      if(delta_hits > 0) then
        alerts_api.trigger(params.alert_entity, ghost_network_type)
      else
        alerts_api.release(params.alert_entity, ghost_network_type)
      end
    end
  end
end

-- #################################################################

check_module = {
  key = "ghost_networks",
  granularity = {"min"},
  always_enabled = true,
  check_function = check_ghost_networks,
}

-- #################################################################

return check_module
