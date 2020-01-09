--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")
local http_lint = require("http_lint")

local action = _POST["action"]

sendHTTPContentTypeHeader('application/json')

if(action == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'action' parameter. Bad CSRF?")
  return
end

if(not isAdministrator()) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Admin privileges required")
  return
end

-- ################################################

local result = {}

local confid = tonumber(_POST["confset_id"])

if(confid == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'confset_id' parameter")
  return
end

if(action == "delete") then
  local success, err = user_scripts.deleteConfigset(confid)
  result.success = success

  if not success then
    result.error = err
  end
elseif(action == "rename") then
  local new_name = _POST["confset_name"]

  if(new_name == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'newname' parameter")
    return
  end

  local success, err = user_scripts.renameConfigset(confid, new_name)
  result.success = success

  if not success then
    result.error = err
     -- Can be used to trigger a new request
     result.csrf = ntop.getRandomCSRFValue()
  end
elseif(action == "clone") then
  local new_name = _POST["confset_name"]

  if(new_name == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'confset_name' parameter")
    return
  end

  local success, err = user_scripts.cloneConfigset(confid, new_name)
  result.success = success

  if not success then
    result.error = err
    -- Can be used to trigger a new request
    result.csrf = ntop.getRandomCSRFValue()
  else
    result.config_id = err
  end
elseif(action == "set_targets") then
  local targets = _POST["confset_targets"]
  local subdir = _POST["script_subdir"]

  if(targets == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'confset_targets' parameter")
    return
  end

  if(subdir == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'script_subdir' parameter")
    return
  end

  local targets, err = http_lint.parseConfsetTargets(subdir, targets)

  if(targets ~= nil) then
    -- Validation ok
    local success, err = user_scripts.setConfigsetTargets(subdir, confid, targets)
    result.success = success

    if not success then
      result.error = err
    end
  else
    -- Validation error
    result.success = false
    result.error = err

    -- Can be used to trigger a new request
    result.csrf = ntop.getRandomCSRFValue()
  end
else
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown action '".. action .. "'")
  return
end

-- ################################################

print(json.encode(result))
