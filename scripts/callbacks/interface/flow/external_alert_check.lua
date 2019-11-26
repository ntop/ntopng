--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")
local json = require ("dkjson")
local user_scripts = require ("user_scripts")

-- #################################################################

local script = {
  -- NOTE: hooks defined below
  hooks = {},
  periodic_update_seconds = 30,

  gui = {
    i18n_title = "flow_callbacks_config.ext_alert",
    i18n_description = "flow_callbacks_config.ext_alert_description",
  }
}

-- #################################################################

function script.hooks.periodicUpdate(now)
  local ext_alert_info = flow.retrieveExternalAlertInfo()

  if(ext_alert_info ~= nil) then
    -- NOTE: the same info will *not* be returned in the next periodicUpdate
    local info = json.decode(ext_alert_info)
    if info ~= nil then
      flow.triggerStatus(flow_consts.status_types.status_external_alert.status_id, 
        info, info.severity_id)
    end
  end
end

-- #################################################################

return script
