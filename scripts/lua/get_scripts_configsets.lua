--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local user_scripts = require("user_scripts")

local subdir = _GET["script_subdir"] or "host"

sendHTTPContentTypeHeader('application/json')

local config_sets = user_scripts.getConfigsets(subdir)
local rv = {}

-- Only return the essential information
for _, configset in pairs(config_sets) do
  rv[#rv + 1] = {
    id = configset.id,
    name = configset.name,
    targets = configset.targets,
  }
end

print(json.encode(rv))
