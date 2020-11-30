--
-- (C) 2019-20 - ntop.org
--

local flow_consts = require("flow_consts")
local user_scripts = require("user_scripts")
local alerts_api = require "alerts_api"
local alert_severities = require "alert_severities"

-- #################################################################

local script = {
  -- Script category
  category = user_scripts.script_categories.network,

  packet_interface_only = true,
  nedge_exclude = true,
  l4_proto = "tcp",

  -- NOTE: hooks defined below
  hooks = {},

  gui = {
    i18n_title = "low_goodput.title",
    i18n_description = "low_goodput.description",
  }
}

-- #################################################################

local function checkFlowGoodput()
   local ratio = flow.getGoodputRatio()
  
   if(ratio <= 60) then
      local cli_score, srv_score, flow_score = 10, 10, 10
      alerts_api.trigger_status(flow_consts.status_types.status_low_goodput.create(ratio),
				alert_severities.notice,
				cli_score, srv_score, flow_score)
   end
end

-- #################################################################

script.hooks.periodicUpdate = checkFlowGoodput
script.hooks.flowEnd        = checkFlowGoodput

-- #################################################################

return script
