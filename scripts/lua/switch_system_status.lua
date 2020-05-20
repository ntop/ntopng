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
   local page_utils = require "page_utils"
   page_utils.set_system_view(system_interface_toggled)
else
   res = false
end

print(json.encode({
    ["success"] = res
}))
