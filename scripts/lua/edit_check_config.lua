--
-- (C) 2019-22 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local checks = require("checks")
local alert_consts = require("alert_consts")
local rest_utils = require "rest_utils"
local auth = require "auth"

-- ################################################

if not auth.has_capability(auth.capabilities.checks) then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

-- ################################################

sendHTTPContentTypeHeader('application/json')

local subdir = _POST["check_subdir"]
local script_key = _POST["script_key"]

-- ################################################

if (_POST["JSON"] == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'JSON' parameter. Bad CSRF?")
    return
end

local data = json.decode(_POST["JSON"])

if (table.empty(data)) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad JSON in 'JSON' parameter")
    return
end

if (subdir == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'check_subdir' parameter")
    return
end

local script_type = checks.getScriptType(subdir)

if (script_type == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad subdir: " .. subdir)
    return
end

if (script_key == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing script_key parameter")
    return
end

-- ################################################

local result = {}
local success = false
local err = ""

success, err = checks.updateScriptConfig(script_key, subdir, data)

::response::

result.success = success

if not success then
    result.error = err
end

-- ################################################

print(json.encode(result))
