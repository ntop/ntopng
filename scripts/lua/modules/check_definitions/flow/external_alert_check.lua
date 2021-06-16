--
-- (C) 2019-21 - ntop.org
--

local json = require ("dkjson")
local checks = require ("checks")
local alert_consts = require("alert_consts")
local alerts_api = require "alerts_api"
local flow_alert_keys = require "flow_alert_keys"

-- #################################################################

local script = {
   alert_id = flow_alert_keys.flow_alert_external,

   gui = {
      i18n_title = "flow_checks_config.ext_alert",
      i18n_description = "flow_checks_config.ext_alert_description",
   }
}

-- #################################################################

return script
