--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

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
}
