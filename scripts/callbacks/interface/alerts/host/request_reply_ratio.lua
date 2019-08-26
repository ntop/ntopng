--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

-- #################################################################

local function request_reply_ratio(params)
  local info = params.entity_info

  -- {requests, replies}
  local to_check = {}

  if(info["dns"] ~= nil) then
    to_check["dns_sent"] = {info["dns"]["sent"]["num_queries"], (info["dns"]["sent"]["num_replies_ok"] + info["dns"]["sent"]["num_replies_error"])}
    to_check["dns_rcvd"] = {info["dns"]["rcvd"]["num_queries"], (info["dns"]["rcvd"]["num_replies_ok"] + info["dns"]["rcvd"]["num_replies_error"])}
  end

  for key, values in pairs(to_check) do
    local requests = values[1]
    local replies = values[2]
    local ratio = (replies * 100) / (requests+1)
    local req_repl_type = alerts_api.requestReplyRatioType(key, requests, replies, params.granularity)

    -- 10: some meaningful value
    if((requests + replies > 10) and (ratio < tonumber(params.alert_config.edge))) then
      alerts_api.trigger(params.alert_entity, req_repl_type)
    else
      alerts_api.release(params.alert_entity, req_repl_type)
    end
  end
end

-- #################################################################

local check_module = {
  key = "request_reply_ratio",
  check_function = request_reply_ratio,
  default_value = "request_reply_ratio;lt;15", -- 15%
  local_only = true,

  granularity = {
     -- executed only in the minute-by-minute check
     "min"
  },

  gui = {
    i18n_title = "entity_thresholds.request_reply_ratio_title",
    i18n_description = "entity_thresholds.request_reply_ratio_description",
    i18n_field_unit = alert_consts.field_units.percentage,
    input_builder = alerts_api.threshold_cross_input_builder,
    field_max = 65535,
    field_min = 1,
    field_operator = "lt";
  }
}

-- #################################################################

function check_module.get_threshold_value(granularity, info)
  return(info["hits.syn_flood_attacker"] or 0)
end

-- #################################################################

return check_module
