--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")
local alert_consts = require("alert_consts")

sendHTTPContentTypeHeader('application/json')

local subdir = _POST["script_subdir"] -- optional (all subdirs if not specified)
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
  local all_subdirs = user_scripts.listSubdirs()
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

  local script_type = user_scripts.getScriptType(subdir)

  if(script_type == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Bad subdir: " .. subdir)
    return
  end

  local succ, err = user_scripts.toggleAllScripts(subdir, (action == "enable"))

  if not succ then
    result.error = err
  end
end

if not result.error then
  result.success = true
end

-- ################################################

print(json.encode(result))
