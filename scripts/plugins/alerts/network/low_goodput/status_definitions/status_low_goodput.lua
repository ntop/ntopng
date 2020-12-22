--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")
local format_utils = require("format_utils")

-- #################################################################

local function formatFlowLowGoodput(info)
   if info and info.goodput_ratio then
      return i18n("flow_details.flow_low_goodput", { ratio = format_utils.round(info.goodput_ratio, 2) })
   end

   return(i18n("alerts_dashboard.flow_low_goodput"))
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_low_goodput,
  alert_type = alert_consts.alert_types.alert_flow_low_goodput,
  i18n_title = "alerts_dashboard.flow_low_goodput",
  i18n_description = formatFlowLowGoodput
}
