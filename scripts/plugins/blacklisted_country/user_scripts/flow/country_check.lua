--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local flow_consts = require("flow_consts")

local script = {
  -- Script category
  category = user_scripts.script_categories.security, 

  -- This module is disabled by default
  default_enabled = false,

  -- The default configuration of this script
  default_value = {
    items = {},
  },

  -- See below
  hooks = {},

  -- Allow user script configuration from the GUI
  gui = {
    -- Localization strings, from the "locales" directory of the plugin
    i18n_title = "alerts_dashboard.blacklisted_country",
    i18n_description = "alerts_dashboard.blacklisted_country_descr",
    input_builder = "items_list",
    item_list_type = "country",
  }
}

-- #################################################################

-- A fast lookup table
local blacklisted_countries = nil

-- Defines an hook which is executed every time a procotol of a flow is detected
function script.hooks.protocolDetected(now, conf)
  if(blacklisted_countries == nil) then
    blacklisted_countries = {}

    for _, country in pairs(conf.items or {}) do
      blacklisted_countries[string.upper(country)] = true
    end
  end

  local cli_country = flow.getClientCountry()
  local srv_country = flow.getServerCountry()
  local is_blacklisted = false
  local flow_score = 60
  local cli_score, srv_score
  local info = {cli_blacklisted = false, srv_blacklisted = false}

  if(cli_country and blacklisted_countries[cli_country]) then
    info.cli_blacklisted = true
    is_blacklisted = true
    cli_score = 60
    srv_score = 10
  end

  if(srv_country and blacklisted_countries[srv_country]) then
    info.srv_blacklisted = true
    is_blacklisted = true
    cli_score = 10
    srv_score = 60
  end

  if(is_blacklisted) then
    -- Note: possibly nil
    info.cli_country = cli_country
    info.srv_country = srv_country

    flow.triggerStatus(
       flow_consts.status_types.status_blacklisted_country.create(
	  flow_consts.status_types.status_blacklisted_country.alert_severity,
	  cli_country,
	  srv_country,
	  info.cli_blacklisted,
	  info.srv_blacklisted
       ),
       flow_score,
       cli_score,
       srv_score
    )
  end
end

-- #################################################################

return script
