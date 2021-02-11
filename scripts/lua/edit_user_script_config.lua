--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")
local rest_utils = require "rest_utils"
local auth = require "auth"

-- ################################################

if not auth.has_capability(auth.capabilities.user_scripts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

sendHTTPContentTypeHeader('application/json')

local subdir = _POST["script_subdir"]
local confset_id = tonumber(_POST["confset_id"] or user_scripts.DEFAULT_CONFIGSET_ID)
local script_key = _POST["script_key"]
local alert_severity = _POST['alert_severity']
local alert_exclusion_list = _POST['alert_exclusion_list']

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
local success = false
local err = ""

local additional_params = {}
if alert_severity ~= nil then
  additional_params.severity = alert_consts.alertSeverityById(alert_severity)
end

local additional_filters = {}
if alert_exclusion_list ~= nil then
  success, additional_filters = user_scripts.parseFilterParams(alert_exclusion_list, subdir, true)

  if not success then
    err = additional_filters
    goto response
  end
end

success, err = user_scripts.updateScriptConfig(confset_id, script_key, subdir, data, additional_params, additional_filters)

::response::

result.success = success

if not success then
  result.error = err
end

-- ################################################

print(json.encode(result))
