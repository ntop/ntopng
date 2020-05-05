--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local plugins_utils = require "plugins_utils"
local notification_endpoint_configs = plugins_utils.loadModule("notification_endpoints", "notification_endpoint_configs")

local action = _POST["action"]

local function reportError(msg)
    print(json.encode({ message = msg, success = false, csrf = ntop.getRandomCSRFValue() }))
end

sendHTTPContentTypeHeader('application/json')

if (action == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'action' parameter. Bad CSRF?")
  reportError("Missing 'action' parameter. Bad CSRF?")
  return
end

local json_data = _POST["JSON"]
local data = json.decode(json_data)

local response = {
    csrf = ntop.getRandomCSRFValue()
}

if (action == "add") then
    response.result = notification_endpoint_configs.add_endpoint_config(data.type, data.name, data.conf_params)
elseif (action == "edit") then
    response.result = notification_endpoint_configs.edit_endpoint_config_params(data.name, data.conf_params)
elseif (action == "remove") then
    response.result = notification_endpoint_configs.delete_endpoint_config(data.name)
else
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid 'action' parameter.")
    response.success = false
    response.message = "Invalid 'action' parameter."
end

print(json.encode(response))
