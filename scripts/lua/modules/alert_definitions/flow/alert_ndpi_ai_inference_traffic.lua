--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
local classes = require "classes"
local alert = require "alert"

-- ##############################################

local alert_ndpi_ai_inference_traffic = classes.class(alert)

-- ##############################################

alert_ndpi_ai_inference_traffic.meta = {
   alert_key  = flow_alert_keys.flow_alert_ndpi_ai_inference_traffic,
   i18n_title = "flow_risk.ndpi_ai_inference_traffic",
   icon = "fas fa-fw fa-info-circle",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_ai_inference_traffic:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_ndpi_ai_inference_traffic.format(ifid, alert, alert_type_params)
   return
end

-- #######################################################

return alert_ndpi_ai_inference_traffic
