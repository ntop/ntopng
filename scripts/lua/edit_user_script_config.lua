--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")

sendHTTPContentTypeHeader('application/json')

local subdir = _POST["script_subdir"]
local confset_id = tonumber(_POST["confset_id"] or user_scripts.DEFAULT_CONFIGSET_ID)
local script_key = _POST["script_key"]

if(not isAdministrator()) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Admin privileges required")
  return
end

-- ################################################

if(_POST["JSON"] == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'JSON' parameter. Bad CSRF?")
  return
end

local data = json.decode(_POST["JSON"])

if(table.empty(data)) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad JSON in 'JSON' parameter")
  return
end

if(subdir == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'script_subdir' parameter")
  return
end

local script_type = user_scripts.getScriptType(subdir)

if(script_type == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad subdir: " .. subdir)
  return
end

if(script_key == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing script_key parameter")
  return
end

-- ################################################

local result = {}

local success, err = user_scripts.updateScriptConfig(confset_id, script_key, subdir, data)

result.success = success

if not success then
  result.error = err
end

-- ################################################

print(json.encode(result))
