--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")

local action = _GET["action"]

sendHTTPContentTypeHeader('application/json')

if(action == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'action' parameter")
  return
end

-- ################################################

local result = {}

if(action == "add") then
  local name = _GET["confset_name"]

  if(name == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'confset_name' parameter")
    return
  end

  local confset, err = user_scripts.newConfigset(name)

  if(confset == nil) then
    result.error = err
  end
else
  local confid = _GET["confset_id"]

  if(confid == nil) then
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'confset_id' parameter")
    return
  end

  if(action == "delete") then
    local success, err = user_scripts.deleteConfigset(confid)

    if not success then
      result.error = err
    end
  elseif(action == "rename") then
    local new_name = _GET["confset_name"]

    if(new_name == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'newname' parameter")
      return
    end

    local success, err = user_scripts.renameConfigset(confid, new_name)

    if not success then
      result.error = err
    end
  elseif(action == "clone") then
    local new_name = _GET["confset_name"]

    if(new_name == nil) then
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'confset_name' parameter")
      return
    end

    local success, err = user_scripts.cloneConfigset(confid, new_name)

    if not success then
      result.error = err
    end
  else
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown action '".. action .. "'")
    return
  end
end

-- ################################################

print(json.encode(result))
