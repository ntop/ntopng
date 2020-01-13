--
-- (C) 2019-20 - ntop.org
--

local user_scripts = require("user_scripts")
local flow_consts = require("flow_consts")

local script = {
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
    i18n_title = "blacklisted_country.title",
    i18n_description = "blacklisted_country.description",
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
  local info = {}

  if(cli_country and blacklisted_countries[cli_country]) then
    info.cli_blacklisted = true
    is_blacklisted = true
  end

  if(srv_country and blacklisted_countries[srv_country]) then
    info.srv_blacklisted = true
    is_blacklisted = true
  end

  if(is_blacklisted) then
    -- Note: possibly nil
    info.cli_country = cli_country
    info.srv_country = srv_country

    flow.triggerStatus(flow_consts.status_types.status_blacklisted_country.status_id, info)
  end
end

-- #################################################################

return script
