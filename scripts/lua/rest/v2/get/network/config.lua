--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils" -- isAdministrator()
local rest_utils = require "rest_utils"
local network_config_utils = require "network_config_utils"

--
-- The expected servers of Admin > Network Configuration, one entry per server
-- type (network_config_utils.servers): key, value_description (comma separated
-- IP[@VLAN] list) and the i18n keys of its title and description.
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/network/config.lua
--

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local res = {}

for _, server in ipairs(network_config_utils.servers) do
   res[#res + 1] = {
      key = server.key,
      value_description = ntop.getCache(server.redis_key) or "",
      i18n_title = server.i18n_title,
      i18n_description = server.i18n_description,
   }
end

rest_utils.answer(rest_utils.consts.success.ok, res)
