--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local user_scripts = require("user_scripts")

local script

-- #################################################################

local function request_reply_ratio(params)
  local info = params.entity_info

  -- {requests, replies}
  local to_check = {}

  if(info["dns"] ~= nil) then
    to_check["dns_sent"] = {info["dns"]["sent"]["num_queries"], (info["dns"]["rcvd"]["num_replies_ok"] + info["dns"]["rcvd"]["num_replies_error"])}
    to_check["dns_rcvd"] = {info["dns"]["rcvd"]["num_queries"], (info["dns"]["sent"]["num_replies_ok"] + info["dns"]["sent"]["num_replies_error"])}
  end

  if(info["http"] ~= nil) then
    to_check["http_sent"] = {info["http"]["sender"]["query"]["total"], info["http"]["receiver"]["response"]["total"]}
    to_check["http_rcvd"] = {info["http"]["receiver"]["query"]["total"], info["http"]["sender"]["response"]["total"]}
  end

  for key, values in pairs(to_check) do
    local to_check_key = script.key .. "__" .. key

    -- true to avoid generating an alert due to a value just restored from redis
    local skip_first = true
    local requests = alerts_api.host_delta_val(to_check_key .. "_requests", params.granularity, values[1], skip_first)
    local replies = alerts_api.host_delta_val(to_check_key .. "_replies", params.granularity, values[2], skip_first)
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

script = {
  key = "request_reply_ratio",
  local_only = true,
  nedge_exclude = true,

  hooks = {
    all = request_reply_ratio
  },

  default_values = {
    ["5mins"] = "request_reply_ratio;lt;50", -- 50%
  },

  gui = {
    i18n_title = "entity_thresholds.request_reply_ratio_title",
    i18n_description = "entity_thresholds.request_reply_ratio_description",
    i18n_field_unit = user_scripts.field_units.percentage,
    input_builder = user_scripts.threshold_cross_input_builder,
    field_max = 100,
    field_min = 1,
    field_operator = "lt";
  }
}

-- #################################################################

return script
