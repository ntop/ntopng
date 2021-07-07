--
-- (C) 2013-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

local res = {success = false}

sendHTTPHeader('application/json')

if _POST["action"] == "toggle_theme" then
    -- does the user want to toggle theme?
    local enabled = toboolean(_POST['toggle_dark_theme'])
    -- set dark theme or the default one
    ntop.setPref("ntopng.user." .. _SESSION['user'] .. ".theme", (enabled and "dark" or "white"))
    res.success = true
elseif isAdministrator() then
   if _POST["action"] == "disable-telemetry-data" then
        ntop.setPref("ntopng.prefs.disable_telemetry_data_message", "1")
    elseif _POST["action"] == "host-id-message-warning" then
        local ifid = _POST["ifid"]
        ntop.setPref(string.format("ntopng.prefs.ifid_%u.disable_host_identifier_message",ifid), "1")
    elseif _POST["action"] == "influxdb-error-msg" then
        ntop.delCache("ntopng.cache.influxdb.last_error")
    elseif _POST["action"] == "flowdevice_timeseries" then
        ntop.setPref("ntopng.prefs.snmp_devices_rrd_creation", "1")
        ntop.setPref("ntopng.prefs.flow_device_port_rrd_creation", "1")
    elseif _POST["action"] == "flow_snmp_ratio" then
        ntop.setPref("ntopng.prefs.notifications.flow_snmp_ratio", "1")
    end
    res.success = true
end

print(json.encode(res))
