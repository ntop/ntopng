--
-- (C) 2019 - ntop.org
--

local flow_consts = require("flow_consts")

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
  local ext_info = flow.retrieveExternalAlertInfo()

  if(ext_info ~= nil) then
    -- NOTE: the same info will *not* be returned in the next periodicUpdate
    flow.triggerStatus(flow_consts.status_types.status_external_alert.status_id, ext_info.info, ext_info.severity --[[ specify a custom severity ]])
  end
end

-- #################################################################

return script
