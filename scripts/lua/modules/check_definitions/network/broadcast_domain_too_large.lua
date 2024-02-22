--
-- (C) 2019-24 - ntop.org
--

local alert_consts = require("alert_consts")
local alert_categories = require "alert_categories"

local script = {
  -- Script category
  category = alert_categories.network,

  default_enabled = true,

  severity = alert_consts.get_printable_severities().warning,

  -- The default configuration of this script
  default_value = {
    items = {},
  },

  -- See below
  hooks = {},

  gui = {
    i18n_title        = "broadcast_domain_too_large_title",
    i18n_description  = "broadcast_domain_too_large_description",
  }
}

-- #################################################################

function script.onEnable(hook, hook_config)
  ntop.setPref("ntopng.prefs.is_broadcast_domain_too_large_enabled", 1)
end

-- #################################################################

function script.onDisable(hook, hook_config)
  ntop.setPref("ntopng.prefs.is_broadcast_domain_too_large_enabled", 0)
end

-- #################################################################

script.hooks["min"] = function(params)
  return
end

-- #################################################################

return script
