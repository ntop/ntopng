--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local checks = require("checks")
local alert_consts = require("alert_consts")

sendHTTPContentTypeHeader('application/json')

local subdir = _POST["check_subdir"]
local script_key = _POST["script_key"]
local action = _POST["action"]

if(not isAdministrator()) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Admin privileges required")
  return
end

-- ################################################

if(action == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'action' parameter")
  return
end

if(subdir == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'check_subdir' parameter")
  return
end

local script_type = checks.getScriptType(subdir)

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

local success, err = checks.toggleScript(script_key, subdir, (action == "enable"))

result.success = success

if not success then
  result.error = err
end

-- ################################################

print(json.encode(result))
