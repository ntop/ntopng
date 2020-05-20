--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

local system_interface_toggled = _POST["system_interface"]
local res = true

if system_interface_toggled then
   ntop.setPref("ntopng.prefs.system_mode_enabled", system_interface_toggled)
else
   res = false
end

print(json.encode({
    ["success"] = res
}))
