--
-- (C) 2019-20 - ntop.org
--

local alerts_api = require("alerts_api")
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local user_scripts = require("user_scripts")

local script

-- #################################################################

local function request_reply_ratio(params)
  local dns_info = host.getDNSInfo()
  local http_info = host.getHTTPInfo()

  -- {requests, replies}
  local to_check = {}

  if(dns_info["dns"] ~= nil) then
    to_check["dns_sent"] = {dns_info["dns"]["sent"]["num_queries"], (dns_info["dns"]["rcvd"]["num_replies_ok"] + dns_info["dns"]["rcvd"]["num_replies_error"])}
    to_check["dns_rcvd"] = {dns_info["dns"]["rcvd"]["num_queries"], (dns_info["dns"]["sent"]["num_replies_ok"] + dns_info["dns"]["sent"]["num_replies_error"])}
  end

  if(http_info["http"] ~= nil) then
    to_check["http_sent"] = {http_info["http"]["sender"]["query"]["total"], http_info["http"]["receiver"]["response"]["total"]}
    to_check["http_rcvd"] = {http_info["http"]["receiver"]["query"]["total"], http_info["http"]["sender"]["response"]["total"]}
  end

  for key, values in pairs(to_check) do
    local to_check_key = script.key .. "__" .. key

    -- true to avoid generating an alert due to a value just restored from redis
    local skip_first = true
    local requests = alerts_api.host_delta_val(to_check_key .. "_requests", params.granularity, values[1], skip_first)
    local replies = alerts_api.host_delta_val(to_check_key .. "_replies", params.granularity, values[2], skip_first)
    local ratio = (replies * 100) / (requests+1)
    local req_repl_type = alert_consts.alert_types.alert_request_reply_ratio.create(
       alert_severities.warning,
       alert_consts.alerts_granularities[params.granularity],
       key,
       requests,
       replies
    )

    -- 10: some meaningful value
    if((requests + replies > 10) and (ratio < tonumber(params.user_script_config.threshold))) then
      alerts_api.trigger(params.alert_entity, req_repl_type, nil, params.cur_alerts)
    else
      alerts_api.release(params.alert_entity, req_repl_type, nil, params.cur_alerts)
    end
  end
end

-- #################################################################

script = {
  -- Script category
  category = user_scripts.script_categories.network,

  local_only = true,
  nedge_exclude = true,
  default_enabled = true,

  -- This script is only for alerts generation
  is_alert = true,

  hooks = {
    ["5mins"] = request_reply_ratio
  },

  default_value = {
    -- "< 50%"
    operator = "lt",
    threshold = 50,
  },

  gui = {
    i18n_title = "entity_thresholds.request_reply_ratio_title",
    i18n_description = "entity_thresholds.request_reply_ratio_description",
    i18n_field_unit = user_scripts.field_units.percentage,
    input_builder = "threshold_cross",
    field_max = 100,
    field_min = 1,
    field_operator = "lt";
  }
}

-- #################################################################

return script
