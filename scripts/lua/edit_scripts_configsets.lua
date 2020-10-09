--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")
local http_lint = require("http_lint")
local rest_utils = require "rest_utils"
local auth = require "auth"

-- ################################################

if not auth.has_capability(auth.capabilities.user_scripts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

local action = _POST["action"]

sendHTTPContentTypeHeader('application/json')

if(action == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'action' parameter. Bad CSRF?")
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
  else
     -- Unbind confid from all pools which are currently using it
     local pools_lua_utils = require "pools_lua_utils"
     pools_lua_utils.unbind_all_configset_id(confid)
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
  else
    result.config_id = err
  end
else
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown action '".. action .. "'")
  return
end

-- ################################################

print(json.encode(result))
