--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local plugins_utils = require "plugins_utils"
local notification_endpoints = require("notification_endpoints")

local action = _POST["action"]

local function reportError(msg)
    print(json.encode({ message = msg, success = false, }))
end

sendHTTPContentTypeHeader('application/json')

if (not isAdministrator()) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "The user doesn't have the privileges to edit a notification endpoint!")
    reportError("The user doesn't have the privileges to edit a notification endpoint!")
end

if (action == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'action' parameter. Bad CSRF?")
  reportError("Missing 'action' parameter. Bad CSRF?")
  return
end

local endpoint_conf_name = _POST["endpoint_conf_name"]
local response = {}

if (action == "add") then
    local endpoint_conf_type = _POST["endpoint_conf_type"]
    response.result = notification_endpoints.add_config(endpoint_conf_type, endpoint_conf_name, _POST)
elseif (action == "edit") then
    response.result = notification_endpoints.edit_config(endpoint_conf_name, _POST)
elseif (action == "remove") then
    response.result = notification_endpoints.delete_config(endpoint_conf_name)
end

print(json.encode(response))
