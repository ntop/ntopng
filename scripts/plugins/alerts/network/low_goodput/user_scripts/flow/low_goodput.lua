--
-- (C) 2019-21 - ntop.org
--

local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"

-- #################################################################

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  packet_interface_only = true,
  nedge_exclude = true,
  l4_proto = "tcp",

  -- This script is only for alerts generation
  is_alert = true,

  default_value = {
    severity = alert_severities.notice,
  },

  
  -- For a full list check "available_subdir.flow.available_fields" in user_scripts.lua
  filter = {
    default_fields = { "srv_addr", "srv_port", "l7_proto", }
  },

  -- NOTE: hooks defined below
  hooks = {},

  gui = {
    i18n_title = "low_goodput.title",
    i18n_description = "low_goodput.description",
  }
}

-- #################################################################

local function checkFlowGoodput(now, conf)
   local ratio = flow.getGoodputRatio()
  
   if(ratio <= 60) then
      local cli_score, srv_score, flow_score = 10, 10, 10
      local alert = alert_consts.alert_types.alert_flow_low_goodput.new(
        ratio
      )

      alert:set_severity(conf.severity)

      alert:trigger_status(cli_score, srv_score, flow_score)
   end
end

-- #################################################################

script.hooks.periodicUpdate = checkFlowGoodput
script.hooks.flowEnd        = checkFlowGoodput

-- #################################################################

return script
