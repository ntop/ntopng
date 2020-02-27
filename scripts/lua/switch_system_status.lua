--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

local system_interface_toggled = _POST["system_interface"]

if (system_interface_toggled == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'system_interface_toggled' parameter")
    return
end

ntop.setPref("ntop.prefs.system_mode_enabled", system_interface_toggled)

print(json.encode({
    ["success"] = true,
    ["href"] = (system_interface_toggled == "1" and ntop.getHttpPrefix() .. "/lua/system_stats.lua" or "/"); 
}))