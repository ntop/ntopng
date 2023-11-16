--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_network_issues = classes.class(alert)

-- ##############################################

alert_network_issues.meta = {
    alert_key = other_alert_keys.alert_network_issues,
    i18n_title = "alerts_dashboard.network_issues",
    icon = "fas fa-fw fa-exclamation",
    entities = {
        alert_entities.network,
    },
}

-- ##############################################

function alert_network_issues:init(lost, lost_threshold, retransmissions, retransmission_threshold, out_of_order, out_of_order_threshold)
   -- Call the parent constructor
  self.super:init()

  self.alert_type_params = {
    lost = lost,
    lost_threshold = lost_threshold,
    retransmissions = retransmissions,
    retransmission_threshold = retransmission_threshold,
    out_of_order = out_of_order,
    out_of_order_threshold = out_of_order_threshold
  }
end

-- #######################################################

function alert_network_issues.format(ifid, alert, alert_type_params)
  local msg = i18n("alert_messages.network_issues")
    
  -- check packet loss
  if alert_type_params.lost > alert_type_params.lost_threshold then
    msg = msg.."["..
          i18n("alert_messages.network_issues_packet_loss")..
          alert_type_params.lost.."% > "..
          alert_type_params.lost_threshold.."%]"
  end

  -- check retransmissions
  if alert_type_params.retransmissions > alert_type_params.retransmission_threshold then
    msg = msg .."["..
          i18n("alert_messages.network_issues_retransmissions")..
          alert_type_params.retransmissions.."% > "..
          alert_type_params.retransmission_threshold.."%]"
  end

  -- check out of orders
  if alert_type_params.out_of_order > alert_type_params.out_of_order_threshold then
    msg = msg.."["..
          i18n("alert_messages.network_issues_out_of_orders")..
          alert_type_params.out_of_order.."% > "..
          alert_type_params.out_of_order_threshold.."%]"
  end

  return msg
end

-- #######################################################

return alert_network_issues
