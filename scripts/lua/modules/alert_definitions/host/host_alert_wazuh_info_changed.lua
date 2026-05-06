--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local host_alert_keys = require("host_alert_keys")

-- Import the classes library.
local alert_creators = require("alert_creators")
local classes = require("classes")
-- Make sure to import the Superclass!
local alert = require("alert")
local alert_entities = require("alert_entities")

-- ##############################################

local host_alert_wazuh_info_changed = classes.class(alert)

host_alert_wazuh_info_changed.meta = {
	alert_key = host_alert_keys.host_alert_wazuh_info_changed,
	i18n_title = "alerts_dashboard.wazuh_info_changed",
	icon = "fas fa-fw fa-arrow-circle-up",
}

-- ##############################################

function host_alert_wazuh_info_changed:init(ifid, info)
	-- Call the parent constructor
	self.super:init()

	self.alert_type_params = {
		ifid = ifid,
		info = info,
	}
end

-- ##############################################

local function formatAlertMsg(info)
	local msg = i18n('alert_messages.wazuh_asset_info_changed')
   if not info then
      return msg
   end
   if info.new_open_ports and #info.new_open_ports > 0 then
      msg = string.format("%s[New Open Ports: %d]", msg, #info.new_open_ports)
   end
   if info.process_changed and #info.process_changed > 0 then
      msg = string.format("%s[Changed Processes: %d]", msg, #info.process_changed)
   end
   if info.old_ports_no_longer_open and #info.old_ports_no_longer_open > 0 then
      msg = string.format("%s[No Longer Open Ports: %d]", msg, #info.old_ports_no_longer_open)
   end
   if info.network_interface_removed and #info.network_interface_removed > 0 then
      msg = string.format("%s[Net. Interfaces Removed: %d]", msg, #info.network_interface_removed)
   end
   if info.network_interface_added and #info.network_interface_added > 0 then
      msg = string.format("%s[New Net. Interfaces: %d]", msg, #info.network_interface_added)
   end
	return msg
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function host_alert_wazuh_info_changed.format(ifid, alert, alert_type_params)
	return formatAlertMsg(alert_type_params.info or {})
end

-- #######################################################

return host_alert_wazuh_info_changed
