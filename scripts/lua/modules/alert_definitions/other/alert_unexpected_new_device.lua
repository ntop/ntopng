--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local dirs = ntop.getDirs()
local other_alert_keys = require "other_alert_keys"
local alert_creators = require "alert_creators"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_unexpected_new_device = classes.class(alert)

-- ##############################################

alert_unexpected_new_device.meta = {
  alert_key = other_alert_keys.alert_unexpected_new_device,
  i18n_title = "unexpected_new_device.alert_unexpected_new_device_title",
  icon = "fas fa-fw fa-exclamation",
  entities = {
    alert_entities.mac
  },
}

-- ##############################################

function alert_unexpected_new_device:init(device, mac)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
    device = device,
    mac = mac,
   }
end

-- #######################################################

function alert_unexpected_new_device.format(ifid, alert, alert_type_params)
  -- Pro description
  if(ntop.isPro()) then
    package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
    local snmp_location = require "snmp_location"

    has_snmp_location = snmp_location.host_has_snmp_location(alert_type_params.mac)
    -- The host has an snmp location
    if has_snmp_location then
      local access_port = snmp_location.get_host_access_port(alert_type_params.mac)

      if access_port then
        return(i18n("unexpected_new_device.status_unexpected_new_device_description_pro", {
          mac_address = alert_type_params.device,
          host_url = getMacUrl(alert_type_params.mac),
          port = access_port.id,
	  port_url = snmpIfaceUrl(access_port.snmp_device_ip, access_port.id),
	  interface_name = access_port.name,
	  ip = access_port.snmp_device_ip,
	  ip_url = snmpDeviceUrl(access_port.snmp_device_ip), 
        }))
      end
    end
  end
  
  -- Non enterprise software or the host hasn't an snmp location
  return(i18n("unexpected_new_device.status_unexpected_new_device_description", {
    mac_address = alert_type_params.device,
    host_url = getMacUrl(alert_type_params.mac),
  }))
end

-- #######################################################

return alert_unexpected_new_device
