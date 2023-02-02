--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_vlan_bidirectional_traffic = classes.class(alert)

-- ##############################################

alert_vlan_bidirectional_traffic.meta = {
   alert_key = flow_alert_keys.flow_alert_vlan_bidirectional_traffic,
   i18n_title = "alerts_dashboard.vlan_bidirectional_traffic",
   icon = "fas fa-fw fa-exclamation",
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_vlan_bidirectional_traffic:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

function alert_vlan_bidirectional_traffic.format(ifid, alert, alert_type_params)
   
end

-- #######################################################

return alert_vlan_bidirectional_traffic


--
-- (C) 2019-20 - ntop.
