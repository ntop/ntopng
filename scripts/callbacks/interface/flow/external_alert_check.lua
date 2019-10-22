--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")
local json = require ("dkjson")

-- #################################################################

local script = {
  key = "external_alert",

  -- NOTE: hooks defined below
  hooks = {},
}

-- #################################################################

function script.setup()
  local enabled = (ntop.getPref("ntopng.prefs.external_alerts") == "1")
  return(enabled)
end

-- #################################################################

function script.hooks.periodicUpdate(params)
  local ext_alert_info = flow.retrieveExternalAlertInfo()

  if ext_alert_info ~= nil then
    -- NOTE: the same info will *not* be returned in the next periodicUpdate
    local info = json.decode(ext_alert_info)
    if info ~= nil then
      flow.triggerStatus(flow_consts.status_types.status_external_alert.status_id, ext_alert_info, info.severity_id --[[ specify a custom severity ]])
    end
  end
end

-- #################################################################

return script
