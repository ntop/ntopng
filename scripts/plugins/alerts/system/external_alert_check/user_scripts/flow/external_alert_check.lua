--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local json = require ("dkjson")
local user_scripts = require ("user_scripts")
local alert_consts = require("alert_consts")
local alerts_api = require "alerts_api"

-- #################################################################

local script = {
  -- NOTE: hooks defined below
  hooks = {},

  gui = {
    i18n_title = "flow_callbacks_config.ext_alert",
    i18n_description = "flow_callbacks_config.ext_alert_description",
  }
}

-- #################################################################

local function checkExternalAlert()

  -- Check for external alert (clear on read, thus it will not be
  -- returned in the next call)
  local info_json = flow.retrieveExternalAlertInfo()

  if(info_json ~= nil) then
    -- Got an alert in JSON format, decoding
    local info = json.decode(info_json)
    if info ~= nil then
      -- Default scores used when no IDS utils is available
      local flow_score = 100
      local cli_score = 100
      local srv_score = 100

      local status_info = flow_consts.status_types.status_external_alert.create(
        info
      )

      if ntop.isEnterpriseM() then
        local ids_utils = require("ids_utils")

        if ids_utils and status_info.alert_type_params and
           status_info.alert_type_params.source == "suricata" then
           local fs, cs, ss = ids_utils.computeScore(status_info.alert_type_params)
           flow_score = fs
           cli_score = cs
           srv_score = ss
        end
      end

      -- Trigger flow alert
      alerts_api.trigger_status(status_info, alert_consts.alertSeverityById(info.severity_id), cli_score, srv_score, flow_score)
    end
  end
end

-- #################################################################

function script.hooks.periodicUpdate(now)
   checkExternalAlert()
end

-- #################################################################

function script.hooks.flowEnd(now, config)
   checkExternalAlert()
end

-- #################################################################

return script
