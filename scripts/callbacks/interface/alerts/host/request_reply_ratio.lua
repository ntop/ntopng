--
-- (C) 2019 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")

local check_module

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

  if(info["ICMPv4"] ~= nil) then
    local reqs = info["ICMPv4"]["8,0"]
    local repl = info["ICMPv4"]["0,0"]

    if((reqs ~= nil) and (repl ~= nil)) then
      to_check["icmp_echo_sent"] = {reqs["sent"], repl["rcvd"]}
      to_check["icmp_echo_rcvd"] = {reqs["rcvd"], repl["sent"]}
    end
  end

  for key, values in pairs(to_check) do
    local to_check_key = check_module.key .. "__" .. key

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

check_module = {
  key = "request_reply_ratio",
  check_function = request_reply_ratio,
  --~ default_value = "request_reply_ratio;lt;15", -- 15%
  local_only = true,

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
