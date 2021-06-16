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

local subdir = _POST["check_subdir"] -- optional (all subdirs if not specified)
local action = _POST["action"] -- enable/disable

if(not isAdministrator()) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Admin privileges required")
  return
end

-- ################################################

if(action == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'action' parameter")
  return
end

local subdirs = {}
if(subdir == nil) then
  local all_subdirs = checks.listSubdirs()
  for _, subdir in ipairs(all_subdirs) do
    subdirs[#subdirs+1] = subdir.id
  end
else
  subdirs[#subdirs+1] = subdir
end

-- ################################################

local result = {}
local success

for _, subdir in ipairs(subdirs) do

  local script_type = checks.getScriptType(subdir)

  if(script_type == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad subdir: " .. subdir)
    return
  end

  local succ, err = checks.toggleAllScripts(subdir, (action == "enable"))

  if not succ then
    result.error = err
  end
end

if not result.error then
  result.success = true
end

-- ################################################

print(json.encode(result))
