--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")
local subdir = _GET["script_subdir"]

sendHTTPContentTypeHeader('application/json')

if(subdir == nil) then
  traceError(TRACE_ERROR, TRACE_CONSOLE, "Missing 'script_subdir' parameter")
  return
end

local target_type = user_scripts.getSubdirTargetType(subdir)

local config_sets = user_scripts.getConfigsets()
local rv = {}

-- Only return the essential information
for _, configset in pairs(config_sets) do
  local targets = {}

  for _, target in ipairs(configset.targets[subdir] or {}) do
    local label = target

    if(target_type == "interface") then
      label = getHumanReadableInterfaceName(getInterfaceName(target))
    elseif(target_type == "network") then
      label = getLocalNetworkAlias(target)
    elseif(target_type == "cidr") then
      label = getHostAltName(target)
    end

    targets[#targets + 1] = {
      key = target,
      label = label,
    }
  end

  rv[#rv + 1] = {
    id = configset.id,
    name = configset.name,
    targets = targets,
  }
end

print(json.encode(rv))
