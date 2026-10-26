
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint" -- also ntop_utils: isAdministrator()
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local network_config_utils = require "network_config_utils"

-- Only the posted lists are changed (http_lint drops the invalid ones)
for _, server in ipairs(network_config_utils.servers) do
   local value = _POST[server.key]

   if value then
      ntop.setCache(server.redis_key, (value:gsub("%s+", ""))) -- Remove the empty spaces
   end
end

ntop.reloadServersConfiguration()

rest_utils.answer(rest_utils.consts.success.ok, {})
