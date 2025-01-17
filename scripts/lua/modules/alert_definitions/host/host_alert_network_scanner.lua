local host_alert_keys = require "host_alert_keys"
local json = require("dkjson")
local alert_creators = require "alert_creators"
local classes = require "classes"
local alert = require "alert"

local host_alert_network_scanner = classes.class(alert)

host_alert_network_scanner.meta = {
    alert_key = host_alert_keys.host_alert_network_scanner,
    i18n_title = "alerts_dashboard.network_scanner_title",
    icon = "fas fa-fw fa-life-ring",
}

function host_alert_network_scanner:init(metric, value, operator, threshold)
    self.super:init()
    self.alert_type_params = alert_creators.createThresholdCross(metric, value, operator, threshold)
end

function host_alert_network_scanner.format(ifid, alert, alert_type_params)
    local alert_consts = require("alert_consts")
    local entity = alert_consts.formatHostAlert(ifid, alert["ip"], alert["vlan_id"])
    local value = string.format("%u", math.ceil(alert_type_params.num_flows_tokens or 0))
    return i18n("alerts_dashboard.http_contacts_message", {
        entity = entity,
        value = value,
        threshold = alert_type_params.threshold or 0,
    })
end

return host_alert_network_scanner