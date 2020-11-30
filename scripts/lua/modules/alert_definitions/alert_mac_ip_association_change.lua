--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param device The name of the device that changed MAC
-- @param ip The ip address of the device that changed MAC
-- @param old_mac The old MAC
-- @param new_mac The new MAC
-- @return A table with the alert built
local function createMmacIpAssociationChangeType(alert_severity, device, ip, old_mac, new_mac)
  local built = {
    alert_subtype = string.format("%s_%s_%s", ip, old_mac, new_mac),
    alert_severity = alert_severity,
    alert_type_params = {
       device = device,
       ip = ip,
       old_mac = old_mac,
       new_mac = new_mac,
    },
  }

  return built
end

-- #######################################################

local function macIpAssociationChangedFormatter(ifid, alert, info)
  return(i18n("alert_messages.mac_ip_association_change", {
    new_mac = info.new_mac, old_mac = info.old_mac,
    ip = info.ip, new_mac_url = getMacUrl(info.new_mac), old_mac_url = getMacUrl(info.old_mac)
  }))
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_mac_ip_association_change,
  i18n_title = "alerts_dashboard.mac_ip_association_change",
  icon = "fas fa-exchange-alt",
  i18n_description = macIpAssociationChangedFormatter,
  creator = createMmacIpAssociationChangeType,
}
