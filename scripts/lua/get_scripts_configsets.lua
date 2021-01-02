--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")
local rest_utils = require "rest_utils"
local auth = require "auth"

if not auth.has_capability(auth.capabilities.user_scripts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local subdir = _GET["script_subdir"]

sendHTTPContentTypeHeader('application/json')

if(subdir == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'script_subdir' parameter")
  return
end

local script_type = user_scripts.script_types[subdir]
local config_sets = user_scripts.getConfigsets()
local rv = {}

-- Only return the essential information
for _, configset in pairs(config_sets) do
  local pools = {}

  if(script_type and script_type.default_config_only and (configset.id ~= user_scripts.DEFAULT_CONFIGSET_ID)) then
    -- Only return the default
    goto continue
  end

  local configset_pools = user_scripts.getConfigsetPools(subdir, configset.id)
  for _, configset_pool in pairs(configset_pools) do
     pools[#pools + 1] = {
	key = configset_pool["pool_id"],
	label = configset_pool["name"]
     }
  end

  rv[#rv + 1] = {
    id = configset.id,
    name = configset.name,
    pools = pools,
  }

  ::continue::
end

print(json.encode(rv))
