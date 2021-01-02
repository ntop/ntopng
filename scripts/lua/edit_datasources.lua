--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local datasources_utils = require("datasources_utils")
local http_lint = require("http_lint")

local action = _POST["action"]

local function reportError(msg)
    print(json.encode({ message = msg, success = false}))
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
}

if (action == "add") then
    response.success, response.message = datasources_utils.add_source(data.alias, tonumber(data.data_retention), data.scope, data.origin, data.schemas)
elseif (action == "edit") then
    response.success, response.message = datasources_utils.edit_source(data.hash, data.alias, tonumber(data.data_retention), data.scope, data.origin, data.schemas)
elseif (action == "remove") then
    response.success, response.message = datasources_utils.delete_source(data.ds_key)
else
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Invalid 'action' parameter.")
    response.success = false
    response.message = "Invalid 'action' parameter."
end


print(json.encode(response))
