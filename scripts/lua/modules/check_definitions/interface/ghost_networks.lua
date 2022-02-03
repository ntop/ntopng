--
-- (C) 2019-21 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local checks = require("checks")
local script

-- #################################################################

local function check_ghost_networks(params)
   for domain, domain_info in pairs(params.entity_info.bcast_domains or {}) do
    if(domain_info.ghost_network) then
      local key = params.check.key .. "__" .. domain
      local delta_hits = alerts_api.interface_delta_val(key, params.granularity, domain_info.hits)

      local alert = alert_consts.alert_types.alert_ghost_network.new(domain)

      alert:set_score_warning()
      alert:set_granularity(params.granularity)
      alert:set_subtype(domain)

      if(delta_hits > 0) then
        alert:trigger(params.alert_entity, nil, params.cur_alerts)
      else
        alert:release(params.alert_entity, nil, params.cur_alerts)
      end
    end
  end
end

-- #################################################################

script = {
  -- Script category
  category = checks.check_categories.security,

  default_enabled = true,


  hooks = {
    min = check_ghost_networks,
  },

  gui = {
    i18n_title = "alerts_dashboard.ghost_networks",
    i18n_description = "alerts_dashboard.ghost_networks_description",
  },
}

-- #################################################################

return script
