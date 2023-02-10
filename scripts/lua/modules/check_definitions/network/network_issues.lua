--
-- (C) 2019-22 - ntop.org
--

local alert_consts = require("alert_consts")
local checks = require("checks")

local script = {

  -- Script category
  category = checks.check_categories.network,
  severity = alert_consts.get_printable_severities().error,

  anomaly_type_builder = alert_consts.alert_types.alert_network_issues.new,

  -- This module is disabled by default
  default_enabled = false,

  default_value = {
    retransmissions = {
      default_value = 15, -- 15%,
      field_min = 0, -- 0%
      field_max = 99, -- 99%
      field_operator = "gt";
      i18n_fields_unit = checks.field_units.percentage,
      title = i18n('retransmission')
    },
    out_of_orders = {
      default_value = 15, -- 15%,
      field_min = 0, -- 0%
      field_max = 99, -- 99%
      field_operator = "gt";
      i18n_fields_unit = checks.field_units.percentage,
      title = i18n('out_of_order')
    },
    packet_loss = {
      default_value = 15, -- 15%,
      field_min = 0, -- 0%
      field_max = 99, -- 99%
      field_operator = "gt";
      i18n_fields_unit = checks.field_units.percentage,
      title = i18n('packet_loss')
    },
  },

  hooks = {},

  -- Allow user script configuration from the GUI
  gui = {
    i18n_title = "entity_thresholds.network_issue_title",
    i18n_description = "entity_thresholds.network_issue_description",

    -- The input builder to use to draw the gui
    input_builder = "threshold_cross"
  }
}

-- #################################################################
local function check_network_issues(params)

  local tot_packets = params.entity_info.inner + params.entity_info.egress + params.entity_info.ingress

  local tot_retransmissions   = 0
  local tot_lost              = 0
  local tot_out_of_order      = 0
    
  -- counting inner traffic tcp packets
  if params.entity_info["tcpPacketStats.inner"] then

    for k,v in pairs(params.entity_info["tcpPacketStats.inner"]) do
      if k == "retransmissions" then
        tot_retransmissions = tot_retransmissions + v
      elseif k == "lost" then
        tot_lost = tot_lost + v
      elseif k == "out_of_order" then
        tot_out_of_order = tot_out_of_order + v
      end
    end

  end
  
  -- counting egress traffic tcp packets
  if params.entity_info["tcpPacketStats.egress"] then

    for k,v in pairs(params.entity_info["tcpPacketStats.egress"]) do
      if k == "retransmissions" then
        tot_retransmissions = tot_retransmissions + v
      elseif k == "lost" then
        tot_lost = tot_lost + v
      elseif k == "out_of_order" then
        tot_out_of_order = tot_out_of_order + v
      end
    end
  end

  -- counting ingress traffic tcp packets 
  if params.entity_info["tcpPacketStats.ingress"] then

    for k,v in pairs(params.entity_info["tcpPacketStats.ingress"]) do
      if k == "retransmissions" then
        tot_retransmissions = tot_retransmissions + v
      elseif k == "lost" then
        tot_lost = tot_lost + v
      elseif k == "out_of_order" then
        tot_out_of_order = tot_out_of_order + v
      end
    end
  end

  -- to percentage
  local lost = (100 * tot_lost) / tot_packets
  local out_of_orders = (100 * tot_out_of_order) / tot_packets
  local retransmissions = (100 * tot_retransmissions) / tot_packets

  -- take thresholds
  local retransmissions_threshold = (params.check_config.retransmissions.threshold or params.check_config.retransmissions.default_value)
  local out_of_orders_threshold = (params.check_config.out_of_orders.threshold or params.check_config.out_of_orders.default_value)
  local lost_threshold = (params.check_config.packet_loss.threshold or params.check_config.packet_loss.default_value)

  -- for debugging
  --tprint("tot_retransmissions: "..retransmissions.."%")
  --tprint("tot_lost: "..lost.."%")
  --tprint("tot_out_of_order: "..out_of_orders.."%")

  -- istantiate alert
  local alert = alert_consts.alert_types.alert_network_issues.new(
    lost,
    lost_threshold,
    retransmissions,
    retransmissions_threshold,
    out_of_orders,
    out_of_orders_threshold
  )
  
  alert:set_info(params)
  alert:set_subtype(params.entity_info.network_key)

  -- check for trigger alert
  if( lost > lost_threshold or 
      retransmissions > retransmissions_threshold or 
      out_of_orders > out_of_orders_threshold ) then

     -- calls Alert:trigger
     alert:trigger(params.alert_entity, nil, params.cur_alerts)
  else
     -- calls Alert:release
     alert:release(params.alert_entity, nil, params.cur_alerts)
  end

end

-- #################################################################

script.hooks.min = check_network_issues

-- #################################################################

return script
