--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

local res = {success = false}
local ifid = _POST["ifid"]

sendHTTPHeader('application/json')

if isAdministrator() then
  if _POST["action"] == "move-rrd-to-influxdb" then
    ntop.setPref("ntopng.prefs.disable_ts_migration_message", "1")
    res.success = true
  elseif _POST["action"] == "disable-telemetry-data" then
     ntop.setPref("ntopng.prefs.disable_telemetry_data_message", "1")
     res.success = true
  elseif _POST["action"] == "host-id-message-warning" then
    ntop.setPref(string.format("ntopng.prefs.ifid_%u.disable_host_identifier_message", ifid), "1")
    res.success = true
  end
end

print(json.encode(res))
