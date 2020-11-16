--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
local alert_keys = require "alert_keys"
local alert_creators = require "alert_creators"


-- #######################################################

local function formatUnexpectedNewDevice(ifid, alert, info)
  -- Pro description
  if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    local snmp_location = require "snmp_location"

    has_snmp_location = snmp_location.host_has_snmp_location(info.mac)
    -- The host has an snmp location
    if has_snmp_location then
      local access_port = snmp_location.get_host_access_port(info.mac)

      if access_port then
        return(i18n("unexpected_new_device.status_unexpected_new_device_description_pro", {
          device = info.device,
          host_url = getMacUrl(alert.alert_entity_val),
          snmp_url = snmpDeviceUrl(access_port.snmp_device_ip),
          device_ip = access_port.snmp_device_ip,
        }))
      end
    end
  end
  
  -- Non enterprise software or the host hasn't an snmp location
  return(i18n("unexpected_new_device.status_unexpected_new_device_description", {
    device = info.device,
    url = getMacUrl(alert.alert_entity_val),
  }))
end

-- ##############################################

local function createUnexpectedNewDevice(alert_severity, device, mac)
  local unexpected_new_device_type = {
    alert_severity = alert_severity,
    alert_type_params = {
       device = device,
       mac = mac,
    },
  }

  return unexpected_new_device_type
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_unexpected_new_device,
  i18n_title = "unexpected_new_device.alert_unexpected_new_device_title",
  i18n_description = formatUnexpectedNewDevice,
  icon = "fas fa-exclamation",
  creator = createUnexpectedNewDevice,
}
